from types import SimpleNamespace
from typing import Any

import pytest
from httpx import AsyncClient

from app.config import Settings
from app.db import SessionLocal
from app.models import Food
from app.routers import ai as ai_router
from app.services.ai import (
    AIUnavailable,
    FoodRef,
    OpenAITextAI,
    SuggestContext,
    _Item,
    _Meal,
    _Suggestion,
    _Suggestions,
)


@pytest.fixture(autouse=True)
async def foods() -> None:
    ai_router._CACHE.clear()
    async with SessionLocal() as db:
        db.add_all(
            [
                Food(name="Roti (whole wheat)", unit="1 roti (40 g)", protein=3, carbs=18, fat=3.5),
                Food(name="Dal tadka", unit="1 bowl (200 g)", protein=12, carbs=28, fat=8),
            ]
        )
        await db.commit()


SUGGEST = {"remainingKcal": 700, "remainingProtein": 40, "remainingCarbs": 80, "remainingFat": 20, "mealType": "dinner"}


async def test_description_matches_database_and_saves_unknown_foods(
    client: AsyncClient, user_headers: dict[str, str], admin_headers: dict[str, str]
) -> None:
    r = await client.post("/v1/ai/parse-meal", headers=user_headers, json={"text": "2 rotis, dal tadka and mango pickle"})
    assert r.status_code == 200, r.text
    body = r.json()
    items = {i["name"]: i for i in body["meal"]["items"]}

    roti = items["Roti (whole wheat)"]
    assert roti["servings"] == 2 and roti["unit"] == "1 roti (40 g)"
    assert roti["macros"] == {"p": 3.0, "c": 18.0, "f": 3.5}, "database values win"
    assert "Dal tadka" in items
    assert "Mango pickle" in items
    assert body["newFoods"] == 1

    # The estimate is now searchable, flagged until an admin checks it.
    found = (await client.get("/v1/foods?q=pickle", headers=user_headers)).json()
    assert found[0]["aiEstimated"] is True

    queue = (await client.get("/v1/admin/foods?review=true", headers=admin_headers)).json()
    assert [f["name"] for f in queue["items"]] == ["Mango pickle"]
    stats = (await client.get("/v1/admin/stats", headers=admin_headers)).json()
    assert stats["foodsToReview"] == 1 and stats["aiRequestsToday"] == 1

    approved = await client.post(f"/v1/admin/foods/{queue['items'][0]['id']}/approve", headers=admin_headers)
    assert approved.json()["reviewed"] is True
    found = (await client.get("/v1/foods?q=pickle", headers=user_headers)).json()
    assert found[0]["aiEstimated"] is False

    # Describing it again doesn't create a duplicate.
    again = await client.post("/v1/ai/parse-meal", headers=user_headers, json={"text": "mango pickle"})
    assert again.json()["newFoods"] == 0


async def test_rejects_text_that_is_not_food(client: AsyncClient, user_headers: dict[str, str]) -> None:
    r = await client.post("/v1/ai/parse-meal", headers=user_headers, json={"text": "12345"})
    assert r.status_code == 422


async def test_daily_ai_limit_for_free_users(
    client: AsyncClient, user_headers: dict[str, str], admin_headers: dict[str, str]
) -> None:
    await client.put("/v1/admin/config", headers=admin_headers, json={"ai_daily_limit_free": 2})
    for _ in range(2):
        ok = await client.post("/v1/ai/parse-meal", headers=user_headers, json={"text": "dal tadka"})
        assert ok.status_code == 200
    blocked = await client.post("/v1/ai/parse-meal", headers=user_headers, json={"text": "dal tadka"})
    assert blocked.status_code == 429
    assert "upgrade to Pro" in blocked.json()["detail"]

    bad = await client.put("/v1/admin/config", headers=admin_headers, json={"ai_daily_limit_free": -5})
    assert bad.status_code == 422


async def test_suggestions_are_cached_and_respect_vegetarian_pattern(
    client: AsyncClient, user_headers: dict[str, str], admin_headers: dict[str, str]
) -> None:
    for i, name in enumerate(["Dal tadka", "Paneer curry"]):
        await client.put(
            f"/v1/meals/v{i}",
            headers=user_headers,
            json={"name": name, "loggedAt": "2026-11-20T12:00:00Z", "type": "lunch",
                  "items": [{"id": "a", "name": name, "unit": "1 bowl", "macros": {"p": 10, "c": 20, "f": 8}}]},
        )
    first = await client.post("/v1/ai/suggestions", headers=user_headers, json=SUGGEST)
    assert first.status_code == 200, first.text
    ideas = first.json()
    assert 1 <= len(ideas) <= 3
    assert all(s["vegetarian"] for s in ideas), "only vegetarian history → vegetarian ideas"

    await client.post("/v1/ai/suggestions", headers=user_headers, json=SUGGEST)  # cached
    stats = (await client.get("/v1/admin/stats", headers=admin_headers)).json()
    assert stats["aiRequestsToday"] == 1, "cached answers don't cost an AI call"


# ── OpenAI implementation (fake SDK, no network) ─────────────────────────────


def fake_openai(monkeypatch: pytest.MonkeyPatch, parsed: Any) -> tuple[OpenAITextAI, dict[str, Any]]:
    ai = OpenAITextAI(Settings(openai_api_key="sk-test"))
    seen: dict[str, Any] = {}

    async def parse(**kwargs: Any) -> Any:
        seen.update(kwargs)
        return SimpleNamespace(output=[], output_parsed=parsed)

    monkeypatch.setattr(ai._client.responses, "parse", parse)
    return ai, seen


async def test_openai_parse_meal_offers_database_foods(monkeypatch: pytest.MonkeyPatch) -> None:
    meal = _Meal(
        is_food=True,
        meal_name="Roti and dal",
        health_score=7.5,
        items=[_Item(name="Roti", portion="1 roti", protein_g=3, carbs_g=18, fat_g=3.5,
                     confidence=0.95, food_id=1, servings=2)],
    )
    ai, seen = fake_openai(monkeypatch, meal)
    result = await ai.parse_meal("2 rotis", [FoodRef(1, "Roti (whole wheat)", "1 roti (40 g)", 3, 18, 3.5)])
    assert result.items[0].food_id == 1 and result.items[0].servings == 2
    assert seen["model"] == "gpt-5.4-mini"
    assert "id 1: Roti (whole wheat)" in seen["input"]
    assert seen["text_format"] is _Meal


async def test_openai_rejects_out_of_range_answers(monkeypatch: pytest.MonkeyPatch) -> None:
    bad = _Meal(is_food=True, meal_name="x", health_score=99, items=[
        _Item(name="x", portion="1", protein_g=1, carbs_g=1, fat_g=1, confidence=1, food_id=None, servings=1)
    ])
    ai, _ = fake_openai(monkeypatch, bad)
    with pytest.raises(AIUnavailable):
        await ai.parse_meal("x", [])


async def test_openai_suggestions_are_capped_at_three(monkeypatch: pytest.MonkeyPatch) -> None:
    one = _Suggestion(title="Paneer tikka", why="Protein.", portion="1 plate", protein_g=28,
                      carbs_g=14, fat_g=22, vegetarian=True)
    ai, seen = fake_openai(monkeypatch, _Suggestions(suggestions=[one] * 5))
    out = await ai.suggest(SuggestContext(700, 40, 80, 20, "dinner", "lose", "IN", ["Dal tadka"]))
    assert len(out.suggestions) == 3
    assert "Country: IN" in seen["input"] and "Dal tadka" in seen["input"]
