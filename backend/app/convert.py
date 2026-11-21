"""Model ↔ schema conversion in one place."""

from datetime import UTC, datetime

from . import models, schemas


def aware(dt: datetime) -> datetime:
    """SQLite drops tz info; treat naive values as UTC."""
    return dt if dt.tzinfo else dt.replace(tzinfo=UTC)


def meal_out(m: models.Meal) -> schemas.MealOut:
    return schemas.MealOut(
        id=m.id,
        name=m.name,
        photo=m.photo,
        logged_at=aware(m.logged_at),
        type=m.meal_type,  # type: ignore[arg-type]
        health_score=m.health_score,
        items=[schemas.FoodItem.model_validate(i) for i in m.items],
    )


def apply_meal(m: models.Meal, data: schemas.MealIn) -> None:
    m.name = data.name
    m.photo = data.photo
    m.meal_type = data.type
    m.logged_at = data.logged_at
    m.health_score = data.health_score
    m.items = [i.model_dump(by_alias=True) for i in data.items]
    p = c = f = 0.0
    for i in data.items:
        p += i.macros.p * i.servings
        c += i.macros.c * i.servings
        f += i.macros.f * i.servings
    m.protein, m.carbs, m.fat = p, c, f
    m.kcal = p * 4 + c * 4 + f * 9


def user_out(u: models.User) -> schemas.UserOut:
    out = schemas.UserOut.model_validate(u)
    out.created_at = aware(out.created_at)
    if out.premium_until is not None:
        out.premium_until = aware(out.premium_until)
    return out


def food_out(f: models.Food) -> schemas.FoodOut:
    return schemas.FoodOut(
        id=f.id,
        name=f.name,
        unit=f.unit,
        macros=schemas.Macros(p=f.protein, c=f.carbs, f=f.fat),
        brand=f.brand,
        photo=f.photo,
        barcode=f.barcode,
        ai_estimated=f.source == "ai" and not f.reviewed,
    )
