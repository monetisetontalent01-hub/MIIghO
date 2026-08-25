import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/conversation_tile.dart';
import '../bloc/chat_bloc.dart';
import '../../models/chat_models.dart';
import 'new_chat_dialog.dart';
import 'create_group_dialog.dart';

class ConversationsScreen extends StatefulWidget {
  final Function(String id)? onConversationSelected;
  final String? selectedConversationId;
  final bool isEmbedded;

  const ConversationsScreen({
    super.key,
    this.onConversationSelected,
    this.selectedConversationId,
    this.isEmbedded = false,
  });

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'unread', 'groups'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openNewChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NewChatDialog(
        onContactSelected: (contact) {
          context.read<ChatBloc>().add(
                CreateConversationEvent(
                  recipientId: contact.id,
                ),
              );
          if (widget.onConversationSelected != null) {
            widget.onConversationSelected!(contact.id);
          } else {
            context.push('/conversations/${contact.id}');
          }
        },
      ),
    );
  }

  void _openCreateGroup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateGroupDialog(
        onGroupCreated: (groupName, members) {
          context.read<ChatBloc>().add(
                CreateGroupEvent(
                  name: groupName,
                  memberIds: members.map((m) => m.id).toList(),
                ),
              );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Groupe "$groupName" créé avec succès')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
      appBar: AppBar(
        title: const Text('MÏÏghO Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Créer un groupe',
            onPressed: _openCreateGroup,
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Nouveau message',
            onPressed: _openNewChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de Recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Rechercher une discussion...',
                prefixIcon: Icon(Icons.search_rounded, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),

          // Filtres rapides (Chips)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('all', 'Toutes', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('unread', 'Non lues', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('groups', 'Groupes', isDark),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Divider(height: 1, color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle),

          // Liste des discussions
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                if (state is ChatLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<MiighoConversation> conversations = [];
                if (state is ConversationsLoaded) {
                  conversations = state.conversations;
                } else {
                  conversations = [
                    MiighoConversation(
                      id: 'conv_0',
                      title: 'Amina Diallo',
                      subtitle: 'Parfait, on valide les maquettes !',
                      updatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
                      unreadCount: 3,
                      isPinned: true,
                      isOnline: true,
                      isVerified: true,
                    ),
                    MiighoConversation(
                      id: 'conv_1',
                      title: 'Équipe MÏÏghO Core',
                      subtitle: 'Réunion de cadrage technique à 10h',
                      updatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
                      isGroup: true,
                    ),
                    MiighoConversation(
                      id: 'conv_2',
                      title: 'Kofi Mensah',
                      subtitle: 'Message vocal reçu',
                      updatedAt: DateTime.now().subtract(const Duration(minutes: 38)),
                      unreadCount: 1,
                      isMuted: true,
                    ),
                  ];
                }

                // Filtrage selon recherche & chips
                final filtered = conversations.where((c) {
                  final matchesSearch = _searchQuery.isEmpty ||
                      c.title.toLowerCase().contains(_searchQuery) ||
                      c.subtitle.toLowerCase().contains(_searchQuery);
                  if (!matchesSearch) return false;

                  if (_selectedFilter == 'unread') {
                    return c.unreadCount > 0;
                  }
                  if (_selectedFilter == 'groups') {
                    return c.isGroup;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucune discussion trouvée',
                      style: TextStyle(
                        color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<ChatBloc>().add(LoadConversations());
                  },
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 82,
                      endIndent: 16,
                      color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
                    ),
                    itemBuilder: (context, index) {
                      final conv = filtered[index];
                      final isSelected = widget.selectedConversationId == conv.id;

                      return Container(
                        color: isSelected
                            ? MiighoColors.primary.withValues(alpha: isDark ? 0.15 : 0.08)
                            : Colors.transparent,
                        child: ConversationTile(
                          id: conv.id,
                          title: conv.title,
                          subtitle: conv.subtitle,
                          avatarUrl: conv.avatarUrl,
                          updatedAt: conv.updatedAt,
                          unreadCount: conv.unreadCount,
                          isPinned: conv.isPinned,
                          isMuted: conv.isMuted,
                          isGroup: conv.isGroup,
                          isOnline: conv.isOnline,
                          isTyping: conv.isTyping,
                          typingUserName: conv.typingUserName,
                          isLastMessageFromMe: conv.isLastMessageFromMe,
                          lastMessageStatus: conv.lastMessageStatus,
                          messageType: conv.messageType,
                          isVerified: conv.isVerified,
                          onTap: () {
                            if (widget.onConversationSelected != null) {
                              widget.onConversationSelected!(conv.id);
                            } else {
                              context.push('/conversations/${conv.id}');
                            }
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.isEmbedded
          ? null
          : FloatingActionButton(
              backgroundColor: MiighoColors.primary,
              onPressed: _openNewChat,
              child: const Icon(Icons.edit_rounded, color: Colors.white),
            ),
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = key;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? MiighoColors.primary
              : (isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? MiighoColors.primary
                : (isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}
