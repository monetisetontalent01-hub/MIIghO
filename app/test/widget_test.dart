import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miigho/core/models/country.dart';
import 'package:miigho/features/auth/presentation/widgets/country_picker_modal.dart';

void main() {
  testWidgets('CountryPickerModal displays supported African countries', (WidgetTester tester) async {
    Country? selectedCountry;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountryPickerModal(
            selectedCountry: Country.rdc,
            onCountrySelected: (country) {
              selectedCountry = country;
            },
          ),
        ),
      ),
    );

    // Verify modal title and country listings
    expect(find.text('Choisir un pays'), findsOneWidget);
    expect(find.text('RD Congo'), findsOneWidget);
    expect(find.text('Côte d\'Ivoire'), findsOneWidget);
    expect(find.text('Sénégal'), findsOneWidget);
    expect(find.text('Cameroun'), findsOneWidget);
    expect(find.text('+243'), findsOneWidget);
    expect(find.text('+225'), findsOneWidget);

    // Tap Côte d'Ivoire
    await tester.tap(find.text('Côte d\'Ivoire'));
    await tester.pump();

    expect(selectedCountry, isNotNull);
    expect(selectedCountry!.isoCode, 'CI');
    expect(selectedCountry!.dialCode, '+225');
  });
}
