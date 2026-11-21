"""AI meal recognition.

`MockScanner` returns realistic sample results (development, tests).
`OpenAIScanner` sends the photo to an OpenAI vision model and gets back
structured output that is validated before it reaches the app.
"""

import base64
import logging
import random
from typing import Protocol

import openai
from pydantic import BaseModel, Field, ValidationError

from ..config import Settings

log = logging.getLogger("nutrilens.scan")


class ScannedItem(BaseModel):
    name: str = Field(max_length=120)
    portion: str = Field(max_length=80)
    protein_g: float = Field(ge=0, le=500)
    carbs_g: float = Field(ge=0, le=500)
    fat_g: float = Field(ge=0, le=500)
    confidence: float = Field(ge=0, le=1)


class ScanResult(BaseModel):
    is_food: bool
    meal_name: str = Field(max_length=120)
    health_score: float = Field(ge=0, le=10)
    items: list[ScannedItem] = Field(max_length=20)


class NoFoodDetected(Exception):
    pass


class ScanUnavailable(Exception):
    pass


class Scanner(Protocol):
    name: str

    async def analyze(
        self, image: bytes, media_type: str, filename: str = ""
    ) -> ScanResult: ...


# ── Mock ─────────────────────────────────────────────────────────────────────

_SAMPLES = [
    ScanResult(
        is_food=True,
        meal_name="Tofu poke bowl",
        health_score=8.8,
        items=[
            ScannedItem(name="Seared tofu", portion="150 g", protein_g=18, carbs_g=4, fat_g=11, confidence=0.95),
            ScannedItem(name="Edamame", portion="½ cup (75 g)", protein_g=8.5, carbs_g=7, fat_g=4, confidence=0.92),
            ScannedItem(name="Boiled egg", portion="1 egg (50 g)", protein_g=6, carbs_g=0.6, fat_g=5, confidence=0.97),
            ScannedItem(name="Sweetcorn", portion="3 tbsp (40 g)", protein_g=1.3, carbs_g=8, fat_g=0.6, confidence=0.9),
            ScannedItem(name="Greens, cabbage & cucumber", portion="120 g", protein_g=2, carbs_g=7, fat_g=0.3, confidence=0.76),
        ],
    ),
    ScanResult(
        is_food=True,
        meal_name="Chicken biryani",
        health_score=6.1,
        items=[
            ScannedItem(name="Basmati rice (biryani)", portion="1.5 cups (240 g)", protein_g=7, carbs_g=68, fat_g=9, confidence=0.93),
            ScannedItem(name="Chicken pieces", portion="130 g", protein_g=32, carbs_g=2, fat_g=11, confidence=0.9),
            ScannedItem(name="Fried onions", portion="2 tbsp (15 g)", protein_g=0.4, carbs_g=5, fat_g=4.5, confidence=0.81),
            ScannedItem(name="Raita", portion="½ cup (100 g)", protein_g=3.5, carbs_g=5, fat_g=3, confidence=0.72),
        ],
    ),
    ScanResult(
        is_food=True,
        meal_name="Double cheeseburger",
        health_score=3.8,
        items=[
            ScannedItem(name="Beef patties", portion="2 × 90 g", protein_g=38, carbs_g=0, fat_g=30, confidence=0.95),
            ScannedItem(name="Brioche bun", portion="1 bun (75 g)", protein_g=7, carbs_g=38, fat_g=6, confidence=0.93),
            ScannedItem(name="Cheddar slices", portion="2 slices (40 g)", protein_g=10, carbs_g=0.5, fat_g=13, confidence=0.9),
            ScannedItem(name="Burger sauce", portion="1 tbsp (15 g)", protein_g=0.2, carbs_g=2, fat_g=7, confidence=0.76),
        ],
    ),
]
_KEYWORDS = {"tofu": 0, "poke": 0, "biryani": 1, "burger": 2}


