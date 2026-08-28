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
  void initState() {
    super.initState();
    context.read<ContactsBloc>().add(const LoadContacts());
  }

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
                _filter = val.trim();
              });
              context.read<ContactsBloc>().add(SearchContacts(val));
            },
            decoration: InputDecoration(
              hintText: 'Rechercher par nom ou numéro...',
              prefixIcon: Icon(Icons.search_rounded, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
              suffixIcon: _filter.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _filter = '';
                        });
                        context.read<ContactsBloc>().add(const SearchContacts(''));
                      },
                    )
                  : null,
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
                  if (_filter.isNotEmpty) {
                    contacts = state.searchResults;
                  } else {
                    contacts = state.miighoContacts.isNotEmpty
                        ? state.miighoContacts
                        : state.allContacts;
                  }
                }

                if (contacts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search_rounded,
                            size: 48,
                            color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _filter.isEmpty
                                ? 'Aucun contact MÏÏghO dans votre carnet.\nTapez un nom ou un numéro pour rechercher un utilisateur.'
                                : 'Aucun utilisateur MÏÏghO trouvé pour "$_filter"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
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
                        c.phoneNumber,
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
