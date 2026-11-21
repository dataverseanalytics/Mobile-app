"""Endpoints the mobile app uses once signed in."""

import time
from datetime import UTC, datetime, timedelta
from typing import Annotated, Any

from fastapi import APIRouter, File, HTTPException, Query, UploadFile, status
from sqlalchemy import delete, func, or_, select, update

from .. import convert, schemas
from ..config import get_settings
from ..deps import CurrentUser, Db
from ..models import Food, Meal, Notice, ScanLog, WeightEntry
from ..services.app_config import get_config
from ..services.scanner import (
    NoFoodDetected,
    ScanUnavailable,
    make_scanner,
    new_item_id,
)

settings = get_settings()
router = APIRouter(prefix="/v1", tags=["app"])


# ── Config (public) ──────────────────────────────────────────────────────────


@router.get("/config")
async def public_config(db: Db) -> dict[str, Any]:
    return await get_config(db)


# ── Me ───────────────────────────────────────────────────────────────────────


@router.get("/me", response_model=schemas.UserOut)
async def me(user: CurrentUser) -> schemas.UserOut:
    return convert.user_out(user)


@router.patch("/me", response_model=schemas.UserOut)
async def update_me(body: schemas.UserPatch, user: CurrentUser, db: Db) -> schemas.UserOut:
    sent = body.model_fields_set
    if "name" in sent and body.name is not None:
        user.name = body.name.strip()
    if "email" in sent and body.email is not None:
        user.email = str(body.email).strip().lower()
    if "onboarded" in sent and body.onboarded is not None:
        user.onboarded = body.onboarded
    if "profile" in sent:
        user.profile = body.profile
    if "custom_targets" in sent:
        user.custom_targets = body.custom_targets
    if "reminders" in sent:
        user.reminders = body.reminders
    await db.commit()
    await db.refresh(user)
    return convert.user_out(user)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_me(user: CurrentUser, db: Db) -> None:
    """Permanently deletes the account and every row that belongs to it."""
    for model in (Meal, WeightEntry, Notice):
        await db.execute(delete(model).where(model.user_id == user.id))
    await db.execute(update(ScanLog).where(ScanLog.user_id == user.id).values(user_id=None))
    await db.delete(user)
    await db.commit()


@router.get("/me/bootstrap", response_model=schemas.Bootstrap)
async def bootstrap(
    user: CurrentUser, db: Db, days: Annotated[int, Query(ge=1, le=365)] = 120
) -> schemas.Bootstrap:
    since = datetime.now(UTC) - timedelta(days=days)
    meals = (
        await db.execute(
            select(Meal).where(Meal.user_id == user.id, Meal.logged_at >= since).order_by(Meal.logged_at)
        )
    ).scalars().all()
    weights = (
        await db.execute(
            select(WeightEntry).where(WeightEntry.user_id == user.id).order_by(WeightEntry.logged_at)
        )
    ).scalars().all()
    notices = (
        await db.execute(
            select(Notice).where(Notice.user_id == user.id).order_by(Notice.created_at.desc()).limit(50)
        )
    ).scalars().all()
    return schemas.Bootstrap(
        user=convert.user_out(user),
        meals=[convert.meal_out(m) for m in meals],
        weights=[schemas.WeightOut(kg=w.kg, logged_at=convert.aware(w.logged_at)) for w in weights],
        notices=[schemas.NoticeOut.model_validate(n) for n in notices],
        config=await get_config(db),
    )


# ── Meals ────────────────────────────────────────────────────────────────────


@router.get("/meals", response_model=list[schemas.MealOut])
async def list_meals(
    user: CurrentUser,
    db: Db,
    start: Annotated[datetime | None, Query(alias="from")] = None,
    end: Annotated[datetime | None, Query(alias="to")] = None,
) -> list[schemas.MealOut]:
    q = select(Meal).where(Meal.user_id == user.id)
    if start:
        q = q.where(Meal.logged_at >= start)
    if end:
        q = q.where(Meal.logged_at < end)
    rows = (await db.execute(q.order_by(Meal.logged_at))).scalars().all()
    return [convert.meal_out(m) for m in rows]


