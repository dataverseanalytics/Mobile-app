"""APITxT OTP delivery (no network: httpx MockTransport)."""

from urllib.parse import parse_qs

import httpx
import pytest

from app.config import Settings
from app.services.sms import ApitxtSms, SmsDeliveryError


def settings(**kw) -> Settings:
    return Settings(sms_provider="apitxt", apitxt_auth_key="k123", **kw)


def transport(status: int, body: dict, seen: list):
    def handler(req: httpx.Request) -> httpx.Response:
        seen.append((req.url.path, {k: v[0] for k, v in parse_qs(req.content.decode()).items()}))
        return httpx.Response(status, json=body)

    return httpx.MockTransport(handler)


async def test_sends_country_code_and_number_without_plus():
    seen: list = []
    ok = {"status": "success", "message": "Sms OTP Sent Successfully", "data": {"request_id": "SMS-OTP-1"}}
    await ApitxtSms(settings(apitxt_template_id=42), transport(200, ok, seen)).send_otp("+919876543210", "482913")
    path, form = seen[0]
    assert path == "/api/sendOTP"
    assert form == {
        "authkey": "k123",
        "mobile": "919876543210",
        "otp": "482913",
        "country": "91",
        "channel": "sms",
        "template_id": "42",
    }


async def test_international_number():
    seen: list = []
    await ApitxtSms(settings(), transport(200, {"status": "success"}, seen)).send_otp("+14155551234", "1111")
    form = seen[0][1]
    assert form["mobile"] == "14155551234" and form["country"] == "1"
    assert "template_id" not in form


@pytest.mark.parametrize(
    ("status", "body"),
    [
        (200, {"status": "error", "message": "Missing mobile"}),  # errors can arrive with HTTP 200
        (401, {"status": "MISSING_AUTH", "message": "Authentication Key is required"}),
        (429, {"status": "error", "message": "Rate limit"}),
    ],
)
async def test_provider_errors_raise(status, body):
    with pytest.raises(SmsDeliveryError):
        await ApitxtSms(settings(), transport(status, body, [])).send_otp("+919876543210", "1234")


def test_apitxt_requires_key():
    with pytest.raises(ValueError):
        Settings(sms_provider="apitxt", apitxt_auth_key="")
