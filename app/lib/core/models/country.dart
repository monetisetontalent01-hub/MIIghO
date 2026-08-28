import 'package:equatable/equatable.dart';

/// Represents a country supported by the MÏÏghO ecosystem.
class Country extends Equatable {
  final String isoCode; // e.g. 'CD', 'CI', 'SN', 'CM'
  final String name; // e.g. 'RD Congo', 'Côte d\'Ivoire'
  final String dialCode; // e.g. '+243', '+225'
  final String flagEmoji; // e.g. '🇨🇩', '🇨🇮'
  final String currencyIso; // e.g. 'CDF', 'XOF', 'XAF'
  final String currencySymbol; // e.g. 'FC', 'FCFA'
  final String placeholder; // e.g. '812 345 678'
  final int nationalLength; // Expected length of national number (without dial code)

  const Country({
    required this.isoCode,
    required this.name,
    required this.dialCode,
    required this.flagEmoji,
    required this.currencyIso,
    required this.currencySymbol,
    required this.placeholder,
    required this.nationalLength,
  });

  @override
  List<Object?> get props => [
        isoCode,
        name,
        dialCode,
        flagEmoji,
        currencyIso,
        currencySymbol,
        placeholder,
        nationalLength,
      ];

  /// Normalizes a user-input phone number to strict E.164 international format (+[CountryCode][NationalNumber]).
  String formatToE164(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    // Extract all digits
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) return '';

    final dialDigits = dialCode.replaceAll('+', '');

    String nationalDigits = digitsOnly;

    // Handle case where user typed / pasted full number starting with dial code
    if (nationalDigits.startsWith(dialDigits)) {
      nationalDigits = nationalDigits.substring(dialDigits.length);
    }

    // Country-specific national format handling:
    switch (isoCode) {
      case 'CD': // RDC: 9 digits (e.g. 812345678). If user typed 0812345678 (10 digits starting with 0), strip leading 0.
        if (nationalDigits.length == 10 && nationalDigits.startsWith('0')) {
          nationalDigits = nationalDigits.substring(1);
        }
        break;

      case 'CI': // Côte d'Ivoire: 10 digits (e.g. 0506169325). National numbers always start with 0 (01, 05, 07...).
        // If user typed 9 digits without 0, or already 10 digits with 0:
        if (nationalDigits.length == 9 && !nationalDigits.startsWith('0')) {
          nationalDigits = '0$nationalDigits';
        }
        break;

      case 'SN': // Sénégal: 9 digits (e.g. 771234567). If user typed 0771234567, strip leading 0.
      case 'CM': // Cameroun: 9 digits (e.g. 612345678). If user typed 0612345678, strip leading 0.
      default:
        if (nationalDigits.length == nationalLength + 1 && nationalDigits.startsWith('0')) {
          nationalDigits = nationalDigits.substring(1);
        }
        break;
    }

    if (nationalDigits.isEmpty) return '';

    return '$dialCode$nationalDigits';
  }

  /// Validates whether the normalized E.164 phone string matches the country's rules.
  bool isValidE164(String e164) {
    if (e164.isEmpty || !e164.startsWith('+')) return false;

    // Standard E.164 regex: + followed by 7 to 15 digits
    final e164Regex = RegExp(r'^\+[1-9]\d{6,14}$');
    if (!e164Regex.hasMatch(e164)) return false;

    // Check dial code prefix
    if (!e164.startsWith(dialCode)) return false;

    final nationalDigits = e164.substring(dialCode.length);
    return nationalDigits.length == nationalLength;
  }

  /// Validates raw national input against expected national length and format.
  bool isValidInput(String input) {
    final e164 = formatToE164(input);
    return isValidE164(e164);
  }

  // --- Predefined Supported Countries ---

  static const Country rdc = Country(
    isoCode: 'CD',
    name: 'RD Congo',
    dialCode: '+243',
    flagEmoji: '🇨🇩',
    currencyIso: 'CDF',
    currencySymbol: 'FC',
    placeholder: '812 345 678',
    nationalLength: 9,
  );

  static const Country coteDIvoire = Country(
    isoCode: 'CI',
    name: "Côte d'Ivoire",
    dialCode: '+225',
    flagEmoji: '🇨🇮',
    currencyIso: 'XOF',
    currencySymbol: 'FCFA',
    placeholder: '05 06 16 93 25',
    nationalLength: 10,
  );

  static const Country senegal = Country(
    isoCode: 'SN',
    name: 'Sénégal',
    dialCode: '+221',
    flagEmoji: '🇸🇳',
    currencyIso: 'XOF',
    currencySymbol: 'FCFA',
    placeholder: '77 123 45 67',
    nationalLength: 9,
  );

  static const Country cameroun = Country(
    isoCode: 'CM',
    name: 'Cameroun',
    dialCode: '+237',
    flagEmoji: '🇨🇲',
    currencyIso: 'XAF',
    currencySymbol: 'FCFA',
    placeholder: '6 12 34 56 78',
    nationalLength: 9,
  );

  /// All supported countries. RDC is the first item (default).
  static const List<Country> supportedCountries = [
    rdc,
    coteDIvoire,
    senegal,
    cameroun,
  ];

  /// Default selected country in local/demo environment.
  static Country get defaultCountry => rdc;

  /// Find country by ISO code or dial code.
  static Country? findByIsoCode(String iso) {
    try {
      return supportedCountries.firstWhere(
        (c) => c.isoCode.toUpperCase() == iso.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  static Country? findByDialCode(String dial) {
    try {
      final sanitized = dial.startsWith('+') ? dial : '+$dial';
      return supportedCountries.firstWhere(
        (c) => c.dialCode == sanitized,
      );
    } catch (_) {
      return null;
    }
  }
}