@router.put("/meals/{meal_id}", response_model=schemas.MealOut)
async def upsert_meal(
    meal_id: str, body: schemas.MealIn, user: CurrentUser, db: Db
) -> schemas.MealOut:
    """Idempotent create-or-replace, so the app can safely retry offline writes."""
    if len(meal_id) > 80:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Meal id too long")
    meal = await db.get(Meal, (user.id, meal_id))
    if meal is None:
        meal = Meal(user_id=user.id, id=meal_id)
        db.add(meal)
    convert.apply_meal(meal, body)
    await db.commit()
    return convert.meal_out(meal)


@router.delete("/meals/{meal_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_meal(meal_id: str, user: CurrentUser, db: Db) -> None:
    # Deleting something already gone is a success (retries are safe).
    await db.execute(delete(Meal).where(Meal.user_id == user.id, Meal.id == meal_id))
    await db.commit()


# ── Weights ──────────────────────────────────────────────────────────────────


@router.get("/weights", response_model=list[schemas.WeightOut])
async def list_weights(user: CurrentUser, db: Db) -> list[schemas.WeightOut]:
    rows = (
        await db.execute(
            select(WeightEntry).where(WeightEntry.user_id == user.id).order_by(WeightEntry.logged_at)
        )
    ).scalars().all()
    return [schemas.WeightOut(kg=w.kg, logged_at=convert.aware(w.logged_at)) for w in rows]


@router.post("/weights", response_model=schemas.WeightOut, status_code=status.HTTP_201_CREATED)
async def add_weight(body: schemas.WeightIn, user: CurrentUser, db: Db) -> schemas.WeightOut:
    entry = WeightEntry(
        user_id=user.id, kg=body.kg, logged_at=body.logged_at or datetime.now(UTC)
    )
    db.add(entry)
    if user.profile is not None:
        user.profile = {**user.profile, "weightKg": body.kg}
    await db.commit()
    return schemas.WeightOut(kg=entry.kg, logged_at=convert.aware(entry.logged_at))


# ── Notifications ────────────────────────────────────────────────────────────


@router.get("/notices", response_model=list[schemas.NoticeOut])
async def list_notices(user: CurrentUser, db: Db) -> list[schemas.NoticeOut]:
    rows = (
        await db.execute(
            select(Notice).where(Notice.user_id == user.id).order_by(Notice.created_at.desc()).limit(100)
        )
    ).scalars().all()
    return [schemas.NoticeOut.model_validate(n) for n in rows]


@router.post("/notices/read-all", status_code=status.HTTP_204_NO_CONTENT)
async def read_all(user: CurrentUser, db: Db) -> None:
    await db.execute(update(Notice).where(Notice.user_id == user.id).values(read=True))
    await db.commit()


@router.post("/notices/{notice_id}/read", status_code=status.HTTP_204_NO_CONTENT)
async def read_one(notice_id: str, user: CurrentUser, db: Db) -> None:
    await db.execute(
        update(Notice).where(Notice.user_id == user.id, Notice.id == notice_id).values(read=True)
    )
    await db.commit()


@router.delete("/notices/{notice_id}", status_code=status.HTTP_204_NO_CONTENT)
async def dismiss(notice_id: str, user: CurrentUser, db: Db) -> None:
    await db.execute(delete(Notice).where(Notice.user_id == user.id, Notice.id == notice_id))
    await db.commit()


# ── Foods ────────────────────────────────────────────────────────────────────


@router.get("/foods", response_model=list[schemas.FoodOut])
async def search_foods(
    db: Db,
    _: CurrentUser,
    q: Annotated[str, Query(max_length=60)] = "",
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
) -> list[schemas.FoodOut]:
    query = select(Food).where(Food.is_active.is_(True))
    term = q.strip()
    if term:
        like = f"%{term.lower()}%"
        query = query.where(or_(func.lower(Food.name).like(like), func.lower(Food.brand).like(like)))
    rows = (await db.execute(query.order_by(Food.name).limit(limit))).scalars().all()
    return [convert.food_out(f) for f in rows]


@router.get("/foods/barcode/{code}", response_model=schemas.FoodOut)
async def food_by_barcode(code: str, db: Db, _: CurrentUser) -> schemas.FoodOut:
    food = (
        await db.execute(select(Food).where(Food.barcode == code, Food.is_active.is_(True)))
    ).scalar_one_or_none()
    if food is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "We don't know this product yet.")
    return convert.food_out(food)


