import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/miigho_avatar.dart';
import '../../../../shared/widgets/miigho_button.dart';
import '../bloc/identity_bloc.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    final state = context.read<IdentityBloc>().state;
    if (state is IdentityLoaded) {
      _nameController = TextEditingController(text: state.profile.displayName);
      _emailController = TextEditingController(text: state.profile.email);
      _bioController = TextEditingController(text: state.profile.bio);
    } else {
      _nameController = TextEditingController(text: 'Mamadou Koné');
      _emailController = TextEditingController(text: 'mamadou.kone@miigho.africa');
      _bioController = TextEditingController(text: 'Pionnier MÏÏghO');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    context.read<IdentityBloc>().add(
          UpdateProfileEvent(
            displayName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            bio: _bioController.text.trim(),
          ),
        );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil MÏÏghO mis à jour avec succès')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
      appBar: AppBar(
        title: const Text('Modifier mon profil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                MiighoAvatar(
                  name: _nameController.text,
                  size: MiighoAvatarSize.xl,
                  isOnline: true,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: MiighoColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? MiighoColors.canvas : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'INFORMATIONS PUBLIQUES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: MiighoColors.primary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom et Prénoms',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Adresse Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Bio / Statut MÏÏghO',
              prefixIcon: Icon(Icons.info_outline_rounded),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 32),

          MiighoButton(
            text: 'Enregistrer les modifications',
            onPressed: _saveProfile,
          ),
        ],
      ),
    );
  }
}
