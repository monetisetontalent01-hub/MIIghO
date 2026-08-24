import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go('/auth/profile-setup');
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Code envoyé au ${widget.phone}'),
                const SizedBox(height: 24),
                MiighoTextField(
                  controller: _codeController,
                  label: 'Code à 6 chiffres',
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const Spacer(),
                MiighoButton(
                  text: 'Vérifier',
                  isLoading: state is AuthLoading,
                  onPressed: () {
                    context.read<AuthBloc>().add(OTPVerifyRequested(widget.phone, _codeController.text));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
