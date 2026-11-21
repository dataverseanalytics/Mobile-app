from pathlib import Path

from httpx import AsyncClient

PHOTO = Path(__file__).resolve().parents[2] / "nutrilens" / "assets" / "images" / "chicken_biryani.jpg"

MEAL = {
    "name": "Dal & rice",
    "photo": None,
    "loggedAt": "2026-11-20T13:00:00Z",
    "type": "lunch",
    "healthScore": 7.5,
    "items": [
        {"id": "a", "name": "Dal tadka", "unit": "1 bowl", "macros": {"p": 12, "c": 28, "f": 8}},
        {"id": "b", "name": "Rice", "unit": "1 cup", "macros": {"p": 4, "c": 45, "f": 0.5}, "servings": 2},
    ],
}


async def test_profile_update_and_bootstrap(client: AsyncClient, user_headers: dict[str, str]) -> None:
    r = await client.patch(
        "/v1/me",
        headers=user_headers,
        json={"name": "Aarav", "email": "a@example.com", "onboarded": True, "profile": {"goal": "lose"}},
    )
    assert r.status_code == 200
    assert r.json()["name"] == "Aarav"

    r = await client.get("/v1/me/bootstrap", headers=user_headers)
    body = r.json()
    assert body["user"]["onboarded"] is True
    assert len(body["notices"]) == 2  # welcome + tip
    assert body["config"]["free_scan_allowance"] == 3


async def test_custom_targets_can_be_cleared(client: AsyncClient, user_headers: dict[str, str]) -> None:
    await client.patch("/v1/me", headers=user_headers, json={"customTargets": {"kcal": 2000}})
    r = await client.patch("/v1/me", headers=user_headers, json={"customTargets": None})
    assert r.json()["customTargets"] is None


async def test_rejects_bad_email(client: AsyncClient, user_headers: dict[str, str]) -> None:
    r = await client.patch("/v1/me", headers=user_headers, json={"email": "not-an-email"})
    assert r.status_code == 422


async def test_meal_upsert_is_idempotent_and_totals_are_computed(
    client: AsyncClient, user_headers: dict[str, str]
) -> None:
    for _ in range(2):  # an offline retry sends the same meal twice
        r = await client.put("/v1/meals/m1", headers=user_headers, json=MEAL)
        assert r.status_code == 200
    meals = (await client.get("/v1/meals", headers=user_headers)).json()
    assert len(meals) == 1
    assert meals[0]["items"][1]["servings"] == 2

    assert (await client.delete("/v1/meals/m1", headers=user_headers)).status_code == 204
    assert (await client.delete("/v1/meals/m1", headers=user_headers)).status_code == 204  # safe retry
    assert (await client.get("/v1/meals", headers=user_headers)).json() == []


async def test_users_cannot_see_each_others_meals(
    client: AsyncClient, user_headers: dict[str, str]
) -> None:
    await client.put("/v1/meals/m1", headers=user_headers, json=MEAL)

    # Second user signs in through the normal (dev-code) path.
    phone = "+919876543210"
    code = (await client.post("/v1/auth/otp/request", json={"phone": phone})).json()["devCode"]
    tokens = (await client.post("/v1/auth/otp/verify", json={"phone": phone, "code": code})).json()
    other = {"Authorization": f"Bearer {tokens['accessToken']}"}

    assert (await client.get("/v1/meals", headers=other)).json() == []
    # Same meal id for a different user is a separate meal, not an overwrite.
    await client.put("/v1/meals/m1", headers=other, json={**MEAL, "name": "Other"})
    mine = (await client.get("/v1/meals", headers=user_headers)).json()
    assert mine[0]["name"] == "Dal & rice"


async def test_weights_update_profile(client: AsyncClient, user_headers: dict[str, str]) -> None:
    await client.patch("/v1/me", headers=user_headers, json={"profile": {"weightKg": 80}})
    r = await client.post("/v1/weights", headers=user_headers, json={"kg": 79.4})
    assert r.status_code == 201
    assert (await client.get("/v1/me", headers=user_headers)).json()["profile"]["weightKg"] == 79.4


async def test_notices_read_and_dismiss(client: AsyncClient, user_headers: dict[str, str]) -> None:
    notices = (await client.get("/v1/notices", headers=user_headers)).json()
    first = notices[0]["id"]
    await client.post(f"/v1/notices/{first}/read", headers=user_headers)
    await client.delete(f"/v1/notices/{notices[1]['id']}", headers=user_headers)
    after = (await client.get("/v1/notices", headers=user_headers)).json()
    assert len(after) == 1 and after[0]["read"] is True


async def test_scan_uses_free_allowance_then_requires_pro(
    client: AsyncClient, user_headers: dict[str, str]
) -> None:
    image = PHOTO.read_bytes()
    for left in (2, 1, 0):
        r = await client.post(
            "/v1/scan", headers=user_headers, files={"photo": ("chicken_biryani.jpg", image, "image/jpeg")}
        )
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["meal"]["name"] == "Chicken biryani"
        assert body["scansLeft"] == left
    r = await client.post(
        "/v1/scan", headers=user_headers, files={"photo": ("chicken_biryani.jpg", image, "image/jpeg")}
    )
    assert r.status_code == 402

    # Upgrading (dev endpoint) unlocks unlimited scans.
    await client.post("/v1/subscription/demo-activate", headers=user_headers)
    r = await client.post(
        "/v1/scan", headers=user_headers, files={"photo": ("chicken_biryani.jpg", image, "image/jpeg")}
    )
    assert r.status_code == 200 and r.json()["scansLeft"] is None


async def test_scan_rejects_non_images(client: AsyncClient, user_headers: dict[str, str]) -> None:
    r = await client.post(
        "/v1/scan", headers=user_headers, files={"photo": ("notes.txt", b"hello", "text/plain")}
    )
    assert r.status_code == 415


async def test_delete_account_removes_data(client: AsyncClient, user_headers: dict[str, str]) -> None:
    await client.put("/v1/meals/m1", headers=user_headers, json=MEAL)
    assert (await client.delete("/v1/me", headers=user_headers)).status_code == 204
    assert (await client.get("/v1/me", headers=user_headers)).status_code == 401
