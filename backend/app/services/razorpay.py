"""Razorpay (https://razorpay.com/docs/api/) — Orders + Checkout.

Flow:
1. Server creates an order for a plan in the customer's currency
   (services/pricing.py — decided here, never by the app).
2. App opens Razorpay Checkout with the order id → user pays (UPI/cards/…).
3. App sends back payment id + signature; we verify
   HMAC_SHA256(order_id + "|" + payment_id, key_secret) == signature.
4. The `payment.captured` / `order.paid` webhook does the same activation
   in case the app closes before step 3. Activation is idempotent.
"""

import hashlib
import hmac
import logging
import httpx

from ..config import Settings

log = logging.getLogger("nutrilens.payments")
API = "https://api.razorpay.com/v1"


class PaymentsUnavailable(Exception):
    pass


class PaymentGatewayError(Exception):
    pass


def configured(settings: Settings) -> bool:
    return bool(settings.razorpay_key_id and settings.razorpay_key_secret)


async def create_order(
    settings: Settings, amount_minor: int, currency: str, receipt: str, notes: dict[str, str]
) -> str:
    """Create a Razorpay order and return its id (order_…).

    Non-INR currencies require International Payments on the account.
    """
    if not configured(settings):
        raise PaymentsUnavailable("Payments aren't set up yet.")
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.post(
                f"{API}/orders",
                auth=(settings.razorpay_key_id, settings.razorpay_key_secret),
                json={
                    "amount": amount_minor,
                    "currency": currency,
                    "receipt": receipt[:40],
                    "notes": notes,
                },
            )
    except httpx.HTTPError as e:
        raise PaymentGatewayError("Couldn't reach Razorpay. Please try again.") from e
    if resp.status_code >= 400:
        log.error("Razorpay order error %s: %s", resp.status_code, resp.text[:300])
        raise PaymentGatewayError("Couldn't start the payment. Please try again.")
    order_id = resp.json().get("id")
    if not isinstance(order_id, str):
        raise PaymentGatewayError("Unexpected response from Razorpay.")
    return order_id


def _hmac(secret: str, message: bytes) -> str:
    return hmac.new(secret.encode(), message, hashlib.sha256).hexdigest()


def verify_payment_signature(settings: Settings, order_id: str, payment_id: str, signature: str) -> bool:
    if not settings.razorpay_key_secret:
        return False
    expected = _hmac(settings.razorpay_key_secret, f"{order_id}|{payment_id}".encode())
    return hmac.compare_digest(expected, signature)


def verify_webhook_signature(settings: Settings, body: bytes, signature: str) -> bool:
    if not settings.razorpay_webhook_secret:
        return False
    return hmac.compare_digest(_hmac(settings.razorpay_webhook_secret, body), signature)
