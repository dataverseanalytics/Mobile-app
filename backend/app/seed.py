"""Seed the database with what a fresh install needs (safe to re-run):

    python -m app.seed    # owner admin account + starter food database

No sample users or meals are created.
"""

import asyncio

from sqlalchemy import func, select

from .config import get_settings
from .db import SessionLocal
from .models import Admin, Food
from .security import hash_password

P = "assets/images"  # Photos bundled in the Flutter app.

FOODS: list[tuple[str, str, float, float, float, str | None, str | None, str | None]] = [
    # name, unit, protein, carbs, fat, photo, brand, barcode
    ("Masala dosa", "1 dosa (180 g)", 7, 52, 14, None, None, None),
    ("Dal tadka", "1 bowl (200 g)", 12, 28, 8, None, None, None),
    ("Chicken biryani", "1 plate (350 g)", 36, 80, 24, f"{P}/chicken_biryani.jpg", None, None),
    ("Paneer butter masala", "1 bowl (200 g)", 18, 14, 30, f"{P}/paneer_curry_rice.jpg", None, None),
    ("Roti (whole wheat)", "1 roti (40 g)", 3, 18, 3.5, None, None, None),
    ("Idli with sambar", "3 idli + 1 bowl", 10, 58, 4, None, None, None),
    ("Poha", "1 plate (180 g)", 5, 46, 9, None, None, None),
    ("Vegetable samosa", "1 piece (80 g)", 3, 24, 11, f"{P}/samosa.jpg", None, None),
    ("Rajma chawal", "1 plate (350 g)", 15, 78, 9, None, None, None),
    ("Greek yogurt, plain", "1 cup (170 g)", 17, 6, 4, None, "Packaged", None),
    ("High-protein Greek yogurt", "1 cup (170 g)", 15, 7, 2.5, f"{P}/berry_yogurt_bowl.jpg", "Packaged", "8901234567890"),
    ("Banana", "1 medium (118 g)", 1.3, 27, 0.4, None, None, None),
    ("Boiled egg", "1 large (50 g)", 6, 0.6, 5, None, None, None),
    ("Oats with milk", "1 bowl (250 g)", 11, 44, 7, None, None, None),
    ("Grilled chicken breast", "150 g", 46, 0, 5, None, None, None),
    ("Tofu poke bowl", "1 bowl (500 g)", 37, 30, 21, f"{P}/tofu_poke_bowl.jpg", None, None),
    ("Margherita pizza", "1 slice (110 g)", 10, 32, 10, f"{P}/margherita_pizza.jpg", None, None),
    ("Cheeseburger", "1 burger (220 g)", 30, 40, 28, f"{P}/cheeseburger.jpg", None, None),
    ("Avocado toast", "1 slice", 5, 22, 12, f"{P}/avocado_egg_toast.jpg", None, None),
    ("Whey protein shake", "1 scoop + water", 24, 3, 1.5, None, "Packaged", None),
    ("Masala chai", "1 cup (150 ml)", 2.5, 12, 3, None, None, None),
    ("Almonds", "20 g (~15 nuts)", 4.2, 4.3, 10, None, None, None),
    ("Apple", "1 medium (180 g)", 0.5, 25, 0.3, None, None, None),
]


async def seed() -> None:
    settings = get_settings()
    async with SessionLocal() as db:
        email = settings.admin_email.lower()
        if not (await db.execute(select(Admin).where(Admin.email == email))).scalar_one_or_none():
            db.add(Admin(email=email, name="Owner", role="owner",
                         password_hash=hash_password(settings.admin_password)))
            print(f"Created owner admin {email}")

        if (await db.execute(select(func.count()).select_from(Food))).scalar_one() == 0:
            db.add_all(Food(name=n, unit=u, protein=p, carbs=c, fat=f, photo=ph, brand=b, barcode=bc)
                       for n, u, p, c, f, ph, b, bc in FOODS)
            print(f"Added {len(FOODS)} foods")
        await db.commit()


if __name__ == "__main__":
    asyncio.run(seed())