# ── AI scan ──────────────────────────────────────────────────────────────────

_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}


@router.post("/scan", response_model=schemas.ScanOut)
async def scan_meal(
    user: CurrentUser,
    db: Db,
    photo: Annotated[UploadFile, File(description="JPEG, PNG or WebP meal photo")],
) -> schemas.ScanOut:
    if not user.is_premium and user.free_scans_left <= 0:
        raise HTTPException(
            status.HTTP_402_PAYMENT_REQUIRED, "You've used your free scans. Upgrade to Pro."
        )
    media_type = (photo.content_type or "").lower()
    if media_type not in _IMAGE_TYPES:
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, "Upload a JPEG, PNG or WebP photo.")
    data = await photo.read(settings.max_upload_mb * 1024 * 1024 + 1)
    if len(data) > settings.max_upload_mb * 1024 * 1024:
        raise HTTPException(status.HTTP_413_CONTENT_TOO_LARGE, "Photo is too large.")

    started = time.perf_counter()
    log = ScanLog(user_id=user.id, provider=settings.ai_provider, success=False)
    try:
        result = await make_scanner(settings).analyze(data, media_type, photo.filename or "")
    except NoFoodDetected as e:
        log.error = "no_food"
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "We couldn't spot any food. Try a closer, brighter photo.",
        ) from e
    except ScanUnavailable as e:
        log.error = str(e)[:300]
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, str(e)) from e
    finally:
        log.latency_ms = int((time.perf_counter() - started) * 1000)
        db.add(log)
        await db.commit()

    now = datetime.now(UTC)
    items = [
        schemas.FoodItem(
            id=new_item_id(),
            name=i.name,
            unit=i.portion,
            macros=schemas.Macros(p=i.protein_g, c=i.carbs_g, f=i.fat_g),
            confidence=i.confidence,
        )
        for i in result.items
    ]
    hour = now.hour
    meal_type = "breakfast" if hour < 11 else "lunch" if hour < 16 else "snack" if hour < 18 else "dinner"
    meal = schemas.MealOut(
        id=f"meal-{int(now.timestamp() * 1e6)}",
        name=result.meal_name,
        photo=None,
        logged_at=now,
        type=meal_type,
        health_score=round(result.health_score, 1),
        items=items,
    )
    log.success = True
    log.meal_name = result.meal_name
    log.kcal = sum(i.macros.kcal for i in items)
    if not user.is_premium:
        user.free_scans_left = max(0, user.free_scans_left - 1)
    await db.commit()
    return schemas.ScanOut(meal=meal, scans_left=None if user.is_premium else user.free_scans_left)


# ── Subscription ─────────────────────────────────────────────────────────────


@router.post("/subscription/demo-activate", response_model=schemas.UserOut)
async def demo_activate(user: CurrentUser, db: Db) -> schemas.UserOut:
    """Development only — real upgrades go through Razorpay (routers/payments.py)."""
    if not settings.is_dev:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Not found")
    user.is_premium = True
    user.premium_until = datetime.now(UTC) + timedelta(days=365)
    await db.commit()
    await db.refresh(user)
    return convert.user_out(user)
