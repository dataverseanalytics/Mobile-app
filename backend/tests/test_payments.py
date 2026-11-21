import hashlib
import hmac
import json
import uuid
from datetime import UTC, datetime, timedelta
from itertools import count

import pytest
from httpx import AsyncClient

from app.config import Settings
from app.db import SessionLocal
from app.models import User
from app.services import razorpay
from app.services.pricing import format_price, prices_for, tier_for_country

from .conftest import sign_in

KEY_SECRET = "rzp_test_secret"
WEBHOOK_SECRET = "rzp_webhook_secret"
_ids = count(1)
ORDERS: dict[str, tuple[int, str]] = {}


@pytest.fixture(autouse=True)
def fake_razorpay(monkeypatch: pytest.MonkeyPatch) -> None:
    """Stand-in for Razorpay's Orders API (no network). Records amounts."""

    async def create_order(
        settings: Settings, amount_minor: int, currency: str, receipt: str, notes: dict[str, str]
    ) -> str:
        order_id = f"order_test{next(_ids)}"
        ORDERS[order_id] = (amount_minor, currency)
        return order_id

    monkeypatch.setattr(razorpay, "create_order", create_order)


async def user_from(client: AsyncClient, phone: str) -> dict[str, str]:
    """Sign in a real (non-test) number through the dev-code path."""
    code = (await client.post("/v1/auth/otp/request", json={"phone": phone})).json()["devCode"]
    tokens = (await client.post("/v1/auth/otp/verify", json={"phone": phone, "code": code})).json()
    return {"Authorization": f"Bearer {tokens['accessToken']}"}


@pytest.fixture
async def indian(client: AsyncClient) -> dict[str, str]:
    return await user_from(client, "+919876543210")


def sign(order_id: str, payment_id: str) -> str:
    return hmac.new(KEY_SECRET.encode(), f"{order_id}|{payment_id}".encode(), hashlib.sha256).hexdigest()


async def buy(client: AsyncClient, headers: dict[str, str], plan: str) -> tuple[str, dict[str, object]]:
    order = (await client.post("/v1/payments/order", headers=headers, json={"plan": plan})).json()
    payment_id = f"pay_{order['orderId']}"
    r = await client.post(
        "/v1/payments/verify",
        headers=headers,
        json={"orderId": order["orderId"], "paymentId": payment_id, "signature": sign(order["orderId"], payment_id)},
    )
    assert r.status_code == 200, r.text
    return order["orderId"], r.json()


# ── Regional pricing ─────────────────────────────────────────────────────────


def test_country_to_price_tier() -> None:
    assert tier_for_country("IN").currency == "INR"
    assert tier_for_country("DE").currency == "EUR"
    assert tier_for_country("FR").id == "EU"
    assert tier_for_country("GB").currency == "GBP"
    assert tier_for_country("PK").id == "EMERGING"
    assert tier_for_country("JP").id == "US"  # everywhere else: USD
    assert tier_for_country(None).id == "US"
    assert format_price(tier_for_country("IN"), 249_900) == "₹2,499"
    assert format_price(tier_for_country("US"), 3_999) == "$39.99"


def test_yearly_shows_monthly_equivalent() -> None:
    yearly = prices_for("IN")[0]
    assert (yearly.plan, yearly.label, yearly.per_month_label) == ("yearly", "₹2,499", "₹208")
    assert prices_for("IN")[1].per_month_label is None


async def test_plans_follow_the_signed_in_users_phone_country(
    client: AsyncClient, indian: dict[str, str], user_headers: dict[str, str]
) -> None:
    inr = (await client.get("/v1/payments/plans", headers=indian)).json()
    assert [p["id"] for p in inr] == ["yearly", "monthly", "weekly"]
    assert (inr[0]["currency"], inr[0]["amountMinor"], inr[0]["priceLabel"]) == ("INR", 249_900, "₹2,499")

    usd = (await client.get("/v1/payments/plans", headers=user_headers)).json()  # +1 test number
    assert (usd[0]["currency"], usd[0]["priceLabel"]) == ("USD", "$39.99")

    # A signed-in user can't pick a cheaper country with ?country=.
    forced = (await client.get("/v1/payments/plans?country=PK", headers=indian)).json()
    assert forced[0]["currency"] == "INR"


async def test_signed_out_visitors_can_preview_by_country(client: AsyncClient) -> None:
    eur = (await client.get("/v1/payments/plans?country=DE")).json()
    assert eur[0]["priceLabel"] == "€39.99"
    default = (await client.get("/v1/payments/plans")).json()
    assert default[0]["currency"] == "USD"


async def test_order_is_charged_in_local_currency(
    client: AsyncClient, indian: dict[str, str], user_headers: dict[str, str]
) -> None:
    inr = (await client.post("/v1/payments/order", headers=indian, json={"plan": "monthly"})).json()
    assert (inr["currency"], inr["amountMinor"]) == ("INR", 69_900)
    assert ORDERS[inr["orderId"]] == (69_900, "INR"), "Razorpay is asked for exactly this"
    assert inr["prefillContact"] == "+919876543210"

    usd = (await client.post("/v1/payments/order", headers=user_headers, json={"plan": "monthly"})).json()
    assert (usd["currency"], usd["amountMinor"]) == ("USD", 799)

    bad = await client.post("/v1/payments/order", headers=indian, json={"plan": "lifetime"})
    assert bad.status_code == 422


