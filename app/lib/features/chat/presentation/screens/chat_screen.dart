import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/conversation_tile.dart' show MessageDeliveryStatus;
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

  String _getContactName() {
    switch (widget.conversationId) {
      case 'conv_0':
        return 'Amina Diallo';
      case 'conv_1':
        return 'Équipe MÏÏghO Core';
      case 'conv_2':
        return 'Kofi Mensah';
      default:
        return 'Contact MÏÏghO';
    }
  }

  bool _isGroup() {
    return widget.conversationId == 'conv_1';
  }

  void _showEmojiReactionPicker(String messageId) {
    final emojis = ['👍', '❤️', '🔥', '👏', '😂', '🎉'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface1,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: emojis.map((emoji) {
              return InkWell(
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.read<ChatBloc>().add(
                        AddReactionEvent(
                          conversationId: widget.conversationId,
                          messageId: messageId,
                          emoji: emoji,
                        ),
                      );
                },
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final contactName = _getContactName();
    final isGroup = _isGroup();

    Widget chatContent = Scaffold(
      backgroundColor: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
      appBar: AppBar(
        titleSpacing: 0,
        automaticallyImplyLeading: !widget.isEmbedded,
        title: InkWell(
          onTap: () {
            setState(() {
              _showContactInfo = !_showContactInfo;
            });
          },
          child: Row(
            children: [
              MiighoAvatar(
                name: contactName,
                size: MiighoAvatarSize.sm,
                isOnline: true,
                showPresenceIndicator: !isGroup,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contactName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      isGroup ? 'Groupe (8 membres)' : 'En ligne',
                      style: TextStyle(
                        fontSize: 11,
                        color: isGroup
                            ? (isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary)
                            : const Color(0xFF10B981),
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
              child: BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  List<MiighoMessageItem> messages = [];
                  if (state is MessagesLoaded && state.conversationId == widget.conversationId) {
                    messages = state.messages;
                  } else {
                    messages = [
                      MiighoMessageItem(
                        id: '5',
                        conversationId: widget.conversationId,
                        content: 'Parfait, nous validons cette étape. On passe à la suite !',
                        isMe: false,
                        type: MessageBubbleType.text,
                        status: MessageDeliveryStatus.read,
                        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
                        reactions: const [MessageReactionData(emoji: '👍', count: 1, hasReacted: true)],
                      ),
                      MiighoMessageItem(
                        id: '4',
                        conversationId: widget.conversationId,
                        content: 'Message vocal (0:18)',
                        isMe: true,
                        type: MessageBubbleType.voice,
                        mediaDuration: const Duration(seconds: 18),
                        status: MessageDeliveryStatus.read,
                        timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
                      ),
                      MiighoMessageItem(
                        id: '3',
                        conversationId: widget.conversationId,
                        content: 'Document d\'architecture MÏÏghO',
                        isMe: false,
                        type: MessageBubbleType.document,
                        mediaFileName: 'architecture_technique_v1.pdf',
                        mediaFileSize: 2450000,
                        status: MessageDeliveryStatus.read,
                        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
                      ),
                      MiighoMessageItem(
                        id: '2',
                        conversationId: widget.conversationId,
                        content: 'Merci beaucoup ! L\'application est très fluide et rapide.',
                        isMe: true,
                        type: MessageBubbleType.text,
                        status: MessageDeliveryStatus.read,
                        timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
                        reactions: const [MessageReactionData(emoji: '🔥', count: 1, hasReacted: false)],
                      ),
                      MiighoMessageItem(
                        id: '1',
                        conversationId: widget.conversationId,
                        content: 'Bonjour ! Bienvenue sur MÏÏghO, l\'écosystème numérique africain.',
                        isMe: false,
                        type: MessageBubbleType.text,
                        status: MessageDeliveryStatus.read,
                        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
                        reactions: const [MessageReactionData(emoji: '👋', count: 2, hasReacted: true)],
                      ),
                    ];
                  }

                  return ListView.builder(
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
                        onReactionTap: (emoji) {
                          _showEmojiReactionPicker(msg.id);
                        },
                      );
                    },
                  );
                },
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
            title: contactName,
            isGroup: isGroup,
            isOnline: true,
          ),
        ],
      );
    }

    return chatContent;
  }
}
