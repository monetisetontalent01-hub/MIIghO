import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/conversation_tile.dart';
import '../../../../shared/widgets/miigho_avatar.dart';
import '../../../contacts/presentation/bloc/contacts_bloc.dart';
import '../../../contacts/models/contact_model.dart';
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
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(LoadConversations());
    context.read<ContactsBloc>().add(const LoadContacts());
  }

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
          final recipientUuid = (contact.userId != null && contact.userId!.isNotEmpty)
              ? contact.userId!
              : contact.id;

          debugPrint('=== CREATE CONVERSATION DEBUG ===');
          debugPrint('recipientId: $recipientUuid');
          debugPrint('recipientPhone: ${contact.phoneNumber}');
          debugPrint('recipientName: ${contact.displayName}');
          debugPrint('endpoint: POST /api/v1/chat/conversations');
          debugPrint('payload: {"recipient_id": "$recipientUuid"}');

          context.read<ChatBloc>().add(
                CreateConversationEvent(
                  recipientId: recipientUuid,
                ),
              );
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
                  memberIds: members.map((m) => m.userId ?? m.id).toList(),
                ),
              );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Groupe "$groupName" créé avec succès')),
          );
        },
      ),
    );
  }

  void _showRequestsSheet(BuildContext context, List<ContactRequest> requests) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? MiighoColors.surface1 : MiighoColors.lightSurface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? MiighoColors.borderStrong : MiighoColors.lightBorderMedium,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Demandes de contact reçues',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (requests.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'Aucune demande en attente.',
                        style: TextStyle(color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted),
                      ),
                    ),
                  )
                else
                  ...requests.map((r) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: MiighoAvatar(
                        name: r.senderName,
                        avatarUrl: r.senderAvatar,
                        size: MiighoAvatarSize.sm,
                      ),
                      title: Text(
                        r.senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                        ),
                      ),
                      subtitle: const Text(
                        'Souhaite discuter avec vous',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                            tooltip: 'Refuser',
                            onPressed: () {
                              context.read<ContactsBloc>().add(RejectContactRequestEvent(r.id));
                              Navigator.of(ctx).pop();
                            },
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MiighoColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: () {
                              context.read<ContactsBloc>().add(AcceptContactRequestEvent(r.id));
                              Navigator.of(ctx).pop();
                              context.read<ChatBloc>().add(CreateConversationEvent(recipientId: r.senderId));
                            },
                            child: const Text('Accepter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
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
      body: BlocListener<ChatBloc, ChatState>(
        listener: (context, state) {
          if (state is ConversationsLoaded && state.activeConversationId != null) {
            final activeId = state.activeConversationId!;
            if (widget.onConversationSelected != null) {
              widget.onConversationSelected!(activeId);
            } else {
              context.push('/conversations/$activeId');
            }
          } else if (state is ChatError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        child: Column(
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

          // Bannière Demandes de Contact reçues
          BlocBuilder<ContactsBloc, ContactsState>(
            builder: (context, contactState) {
              if (contactState is ContactsLoaded && contactState.pendingRequestsCount > 0) {
                final count = contactState.pendingRequestsCount;
                return Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: MiighoColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MiighoColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: MiighoColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$count demande${count > 1 ? 's' : ''} de contact en attente',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                              ),
                            ),
                            Text(
                              'Acceptez pour démarrer la discussion',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showRequestsSheet(context, contactState.incomingRequests),
                        style: TextButton.styleFrom(
                          foregroundColor: MiighoColors.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Voir', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
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

                if (state is ChatError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent.withValues(alpha: 0.8)),
                          const SizedBox(height: 12),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => context.read<ChatBloc>().add(LoadConversations()),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                List<MiighoConversation> conversations = [];
                if (state is ConversationsLoaded) {
                  conversations = state.conversations;
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: MiighoColors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.forum_outlined,
                              size: 32,
                              color: MiighoColors.primary.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Aucun résultat pour "$_searchQuery"'
                                : 'Aucune discussion pour le moment',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Essayez un autre nom ou numéro,\nou recherchez un utilisateur MÏÏghO.'
                                : 'Commencez par rechercher un contact\net envoyez votre premier message.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _openNewChat,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MiighoColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text(
                              'Démarrer une nouvelle discussion',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
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
      ),
      floatingActionButton: FloatingActionButton(
              mini: widget.isEmbedded,
              backgroundColor: MiighoColors.primary,
              onPressed: _openNewChat,
              tooltip: 'Nouveau message',
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
