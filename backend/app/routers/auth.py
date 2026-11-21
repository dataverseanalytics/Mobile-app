"""Phone OTP sign-in — one flow for new and returning users, worldwide."""

from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select, update

from .. import convert, schemas
from ..config import get_settings
from ..deps import Db
from ..models import Notice, OtpCode, RefreshToken, User
from ..security import (
    constant_time_equal,
    create_access_token,
    hash_secret,
    new_otp,
    new_refresh_token,
)
from ..services.app_config import get_config
from ..services.phone import InvalidPhone, normalize_phone
from ..services.sms import SmsDeliveryError, sms_sender

router = APIRouter(prefix="/v1/auth", tags=["auth"])
settings = get_settings()


def _now() -> datetime:
    return datetime.now(UTC)


def _phone(raw: str) -> tuple[str, str]:
    try:
        return normalize_phone(raw, frozenset(settings.otp_test_numbers))
    except InvalidPhone as e:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, str(e)) from e


@router.post("/otp/request", response_model=schemas.OtpRequestOut)
async def request_otp(body: schemas.OtpRequest, db: Db) -> schemas.OtpRequestOut:
    phone, _ = _phone(body.phone)
    now = _now()

    recent = (
        await db.execute(
            select(OtpCode)
            .where(OtpCode.phone == phone, OtpCode.created_at > now - timedelta(hours=1))
            .order_by(OtpCode.created_at.desc())
        )
    ).scalars().all()
    if len(recent) >= settings.otp_max_per_hour:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Too many codes requested. Please try again in an hour.",
        )
    if recent:
        last = convert.aware(recent[0].created_at)
        wait = settings.otp_resend_seconds - int((now - last).total_seconds())
        if wait > 0:
            raise HTTPException(
                status.HTTP_429_TOO_MANY_REQUESTS,
                f"Please wait {wait}s before requesting another code.",
                headers={"Retry-After": str(wait)},
            )

    is_test = phone in settings.otp_test_numbers
    code = settings.otp_test_code if is_test else new_otp(settings.otp_length)
    # Only the newest code is valid.
    await db.execute(
        update(OtpCode).where(OtpCode.phone == phone, OtpCode.consumed.is_(False)).values(consumed=True)
    )
    db.add(
        OtpCode(
            phone=phone,
            code_hash=hash_secret(code),
            expires_at=now + timedelta(seconds=settings.otp_ttl_seconds),
        )
    )
    await db.commit()

    if not is_test:
        try:
            await sms_sender(settings).send_otp(phone, code)
        except SmsDeliveryError as e:
            raise HTTPException(
                status.HTTP_502_BAD_GATEWAY, "We couldn't send the SMS. Please try again."
            ) from e

    show_code = settings.is_dev and settings.sms_provider == "console"
    return schemas.OtpRequestOut(
        phone=phone,
        expires_in=settings.otp_ttl_seconds,
        resend_in=settings.otp_resend_seconds,
        dev_code=code if show_code else None,
    )


async def _issue_tokens(db: Db, user: User, is_new: bool) -> schemas.TokenOut:
    refresh = new_refresh_token()
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_secret(refresh),
            expires_at=_now() + timedelta(days=settings.refresh_token_days),
        )
    )
    await db.commit()
    await db.refresh(user)
    return schemas.TokenOut(
        access_token=create_access_token(str(user.id)),
        refresh_token=refresh,
        expires_in=settings.access_token_minutes * 60,
        is_new=is_new,
        user=convert.user_out(user),
    )


@router.post("/otp/verify", response_model=schemas.TokenOut)
async def verify_otp(body: schemas.OtpVerify, db: Db) -> schemas.TokenOut:
    phone, country = _phone(body.phone)
    otp = (
        await db.execute(
            select(OtpCode)
            .where(OtpCode.phone == phone, OtpCode.consumed.is_(False))
            .order_by(OtpCode.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    if otp is None or convert.aware(otp.expires_at) < _now():
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "This code has expired. Request a new one."
        )
    if otp.attempts >= settings.otp_max_attempts:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS, "Too many wrong attempts. Request a new code."
        )
    if not constant_time_equal(otp.code_hash, hash_secret(body.code)):
        otp.attempts += 1
        await db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "That code isn't right.")

    otp.consumed = True
    user = (await db.execute(select(User).where(User.phone == phone))).scalar_one_or_none()
    is_new = user is None
    if user is None:
        config = await get_config(db)
        user = User(
            phone=phone,
            country=country,
            free_scans_left=int(config["free_scan_allowance"]),
        )
        db.add(user)
        await db.flush()
        db.add_all(
            [
                Notice(
                    id=f"welcome-{user.id}",
                    user_id=user.id,
                    kind="welcome",
                    title="Welcome to NutriLens",
                    body="Snap your first meal — we’ll count calories and macros for you.",
                ),
                Notice(
                    id=f"tip-light-{user.id}",
                    user_id=user.id,
                    kind="tip",
                    title="Tip: better photos, better numbers",
                    body="Shoot from above in good light and fit the whole plate in the frame.",
                    created_at=_now() - timedelta(minutes=1),
                ),
            ]
        )
    elif user.is_banned:
        await db.commit()
        raise HTTPException(status.HTTP_403_FORBIDDEN, "This account has been suspended")
    return await _issue_tokens(db, user, is_new)


@router.post("/refresh", response_model=schemas.TokenOut)
async def refresh(body: schemas.RefreshIn, db: Db) -> schemas.TokenOut:
    token = (
        await db.execute(
            select(RefreshToken).where(RefreshToken.token_hash == hash_secret(body.refresh_token))
        )
    ).scalar_one_or_none()
    if token is None or token.revoked or convert.aware(token.expires_at) < _now():
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Session expired. Please sign in again.")
    user = await db.get(User, token.user_id)
    if user is None or user.is_banned:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Session expired. Please sign in again.")
    token.revoked = True  # Rotation: each refresh token works once.
    return await _issue_tokens(db, user, is_new=False)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(body: schemas.RefreshIn, db: Db) -> None:
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.token_hash == hash_secret(body.refresh_token))
        .values(revoked=True)
    )
    await db.commit()

