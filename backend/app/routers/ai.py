"""AI features for the app: describe a meal in words, and "what to eat next"."""

import random
import re
import time
from datetime import UTC, datetime, timedelta
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import Field
from sqlalchemy import func, or_, select

from .. import schemas
from ..config import get_settings
from ..deps import CurrentUser, Db
from ..models import Food, Meal, ScanLog, User
from ..schemas import Camel
from ..services.ai import (
    AIUnavailable,
    FoodRef,
    NotFood,
    SuggestContext,
    Suggestions,
    make_text_ai,
)
from ..services.app_config import get_config

settings = get_settings()
router = APIRouter(prefix="/v1/ai", tags=["ai"])

PRO_DAILY_LIMIT = 200
_STOP = {"and", "with", "the", "some", "had", "ate", "for", "one", "two", "half", "bowl", "plate", "cup", "glass"}


def _now() -> datetime:
    return datetime.now(UTC)


async def check_quota(db: Db, user: User) -> None:
    """Daily cap on AI text requests (photo scans have their own allowance)."""
    limit = PRO_DAILY_LIMIT if user.is_premium else int((await get_config(db))["ai_daily_limit_free"])
    today = datetime.combine(_now().date(), datetime.min.time(), UTC)
    used = (
        await db.execute(
            select(func.count()).where(
                ScanLog.user_id == user.id,
                ScanLog.kind.in_(("text", "suggest")),
                ScanLog.created_at >= today,
            )
        )
    ).scalar_one()
    if used >= limit:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "You've reached today's AI limit. Try again tomorrow"
            + ("." if user.is_premium else " or upgrade to Pro."),
        )


async def _quota(db: Db, user: CurrentUser) -> None:
    await check_quota(db, user)


Quota = Annotated[None, Depends(_quota)]


# ── Describe a meal ──────────────────────────────────────────────────────────


class ParseMealIn(Camel):
    text: str = Field(min_length=2, max_length=300)


class ParseMealOut(Camel):
    meal: schemas.MealOut
    # Foods the AI estimated that weren't in the database (now saved for review).
    new_foods: int


async def _candidates(db: Db, text: str) -> list[Food]:
    words = {w for w in re.findall(r"[a-zA-Z]{3,}", text.lower()) if w not in _STOP}
    if not words:
        return []
    conditions = [func.lower(Food.name).like(f"%{w.rstrip('s')}%") for w in words]
    rows = (
        await db.execute(select(Food).where(Food.is_active.is_(True), or_(*conditions)).limit(25))
    ).scalars().all()
    return list(rows)


@router.post("/parse-meal", response_model=ParseMealOut)
async def parse_meal(body: ParseMealIn, user: CurrentUser, db: Db, _: Quota) -> ParseMealOut:
    started = time.perf_counter()
    candidates = await _candidates(db, body.text)
    by_id = {f.id: f for f in candidates}
    usage = ScanLog(user_id=user.id, provider=settings.ai_provider, kind="text", success=False)
    try:
        parsed = await make_text_ai(settings).parse_meal(
            body.text,
            [FoodRef(f.id, f.name, f.unit, f.protein, f.carbs, f.fat) for f in candidates],
        )
    except NotFood as e:
        usage.error = "not_food"
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "That doesn't look like food. Try something like “2 rotis and dal”.",
        ) from e
    except AIUnavailable as e:
        usage.error = str(e)[:300]
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, str(e)) from e
    finally:
        usage.latency_ms = int((time.perf_counter() - started) * 1000)
        db.add(usage)
        await db.commit()

    items: list[schemas.FoodItem] = []
    new_foods = 0
    for i, it in enumerate(parsed.items):
        food = by_id.get(it.food_id) if it.food_id is not None else None
        if food is not None:
            # Database values win over the AI's copy.
            items.append(
                schemas.FoodItem(
                    id=f"db{food.id}-{i}",
                    name=food.name,
                    unit=food.unit,
                    macros=schemas.Macros(p=food.protein, c=food.carbs, f=food.fat),
                    servings=it.servings,
                    confidence=0.97,
                )
            )
            continue
        items.append(
            schemas.FoodItem(
                id=f"ai{random.getrandbits(40):x}-{i}",
                name=it.name,
                unit=it.portion,
                macros=schemas.Macros(p=it.protein_g, c=it.carbs_g, f=it.fat_g),
                servings=it.servings,
                confidence=it.confidence,
            )
        )
        # Grow the database: save the estimate once, flagged for review.
        exists = (
            await db.execute(select(Food.id).where(func.lower(Food.name) == it.name.strip().lower()))
        ).first()
        if exists is None:
            db.add(
                Food(
                    name=it.name.strip()[:120],
                    unit=it.portion[:80],
                    protein=it.protein_g,
                    carbs=it.carbs_g,
                    fat=it.fat_g,
                    source="ai",
                    reviewed=False,
                )
            )
            new_foods += 1

    now = _now()
    meal = schemas.MealOut(
        id=f"meal-{int(now.timestamp() * 1e6)}",
        name=parsed.meal_name or body.text[:60],
        photo=None,
        logged_at=now,
        type=_meal_type(now),
        health_score=round(parsed.health_score, 1),
        items=items,
    )
    usage.success = True
    usage.meal_name = meal.name[:120]
    usage.kcal = sum(x.macros.kcal * x.servings for x in items)
    await db.commit()
    return ParseMealOut(meal=meal, new_foods=new_foods)


