"""OTP delivery. `console` for development; `apitxt` or `twilio` for real SMS.

We always generate and verify our own codes, so the same OTP rules (rate
limits, attempts, expiry) apply whichever provider delivers them.
"""

import logging
from typing import Protocol

import httpx
import phonenumbers

from ..config import Settings

log = logging.getLogger("nutrilens.sms")


def otp_text(code: str) -> str:
    return f"{code} is your NutriLens code. It expires in 5 minutes."


class SmsSender(Protocol):
    async def send_otp(self, phone: str, code: str) -> None: ...


class SmsDeliveryError(Exception):
    pass


class ConsoleSms:
    async def send_otp(self, phone: str, code: str) -> None:
        log.warning("SMS to %s: %s", phone, otp_text(code))


class ApitxtSms:
    """APITxT unified OTP API: GET/POST {base}/api/sendOTP.

    Form fields: authkey, mobile (country code + number, no +), otp, country
    (code without +), channel, optional template_id. Success responses have
    "status": "success"; errors come back as {"status": "...", "message": "..."}
    (sometimes with HTTP 200), so the body is checked, not just the status code.
    """

    def __init__(self, settings: Settings, transport: httpx.AsyncBaseTransport | None = None) -> None:
        self._s = settings
        self._transport = transport

    async def send_otp(self, phone: str, code: str) -> None:
        num = phonenumbers.parse(phone)
        country = str(num.country_code)
        data = {
            "authkey": self._s.apitxt_auth_key,
            "mobile": f"{country}{num.national_number}",
            "otp": code,
            "country": country,
            "channel": self._s.apitxt_channel,
        }
        if self._s.apitxt_template_id and self._s.apitxt_channel == "sms":
            data["template_id"] = str(self._s.apitxt_template_id)
        try:
            async with httpx.AsyncClient(timeout=15, transport=self._transport) as client:
                resp = await client.post(f"{self._s.apitxt_base_url.rstrip('/')}/api/sendOTP", data=data)
            body = resp.json()
        except (httpx.HTTPError, ValueError) as e:
            log.error("APITxT request failed: %s", type(e).__name__)
            raise SmsDeliveryError("Could not send SMS") from e
        if resp.status_code >= 400 or not isinstance(body, dict) or body.get("status") != "success":
            # Never log the auth key; status + message are enough to debug.
            status = body.get("status") if isinstance(body, dict) else None
            message = body.get("message") if isinstance(body, dict) else None
            log.error("APITxT error %s: %s %s", resp.status_code, status, str(message)[:200])
            raise SmsDeliveryError("Could not send SMS")
        log.info("APITxT OTP sent: %s", (body.get("data") or {}).get("request_id"))


class TwilioSms:
    def __init__(self, settings: Settings) -> None:
        self._sid = settings.twilio_account_sid
        self._token = settings.twilio_auth_token
        # A Messaging Service SID routes to the right sender per country.
        self._service = settings.twilio_verify_service_sid

    async def send_otp(self, phone: str, code: str) -> None:
        url = f"https://api.twilio.com/2010-04-01/Accounts/{self._sid}/Messages.json"
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post(
                url,
                auth=(self._sid, self._token),
                data={"To": phone, "MessagingServiceSid": self._service, "Body": otp_text(code)},
            )
        if resp.status_code >= 400:
            log.error("Twilio error %s: %s", resp.status_code, resp.text[:300])
            raise SmsDeliveryError("Could not send SMS")


def sms_sender(settings: Settings) -> SmsSender:
    match settings.sms_provider:
        case "apitxt":
            return ApitxtSms(settings)
        case "twilio":
            return TwilioSms(settings)
        case _:
            return ConsoleSms()
