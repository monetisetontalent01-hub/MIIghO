import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/miigho_avatar.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
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
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
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
                fillColor: const Color(0x0D000000),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
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
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                      itemBuilder: (context, index) {
                        return _buildContactTile(context, state.searchResults[index]);
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
                          ...state.favorites.map((c) => _buildContactTile(context, c)),
                          const Divider(height: 16, thickness: 4, color: Color(0x0A000000)),
                        ],
                        _buildSectionHeader('SUR MÏÏghO (${state.miighoContacts.length})'),
                        if (state.miighoContacts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Aucun contact MÏÏghO synchronisé', style: TextStyle(color: Colors.grey)),
                          )
                        else
                          ...state.miighoContacts.map((c) => _buildContactTile(context, c)),
                        if (state.nonMiighoContacts.isNotEmpty) ...[
                          const Divider(height: 16, thickness: 4, color: Color(0x0A000000)),
                          _buildSectionHeader('INVITER SUR MÏÏghO (${state.nonMiighoContacts.length})'),
                          ...state.nonMiighoContacts.map((c) => _buildInviteTile(context, c)),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: MiighoColors.primary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_rounded), label: 'Discussions'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Contacts'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Paramètres'),
        ],
        onTap: (index) {
          if (index == 0) context.go('/conversations');
          if (index == 2) context.go('/settings');
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: MiighoColors.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildContactTile(BuildContext context, Contact contact) {
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
        style: const TextStyle(fontSize: 13, color: Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: MiighoColors.primary),
            onPressed: () {
              context.push('/conversations/${contact.id}');
            },
          ),
        ],
      ),
      onTap: () {
        context.push('/conversations/${contact.id}');
      },
    );
  }

  Widget _buildInviteTile(BuildContext context, Contact contact) {
    return ListTile(
      leading: MiighoAvatar(
        name: contact.displayName,
        backgroundColor: Colors.grey.shade400,
      ),
      title: Text(contact.displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(contact.phoneNumber, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
