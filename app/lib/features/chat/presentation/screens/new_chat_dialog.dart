import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/miigho_avatar.dart';
import '../../../contacts/presentation/bloc/contacts_bloc.dart';
import '../../../contacts/models/contact_model.dart';

class NewChatDialog extends StatefulWidget {
  final Function(Contact contact) onContactSelected;

  const NewChatDialog({super.key, required this.onContactSelected});

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
                'Nouvelle Discussion',
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
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _filter = val.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Rechercher un contact MÏÏghO...',
              prefixIcon: Icon(Icons.search_rounded, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
              filled: true,
              fillColor: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BlocBuilder<ContactsBloc, ContactsState>(
              builder: (context, state) {
                if (state is ContactsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<Contact> contacts = [];
                if (state is ContactsLoaded) {
                  contacts = state.miighoContacts.where((c) {
                    if (_filter.isEmpty) return true;
                    return c.displayName.toLowerCase().contains(_filter) ||
                        c.phoneNumber.contains(_filter);
                  }).toList();
                }

                if (contacts.isEmpty) {
                  final isDirectId = _filter.isNotEmpty;
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Aucun contact MÏÏghO dans votre carnet',
                          style: TextStyle(color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted),
                        ),
                        if (isDirectId) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onContactSelected(
                                Contact(
                                  id: _searchController.text.trim(),
                                  displayName: _searchController.text.trim(),
                                  phoneNumber: _searchController.text.trim(),
                                  isMiighoUser: true,
                                ),
                              );
                            },
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: Text('Discuter avec "${_searchController.text.trim()}"'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 64,
                    color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
                  ),
                  itemBuilder: (context, index) {
                    final c = contacts[index];
                    return ListTile(
                      leading: MiighoAvatar(
                        name: c.displayName,
                        avatarUrl: c.avatarUrl,
                        isOnline: c.isOnline,
                        showPresenceIndicator: true,
                      ),
                      title: Text(
                        c.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                        ),
                      ),
                      subtitle: Text(
                        c.statusMessage ?? c.phoneNumber,
                        style: TextStyle(fontSize: 12, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                      ),
                      trailing: const Icon(Icons.chat_bubble_outline_rounded, color: MiighoColors.primary, size: 20),
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onContactSelected(c);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
