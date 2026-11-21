"""Country-based pricing for Pro passes.

The customer's country comes from their verified phone number (stored on
the user at sign-in), so it can't be changed with a VPN. The server picks
the price; the app only displays it, and Razorpay is charged exactly that.

To change prices, edit TIERS. Amounts are in the currency's minor unit
(paise, cents, pence, fils). Only currencies with 2 decimal places are
used, which keeps Razorpay's amount format simple.

Non-INR currencies need "International Payments" enabled on the Razorpay
account. UPI/net banking work only in INR; elsewhere customers pay by card.
"""

from dataclasses import dataclass

PLAN_IDS = ("yearly", "monthly", "weekly")  # paywall order: best value first
PLAN_DAYS = {"yearly": 365, "monthly": 30, "weekly": 7}
PLAN_NAMES = {"yearly": "Pro · 1 year", "monthly": "Pro · 1 month", "weekly": "Pro · 1 week"}


@dataclass(frozen=True)
class Tier:
    id: str
    currency: str
    symbol: str
    # plan id → amount in minor units
    amounts: dict[str, int]


TIERS: dict[str, Tier] = {
    "IN": Tier("IN", "INR", "₹", {"yearly": 2_49_900, "monthly": 69_900, "weekly": 24_900}),
    "US": Tier("US", "USD", "$", {"yearly": 3_999, "monthly": 799, "weekly": 299}),
    # Lower prices (still USD) for markets where the standard price is out of reach.
    "EMERGING": Tier("EMERGING", "USD", "$", {"yearly": 1_999, "monthly": 399, "weekly": 149}),
    "EU": Tier("EU", "EUR", "€", {"yearly": 3_999, "monthly": 799, "weekly": 299}),
    "GB": Tier("GB", "GBP", "£", {"yearly": 3_499, "monthly": 699, "weekly": 249}),
    "AE": Tier("AE", "AED", "AED ", {"yearly": 14_999, "monthly": 2_999, "weekly": 1_099}),
    "SG": Tier("SG", "SGD", "S$", {"yearly": 5_499, "monthly": 1_099, "weekly": 399}),
    "AU": Tier("AU", "AUD", "A$", {"yearly": 5_999, "monthly": 1_199, "weekly": 449}),
    "CA": Tier("CA", "CAD", "C$", {"yearly": 5_499, "monthly": 1_099, "weekly": 399}),
}
DEFAULT_TIER = "US"

_EUROZONE = {
    "AT", "BE", "HR", "CY", "EE", "FI", "FR", "DE", "GR", "IE", "IT", "LV",
    "LT", "LU", "MT", "NL", "PT", "SK", "SI", "ES",
}
_EMERGING = {
    "PK", "BD", "NP", "LK", "MM", "ID", "PH", "VN", "KH", "LA", "EG", "NG",
    "KE", "GH", "ET", "TZ", "UG", "MA", "DZ", "TN", "BO", "PY", "HN", "NI",
}
_DIRECT = {"IN", "US", "GB", "AE", "SG", "AU", "CA"}


def tier_countries() -> dict[str, list[str]]:
    """Which countries each tier covers (for the admin panel)."""
    return {
        "IN": ["IN"], "US": ["US", "everywhere else"], "EMERGING": sorted(_EMERGING),
        "EU": sorted(_EUROZONE), "GB": ["GB"], "AE": ["AE"], "SG": ["SG"],
        "AU": ["AU"], "CA": ["CA"],
    }


def tier_for_country(country: str | None) -> Tier:
    code = (country or "").upper()
    if code in _DIRECT:
        return TIERS[code]
    if code in _EUROZONE:
        return TIERS["EU"]
    if code in _EMERGING:
        return TIERS["EMERGING"]
    return TIERS[DEFAULT_TIER]


def format_price(tier: Tier, minor: int) -> str:
    whole, cents = divmod(minor, 100)
    if tier.currency == "INR":
        return f"{tier.symbol}{whole:,}" if cents == 0 else f"{tier.symbol}{whole:,}.{cents:02d}"
    return f"{tier.symbol}{whole:,}.{cents:02d}"


@dataclass(frozen=True)
class Price:
    plan: str
    name: str
    days: int
    currency: str
    amount_minor: int
    label: str
    # Only for the yearly plan ("₹208 / month"); None otherwise.
    per_month_label: str | None


def prices_for(country: str | None) -> list[Price]:
    tier = tier_for_country(country)
    out = []
    for plan in PLAN_IDS:
        minor = tier.amounts[plan]
        per_month = round(minor * (365 / 12) / PLAN_DAYS[plan])
        # Whole-unit monthly figure reads better ("₹208 / month").
        per_month = per_month - per_month % 100 if tier.currency == "INR" else per_month
        out.append(
            Price(
                plan=plan,
                name=PLAN_NAMES[plan],
                days=PLAN_DAYS[plan],
                currency=tier.currency,
                amount_minor=minor,
                label=format_price(tier, minor),
                per_month_label=format_price(tier, per_month) if plan == "yearly" else None,
            )
        )
    return out


def price_for(country: str | None, plan: str) -> Price:
    return next(p for p in prices_for(country) if p.plan == plan)