class MockScanner:
    name = "mock"

    async def analyze(
        self, image: bytes, media_type: str, filename: str = ""
    ) -> ScanResult:
        if len(image) < 1024:
            raise NoFoodDetected()
        # Match the demo photo by file name; otherwise stable per image.
        name = filename.lower()
        for word, idx in _KEYWORDS.items():
            if word in name:
                return _SAMPLES[idx]
        return _SAMPLES[len(image) % len(_SAMPLES)]


# ── OpenAI vision ────────────────────────────────────────────────────────────

_INSTRUCTIONS = (
    "You are a nutrition analyst for a calorie-tracking app. Identify every "
    "distinct food in the photo, estimate each portion from visual cues "
    "(plate size, utensils, typical servings) and give protein, carbohydrate "
    "and fat in grams for that portion. Recognise regional dishes accurately, "
    "including Indian, East Asian and Middle Eastern cuisine. Use confidence "
    "below 0.8 when the item or its portion is genuinely uncertain. "
    "health_score is 0-10 for overall balance (protein, fibre, vegetables, "
    "processing, added sugar and fat). meal_name is short and natural, e.g. "
    "'Paneer curry with rice'. portion is human-readable with grams, e.g. "
    "'1 cup (160 g)'. If the photo contains no food, set is_food to false "
    "and return no items."
)


# Plain shapes for the model's structured output. OpenAI's strict schema
# mode doesn't accept every JSON-schema constraint, so limits are enforced
# afterwards by validating into ScanResult.
class _ModelItem(BaseModel):
    name: str
    portion: str
    protein_g: float
    carbs_g: float
    fat_g: float
    confidence: float


class _ModelResult(BaseModel):
    is_food: bool
    meal_name: str
    health_score: float
    items: list[_ModelItem]


class OpenAIScanner:
    name = "openai"

    def __init__(self, settings: Settings) -> None:
        if not settings.openai_api_key:
            raise ScanUnavailable("OPENAI_API_KEY is not set")
        self._client = openai.AsyncOpenAI(api_key=settings.openai_api_key, timeout=60)
        self._model = settings.openai_model
        self._effort = settings.openai_reasoning_effort

    async def analyze(
        self, image: bytes, media_type: str, filename: str = ""
    ) -> ScanResult:
        data_url = f"data:{media_type};base64,{base64.standard_b64encode(image).decode()}"
        extra = {"reasoning": {"effort": self._effort}} if self._effort else {}
        try:
            response = await self._client.responses.parse(
                model=self._model,
                instructions=_INSTRUCTIONS,
                input=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "input_image", "image_url": data_url, "detail": "high"},
                            {"type": "input_text", "text": "Analyse this meal."},
                        ],
                    }
                ],
                text_format=_ModelResult,
                max_output_tokens=16000,
                **extra,
            )
        except openai.RateLimitError as e:
            raise ScanUnavailable("Scanning is busy right now. Please try again.") from e
        except openai.APIStatusError as e:
            log.error("OpenAI API error %s: %s", e.status_code, e.message)
            raise ScanUnavailable("Scanning failed. Please try again.") from e
        except openai.APIConnectionError as e:
            raise ScanUnavailable("Couldn't reach the scanning service.") from e

        # A refusal comes back as a content item instead of parsed output.
        for item in response.output:
            for part in getattr(item, "content", None) or []:
                if getattr(part, "type", "") == "refusal":
                    raise NoFoodDetected()

        parsed = response.output_parsed
        if parsed is None:
            log.error("Scan returned no structured output (status=%s)", response.status)
            raise ScanUnavailable("Scanning failed. Please try again.")
        try:
            result = ScanResult.model_validate(parsed.model_dump())
        except ValidationError as e:
            log.error("Scan output out of range: %s", e)
            raise ScanUnavailable("Scanning failed. Please try again.") from e
        if not result.is_food or not result.items:
            raise NoFoodDetected()
        return result


def make_scanner(settings: Settings) -> Scanner:
    if settings.ai_provider == "openai":
        return OpenAIScanner(settings)
    return MockScanner()


def new_item_id() -> str:
    return f"ai-{random.getrandbits(48):x}"
