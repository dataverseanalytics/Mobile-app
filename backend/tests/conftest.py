import os

# Configure before the app (and its engine) are imported.
os.environ.update(
    {
        "ENV": "test",
        "DATABASE_URL": "sqlite+aiosqlite:///./test.db",
        "JWT_SECRET": "test-secret-test-secret-test-secret-32b",
        "ADMIN_JWT_SECRET": "test-admin-secret-test-admin-secret-32b",
        "SMS_PROVIDER": "console",
        "SCAN_PROVIDER": "mock",
        "OTP_TEST_NUMBERS": '["+15005550006"]',
        "OTP_RESEND_SECONDS": "0",
        "RAZORPAY_KEY_ID": "rzp_test_key",
        "RAZORPAY_KEY_SECRET": "rzp_test_secret",
        "RAZORPAY_WEBHOOK_SECRET": "rzp_webhook_secret",
    }
)

from collections.abc import AsyncIterator  # noqa: E402

import pytest  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402

from app.db import Base, SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.models import Admin  # noqa: E402
from app.security import hash_password  # noqa: E402

TEST_PHONE = "+15005550006"  # Always accepts OTP_TEST_CODE (123456).


@pytest.fixture(autouse=True)
async def fresh_db() -> AsyncIterator[None]:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield


@pytest.fixture
async def client() -> AsyncIterator[AsyncClient]:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c


async def sign_in(client: AsyncClient, phone: str = TEST_PHONE) -> dict[str, object]:
    r = await client.post("/v1/auth/otp/request", json={"phone": phone})
    assert r.status_code == 200, r.text
    r = await client.post("/v1/auth/otp/verify", json={"phone": phone, "code": "123456"})
    assert r.status_code == 200, r.text
    return r.json()


@pytest.fixture
async def user_headers(client: AsyncClient) -> dict[str, str]:
    tokens = await sign_in(client)
    return {"Authorization": f"Bearer {tokens['accessToken']}"}


@pytest.fixture
async def admin_headers(client: AsyncClient) -> dict[str, str]:
    async with SessionLocal() as db:
        db.add(Admin(email="owner@test.dev", role="owner", password_hash=hash_password("Password123!")))
        await db.commit()
    r = await client.post(
        "/v1/admin/auth/login", json={"email": "owner@test.dev", "password": "Password123!"}
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['accessToken']}"}
