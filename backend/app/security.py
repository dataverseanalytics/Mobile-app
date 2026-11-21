import hashlib
import hmac
import secrets
from datetime import UTC, datetime, timedelta
from typing import Any

import bcrypt
import jwt

from .config import get_settings

settings = get_settings()
ALGORITHM = "HS256"


def hash_secret(value: str) -> str:
    """Keyed hash for OTP codes and refresh tokens (never stored in plain)."""
    return hmac.new(settings.jwt_secret.encode(), value.encode(), hashlib.sha256).hexdigest()


def constant_time_equal(a: str, b: str) -> bool:
    return hmac.compare_digest(a, b)


def new_otp(length: int) -> str:
    return "".join(secrets.choice("0123456789") for _ in range(length))


def new_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def _encode(claims: dict[str, Any], secret: str, ttl: timedelta) -> str:
    now = datetime.now(UTC)
    return jwt.encode({**claims, "iat": now, "exp": now + ttl}, secret, algorithm=ALGORITHM)


def create_access_token(user_id: str) -> str:
    return _encode(
        {"sub": user_id, "typ": "access"},
        settings.jwt_secret,
        timedelta(minutes=settings.access_token_minutes),
    )


def decode_access_token(token: str) -> str | None:
    try:
        claims = jwt.decode(token, settings.jwt_secret, algorithms=[ALGORITHM])
    except jwt.PyJWTError:
        return None
    return claims.get("sub") if claims.get("typ") == "access" else None


def create_admin_token(admin_id: str, role: str) -> str:
    return _encode(
        {"sub": admin_id, "role": role, "typ": "admin"},
        settings.admin_jwt_secret,
        timedelta(hours=settings.admin_token_hours),
    )


def decode_admin_token(token: str) -> dict[str, Any] | None:
    try:
        claims = jwt.decode(token, settings.admin_jwt_secret, algorithms=[ALGORITHM])
    except jwt.PyJWTError:
        return None
    return claims if claims.get("typ") == "admin" else None


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(password: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode(), hashed.encode())
    except ValueError:
        return False
