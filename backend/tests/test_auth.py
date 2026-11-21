from httpx import AsyncClient

from .conftest import TEST_PHONE, sign_in


async def test_rejects_invalid_and_landline_numbers(client: AsyncClient) -> None:
    r = await client.post("/v1/auth/otp/request", json={"phone": "12345"})
    assert r.status_code == 422
    r = await client.post("/v1/auth/otp/request", json={"phone": "+999 1234 5678"})
    assert r.status_code == 422


async def test_normalises_numbers_from_any_country(client: AsyncClient) -> None:
    for raw, e164 in [
        ("+91 98765 43210", "+919876543210"),
        ("+44 7400 123456", "+447400123456"),
        ("+971 50 123 4567", "+971501234567"),
    ]:
        r = await client.post("/v1/auth/otp/request", json={"phone": raw})
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["phone"] == e164
        assert len(body["devCode"]) == 6  # shown only in dev/test with console SMS


async def test_full_sign_in_creates_user_once(client: AsyncClient) -> None:
    first = await sign_in(client)
    assert first["isNew"] is True
    assert first["user"]["phone"] == TEST_PHONE
    assert first["user"]["freeScansLeft"] == 3
    second = await sign_in(client)
    assert second["isNew"] is False
    assert second["user"]["id"] == first["user"]["id"]


async def test_wrong_code_counts_attempts_then_locks(client: AsyncClient) -> None:
    await client.post("/v1/auth/otp/request", json={"phone": TEST_PHONE})
    for _ in range(5):
        r = await client.post("/v1/auth/otp/verify", json={"phone": TEST_PHONE, "code": "000000"})
        assert r.status_code == 400
    r = await client.post("/v1/auth/otp/verify", json={"phone": TEST_PHONE, "code": "123456"})
    assert r.status_code == 429  # locked even with the right code


async def test_code_is_single_use(client: AsyncClient) -> None:
    await sign_in(client)
    r = await client.post("/v1/auth/otp/verify", json={"phone": TEST_PHONE, "code": "123456"})
    assert r.status_code == 400


async def test_refresh_rotates_tokens(client: AsyncClient) -> None:
    tokens = await sign_in(client)
    r = await client.post("/v1/auth/refresh", json={"refreshToken": tokens["refreshToken"]})
    assert r.status_code == 200
    # The old refresh token can't be reused.
    r = await client.post("/v1/auth/refresh", json={"refreshToken": tokens["refreshToken"]})
    assert r.status_code == 401


async def test_protected_routes_need_a_token(client: AsyncClient) -> None:
    assert (await client.get("/v1/me")).status_code == 401
    r = await client.get("/v1/me", headers={"Authorization": "Bearer nonsense"})
    assert r.status_code == 401
