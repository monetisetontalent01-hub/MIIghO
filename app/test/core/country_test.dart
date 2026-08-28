import 'package:flutter_test/flutter_test.dart';
import 'package:miigho/core/models/country.dart';

void main() {
  group('Country Model & E.164 Normalization Tests', () {
    test('1. RDC: 0812345678 (10 digits with leading 0) -> +243812345678', () {
      final e164 = Country.rdc.formatToE164('0812345678');
      expect(e164, '+243812345678');
      expect(Country.rdc.isValidE164(e164), isTrue);
      expect(Country.rdc.isValidInput('0812345678'), isTrue);
    });

    test('2. RDC: 812345678 (9 digits national) -> +243812345678', () {
      final e164 = Country.rdc.formatToE164('812345678');
      expect(e164, '+243812345678');
      expect(Country.rdc.isValidE164(e164), isTrue);
      expect(Country.rdc.isValidInput('812345678'), isTrue);
    });

    test('3. RDC: +243812345678 (already formatted E.164) -> +243812345678', () {
      final e164 = Country.rdc.formatToE164('+243812345678');
      expect(e164, '+243812345678');
      expect(Country.rdc.isValidE164(e164), isTrue);
      expect(Country.rdc.isValidInput('+243812345678'), isTrue);
    });

    test('4. Côte d\'Ivoire: 0506169325 -> +2250506169325', () {
      final e164 = Country.coteDIvoire.formatToE164('0506169325');
      expect(e164, '+2250506169325');
      expect(Country.coteDIvoire.isValidE164(e164), isTrue);
      expect(Country.coteDIvoire.isValidInput('0506169325'), isTrue);
    });

    test('5. Sénégal: 771234567 -> +221771234567', () {
      final e164 = Country.senegal.formatToE164('771234567');
      expect(e164, '+221771234567');
      expect(Country.senegal.isValidE164(e164), isTrue);
      expect(Country.senegal.isValidInput('771234567'), isTrue);
    });

    test('6. Cameroun: 612345678 -> +237612345678', () {
      final e164 = Country.cameroun.formatToE164('612345678');
      expect(e164, '+237612345678');
      expect(Country.cameroun.isValidE164(e164), isTrue);
      expect(Country.cameroun.isValidInput('612345678'), isTrue);
    });

    test('7. Empty number -> rejected', () {
      expect(Country.rdc.formatToE164(''), '');
      expect(Country.rdc.formatToE164('   '), '');
      expect(Country.rdc.isValidInput(''), isFalse);
      expect(Country.rdc.isValidInput('   '), isFalse);
    });

    test('8. Invalid number -> rejected', () {
      expect(Country.rdc.isValidInput('123'), isFalse);
      expect(Country.rdc.isValidInput('abc-xyz'), isFalse);
      expect(Country.rdc.isValidE164('+243123'), isFalse);
      expect(Country.rdc.isValidE164('+2250506169325'), isFalse); // Dial code mismatch
    });

    test('9. Double dial code -> corrected without duplication', () {
      // User pasted full 243812345678 while dialCode is +243
      expect(Country.rdc.formatToE164('243812345678'), '+243812345678');
      expect(Country.rdc.formatToE164('+243812345678'), '+243812345678');
      // Verify no +243243812345678 is generated
      expect(Country.rdc.formatToE164('243812345678').startsWith('+243243'), isFalse);
    });

    test('Default country is RDC (CD / +243 / CDF / FC)', () {
      expect(Country.defaultCountry, Country.rdc);
      expect(Country.defaultCountry.isoCode, 'CD');
      expect(Country.defaultCountry.dialCode, '+243');
      expect(Country.defaultCountry.currencyIso, 'CDF');
      expect(Country.defaultCountry.currencySymbol, 'FC');
    });

    test('Côte d\'Ivoire config (CI / +225 / XOF / FCFA)', () {
      expect(Country.coteDIvoire.isoCode, 'CI');
      expect(Country.coteDIvoire.dialCode, '+225');
      expect(Country.coteDIvoire.currencyIso, 'XOF');
      expect(Country.coteDIvoire.currencySymbol, 'FCFA');
    });
  });
}
