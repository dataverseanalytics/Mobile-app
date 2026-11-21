"""Admin API used by the Next.js panel. Separate login, separate JWT secret."""

import uuid
from datetime import UTC, date, datetime, timedelta
from typing import Annotated, Any, Literal

from fastapi import APIRouter, HTTPException, Query, status
from pydantic import EmailStr, Field
from sqlalchemy import Select, delete, func, or_, select, update

from .. import convert
from ..deps import CurrentAdmin, Db, OwnerAdmin
from ..models import (
    Admin,
    Broadcast,
    Food,
    Meal,
    Notice,
    Payment,
    ScanLog,
    User,
    WeightEntry,
)
from ..schemas import Camel, Macros, MealOut, UserOut
from ..security import create_admin_token, hash_password, verify_password
from ..services.app_config import get_config, set_config
from ..services.pricing import PLAN_IDS, TIERS, format_price, tier_countries

router = APIRouter(prefix="/v1/admin", tags=["admin"])


def _now() -> datetime:
    return datetime.now(UTC)


# ── Schemas (admin-only) ─────────────────────────────────────────────────────


class AdminLogin(Camel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=200)


class AdminOut(Camel):
    id: uuid.UUID
    email: str
    name: str
    role: str
    created_at: datetime


class AdminToken(Camel):
    access_token: str
    admin: AdminOut


class Page[T](Camel):
    items: list[T]
    total: int
    page: int
    size: int


class AdminUserRow(Camel):
    id: uuid.UUID
    phone: str
    name: str
    email: str
    country: str
    is_premium: bool
    is_banned: bool
    onboarded: bool
    free_scans_left: int
    meal_count: int
    created_at: datetime
    last_seen_at: datetime


class AdminUserDetail(Camel):
    user: UserOut
    country: str
    is_banned: bool
    last_seen_at: datetime
    meal_count: int
    scan_count: int
    recent_meals: list[MealOut]
    weights: list[float]


class AdminUserPatch(Camel):
    name: str | None = Field(default=None, max_length=80)
    is_premium: bool | None = None
    is_banned: bool | None = None
    free_scans_left: int | None = Field(default=None, ge=0, le=1000)


class AdminMealRow(Camel):
    user_id: uuid.UUID
    user_name: str
    user_phone: str
    id: str
    name: str
    photo: str | None
    type: str
    kcal: float
    protein: float
    carbs: float
    fat: float
    health_score: float
    logged_at: datetime


class FoodIn(Camel):
    name: str = Field(min_length=1, max_length=120)
    unit: str = Field(min_length=1, max_length=80)
    macros: Macros
    brand: str | None = Field(default=None, max_length=80)
    barcode: str | None = Field(default=None, max_length=32)
    photo: str | None = Field(default=None, max_length=500)
    is_active: bool = True


class AdminFoodRow(Camel):
    id: int
    name: str
    unit: str
    macros: Macros
    kcal: float
    brand: str | None
    barcode: str | None
    photo: str | None
    is_active: bool
    source: str
    reviewed: bool


class BroadcastIn(Camel):
    title: str = Field(min_length=1, max_length=120)
    body: str = Field(min_length=1, max_length=500)
    kind: Literal["tip", "report", "streak", "pro", "welcome"] = "tip"
    segment: Literal["all", "premium", "free"] = "all"


class BroadcastOut(Camel):
    id: int
    title: str
    body: str
    kind: str
    segment: str
    recipients: int
    admin_email: str
    created_at: datetime


class ScanLogRow(Camel):
    id: int
    user_id: uuid.UUID | None
    provider: str
    kind: str
    success: bool
    meal_name: str
    kcal: float
    latency_ms: int
    error: str
    created_at: datetime


class AdminCreate(Camel):
    email: EmailStr
    name: str = Field(default="", max_length=80)
    password: str = Field(min_length=10, max_length=200)
    role: Literal["owner", "editor"] = "editor"


class DayPoint(Camel):
    day: date
    value: float


