import uuid
from datetime import UTC, datetime, timedelta
from typing import Annotated, Any

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from .db import get_db
from .models import Admin, User
from .security import decode_access_token, decode_admin_token

bearer = HTTPBearer(auto_error=False)
Db = Annotated[AsyncSession, Depends(get_db)]


def _unauthorized(detail: str = "Not signed in") -> HTTPException:
    return HTTPException(
        status.HTTP_401_UNAUTHORIZED, detail, headers={"WWW-Authenticate": "Bearer"}
    )


async def current_user(
    db: Db,
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> User:
    if creds is None:
        raise _unauthorized()
    sub = decode_access_token(creds.credentials)
    if sub is None:
        raise _unauthorized("Session expired")
    try:
        user = await db.get(User, uuid.UUID(sub))
    except ValueError:
        user = None
    if user is None:
        raise _unauthorized("Account not found")
    if user.is_banned:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "This account has been suspended")
    now = datetime.now(UTC)
    if user.is_premium and user.premium_until is not None:
        until = user.premium_until if user.premium_until.tzinfo else user.premium_until.replace(tzinfo=UTC)
        if until <= now:
            user.is_premium = False
            await db.commit()
    # Cheap activity tracking for DAU stats (at most once a minute).
    last = user.last_seen_at if user.last_seen_at.tzinfo else user.last_seen_at.replace(tzinfo=UTC)
    if now - last > timedelta(minutes=1):
        user.last_seen_at = now
        await db.commit()
    return user


CurrentUser = Annotated[User, Depends(current_user)]


async def optional_user(
    db: Db,
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> User | None:
    """The signed-in user if a valid token was sent, else None (no error)."""
    sub = decode_access_token(creds.credentials) if creds else None
    if sub is None:
        return None
    try:
        return await db.get(User, uuid.UUID(sub))
    except ValueError:
        return None


OptionalUser = Annotated[User | None, Depends(optional_user)]


async def current_admin(
    db: Db,
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> Admin:
    claims: dict[str, Any] | None = decode_admin_token(creds.credentials) if creds else None
    if claims is None:
        raise _unauthorized("Admin sign-in required")
    admin = await db.get(Admin, uuid.UUID(claims["sub"]))
    if admin is None:
        raise _unauthorized("Admin not found")
    return admin


CurrentAdmin = Annotated[Admin, Depends(current_admin)]


async def owner_admin(admin: CurrentAdmin) -> Admin:
    if admin.role != "owner":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Only owners can do this")
    return admin


OwnerAdmin = Annotated[Admin, Depends(owner_admin)]
