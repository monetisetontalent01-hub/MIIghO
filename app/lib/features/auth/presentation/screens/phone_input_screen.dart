import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';
import '../../../../shared/widgets/miigho_button.dart';
import '../../../../shared/widgets/miigho_text_field.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrez votre numéro')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is OTPSent) {
            context.push('/auth/otp', extra: _phoneController.text);
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
                const Text('Nous allons envoyer un code par SMS pour vérifier votre numéro.'),
                const SizedBox(height: 24),
                MiighoTextField(
                  controller: _phoneController,
                  label: 'Numéro de téléphone',
                  keyboardType: TextInputType.phone,
                  prefixText: '+225 ', // Simplification for MVP
                ),
                const Spacer(),
                MiighoButton(
                  text: 'Envoyer le code',
                  isLoading: state is AuthLoading,
                  onPressed: () {
                    final phone = '+225${_phoneController.text}';
                    context.read<AuthBloc>().add(OTPSendRequested(phone));
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
