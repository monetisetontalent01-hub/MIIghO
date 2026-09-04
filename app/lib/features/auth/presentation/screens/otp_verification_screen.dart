import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../bloc/auth_bloc.dart';
import '../../../identity/presentation/bloc/identity_bloc.dart';
import '../../../chat/presentation/bloc/chat_bloc.dart';
import '../../../pay/presentation/bloc/pay_bloc.dart';
import '../../../../shared/widgets/miigho_button.dart';
import '../../../../shared/widgets/miigho_text_field.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  const OtpVerificationScreen({super.key, required this.phone});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _handleVerify() {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir un code à 6 chiffres valide'),
          backgroundColor: MiighoColors.error,
        ),
      );
      return;
    }
    context.read<AuthBloc>().add(OTPVerifyRequested(widget.phone, code));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiighoColors.canvas,
      appBar: AppBar(
        title: const Text('Vérification OTP'),
        backgroundColor: MiighoColors.canvas,
        elevation: 0,
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.read<IdentityBloc>().add(LoadIdentity());
            context.read<ChatBloc>().add(LoadConversations());
            context.read<PayBloc>().add(LoadPayWallet());
            context.go('/home');
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
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: MiighoColors.textSecondary,
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'Code envoyé au numéro sécurisé '),
                      TextSpan(
                        text: widget.phone,
                        style: const TextStyle(
                          color: MiighoColors.gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: '. Saisissez le code à 6 chiffres pour continuer.'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                MiighoTextField(
                  controller: _codeController,
                  label: 'Code de vérification (6 chiffres)',
                  hintText: '123456',
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onSubmitted: _handleVerify,
                ),
                if (kDebugMode || const bool.fromEnvironment('DEV_MODE', defaultValue: true)) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: MiighoColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: MiighoColors.borderSubtle),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: MiighoColors.gold, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mode Dev / Sandbox : le code OTP est 123456',
                            style: TextStyle(
                              color: MiighoColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                MiighoButton(
                  text: 'Vérifier le code',
                  isLoading: state is AuthLoading,
                  onPressed: _handleVerify,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
