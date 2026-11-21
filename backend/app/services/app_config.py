from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models import AppConfig

DEFAULTS: dict[str, Any] = {
    "free_scan_allowance": 3,
    # AI text requests (meal descriptions + suggestions) per day, free users.
    "ai_daily_limit_free": 20,
    "maintenance_mode": False,
    "maintenance_message": "",
    "min_app_version": "1.0.0",
    "support_email": "support@nutrilens.app",
}


async def get_config(db: AsyncSession) -> dict[str, Any]:
    rows = (await db.execute(select(AppConfig))).scalars().all()
    return {**DEFAULTS, **{r.key: r.value for r in rows}}


async def set_config(db: AsyncSession, values: dict[str, Any]) -> dict[str, Any]:
    for key, value in values.items():
        if key not in DEFAULTS:
            continue  # Unknown keys are ignored, not stored.
        row = await db.get(AppConfig, key)
        if row is None:
            db.add(AppConfig(key=key, value=value))
        else:
            row.value = value
    await db.commit()
    return await get_config(db)
