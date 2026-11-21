"""Public API shapes. JSON is camelCase and matches the Flutter app's own
serialisation, so the app can cache server payloads as-is."""

import uuid
from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator
from pydantic.alias_generators import to_camel

MealType = Literal["breakfast", "lunch", "dinner", "snack"]


class Camel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel, populate_by_name=True, from_attributes=True
    )


# ── Nutrition ────────────────────────────────────────────────────────────────


class Macros(Camel):
    p: float = Field(ge=0, le=2000)
    c: float = Field(ge=0, le=2000)
    f: float = Field(ge=0, le=2000)

    @property
    def kcal(self) -> float:
        return self.p * 4 + self.c * 4 + self.f * 9


class FoodItem(Camel):
    id: str = Field(max_length=80)
    name: str = Field(max_length=120)
    unit: str = Field(max_length=80)
    macros: Macros
    servings: float = Field(default=1, gt=0, le=50)
    confidence: float = Field(default=1, ge=0, le=1)


class MealIn(Camel):
    name: str = Field(min_length=1, max_length=120)
    photo: str | None = Field(default=None, max_length=500)
    logged_at: datetime
    type: MealType
    health_score: float = Field(default=7, ge=0, le=10)
    items: list[FoodItem] = Field(max_length=40)


class MealOut(MealIn):
    id: str


# ── Users ────────────────────────────────────────────────────────────────────


class UserOut(Camel):
    id: uuid.UUID
    phone: str
    name: str
    email: str
    onboarded: bool
    profile: dict[str, Any] | None
    custom_targets: dict[str, Any] | None
    reminders: list[Any] | None
    is_premium: bool
    premium_until: datetime | None
    free_scans_left: int
    created_at: datetime


class UserPatch(Camel):
    name: str | None = Field(default=None, max_length=80)
    email: EmailStr | Literal[""] | None = None
    onboarded: bool | None = None
    profile: dict[str, Any] | None = None
    # Send `null` explicitly to switch back to automatic targets.
    custom_targets: dict[str, Any] | None = None
    reminders: list[Any] | None = None


# ── Auth ─────────────────────────────────────────────────────────────────────


class OtpRequest(Camel):
    phone: str = Field(min_length=6, max_length=24, description="E.164, e.g. +919876543210")


class OtpRequestOut(Camel):
    phone: str
    expires_in: int
    resend_in: int
    # Only returned outside production with the console SMS provider.
    dev_code: str | None = None


class OtpVerify(Camel):
    phone: str = Field(min_length=6, max_length=24)
    code: str = Field(min_length=4, max_length=8)

    @field_validator("code")
    @classmethod
    def digits_only(cls, v: str) -> str:
        if not v.isdigit():
            raise ValueError("Code must contain digits only")
        return v


class TokenOut(Camel):
    access_token: str
    refresh_token: str
    expires_in: int
    is_new: bool
    user: UserOut


class RefreshIn(Camel):
    refresh_token: str


# ── Other resources ──────────────────────────────────────────────────────────


class WeightIn(Camel):
    kg: float = Field(gt=20, lt=400)
    logged_at: datetime | None = None


class WeightOut(Camel):
    kg: float
    logged_at: datetime


class NoticeOut(Camel):
    id: str
    kind: str
    title: str
    body: str
    created_at: datetime
    read: bool


class FoodOut(Camel):
    id: int
    name: str
    unit: str
    macros: Macros
    brand: str | None
    photo: str | None
    barcode: str | None
    # True for AI-estimated foods an admin hasn't checked yet.
    ai_estimated: bool = False


class ScanOut(Camel):
    meal: MealOut
    scans_left: int | None  # None = unlimited (Pro)


class Bootstrap(Camel):
    """Everything the app needs after sign-in, in one request."""

    user: UserOut
    meals: list[MealOut]
    weights: list[WeightOut]
    notices: list[NoticeOut]
    config: dict[str, Any]
