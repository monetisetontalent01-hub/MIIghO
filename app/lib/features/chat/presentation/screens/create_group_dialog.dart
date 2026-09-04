import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/miigho_avatar.dart';
import '../../../../shared/widgets/miigho_button.dart';
import '../../../contacts/presentation/bloc/contacts_bloc.dart';
import '../../../contacts/models/contact_model.dart';

class CreateGroupDialog extends StatefulWidget {
  final Function(String groupName, List<Contact> members) onGroupCreated;

  const CreateGroupDialog({super.key, required this.onGroupCreated});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selectedContactIds = {};
  final List<Contact> _selectedContacts = [];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner le nom du groupe')),
      );
      return;
    }
    if (_selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un membre')),
      );
      return;
    }

    Navigator.of(context).pop();
    widget.onGroupCreated(_nameController.text.trim(), _selectedContacts);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? MiighoColors.surface1 : MiighoColors.lightSurface1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? MiighoColors.borderStrong : MiighoColors.lightBorderMedium,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Créer un Groupe MÏÏghO',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: MiighoColors.primaryAlpha,
                  shape: BoxShape.circle,
                  border: Border.all(color: MiighoColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.groups_rounded, color: MiighoColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Nom du groupe...',
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Membres sélectionnés
          if (_selectedContacts.isNotEmpty) ...[
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedContacts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final c = _selectedContacts[index];
                  return Chip(
                    avatar: MiighoAvatar(name: c.displayName, size: MiighoAvatarSize.xs),
                    label: Text(c.displayName.split(' ').first, style: const TextStyle(fontSize: 12)),
                    onDeleted: () {
                      setState(() {
                        _selectedContactIds.remove(c.id);
                        _selectedContacts.removeWhere((item) => item.id == c.id);
                      });
                    },
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ajouter des membres (${_selectedContacts.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Expanded(
            child: BlocBuilder<ContactsBloc, ContactsState>(
              builder: (context, state) {
                if (state is ContactsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<Contact> contacts = [];
                if (state is ContactsLoaded) {
                  // Only allow adding mutual (accepted) contacts to groups
                  contacts = state.allContacts.where((c) => c.relationshipStatus == 'accepted' || c.isMutualContact).toList();
                  if (contacts.isEmpty) {
                    // Fallback to miighoContacts if relations not yet tagged as accepted
                    contacts = state.miighoContacts;
                  }
                }

                if (contacts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Vous devez avoir des contacts mutuels acceptés pour créer un groupe.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final c = contacts[index];
                    final isSelected = _selectedContactIds.contains(c.id);
                    final hasMiighoId = c.miighoId != null && c.miighoId!.isNotEmpty;

                    return CheckboxListTile(
                      value: isSelected,
                      activeColor: MiighoColors.primary,
                      secondary: MiighoAvatar(
                        name: c.displayName,
                        avatarUrl: c.avatarUrl,
                        size: MiighoAvatarSize.sm,
                      ),
                      title: Text(
                        c.displayName.isNotEmpty ? c.displayName : 'Utilisateur MÏÏghO',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                        ),
                      ),
                      subtitle: Text(
                        hasMiighoId ? c.miighoId! : c.phoneNumber,
                        style: TextStyle(
                          fontSize: 11,
                          color: hasMiighoId
                              ? MiighoColors.primary
                              : (isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                          fontWeight: hasMiighoId ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedContactIds.add(c.id);
                            _selectedContacts.add(c);
                          } else {
                            _selectedContactIds.remove(c.id);
                            _selectedContacts.removeWhere((item) => item.id == c.id);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 12),
          MiighoButton(
            text: 'Créer le groupe',
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
