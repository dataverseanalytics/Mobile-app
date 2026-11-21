"""OpenAIScanner without network calls: the SDK's `responses.parse` is
replaced by a fake that records the request and returns a canned result."""

from types import SimpleNamespace
from typing import Any

import pytest

from app.config import Settings
from app.services.scanner import NoFoodDetected, OpenAIScanner, ScanUnavailable, _ModelItem, _ModelResult

JPEG = b"\xff\xd8\xff" + b"0" * 2000


def make_scanner(monkeypatch: pytest.MonkeyPatch, reply: Any, **settings: Any) -> dict[str, Any]:
    scanner = OpenAIScanner(Settings(openai_api_key="sk-test", **settings))
    seen: dict[str, Any] = {"scanner": scanner}

    async def fake_parse(**kwargs: Any) -> Any:
        seen["kwargs"] = kwargs
        return reply

    monkeypatch.setattr(scanner._client.responses, "parse", fake_parse)
    return seen


def response(parsed: _ModelResult | None, refusal: bool = False) -> SimpleNamespace:
    content = [SimpleNamespace(type="refusal", refusal="no")] if refusal else []
    return SimpleNamespace(output=[SimpleNamespace(content=content)], output_parsed=parsed, status="completed")


BIRYANI = _ModelResult(
    is_food=True,
    meal_name="Chicken biryani",
    health_score=6.2,
    items=[_ModelItem(name="Biryani rice", portion="1.5 cups (240 g)", protein_g=7, carbs_g=68, fat_g=9, confidence=0.9)],
)


def test_requires_api_key() -> None:
    with pytest.raises(ScanUnavailable):
        OpenAIScanner(Settings(openai_api_key=""))


async def test_sends_image_and_returns_validated_result(monkeypatch: pytest.MonkeyPatch) -> None:
    seen = make_scanner(monkeypatch, response(BIRYANI), openai_reasoning_effort="low")
    result = await seen["scanner"].analyze(JPEG, "image/jpeg")

    assert result.meal_name == "Chicken biryani"
    kw = seen["kwargs"]
    assert kw["model"] == "gpt-5.5"
    assert kw["text_format"] is _ModelResult
    assert kw["reasoning"] == {"effort": "low"}
    image = kw["input"][0]["content"][0]
    assert image["type"] == "input_image"
    assert image["image_url"].startswith("data:image/jpeg;base64,")


async def test_omits_reasoning_for_non_reasoning_models(monkeypatch: pytest.MonkeyPatch) -> None:
    seen = make_scanner(monkeypatch, response(BIRYANI), openai_model="gpt-4.1")
    await seen["scanner"].analyze(JPEG, "image/jpeg")
    assert "reasoning" not in seen["kwargs"]


async def test_refusal_and_no_food(monkeypatch: pytest.MonkeyPatch) -> None:
    seen = make_scanner(monkeypatch, response(None, refusal=True))
    with pytest.raises(NoFoodDetected):
        await seen["scanner"].analyze(JPEG, "image/jpeg")

    empty = _ModelResult(is_food=False, meal_name="", health_score=0, items=[])
    seen = make_scanner(monkeypatch, response(empty))
    with pytest.raises(NoFoodDetected):
        await seen["scanner"].analyze(JPEG, "image/jpeg")


async def test_out_of_range_output_is_rejected(monkeypatch: pytest.MonkeyPatch) -> None:
    bad = BIRYANI.model_copy(update={"health_score": 42})
    seen = make_scanner(monkeypatch, response(bad))
    with pytest.raises(ScanUnavailable):
        await seen["scanner"].analyze(JPEG, "image/jpeg")