# ── Purchase flow ────────────────────────────────────────────────────────────


async def test_verified_payment_unlocks_pro_once(client: AsyncClient, indian: dict[str, str]) -> None:
    order_id, user = await buy(client, indian, "yearly")
    assert user["isPremium"] is True
    until = datetime.fromisoformat(str(user["premiumUntil"]))
    assert timedelta(days=364) < until - datetime.now(UTC) <= timedelta(days=365)

    payment_id = f"pay_{order_id}"
    again = await client.post(
        "/v1/payments/verify",
        headers=indian,
        json={"orderId": order_id, "paymentId": payment_id, "signature": sign(order_id, payment_id)},
    )
    assert again.json()["premiumUntil"] == user["premiumUntil"]

    notices = (await client.get("/v1/notices", headers=indian)).json()
    assert any(n["kind"] == "pro" for n in notices)
    history = (await client.get("/v1/payments", headers=indian)).json()
    assert [(p["plan"], p["currency"], p["amountMinor"]) for p in history] == [("yearly", "INR", 249_900)]


async def test_rejects_forged_signature_and_other_users_orders(
    client: AsyncClient, indian: dict[str, str], user_headers: dict[str, str]
) -> None:
    order = (await client.post("/v1/payments/order", headers=indian, json={"plan": "weekly"})).json()
    forged = await client.post(
        "/v1/payments/verify",
        headers=indian,
        json={"orderId": order["orderId"], "paymentId": "pay_x", "signature": "0" * 64},
    )
    assert forged.status_code == 400

    r = await client.post(
        "/v1/payments/verify",
        headers=user_headers,
        json={"orderId": order["orderId"], "paymentId": "pay_x", "signature": sign(order["orderId"], "pay_x")},
    )
    assert r.status_code == 404


async def test_buying_again_extends_from_current_end(client: AsyncClient, indian: dict[str, str]) -> None:
    _, first = await buy(client, indian, "weekly")
    _, second = await buy(client, indian, "weekly")
    a = datetime.fromisoformat(str(first["premiumUntil"]))
    b = datetime.fromisoformat(str(second["premiumUntil"]))
    assert abs((b - a) - timedelta(days=7)) < timedelta(seconds=5)


def webhook_body(order_id: str, amount: int, currency: str, event: str = "payment.captured") -> bytes:
    entity = {"id": "pay_wh1", "order_id": order_id, "amount": amount, "currency": currency}
    return json.dumps({"event": event, "payload": {"payment": {"entity": entity}}}).encode()


def webhook_sig(body: bytes) -> str:
    return hmac.new(WEBHOOK_SECRET.encode(), body, hashlib.sha256).hexdigest()


async def post_webhook(client: AsyncClient, body: bytes, sig: str | None = None) -> int:
    r = await client.post(
        "/v1/webhooks/razorpay", content=body, headers={"X-Razorpay-Signature": sig or webhook_sig(body)}
    )
    return r.status_code


async def test_webhook_activates_when_app_never_verifies(
    client: AsyncClient, user_headers: dict[str, str]
) -> None:
    order = (await client.post("/v1/payments/order", headers=user_headers, json={"plan": "monthly"})).json()
    body = webhook_body(order["orderId"], 799, "USD")
    assert await post_webhook(client, body, "nope") == 401

    # Wrong amount or currency is ignored.
    await post_webhook(client, webhook_body(order["orderId"], 100, "USD"))
    await post_webhook(client, webhook_body(order["orderId"], 799, "INR"))
    assert (await client.get("/v1/me", headers=user_headers)).json()["isPremium"] is False

    assert await post_webhook(client, body) == 204
    assert (await client.get("/v1/me", headers=user_headers)).json()["isPremium"] is True


async def test_expired_pass_switches_pro_off(client: AsyncClient, user_headers: dict[str, str]) -> None:
    tokens = await sign_in(client)
    async with SessionLocal() as db:
        user = await db.get(User, uuid.UUID(str(tokens["user"]["id"])))  # type: ignore[index]
        assert user is not None
        user.is_premium = True
        user.premium_until = datetime.now(UTC) - timedelta(minutes=1)
        await db.commit()
    assert (await client.get("/v1/me", headers=user_headers)).json()["isPremium"] is False


async def test_admin_sees_revenue_per_currency(
    client: AsyncClient,
    indian: dict[str, str],
    user_headers: dict[str, str],
    admin_headers: dict[str, str],
) -> None:
    await buy(client, indian, "yearly")
    await buy(client, user_headers, "monthly")
    await client.post("/v1/payments/order", headers=indian, json={"plan": "weekly"})  # unpaid

    stats = (await client.get("/v1/admin/stats", headers=admin_headers)).json()
    revenue = {r["currency"]: r["amountMinor"] for r in stats["revenueMonth"]}
    assert revenue == {"INR": 249_900, "USD": 799}
    assert stats["paymentsMonth"] == 2

    paid = (await client.get("/v1/admin/payments", headers=admin_headers)).json()
    assert {(p["currency"], p["amountMinor"]) for p in paid["items"]} == {("INR", 249_900), ("USD", 799)}
    everything = (await client.get("/v1/admin/payments?status=all", headers=admin_headers)).json()
    assert everything["total"] == 3


def test_payments_need_keys() -> None:
    assert razorpay.configured(Settings(razorpay_key_id="", razorpay_key_secret="")) is False
