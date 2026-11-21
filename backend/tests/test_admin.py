from httpx import AsyncClient

from .conftest import sign_in


async def test_admin_login_rejects_wrong_password(client: AsyncClient, admin_headers: dict[str, str]) -> None:
    r = await client.post("/v1/admin/auth/login", json={"email": "owner@test.dev", "password": "nope"})
    assert r.status_code == 401


async def test_app_tokens_cannot_use_admin_api(client: AsyncClient, user_headers: dict[str, str]) -> None:
    assert (await client.get("/v1/admin/stats", headers=user_headers)).status_code == 401


async def test_stats_and_user_management(client: AsyncClient, admin_headers: dict[str, str]) -> None:
    tokens = await sign_in(client)
    user_id = tokens["user"]["id"]  # type: ignore[index]

    stats = (await client.get("/v1/admin/stats", headers=admin_headers)).json()
    assert stats["totalUsers"] == 1
    assert len(stats["signups"]) == 30

    page = (await client.get("/v1/admin/users?q=5005", headers=admin_headers)).json()
    assert page["total"] == 1

    r = await client.patch(
        f"/v1/admin/users/{user_id}", headers=admin_headers, json={"isPremium": True, "freeScansLeft": 10}
    )
    assert r.json()["user"]["isPremium"] is True

    # Banning blocks the app immediately.
    await client.patch(f"/v1/admin/users/{user_id}", headers=admin_headers, json={"isBanned": True})
    app_headers = {"Authorization": f"Bearer {tokens['accessToken']}"}
    assert (await client.get("/v1/me", headers=app_headers)).status_code == 403


async def test_food_crud_feeds_app_search(
    client: AsyncClient, admin_headers: dict[str, str], user_headers: dict[str, str]
) -> None:
    r = await client.post(
        "/v1/admin/foods",
        headers=admin_headers,
        json={"name": "Chole bhature", "unit": "1 plate", "macros": {"p": 14, "c": 70, "f": 28}},
    )
    assert r.status_code == 201
    food_id = r.json()["id"]
    found = (await client.get("/v1/foods?q=chole", headers=user_headers)).json()
    assert found[0]["name"] == "Chole bhature"

    await client.put(
        f"/v1/admin/foods/{food_id}",
        headers=admin_headers,
        json={"name": "Chole bhature", "unit": "1 plate", "macros": {"p": 14, "c": 70, "f": 28}, "isActive": False},
    )
    assert (await client.get("/v1/foods?q=chole", headers=user_headers)).json() == []


async def test_broadcast_reaches_users(
    client: AsyncClient, admin_headers: dict[str, str], user_headers: dict[str, str]
) -> None:
    r = await client.post(
        "/v1/admin/broadcasts",
        headers=admin_headers,
        json={"title": "New: barcode scanning", "body": "Scan packaged food for exact numbers."},
    )
    assert r.json()["recipients"] == 1
    notices = (await client.get("/v1/notices", headers=user_headers)).json()
    assert notices[0]["title"] == "New: barcode scanning"


async def test_config_validation_and_public_read(client: AsyncClient, admin_headers: dict[str, str]) -> None:
    bad = await client.put("/v1/admin/config", headers=admin_headers, json={"free_scan_allowance": -1})
    assert bad.status_code == 422
    await client.put("/v1/admin/config", headers=admin_headers, json={"free_scan_allowance": 5})
    assert (await client.get("/v1/config")).json()["free_scan_allowance"] == 5
    # New users get the configured allowance.
    tokens = await sign_in(client)
    assert tokens["user"]["freeScansLeft"] == 5  # type: ignore[index]
