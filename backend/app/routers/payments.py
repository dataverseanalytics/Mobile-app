"""Pro passes paid with Razorpay (UPI, cards, net banking, wallets)."""

import json
import logging
from datetime import UTC, datetime, timedelta
from typing import Annotated, Any

from fastapi import APIRouter, Header, HTTPException, Query, Request, status
from pydantic import Field
from sqlalchemy import select

from .. import convert, schemas
from ..config import get_settings
from ..deps import CurrentUser, Db, OptionalUser
from ..models import Notice, Payment, User
from ..schemas import Camel
from ..services import razorpay
from ..services.pricing import PLAN_DAYS, price_for, prices_for
from ..services.razorpay import PaymentGatewayError, PaymentsUnavailable

log = logging.getLogger("nutrilens.payments")
settings = get_settings()
router = APIRouter(prefix="/v1", tags=["payments"])


class PlanOut(Camel):
    id: str
    name: str
    days: int
    currency: str
    amount_minor: int
    price_label: str
    per_month_label: str | None


class OrderIn(Camel):
    plan: str = Field(pattern="^(weekly|monthly|yearly)$")


class OrderOut(Camel):
    """Everything Razorpay Checkout needs (key id is public by design)."""

    order_id: str
    key_id: str
    amount_minor: int
    currency: str
    name: str
    description: str
    prefill_contact: str
    prefill_email: str


class VerifyIn(Camel):
    order_id: str = Field(max_length=64)
    payment_id: str = Field(max_length=64)
    signature: str = Field(max_length=128)


class PaymentOut(Camel):
    id: str
    plan: str
    currency: str
    amount_minor: int
    status: str
    created_at: datetime
    paid_at: datetime | None


def _now() -> datetime:
    return datetime.now(UTC)


async def activate(db: Db, payment: Payment, payment_id: str) -> None:
    """Mark paid and extend Pro. Safe to call twice (app verify + webhook)."""
    if payment.status == "paid":
        return
    days = PLAN_DAYS[payment.plan]
    payment.status = "paid"
    payment.payment_id = payment_id
    payment.paid_at = _now()
    user = await db.get(User, payment.user_id) if payment.user_id else None
    if user is not None:
        current = convert.aware(user.premium_until) if user.premium_until else None
        start = current if current and current > _now() else _now()
        user.premium_until = start + timedelta(days=days)
        user.is_premium = True
        db.add(
            Notice(
                id=f"pro-{payment.order_id}",
                user_id=user.id,
                kind="pro",
                title="Welcome to NutriLens Pro",
                body=f"Unlimited scans are on until {user.premium_until:%d %b %Y}. Thanks for your support!",
            )
        )
    await db.commit()


@router.get("/payments/plans", response_model=list[PlanOut])
async def plans(
    user: OptionalUser,
    country: Annotated[str | None, Query(min_length=2, max_length=2)] = None,
) -> list[PlanOut]:
    """Prices in the customer's currency. Signed in: from their verified
    phone number's country. Otherwise `?country=IN` (e.g. the website)."""
    code = user.country if user is not None and user.country else country
    return [
        PlanOut(
            id=p.plan,
            name=p.name,
            days=p.days,
            currency=p.currency,
            amount_minor=p.amount_minor,
            price_label=p.label,
            per_month_label=p.per_month_label,
        )
        for p in prices_for(code)
    ]


@router.post("/payments/order", response_model=OrderOut)
async def create_order(body: OrderIn, user: CurrentUser, db: Db) -> OrderOut:
    price = price_for(user.country, body.plan)  # locked to the verified phone's country
    try:
        order_id = await razorpay.create_order(
            settings,
            price.amount_minor,
            price.currency,
            receipt=f"nl-{user.id.hex[:12]}-{int(_now().timestamp())}",
            notes={"user_id": str(user.id), "plan": price.plan, "country": user.country},
        )
    except PaymentsUnavailable as e:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, str(e)) from e
    except PaymentGatewayError as e:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, str(e)) from e
    db.add(
        Payment(
            user_id=user.id,
            plan=price.plan,
            amount_minor=price.amount_minor,
            currency=price.currency,
            order_id=order_id,
        )
    )
    await db.commit()
    return OrderOut(
        order_id=order_id,
        key_id=settings.razorpay_key_id,
        amount_minor=price.amount_minor,
        currency=price.currency,
        name="NutriLens",
        description=f"{price.name} · {price.label}",
        prefill_contact=user.phone,
        prefill_email=user.email,
    )


@router.post("/payments/verify", response_model=schemas.UserOut)
async def verify(body: VerifyIn, user: CurrentUser, db: Db) -> schemas.UserOut:
    payment = (
        await db.execute(select(Payment).where(Payment.order_id == body.order_id))
    ).scalar_one_or_none()
    if payment is None or payment.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Payment not found")
    if not razorpay.verify_payment_signature(settings, body.order_id, body.payment_id, body.signature):
        log.warning("Bad Razorpay signature for order %s", body.order_id)
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "We couldn't verify this payment.")
    await activate(db, payment, body.payment_id)
    await db.refresh(user)
    return convert.user_out(user)


@router.get("/payments", response_model=list[PaymentOut])
async def my_payments(user: CurrentUser, db: Db) -> list[PaymentOut]:
    rows = (
        await db.execute(
            select(Payment)
            .where(Payment.user_id == user.id, Payment.status == "paid")
            .order_by(Payment.created_at.desc())
        )
    ).scalars().all()
    return [
        PaymentOut(
            id=str(p.id),
            plan=p.plan,
            currency=p.currency,
            amount_minor=p.amount_minor,
            status=p.status,
            created_at=convert.aware(p.created_at),
            paid_at=convert.aware(p.paid_at) if p.paid_at else None,
        )
        for p in rows
    ]


@router.post("/webhooks/razorpay", status_code=status.HTTP_204_NO_CONTENT)
async def razorpay_webhook(
    request: Request,
    db: Db,
    x_razorpay_signature: Annotated[str | None, Header()] = None,
) -> None:
    """Dashboard → Webhooks → events `payment.captured`, `order.paid`, `payment.failed`."""
    body = await request.body()
    if not x_razorpay_signature or not razorpay.verify_webhook_signature(settings, body, x_razorpay_signature):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Bad webhook signature")
    try:
        event: dict[str, Any] = json.loads(body)
    except json.JSONDecodeError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid JSON") from e

    entity = event.get("payload", {}).get("payment", {}).get("entity", {})
    order_id = entity.get("order_id")
    payment_id = entity.get("id")
    if not isinstance(order_id, str) or not isinstance(payment_id, str):
        return  # Not an order payment we track.
    payment = (
        await db.execute(select(Payment).where(Payment.order_id == order_id))
    ).scalar_one_or_none()
    if payment is None:
        return
    kind = event.get("event")
    if kind in {"payment.captured", "order.paid"}:
        if entity.get("amount") not in (None, payment.amount_minor) or entity.get(
            "currency", payment.currency
        ) != payment.currency:
            log.error("Amount mismatch on %s", order_id)
            return
        await activate(db, payment, payment_id)
    elif kind == "payment.failed" and payment.status != "paid":
        payment.status = "failed"
        await db.commit()
