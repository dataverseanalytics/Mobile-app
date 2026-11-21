import re

from app.main import app


def test_no_mangled_camel_case_field_names() -> None:
    """Pydantic's to_camel turns `x_7d` into `x7D`, which clients won't
    expect. Keep digits out of field names (we've been bitten twice)."""
    bad = [
        f"{schema}.{prop}"
        for schema, spec in app.openapi()["components"]["schemas"].items()
        for prop in spec.get("properties", {})
        if re.search(r"\d[A-Z]", prop)
    ]
    assert bad == []
