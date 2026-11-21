import phonenumbers


class InvalidPhone(ValueError):
    pass


def normalize_phone(raw: str, allow: frozenset[str] = frozenset()) -> tuple[str, str]:
    """Return (E.164, ISO country) for a valid mobile-capable number.

    Numbers in `allow` (configured test numbers) skip the mobile-type check.
    """
    try:
        parsed = phonenumbers.parse(raw.strip(), None)
    except phonenumbers.NumberParseException as e:
        raise InvalidPhone("Enter the number with its country code, e.g. +91…") from e
    if not phonenumbers.is_valid_number(parsed):
        raise InvalidPhone("That phone number isn't valid.")
    e164 = phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)
    region = phonenumbers.region_code_for_number(parsed) or ""
    if e164 in allow:
        return e164, region
    kind = phonenumbers.number_type(parsed)
    if kind not in (
        phonenumbers.PhoneNumberType.MOBILE,
        phonenumbers.PhoneNumberType.FIXED_LINE_OR_MOBILE,
    ):
        raise InvalidPhone("Please use a mobile number that can receive SMS.")
    return e164, region