class Stats(Camel):
    total_users: int
    new_users_week: int
    active_today: int
    premium_users: int
    meals_today: int
    meals_total: int
    scans_today: int
    ai_requests_today: int
    foods_to_review: int
    scan_success_rate: float
    avg_kcal_per_meal: float
    signups: list[DayPoint]
    meals: list[DayPoint]
    scans: list[DayPoint]
    top_countries: list[dict[str, Any]]
    # Per currency — amounts in different currencies can't be added up.
    revenue_month: list[dict[str, Any]]
    revenue_total: list[dict[str, Any]]
    payments_month: int


class AdminPaymentRow(Camel):
    id: uuid.UUID
    user_id: uuid.UUID | None
    user_name: str
    user_phone: str
    plan: str
    currency: str
    amount_minor: int
    status: str
    order_id: str
    payment_id: str | None
    created_at: datetime
    paid_at: datetime | None


# ── Auth ─────────────────────────────────────────────────────────────────────


@router.post("/auth/login", response_model=AdminToken)
async def login(body: AdminLogin, db: Db) -> AdminToken:
    admin = (
        await db.execute(select(Admin).where(Admin.email == str(body.email).lower()))
    ).scalar_one_or_none()
    if admin is None or not verify_password(body.password, admin.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Wrong email or password")
    return AdminToken(
        access_token=create_admin_token(str(admin.id), admin.role),
        admin=AdminOut.model_validate(admin),
    )


@router.get("/me", response_model=AdminOut)
async def admin_me(admin: CurrentAdmin) -> AdminOut:
    return AdminOut.model_validate(admin)


# ── Dashboard ────────────────────────────────────────────────────────────────


async def _daily(db: Db, column: Any, days: int, where: Any = None) -> list[DayPoint]:
    """Counts per day for the last `days` days, zero-filled."""
    start = (_now() - timedelta(days=days - 1)).date()
    day = func.date(column)
    q: Select[Any] = select(day, func.count()).where(column >= datetime.combine(start, datetime.min.time(), UTC))
    if where is not None:
        q = q.where(where)
    rows = (await db.execute(q.group_by(day))).all()
    counts = {str(d): n for d, n in rows}
    return [
        DayPoint(day=start + timedelta(days=i), value=counts.get(str(start + timedelta(days=i)), 0))
        for i in range(days)
    ]


async def _revenue(db: Db, since: datetime | None) -> list[dict[str, Any]]:
    q = select(Payment.currency, func.sum(Payment.amount_minor), func.count()).where(Payment.status == "paid")
    if since is not None:
        q = q.where(Payment.paid_at >= since)
    rows = (await db.execute(q.group_by(Payment.currency).order_by(func.sum(Payment.amount_minor).desc()))).all()
    return [{"currency": c, "amountMinor": int(a or 0), "payments": n} for c, a, n in rows]


@router.get("/stats", response_model=Stats)
async def stats(db: Db, _: CurrentAdmin) -> Stats:
    now = _now()
    today = datetime.combine(now.date(), datetime.min.time(), UTC)

    async def count(q: Any) -> int:
        return int((await db.execute(q)).scalar_one() or 0)

    photo = ScanLog.kind == "photo"
    scans_ok = await count(select(func.count()).select_from(ScanLog).where(photo, ScanLog.success.is_(True)))
    scans_all = await count(select(func.count()).select_from(ScanLog).where(photo))
    avg_kcal = (await db.execute(select(func.avg(Meal.kcal)))).scalar_one() or 0
    countries = (
        await db.execute(
            select(User.country, func.count()).group_by(User.country).order_by(func.count().desc()).limit(6)
        )
    ).all()
    return Stats(
        total_users=await count(select(func.count()).select_from(User)),
        new_users_week=await count(select(func.count()).select_from(User).where(User.created_at >= now - timedelta(days=7))),
        active_today=await count(select(func.count()).select_from(User).where(User.last_seen_at >= today)),
        premium_users=await count(select(func.count()).select_from(User).where(User.is_premium.is_(True))),
        meals_today=await count(select(func.count()).select_from(Meal).where(Meal.logged_at >= today)),
        meals_total=await count(select(func.count()).select_from(Meal)),
        scans_today=await count(select(func.count()).select_from(ScanLog).where(photo, ScanLog.created_at >= today)),
        ai_requests_today=await count(
            select(func.count()).select_from(ScanLog).where(ScanLog.kind != "photo", ScanLog.created_at >= today)
        ),
        foods_to_review=await count(
            select(func.count()).select_from(Food).where(Food.source == "ai", Food.reviewed.is_(False))
        ),
        scan_success_rate=round(scans_ok / scans_all, 3) if scans_all else 0,
        revenue_month=await _revenue(db, now - timedelta(days=30)),
        revenue_total=await _revenue(db, None),
        payments_month=await count(
            select(func.count()).select_from(Payment).where(
                Payment.status == "paid", Payment.paid_at >= now - timedelta(days=30)
            )
        ),
        avg_kcal_per_meal=round(float(avg_kcal), 1),
        signups=await _daily(db, User.created_at, 30),
        meals=await _daily(db, Meal.logged_at, 30),
        scans=await _daily(db, ScanLog.created_at, 30, ScanLog.kind == "photo"),
        top_countries=[{"country": c or "—", "users": n} for c, n in countries],
    )


# ── Users ────────────────────────────────────────────────────────────────────


@router.get("/users", response_model=Page[AdminUserRow])
async def list_users(
    db: Db,
    _: CurrentAdmin,
    q: Annotated[str, Query(max_length=80)] = "",
    status_: Annotated[Literal["all", "premium", "free", "banned"], Query(alias="status")] = "all",
    page: Annotated[int, Query(ge=1)] = 1,
    size: Annotated[int, Query(ge=1, le=100)] = 20,
) -> Page[AdminUserRow]:
    meal_count = (
        select(func.count()).where(Meal.user_id == User.id).correlate(User).scalar_subquery()
    )
    base = select(User)
    term = q.strip()
    if term:
        like = f"%{term.lower()}%"
        base = base.where(
            or_(func.lower(User.name).like(like), User.phone.like(f"%{term}%"), func.lower(User.email).like(like))
        )
    if status_ == "premium":
        base = base.where(User.is_premium.is_(True))
    elif status_ == "free":
        base = base.where(User.is_premium.is_(False))
    elif status_ == "banned":
        base = base.where(User.is_banned.is_(True))

    total = int((await db.execute(select(func.count()).select_from(base.subquery()))).scalar_one())
    rows = (
        await db.execute(
            base.add_columns(meal_count)
            .order_by(User.created_at.desc())
            .offset((page - 1) * size)
            .limit(size)
        )
    ).all()
    items = [
        AdminUserRow(
            id=u.id,
            phone=u.phone,
            name=u.name,
            email=u.email,
            country=u.country,
            is_premium=u.is_premium,
            is_banned=u.is_banned,
            onboarded=u.onboarded,
            free_scans_left=u.free_scans_left,
            meal_count=mc,
            created_at=convert.aware(u.created_at),
            last_seen_at=convert.aware(u.last_seen_at),
        )
        for u, mc in rows
    ]
    return Page(items=items, total=total, page=page, size=size)


async def _get_user(db: Db, user_id: uuid.UUID) -> User:
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found")
    return user


@router.get("/users/{user_id}", response_model=AdminUserDetail)
async def user_detail(user_id: uuid.UUID, db: Db, _: CurrentAdmin) -> AdminUserDetail:
    user = await _get_user(db, user_id)
    meals = (
        await db.execute(
            select(Meal).where(Meal.user_id == user.id).order_by(Meal.logged_at.desc()).limit(20)
        )
    ).scalars().all()
    weights = (
        await db.execute(
            select(WeightEntry.kg).where(WeightEntry.user_id == user.id).order_by(WeightEntry.logged_at)
        )
    ).scalars().all()
    return AdminUserDetail(
        user=convert.user_out(user),
        country=user.country,
        is_banned=user.is_banned,
        last_seen_at=convert.aware(user.last_seen_at),
        meal_count=int((await db.execute(select(func.count()).where(Meal.user_id == user.id))).scalar_one()),
        scan_count=int((await db.execute(select(func.count()).where(ScanLog.user_id == user.id))).scalar_one()),
        recent_meals=[convert.meal_out(m) for m in meals],
        weights=list(weights),
    )


@router.patch("/users/{user_id}", response_model=AdminUserDetail)
async def update_user(
    user_id: uuid.UUID, body: AdminUserPatch, db: Db, admin: CurrentAdmin
) -> AdminUserDetail:
    user = await _get_user(db, user_id)
    if body.name is not None:
        user.name = body.name.strip()
    if body.is_premium is not None:
        user.is_premium = body.is_premium
        user.premium_until = _now() + timedelta(days=365) if body.is_premium else None
    if body.is_banned is not None:
        user.is_banned = body.is_banned
    if body.free_scans_left is not None:
        user.free_scans_left = body.free_scans_left
    await db.commit()
    return await user_detail(user_id, db, admin)


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(user_id: uuid.UUID, db: Db, _: OwnerAdmin) -> None:
    user = await _get_user(db, user_id)
    for model in (Meal, WeightEntry, Notice):
        await db.execute(delete(model).where(model.user_id == user.id))
    await db.execute(update(ScanLog).where(ScanLog.user_id == user.id).values(user_id=None))
    await db.delete(user)
    await db.commit()


# ── Meals ────────────────────────────────────────────────────────────────────


@router.get("/meals", response_model=Page[AdminMealRow])
async def list_meals(
    db: Db,
    _: CurrentAdmin,
    q: Annotated[str, Query(max_length=80)] = "",
    page: Annotated[int, Query(ge=1)] = 1,
    size: Annotated[int, Query(ge=1, le=100)] = 25,
) -> Page[AdminMealRow]:
    base = select(Meal, User.name, User.phone).join(User, User.id == Meal.user_id)
    if q.strip():
        base = base.where(func.lower(Meal.name).like(f"%{q.strip().lower()}%"))
    total = int((await db.execute(select(func.count()).select_from(base.subquery()))).scalar_one())
    rows = (
        await db.execute(base.order_by(Meal.logged_at.desc()).offset((page - 1) * size).limit(size))
    ).all()
    items = [
        AdminMealRow(
            user_id=m.user_id,
            user_name=name,
            user_phone=phone,
            id=m.id,
            name=m.name,
            photo=m.photo,
            type=m.meal_type,
            kcal=round(m.kcal, 1),
            protein=round(m.protein, 1),
            carbs=round(m.carbs, 1),
            fat=round(m.fat, 1),
            health_score=m.health_score,
            logged_at=convert.aware(m.logged_at),
        )
        for m, name, phone in rows
    ]
    return Page(items=items, total=total, page=page, size=size)


@router.delete("/meals/{user_id}/{meal_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_meal(user_id: uuid.UUID, meal_id: str, db: Db, _: CurrentAdmin) -> None:
    await db.execute(delete(Meal).where(Meal.user_id == user_id, Meal.id == meal_id))
    await db.commit()


# ── Foods ────────────────────────────────────────────────────────────────────


def _food_row(f: Food) -> AdminFoodRow:
    return AdminFoodRow(
        id=f.id,
        name=f.name,
        unit=f.unit,
        macros=Macros(p=f.protein, c=f.carbs, f=f.fat),
        kcal=round(f.kcal, 1),
        brand=f.brand,
        barcode=f.barcode,
        photo=f.photo,
        is_active=f.is_active,
        source=f.source,
        reviewed=f.reviewed,
    )


@router.get("/foods", response_model=Page[AdminFoodRow])
async def list_foods(
    db: Db,
    _: CurrentAdmin,
    q: Annotated[str, Query(max_length=80)] = "",
    review: Annotated[bool, Query(description="Only AI estimates awaiting review")] = False,
    page: Annotated[int, Query(ge=1)] = 1,
    size: Annotated[int, Query(ge=1, le=100)] = 25,
) -> Page[AdminFoodRow]:
    base = select(Food)
    if review:
        base = base.where(Food.source == "ai", Food.reviewed.is_(False))
    if q.strip():
        base = base.where(func.lower(Food.name).like(f"%{q.strip().lower()}%"))
    total = int((await db.execute(select(func.count()).select_from(base.subquery()))).scalar_one())
    rows = (
        await db.execute(base.order_by(Food.name).offset((page - 1) * size).limit(size))
    ).scalars().all()
    return Page(items=[_food_row(f) for f in rows], total=total, page=page, size=size)


def _apply_food(f: Food, body: FoodIn) -> None:
    f.name = body.name.strip()
    f.unit = body.unit.strip()
    f.protein, f.carbs, f.fat = body.macros.p, body.macros.c, body.macros.f
    f.brand = body.brand or None
    f.barcode = body.barcode or None
    f.photo = body.photo or None
    f.is_active = body.is_active
    f.reviewed = True  # Saved by a person = checked.


@router.post("/foods", response_model=AdminFoodRow, status_code=status.HTTP_201_CREATED)
async def create_food(body: FoodIn, db: Db, _: CurrentAdmin) -> AdminFoodRow:
    food = Food()
    _apply_food(food, body)
    db.add(food)
    await db.commit()
    return _food_row(food)


@router.get("/foods/{food_id}", response_model=AdminFoodRow)
async def get_food(food_id: int, db: Db, _: CurrentAdmin) -> AdminFoodRow:
    food = await db.get(Food, food_id)
    if food is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Food not found")
    return _food_row(food)


@router.put("/foods/{food_id}", response_model=AdminFoodRow)
async def update_food(food_id: int, body: FoodIn, db: Db, _: CurrentAdmin) -> AdminFoodRow:
    food = await db.get(Food, food_id)
    if food is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Food not found")
    _apply_food(food, body)
    await db.commit()
    return _food_row(food)


@router.post("/foods/{food_id}/approve", response_model=AdminFoodRow)
async def approve_food(food_id: int, db: Db, _: CurrentAdmin) -> AdminFoodRow:
    """Mark an AI estimate as checked (it stops showing the AI badge)."""
    food = await db.get(Food, food_id)
    if food is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Food not found")
    food.reviewed = True
    await db.commit()
    return _food_row(food)


@router.delete("/foods/{food_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_food(food_id: int, db: Db, _: CurrentAdmin) -> None:
    await db.execute(delete(Food).where(Food.id == food_id))
    await db.commit()


# ── Broadcast notifications ──────────────────────────────────────────────────


@router.get("/broadcasts", response_model=list[BroadcastOut])
async def list_broadcasts(db: Db, _: CurrentAdmin) -> list[BroadcastOut]:
    rows = (await db.execute(select(Broadcast).order_by(Broadcast.created_at.desc()).limit(50))).scalars().all()
    return [BroadcastOut.model_validate(b) for b in rows]


@router.post("/broadcasts", response_model=BroadcastOut, status_code=status.HTTP_201_CREATED)
async def send_broadcast(body: BroadcastIn, db: Db, admin: CurrentAdmin) -> BroadcastOut:
    q = select(User.id).where(User.is_banned.is_(False))
    if body.segment == "premium":
        q = q.where(User.is_premium.is_(True))
    elif body.segment == "free":
        q = q.where(User.is_premium.is_(False))
    user_ids = (await db.execute(q)).scalars().all()
    broadcast = Broadcast(
        title=body.title,
        body=body.body,
        kind=body.kind,
        segment=body.segment,
        recipients=len(user_ids),
        admin_email=admin.email,
    )
    db.add(broadcast)
    await db.flush()
    db.add_all(
        Notice(
            id=f"bc{broadcast.id}-{uid}",
            user_id=uid,
            kind=body.kind,
            title=body.title,
            body=body.body,
        )
        for uid in user_ids
    )
    await db.commit()
    return BroadcastOut.model_validate(broadcast)


# ── Scan logs ────────────────────────────────────────────────────────────────


@router.get("/scans", response_model=Page[ScanLogRow])
async def list_scans(
    db: Db,
    _: CurrentAdmin,
    failed_only: Annotated[bool, Query(alias="failedOnly")] = False,
    kind: Annotated[Literal["all", "photo", "text", "suggest"], Query()] = "all",
    page: Annotated[int, Query(ge=1)] = 1,
    size: Annotated[int, Query(ge=1, le=100)] = 25,
) -> Page[ScanLogRow]:
    base = select(ScanLog)
    if kind != "all":
        base = base.where(ScanLog.kind == kind)
    if failed_only:
        base = base.where(ScanLog.success.is_(False))
    total = int((await db.execute(select(func.count()).select_from(base.subquery()))).scalar_one())
    rows = (
        await db.execute(base.order_by(ScanLog.created_at.desc()).offset((page - 1) * size).limit(size))
    ).scalars().all()
    return Page(items=[ScanLogRow.model_validate(r) for r in rows], total=total, page=page, size=size)


# ── Payments ─────────────────────────────────────────────────────────────────


@router.get("/payments", response_model=Page[AdminPaymentRow])
async def list_payments(
    db: Db,
    _: CurrentAdmin,
    status_: Annotated[Literal["all", "paid", "created", "failed"], Query(alias="status")] = "paid",
    page: Annotated[int, Query(ge=1)] = 1,
    size: Annotated[int, Query(ge=1, le=100)] = 25,
) -> Page[AdminPaymentRow]:
    base = select(Payment, User.name, User.phone).outerjoin(User, User.id == Payment.user_id)
    if status_ != "all":
        base = base.where(Payment.status == status_)
    total = int((await db.execute(select(func.count()).select_from(base.subquery()))).scalar_one())
    rows = (
        await db.execute(base.order_by(Payment.created_at.desc()).offset((page - 1) * size).limit(size))
    ).all()
    items = [
        AdminPaymentRow(
            id=p.id,
            user_id=p.user_id,
            user_name=name or "",
            user_phone=phone or "",
            plan=p.plan,
            currency=p.currency,
            amount_minor=p.amount_minor,
            status=p.status,
            order_id=p.order_id,
            payment_id=p.payment_id,
            created_at=convert.aware(p.created_at),
            paid_at=convert.aware(p.paid_at) if p.paid_at else None,
        )
        for p, name, phone in rows
    ]
    return Page(items=items, total=total, page=page, size=size)


# ── Pricing (read-only; edit backend/app/services/pricing.py) ────────────────


@router.get("/pricing")
async def pricing_table(_: CurrentAdmin) -> list[dict[str, Any]]:
    countries = tier_countries()
    return [
        {
            "tier": tier.id,
            "currency": tier.currency,
            "countries": countries.get(tier.id, []),
            "prices": [
                {"plan": plan, "label": format_price(tier, tier.amounts[plan])}
                for plan in PLAN_IDS
            ],
        }
        for tier in TIERS.values()
    ]


# ── App settings ─────────────────────────────────────────────────────────────


@router.get("/config")
async def read_config(db: Db, _: CurrentAdmin) -> dict[str, Any]:
    return await get_config(db)


@router.put("/config")
async def write_config(values: dict[str, Any], db: Db, _: OwnerAdmin) -> dict[str, Any]:
    if "ai_daily_limit_free" in values:
        limit = values["ai_daily_limit_free"]
        if not isinstance(limit, int) or not 0 <= limit <= 1000:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "ai_daily_limit_free must be 0–1000")
    if "free_scan_allowance" in values:
        allowance = values["free_scan_allowance"]
        if not isinstance(allowance, int) or not 0 <= allowance <= 100:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "free_scan_allowance must be 0–100")
    return await set_config(db, values)


# ── Team ─────────────────────────────────────────────────────────────────────


@router.get("/admins", response_model=list[AdminOut])
async def list_admins(db: Db, _: CurrentAdmin) -> list[AdminOut]:
    rows = (await db.execute(select(Admin).order_by(Admin.created_at))).scalars().all()
    return [AdminOut.model_validate(a) for a in rows]


@router.post("/admins", response_model=AdminOut, status_code=status.HTTP_201_CREATED)
async def create_admin(body: AdminCreate, db: Db, _: OwnerAdmin) -> AdminOut:
    email = str(body.email).lower()
    if (await db.execute(select(Admin).where(Admin.email == email))).scalar_one_or_none():
        raise HTTPException(status.HTTP_409_CONFLICT, "An admin with this email already exists")
    admin = Admin(email=email, name=body.name, password_hash=hash_password(body.password), role=body.role)
    db.add(admin)
    await db.commit()
    return AdminOut.model_validate(admin)


@router.delete("/admins/{admin_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_admin(admin_id: uuid.UUID, db: Db, me: OwnerAdmin) -> None:
    if admin_id == me.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You can't remove yourself")
    await db.execute(delete(Admin).where(Admin.id == admin_id))
    await db.commit()
