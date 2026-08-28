import 'package:flutter/material.dart';
import '../../../../core/models/country.dart';
import '../../../../core/theme/colors.dart';

/// Modal dialog / bottom sheet allowing the user to select a country.
class CountryPickerModal extends StatefulWidget {
  final Country selectedCountry;
  final ValueChanged<Country> onCountrySelected;

  const CountryPickerModal({
    super.key,
    required this.selectedCountry,
    required this.onCountrySelected,
  });

  static Future<Country?> show(
    BuildContext context, {
    required Country selectedCountry,
  }) {
    return showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CountryPickerModal(
        selectedCountry: selectedCountry,
        onCountrySelected: (country) {
          Navigator.of(context).pop(country);
        },
      ),
    );
  }

  @override
  State<CountryPickerModal> createState() => _CountryPickerModalState();
}

class _CountryPickerModalState extends State<CountryPickerModal> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Country> get _filteredCountries {
    if (_searchQuery.isEmpty) {
      return Country.supportedCountries;
    }
    final query = _searchQuery.toLowerCase().trim();
    return Country.supportedCountries.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.dialCode.toLowerCase().contains(query) ||
          c.isoCode.toLowerCase().contains(query) ||
          c.currencyIso.toLowerCase().contains(query) ||
          c.currencySymbol.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCountries;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: MiighoColors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: MiighoColors.borderMedium, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MiighoColors.textMuted.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Choisir un pays',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: MiighoColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: MiighoColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(color: MiighoColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher un pays ou indicatif...',
                  hintStyle: const TextStyle(color: MiighoColors.textMuted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: MiighoColors.textSecondary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: MiighoColors.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: MiighoColors.surface2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: MiighoColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: MiighoColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: MiighoColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Country List
            Flexible(
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Aucun pays trouvé',
                        style: TextStyle(color: MiighoColors.textMuted, fontSize: 14),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(
                        color: MiighoColors.borderSubtle,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final country = filtered[index];
                        final isSelected = country == widget.selectedCountry;

                        return InkWell(
                          onTap: () => widget.onCountrySelected(country),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected ? MiighoColors.primaryAlpha : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  country.flagEmoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        country.name,
                                        style: TextStyle(
                                          color: isSelected ? MiighoColors.gold : MiighoColors.textPrimary,
                                          fontSize: 15,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${country.isoCode} • Devise: ${country.currencyIso} (${country.currencySymbol})',
                                        style: const TextStyle(
                                          color: MiighoColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: MiighoColors.surface3,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    country.dialCode,
                                    style: TextStyle(
                                      color: isSelected ? MiighoColors.gold : MiighoColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle, color: MiighoColors.gold, size: 18),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
