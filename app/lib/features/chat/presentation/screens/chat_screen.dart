import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/miigho_avatar.dart';
import '../../models/chat_models.dart';
import '../bloc/chat_bloc.dart';
import '../widgets/chat_input.dart';
import '../widgets/contact_info_drawer.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final bool isEmbedded;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.isEmbedded = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  MessageReplyData? _replyData;
  bool _showContactInfo = false;

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(LoadMessages(widget.conversationId));
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      context.read<ChatBloc>().add(LoadMessages(widget.conversationId));
    }
  }

  void _handleSendMessage(String text, {String? replyToId}) {
    context.read<ChatBloc>().add(
          SendTextMessage(
            conversationId: widget.conversationId,
            content: text,
            replyToId: replyToId ?? _replyData?.id,
          ),
        );
    setState(() {
      _replyData = null;
    });
  }

  void _handleSendVoice(String audioPath, Duration duration, {String? replyToId}) {
    context.read<ChatBloc>().add(
          SendVoiceMessage(
            conversationId: widget.conversationId,
            audioPath: audioPath,
            duration: duration,
            replyToId: replyToId ?? _replyData?.id,
          ),
        );
    setState(() {
      _replyData = null;
    });
  }

  void _handleSendMedia(String filePath, String mediaType, {String? caption, String? replyToId}) {
    context.read<ChatBloc>().add(
          SendMediaMessage(
            conversationId: widget.conversationId,
            filePath: filePath,
            mediaType: mediaType,
            caption: caption,
            replyToId: replyToId ?? _replyData?.id,
          ),
        );
    setState(() {
      _replyData = null;
    });
  }

  void _setReplyMessage(MiighoMessageItem msg) {
    setState(() {
      _replyData = MessageReplyData(
        id: msg.id,
        senderName: msg.isMe ? 'Vous' : 'Contact',
        content: msg.content,
        type: msg.type,
      );
    });
  }

  void _showContextMenu(MiighoMessageItem msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emojis = ['👍', '❤️', '🔥', '👏', '😂', '🎉'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? MiighoColors.surface1 : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick emoji reaction bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: emojis.map((emoji) {
                      return InkWell(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          context.read<ChatBloc>().add(
                                AddReactionEvent(
                                  conversationId: widget.conversationId,
                                  messageId: msg.id,
                                  emoji: emoji,
                                ),
                              );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Text(emoji, style: const TextStyle(fontSize: 26)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1),

                // Copy
                ListTile(
                  leading: const Icon(Icons.copy_rounded, size: 20),
                  title: const Text('Copier le texte', style: TextStyle(fontSize: 14)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Clipboard.setData(ClipboardData(text: msg.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Texte copié'), duration: Duration(seconds: 1)),
                    );
                  },
                ),

                // Reply
                ListTile(
                  leading: const Icon(Icons.reply_rounded, size: 20),
                  title: const Text('Répondre', style: TextStyle(fontSize: 14)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _setReplyMessage(msg);
                  },
                ),

                // Edit (only if isMe)
                if (msg.isMe)
                  ListTile(
                    leading: const Icon(Icons.edit_rounded, size: 20),
                    title: const Text('Modifier', style: TextStyle(fontSize: 14)),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showEditDialog(msg);
                    },
                  ),

                // Delete (only if isMe)
                if (msg.isMe)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                    title: const Text(
                      'Supprimer',
                      style: TextStyle(fontSize: 14, color: Colors.redAccent),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showDeleteDialog(msg);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(MiighoMessageItem msg) {
    final controller = TextEditingController(text: msg.content);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Modifier le message'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Nouveau contenu...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final newText = controller.text.trim();
                if (newText.isNotEmpty && newText != msg.content) {
                  context.read<ChatBloc>().add(
                        EditMessageEvent(
                          conversationId: widget.conversationId,
                          messageId: msg.id,
                          newContent: newText,
                        ),
                      );
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(MiighoMessageItem msg) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Supprimer le message'),
          content: const Text('Voulez-vous vraiment supprimer ce message pour tous les participants ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                context.read<ChatBloc>().add(
                      DeleteMessageEvent(
                        conversationId: widget.conversationId,
                        messageId: msg.id,
                      ),
                    );
                Navigator.of(ctx).pop();
              },
              child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        String contactTitle = 'Discussion';
        bool isGroup = false;
        bool isOnline = false;
        bool isTyping = false;
        List<MiighoMessageItem> messages = [];

        if (state is MessagesLoaded && state.conversationId == widget.conversationId) {
          messages = state.messages;
          isTyping = state.isPeerTyping;
          // Trigger read receipt on load
          if (messages.isNotEmpty && !messages.first.isMe) {
            context.read<ChatBloc>().add(
                  MarkConversationReadEvent(
                    conversationId: widget.conversationId,
                    messageId: messages.first.id,
                  ),
                );
          }
        }

        // Find metadata from conversations list if available
        if (state is ConversationsLoaded) {
          final conv = state.conversations.firstWhere(
            (c) => c.id == widget.conversationId,
            orElse: () => MiighoConversation(
              id: widget.conversationId,
              title: 'Discussion',
              subtitle: '',
              updatedAt: DateTime.now(),
            ),
          );
          contactTitle = conv.title;
          isGroup = conv.isGroup;
          isOnline = conv.isOnline;
        }

        Widget chatContent = Scaffold(
          backgroundColor: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
          appBar: AppBar(
            titleSpacing: widget.isEmbedded ? 16 : 0,
            leading: widget.isEmbedded
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    tooltip: 'Retour',
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/conversations');
                      }
                    },
                  ),
            title: InkWell(
              onTap: () {
                setState(() {
                  _showContactInfo = !_showContactInfo;
                });
              },
              child: Row(
                children: [
                  MiighoAvatar(
                    name: contactTitle,
                    size: MiighoAvatarSize.sm,
                    isOnline: isOnline,
                    showPresenceIndicator: !isGroup,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contactTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          isTyping
                              ? 'En train d\'écrire...'
                              : (isGroup ? 'Groupe' : (isOnline ? 'En ligne' : 'Récemment vu')),
                          style: TextStyle(
                            fontSize: 11,
                            color: isTyping
                                ? MiighoColors.primary
                                : (isOnline ? const Color(0xFF10B981) : MiighoColors.textTertiary),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.call_outlined),
                tooltip: 'Appel Audio',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Appels audio P2P (Phase suivante de la roadmap)'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.videocam_outlined),
                tooltip: 'Appel Vidéo',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Appels vidéo WebRTC (Phase suivante de la roadmap)'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  _showContactInfo ? Icons.info_rounded : Icons.info_outline_rounded,
                  color: _showContactInfo ? MiighoColors.primary : null,
                ),
                tooltip: 'Fiche contact',
                onPressed: () {
                  setState(() {
                    _showContactInfo = !_showContactInfo;
                  });
                },
              ),
            ],
          ),
          body: Container(
            color: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
            child: Column(
              children: [
                // Message List
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 48,
                                color: isDark ? MiighoColors.textTertiary : MiighoColors.lightTextTertiary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Aucun message pour le moment.\nDites bonjour !',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            return MessageBubble(
                              id: msg.id,
                              content: msg.content,
                              isMe: msg.isMe,
                              type: msg.type,
                              status: msg.status,
                              timestamp: msg.timestamp,
                              mediaPath: msg.mediaPath,
                              mediaUrl: msg.mediaUrl,
                              mediaFileName: msg.mediaFileName,
                              mediaFileSize: msg.mediaFileSize,
                              mediaDuration: msg.mediaDuration,
                              replyData: msg.replyData,
                              reactions: msg.reactions,
                              onSwipeReply: () => _setReplyMessage(msg),
                              onLongPress: () => _showContextMenu(msg),
                              onReactionTap: (emoji) => _showContextMenu(msg),
                            );
                          },
                        ),
                ),

                // Typing indicator banner
                if (isTyping)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Un membre est en train d\'écrire...',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? MiighoColors.primary : MiighoColors.primaryDark,
                      ),
                    ),
                  ),

                // Input Bar
                ChatInput(
                  onSendMessage: _handleSendMessage,
                  onSendVoice: _handleSendVoice,
                  onSendMedia: _handleSendMedia,
                  replyData: _replyData,
                  onCancelReply: () {
                    setState(() {
                      _replyData = null;
                    });
                  },
                ),
              ],
            ),
          ),
        );

        if (_showContactInfo) {
          return Row(
            children: [
              Expanded(child: chatContent),
              ContactInfoDrawer(
                title: contactTitle,
                isGroup: isGroup,
                isOnline: isOnline,
              ),
            ],
          );
        }

        return chatContent;
      },
    );
  }
}
