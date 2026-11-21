"""Text AI: meal descriptions → logged items, and "what to eat next".

Principle: the database is the source of truth, AI fills the gaps.
* Meal descriptions are matched against the food database first; AI only
  estimates foods we don't know, and those estimates are saved to the
  database (flagged for admin review) so each food is estimated once.
* Calorie targets are never decided by AI — the app's formula does that;
  suggestions only have to fit the remaining budget the app sends.

`OpenAITextAI` uses the Responses API with structured output (strict
schema), then validates ranges with the stricter models below.
`MockTextAI` gives deterministic answers for development and tests.
"""

import logging
import re
from dataclasses import dataclass, field
from typing import Protocol

import openai
from pydantic import BaseModel, Field, ValidationError

from ..config import Settings

log = logging.getLogger("nutrilens.ai")


class AIUnavailable(Exception):
    pass


class NotFood(Exception):
    pass


# ── Validated shapes (what the rest of the app receives) ─────────────────────


class ParsedItem(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    portion: str = Field(min_length=1, max_length=80)
    protein_g: float = Field(ge=0, le=300)
    carbs_g: float = Field(ge=0, le=500)
    fat_g: float = Field(ge=0, le=300)
    confidence: float = Field(ge=0, le=1)
    # When the item is a food from the database: its id and how many of its units.
    food_id: int | None = None
    servings: float = Field(default=1, gt=0, le=20)


class ParsedMeal(BaseModel):
    is_food: bool
    meal_name: str = Field(max_length=120)
    health_score: float = Field(ge=0, le=10)
    items: list[ParsedItem] = Field(max_length=15)


class Suggestion(BaseModel):
    title: str = Field(min_length=1, max_length=80)
    why: str = Field(min_length=1, max_length=120)
    portion: str = Field(min_length=1, max_length=80)
    protein_g: float = Field(ge=0, le=200)
    carbs_g: float = Field(ge=0, le=300)
    fat_g: float = Field(ge=0, le=150)
    vegetarian: bool


class Suggestions(BaseModel):
    suggestions: list[Suggestion] = Field(min_length=1, max_length=3)


# ── Inputs ───────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class FoodRef:
    """A database food offered to the AI as a match candidate."""

    id: int
    name: str
    unit: str
    protein: float
    carbs: float
    fat: float


@dataclass(frozen=True)
class SuggestContext:
    remaining_kcal: float
    remaining_protein: float
    remaining_carbs: float
    remaining_fat: float
    meal_type: str
    goal: str
    country: str
    recent_meals: list[str] = field(default_factory=list)


class TextAI(Protocol):
    name: str

    async def parse_meal(self, text: str, candidates: list[FoodRef]) -> ParsedMeal: ...

    async def suggest(self, ctx: SuggestContext) -> Suggestions: ...


# ── OpenAI ───────────────────────────────────────────────────────────────────

_PARSE_INSTRUCTIONS = (
    "You turn a person's description of what they ate into food items for a "
    "calorie tracker. Split it into separate foods with realistic portions. "
    "Understand Indian and other regional dishes, Hinglish and casual phrasing "
    "('2 rotis', 'a bowl of dal', 'half plate biryani'). "
    "You are given DATABASE FOODS with ids and per-unit nutrition. When an item "
    "is one of them, set food_id to its id and servings to how many units were "
    "eaten (e.g. 2 rotis with unit '1 roti' → servings 2), and copy its "
    "nutrition per unit. Otherwise set food_id to null, servings to 1, give a "
    "human portion with grams (e.g. '1 bowl (200 g)') and estimate protein, "
    "carbs and fat in grams for that portion. Use confidence below 0.8 when "
    "unsure. health_score is 0-10 for overall balance. meal_name is short and "
    "natural. If the text isn't about food, set is_food to false and return no items."
)

_SUGGEST_INSTRUCTIONS = (
    "You suggest what someone could eat next, for a calorie tracker. Give "
    "exactly 3 different, realistic options that fit inside the remaining "
    "calories and help close the biggest macro gap (usually protein). Prefer "
    "dishes common where the person lives (country code given) and match their "
    "apparent eating pattern from recent meals — if they only eat vegetarian "
    "food, only suggest vegetarian food. Suit the meal type. Keep 'why' to one "
    "short, friendly sentence about how it fits their day. Never give medical "
    "advice. Nutrition values are for the stated portion."
)


class _Item(BaseModel):
    name: str
    portion: str
    protein_g: float
    carbs_g: float
    fat_g: float
    confidence: float
    food_id: int | None
    servings: float


class _Meal(BaseModel):
    is_food: bool
    meal_name: str
    health_score: float
    items: list[_Item]


class _Suggestion(BaseModel):
    title: str
    why: str
    portion: str
    protein_g: float
    carbs_g: float
    fat_g: float
    vegetarian: bool


class _Suggestions(BaseModel):
    suggestions: list[_Suggestion]


class OpenAITextAI:
    name = "openai"

    def __init__(self, settings: Settings) -> None:
        if not settings.openai_api_key:
            raise AIUnavailable("OPENAI_API_KEY is not set")
        self._client = openai.AsyncOpenAI(api_key=settings.openai_api_key, timeout=45)
        self._model = settings.openai_text_model
        self._effort = settings.openai_reasoning_effort

    async def _ask[T: BaseModel](self, instructions: str, prompt: str, fmt: type[T]) -> T:
        extra = {"reasoning": {"effort": self._effort}} if self._effort else {}
        try:
            response = await self._client.responses.parse(
                model=self._model,
                instructions=instructions,
                input=prompt,
                text_format=fmt,
                max_output_tokens=8000,
                **extra,
            )
        except openai.RateLimitError as e:
            raise AIUnavailable("The AI is busy right now. Please try again.") from e
        except openai.APIStatusError as e:
            log.error("OpenAI error %s: %s", e.status_code, e.message)
            raise AIUnavailable("The AI couldn't answer. Please try again.") from e
        except openai.APIConnectionError as e:
            raise AIUnavailable("Couldn't reach the AI service.") from e
        for item in response.output:
            for part in getattr(item, "content", None) or []:
                if getattr(part, "type", "") == "refusal":
                    raise NotFood()
        if response.output_parsed is None:
            raise AIUnavailable("The AI couldn't answer. Please try again.")
        return response.output_parsed

    async def parse_meal(self, text: str, candidates: list[FoodRef]) -> ParsedMeal:
        foods = "\n".join(
            f"- id {c.id}: {c.name} — unit '{c.unit}' — P {c.protein}g C {c.carbs}g F {c.fat}g"
            for c in candidates
        ) or "(none)"
        raw = await self._ask(
            _PARSE_INSTRUCTIONS, f"DATABASE FOODS:\n{foods}\n\nWHAT I ATE:\n{text}", _Meal
        )
        try:
            meal = ParsedMeal.model_validate(raw.model_dump())
        except ValidationError as e:
            log.error("Meal parse out of range: %s", e)
            raise AIUnavailable("The AI couldn't understand that. Try rephrasing.") from e
        if not meal.is_food or not meal.items:
            raise NotFood()
        return meal

    async def suggest(self, ctx: SuggestContext) -> Suggestions:
        prompt = (
            f"Meal: {ctx.meal_type}. Goal: {ctx.goal}. Country: {ctx.country or 'unknown'}.\n"
            f"Remaining today: {round(ctx.remaining_kcal)} kcal, protein {round(ctx.remaining_protein)} g, "
            f"carbs {round(ctx.remaining_carbs)} g, fat {round(ctx.remaining_fat)} g.\n"
            f"Recent meals: {', '.join(ctx.recent_meals[:25]) or 'none logged yet'}."
        )
        raw = await self._ask(_SUGGEST_INSTRUCTIONS, prompt, _Suggestions)
        try:
            return Suggestions.model_validate({"suggestions": [s.model_dump() for s in raw.suggestions[:3]]})
        except ValidationError as e:
            log.error("Suggestions out of range: %s", e)
            raise AIUnavailable("Couldn't get suggestions right now.") from e


# ── Mock (development and tests) ─────────────────────────────────────────────

_SPLIT = re.compile(r",|\band\b|\bwith\b|\+|&", re.I)
_COUNT = re.compile(r"^\s*(\d+(?:\.\d+)?|a|an|one|two|three|half)\s+", re.I)
_WORDS = {"a": 1.0, "an": 1.0, "one": 1.0, "two": 2.0, "three": 3.0, "half": 0.5}


class MockTextAI:
    """Deterministic stand-in: splits on commas/'and', matches the database,
    and gives a plain estimate for anything unknown."""

    name = "mock"

    async def parse_meal(self, text: str, candidates: list[FoodRef]) -> ParsedMeal:
        parts = [p.strip() for p in _SPLIT.split(text) if p and p.strip()]
        if not parts or not any(ch.isalpha() for ch in text):
            raise NotFood()
        items: list[ParsedItem] = []
        for part in parts[:15]:
            servings = 1.0
            m = _COUNT.match(part)
            if m:
                token = m.group(1).lower()
                servings = _WORDS.get(token) or float(token)
                part = part[m.end():]
            name = part.strip().rstrip("s") or part.strip()
            match = next(
                (c for c in candidates if name.lower() in c.name.lower() or c.name.lower().startswith(name.lower())),
                None,
            )
            if match:
                items.append(ParsedItem(name=match.name, portion=match.unit, protein_g=match.protein,
                                        carbs_g=match.carbs, fat_g=match.fat, confidence=0.95,
                                        food_id=match.id, servings=servings))
            else:
                items.append(ParsedItem(name=name.strip().capitalize(), portion="1 serving",
                                        protein_g=8, carbs_g=25, fat_g=6, confidence=0.6,
                                        servings=servings))
        title = ", ".join(i.name for i in items[:2]) + (" & more" if len(items) > 2 else "")
        return ParsedMeal(is_food=True, meal_name=title[:120], health_score=7, items=items)

    async def suggest(self, ctx: SuggestContext) -> Suggestions:
        veg = bool(ctx.recent_meals) and not any(
            w in " ".join(ctx.recent_meals).lower() for w in ("chicken", "egg", "fish", "mutton", "beef")
        )
        options = [
            Suggestion(title="Paneer tikka with salad", why="High protein to close today's gap.",
                       portion="1 plate (250 g)", protein_g=28, carbs_g=14, fat_g=22, vegetarian=True),
            Suggestion(title="Moong dal chilla", why="Light, filling and protein-rich.",
                       portion="2 chillas", protein_g=16, carbs_g=30, fat_g=8, vegetarian=True),
            Suggestion(title="Greek yogurt with fruit", why="A quick snack that fits your calories.",
                       portion="1 bowl (200 g)", protein_g=18, carbs_g=24, fat_g=4, vegetarian=True),
            Suggestion(title="Grilled chicken with rice", why="Lean protein for your goal.",
                       portion="1 plate (300 g)", protein_g=40, carbs_g=45, fat_g=9, vegetarian=False),
        ]
        picks = [o for o in options if o.vegetarian or not veg]
        fits = [o for o in picks if o.protein_g * 4 + o.carbs_g * 4 + o.fat_g * 9 <= max(ctx.remaining_kcal, 250)]
        return Suggestions(suggestions=(fits or picks)[:3])


def make_text_ai(settings: Settings) -> TextAI:
    if settings.ai_provider == "openai":
        return OpenAITextAI(settings)
    return MockTextAI()
