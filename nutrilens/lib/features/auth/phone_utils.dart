import 'package:country_picker/country_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Phone helpers backed by libphonenumber metadata, so validation and
/// formatting are correct for every country.
abstract final class PhoneUtils {
  static final _service = CountryService();

  static List<Country> get allCountries =>
      _service.getAll()..sort((a, b) => a.name.compareTo(b.name));

  /// Country from the device locale, falling back to India.
  static Country deviceCountry() {
    final code = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    return _service.findByCode(code) ??
        _service.findByCode('IN') ??
        allCountries.first;
  }

  static IsoCode? _iso(Country c) {
    try {
      return IsoCode.fromJson(c.countryCode);
    } on Object {
      return null;
    }
  }

  static PhoneNumber? _parse(Country c, String input) {
    final digits = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return null;
    try {
      return digits.startsWith('+')
          ? PhoneNumber.parse(digits)
          : PhoneNumber.parse(digits, destinationCountry: _iso(c));
    } on Object {
      return null;
    }
  }

  /// `+919876543210` when the number is valid for [c], else `null`.
  static String? toE164(Country c, String input) {
    final p = _parse(c, input);
    return p != null && p.isValid() ? p.international : null;
  }

  /// Enough digits to be worth validating (enables the Continue button).
  static bool looksComplete(Country c, String input) {
    final p = _parse(c, input);
    return p != null && p.isValidLength();
  }

  /// `+91 98765 43210` — human-friendly for display.
  static String pretty(String e164) {
    try {
      final p = PhoneNumber.parse(e164);
      return '+${p.countryCode} ${p.formatNsn()}';
    } on Object {
      return e164;
    }
  }
}
