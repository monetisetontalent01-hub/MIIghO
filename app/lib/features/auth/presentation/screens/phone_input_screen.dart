import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/country.dart';
import '../../../../core/theme/colors.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/country_picker_modal.dart';
import '../../../../shared/widgets/miigho_button.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _phoneController = TextEditingController();
  Country _selectedCountry = Country.defaultCountry;
  String? _validationError;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onCountryTap() async {
    final picked = await CountryPickerModal.show(
      context,
      selectedCountry: _selectedCountry,
    );
    if (picked != null && picked != _selectedCountry) {
      setState(() {
        _selectedCountry = picked;
        _validationError = null;
      });
    }
  }

  void _handleSendOTP() {
    final rawText = _phoneController.text.trim();
    if (rawText.isEmpty) {
      setState(() => _validationError = 'Veuillez saisir votre numéro de téléphone');
      return;
    }

    final e164 = _selectedCountry.formatToE164(rawText);
    if (!_selectedCountry.isValidE164(e164)) {
      setState(() {
        _validationError = 'Numéro invalide pour ${_selectedCountry.name} (attendu: ${_selectedCountry.placeholder})';
      });
      return;
    }

    setState(() => _validationError = null);
    context.read<AuthBloc>().add(OTPSendRequested(e164));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiighoColors.canvas,
      appBar: AppBar(
        title: const Text('Entrez votre numéro'),
        backgroundColor: MiighoColors.canvas,
        elevation: 0,
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is OTPSent) {
            // Pass full E.164 phone number (e.g. +243812345678, +2250506169325)
            context.push('/auth/otp', extra: state.phone);
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: MiighoColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nous allons vous envoyer un code par SMS pour vérifier et sécuriser votre compte.',
                  style: TextStyle(
                    color: MiighoColors.textSecondary,
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),

                // Label
                const Text(
                  'Numéro de téléphone',
                  style: TextStyle(
                    color: MiighoColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Country Selector + Phone Field Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Country Picker Button
                    InkWell(
                      onTap: _onCountryTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: MiighoColors.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: MiighoColors.borderMedium,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedCountry.flagEmoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedCountry.dialCode,
                              style: const TextStyle(
                                color: MiighoColors.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: MiighoColors.textSecondary,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Phone Number Input Field
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) {
                          if (_validationError != null) {
                            setState(() => _validationError = null);
                          }
                        },
                        onSubmitted: (_) => _handleSendOTP(),
                        style: const TextStyle(
                          color: MiighoColors.textPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: _selectedCountry.placeholder,
                          hintStyle: const TextStyle(
                            color: MiighoColors.textMuted,
                            fontSize: 14.5,
                          ),
                          filled: true,
                          fillColor: MiighoColors.surface2,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _validationError != null ? MiighoColors.error : MiighoColors.borderMedium,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _validationError != null ? MiighoColors.error : MiighoColors.borderMedium,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: MiighoColors.gold,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Error Message if invalid
                if (_validationError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _validationError!,
                    style: const TextStyle(
                      color: MiighoColors.error,
                      fontSize: 12.5,
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Text(
                  'Pays sélectionné : ${_selectedCountry.name} (${_selectedCountry.isoCode}) • Devise : ${_selectedCountry.currencyIso} (${_selectedCountry.currencySymbol})',
                  style: const TextStyle(
                    color: MiighoColors.textMuted,
                    fontSize: 12,
                  ),
                ),

                const Spacer(),

                // Submit Button
                MiighoButton(
                  text: 'Envoyer le code',
                  isLoading: state is AuthLoading,
                  onPressed: _handleSendOTP,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
