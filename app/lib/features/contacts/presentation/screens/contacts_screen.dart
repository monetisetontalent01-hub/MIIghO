import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/miigho_avatar.dart';
import '../../../chat/presentation/bloc/chat_bloc.dart';
import '../bloc/contacts_bloc.dart';
import '../../models/contact_model.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();

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

    return Scaffold(
      backgroundColor: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
      appBar: AppBar(
        title: const Text('Contacts MÏÏghO'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Synchroniser',
            onPressed: () {
              context.read<ContactsBloc>().add(const SyncContacts());
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                context.read<ContactsBloc>().add(SearchContacts(val));
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un contact ou numéro...',
                prefixIcon: Icon(Icons.search_rounded, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          context.read<ContactsBloc>().add(const SearchContacts(''));
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? MiighoColors.surface1 : MiighoColors.lightSurface2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle),
                ),
              ),
            ),
          ),

          // Liste des contacts
          Expanded(
            child: BlocBuilder<ContactsBloc, ContactsState>(
              builder: (context, state) {
                if (state is ContactsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is ContactsError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(state.message),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => context.read<ContactsBloc>().add(const LoadContacts()),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  );
                }

                if (state is ContactsLoaded) {
                  if (state.isSearching) {
                    if (state.searchResults.isEmpty) {
                      return const Center(child: Text('Aucun contact trouvé'));
                    }
                    return ListView.separated(
                      itemCount: state.searchResults.length,
                      separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle),
                      itemBuilder: (context, index) {
                        return _buildContactTile(context, state.searchResults[index], isDark);
                      },
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<ContactsBloc>().add(const SyncContacts());
                    },
                    child: ListView(
                      children: [
                        if (state.favorites.isNotEmpty) ...[
                          _buildSectionHeader('FAVORIS (${state.favorites.length})'),
                          ...state.favorites.map((c) => _buildContactTile(context, c, isDark)),
                          Divider(height: 16, thickness: 1, color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle),
                        ],
                        _buildSectionHeader('SUR MÏÏghO (${state.miighoContacts.length})'),
                        if (state.miighoContacts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Aucun contact MÏÏghO synchronisé',
                              style: TextStyle(color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted),
                            ),
                          )
                        else
                          ...state.miighoContacts.map((c) => _buildContactTile(context, c, isDark)),
                        if (state.nonMiighoContacts.isNotEmpty) ...[
                          Divider(height: 16, thickness: 1, color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle),
                          _buildSectionHeader('INVITER SUR MÏÏghO (${state.nonMiighoContacts.length})'),
                          ...state.nonMiighoContacts.map((c) => _buildInviteTile(context, c, isDark)),
                        ],
                      ],
                    ),
                  );
                }

                return const Center(child: Text('Chargement...'));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: MiighoColors.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildContactTile(BuildContext context, Contact contact, bool isDark) {
    return ListTile(
      leading: MiighoAvatar(
        name: contact.displayName,
        avatarUrl: contact.avatarUrl,
        isOnline: contact.isOnline,
        showPresenceIndicator: contact.isMiighoUser,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              contact.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
              ),
            ),
          ),
          if (contact.isFavorite)
            const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
        ],
      ),
      subtitle: Text(
        contact.statusMessage ?? contact.phoneNumber,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.chat_bubble_outline_rounded, color: MiighoColors.primary),
        onPressed: () {
          final recipientUuid = (contact.userId != null && contact.userId!.isNotEmpty)
              ? contact.userId!
              : contact.id;
          context.read<ChatBloc>().add(CreateConversationEvent(recipientId: recipientUuid));
          context.go('/conversations');
        },
      ),
      onTap: () {
        final recipientUuid = (contact.userId != null && contact.userId!.isNotEmpty)
            ? contact.userId!
            : contact.id;
        context.read<ChatBloc>().add(CreateConversationEvent(recipientId: recipientUuid));
        context.go('/conversations');
      },
    );
  }

  Widget _buildInviteTile(BuildContext context, Contact contact, bool isDark) {
    return ListTile(
      leading: MiighoAvatar(
        name: contact.displayName,
        backgroundColor: Colors.grey.shade600,
      ),
      title: Text(
        contact.displayName,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
        ),
      ),
      subtitle: Text(
        contact.phoneNumber,
        style: TextStyle(fontSize: 12, color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted),
      ),
      trailing: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: MiighoColors.primary,
          side: const BorderSide(color: MiighoColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        ),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invitation envoyée à ${contact.displayName}')),
          );
        },
        child: const Text('Inviter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