def _meal_type(t: datetime) -> Literal["breakfast", "lunch", "dinner", "snack"]:
    h = t.hour
    return "breakfast" if h < 11 else "lunch" if h < 16 else "snack" if h < 18 else "dinner"


# ── What to eat next ─────────────────────────────────────────────────────────


class SuggestIn(Camel):
    remaining_kcal: float = Field(ge=0, le=10000)
    remaining_protein: float = Field(ge=0, le=1000)
    remaining_carbs: float = Field(ge=0, le=2000)
    remaining_fat: float = Field(ge=0, le=1000)
    meal_type: Literal["breakfast", "lunch", "dinner", "snack"]


class SuggestionOut(Camel):
    title: str
    why: str
    portion: str
    macros: schemas.Macros
    vegetarian: bool


# Same user + similar remaining budget within 2 hours → reuse (no AI cost).
_CACHE: dict[tuple[object, ...], tuple[float, Suggestions]] = {}
_CACHE_TTL = 2 * 3600


def _cache_key(user: User, body: SuggestIn) -> tuple[object, ...]:
    return (
        user.id,
        body.meal_type,
        round(body.remaining_kcal / 100),
        round(body.remaining_protein / 10),
        int(time.time() // _CACHE_TTL),
    )


@router.post("/suggestions", response_model=list[SuggestionOut])
async def suggestions(body: SuggestIn, user: CurrentUser, db: Db) -> list[SuggestionOut]:
    key = _cache_key(user, body)
    hit = _CACHE.get(key)
    if hit is None or hit[0] < time.time():
        await check_quota(db, user)
        recent = (
            await db.execute(
                select(Meal.name)
                .where(Meal.user_id == user.id, Meal.logged_at >= _now() - timedelta(days=14))
                .order_by(Meal.logged_at.desc())
                .limit(40)
            )
        ).scalars().all()
        ctx = SuggestContext(
            remaining_kcal=body.remaining_kcal,
            remaining_protein=body.remaining_protein,
            remaining_carbs=body.remaining_carbs,
            remaining_fat=body.remaining_fat,
            meal_type=body.meal_type,
            goal=str((user.profile or {}).get("goal", "maintain")),
            country=user.country,
            recent_meals=list(dict.fromkeys(recent)),
        )
        started = time.perf_counter()
        usage = ScanLog(user_id=user.id, provider=settings.ai_provider, kind="suggest", success=False)
        try:
            result = await make_text_ai(settings).suggest(ctx)
        except (AIUnavailable, NotFood) as e:
            usage.error = str(e)[:300] or "no_answer"
            raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Couldn't get suggestions right now.") from e
        finally:
            usage.latency_ms = int((time.perf_counter() - started) * 1000)
            db.add(usage)
            await db.commit()
        usage.success = True
        usage.meal_name = result.suggestions[0].title[:120]
        await db.commit()
        if len(_CACHE) > 5000:
            _CACHE.clear()
        _CACHE[key] = (time.time() + _CACHE_TTL, result)
        hit = _CACHE[key]

    return [
        SuggestionOut(
            title=s.title,
            why=s.why,
            portion=s.portion,
            macros=schemas.Macros(p=s.protein_g, c=s.carbs_g, f=s.fat_g),
            vegetarian=s.vegetarian,
        )
        for s in hit[1].suggestions
    ]

