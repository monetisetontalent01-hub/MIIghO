import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/miigho_button.dart';
import '../../../../shared/widgets/miigho_text_field.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(radius: 50, child: Icon(Icons.camera_alt, size: 40)),
            const SizedBox(height: 24),
            const MiighoTextField(label: 'Nom d\'affichage'),
            const SizedBox(height: 16),
            const MiighoTextField(label: 'Bio (optionnel)'),
            const Spacer(),
            MiighoButton(
              text: 'Terminer',
              onPressed: () => context.go('/conversations'),
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
