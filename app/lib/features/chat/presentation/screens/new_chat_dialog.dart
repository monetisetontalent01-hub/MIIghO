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

  Widget _buildActionButton(BuildContext context, Contact c, bool isDark) {
    switch (c.relationshipStatus) {
      case 'accepted':
        return ElevatedButton.icon(
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
          label: const Text('Message'),
          style: ElevatedButton.styleFrom(
            backgroundColor: MiighoColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            widget.onContactSelected(c);
          },
        );

      case 'pending_sent':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted,
              ),
              const SizedBox(width: 4),
              Text(
                'Envoyée',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

      case 'pending_received':
        return ElevatedButton.icon(
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('Accepter'),
          style: ElevatedButton.styleFrom(
            backgroundColor: MiighoColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            final targetId = c.userId ?? c.id;
            context.read<ContactsBloc>().add(SendContactRequestEvent(targetId));
            Navigator.of(context).pop();
            widget.onContactSelected(c);
          },
        );

      case 'none':
      default:
        return OutlinedButton.icon(
          icon: const Icon(Icons.person_add_outlined, size: 16),
          label: const Text('Ajouter'),
          style: OutlinedButton.styleFrom(
            foregroundColor: MiighoColors.primary,
            side: const BorderSide(color: MiighoColors.primary),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            final targetId = c.userId ?? c.id;
            context.read<ContactsBloc>().add(SendContactRequestEvent(targetId));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Demande de contact envoyée à ${c.displayName}'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        );
    }
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
              prefixIcon: Icon(
                Icons.search_rounded,
                color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
              ),
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
                    final hasMiighoId = c.miighoId != null && c.miighoId!.isNotEmpty;

                    return ListTile(
                      leading: MiighoAvatar(
                        name: c.displayName,
                        avatarUrl: c.avatarUrl,
                        isOnline: c.isOnline,
                        showPresenceIndicator: true,
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
                          fontSize: 12,
                          color: hasMiighoId
                              ? MiighoColors.primary
                              : (isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                          fontWeight: hasMiighoId ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      trailing: _buildActionButton(context, c, isDark),
                      onTap: () {
                        if (c.relationshipStatus == 'accepted') {
                          Navigator.of(context).pop();
                          widget.onContactSelected(c);
                        } else if (c.relationshipStatus == 'pending_sent') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Votre demande de contact est en attente d\'acceptation.'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Veuillez envoyer ou accepter une demande de contact avant de discuter.'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
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
