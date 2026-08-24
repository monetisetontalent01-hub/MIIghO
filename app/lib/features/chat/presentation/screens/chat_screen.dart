import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/conversation_tile.dart' show MessageDeliveryStatus;
import '../../../../shared/widgets/miigho_avatar.dart';
import '../../models/chat_models.dart';
import '../bloc/chat_bloc.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  MessageReplyData? _replyData;

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(LoadMessages(widget.conversationId));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            MiighoAvatar(
              name: 'Contact ${widget.conversationId}',
              size: MiighoAvatarSize.sm,
              isOnline: true,
              showPresenceIndicator: true,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact ${widget.conversationId}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Text(
                    'En ligne',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFC8E6C9),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? MiighoColors.backgroundDark : const Color(0xFFEFEAE2),
        ),
        child: Column(
          children: [
            // Message List with BlocBuilder
            Expanded(
              child: BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  List<MiighoMessageItem> messages = [];
                  if (state is MessagesLoaded && state.conversationId == widget.conversationId) {
                    messages = state.messages;
                  } else {
                    // Default placeholder messages for seamless experience
                    messages = [
                      MiighoMessageItem(
                        id: '5',
                        content: 'Parfait, nous validons cette étape. On passe à la suite !',
                        isMe: false,
                        type: MessageBubbleType.text,
                        status: MessageDeliveryStatus.read,
                        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
                        reactions: const [MessageReactionData(emoji: '👍', count: 1, hasReacted: true)],
                      ),
                      MiighoMessageItem(
                        id: '4',
                        content: 'Message vocal (0:18)',
                        isMe: true,
                        type: MessageBubbleType.voice,
                        mediaDuration: const Duration(seconds: 18),
                        status: MessageDeliveryStatus.read,
                        timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
                      ),
                      MiighoMessageItem(
                        id: '3',
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
                        content: 'Merci beaucoup ! L\'application est très fluide et rapide.',
                        isMe: true,
                        type: MessageBubbleType.text,
                        status: MessageDeliveryStatus.read,
                        timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
                        reactions: const [MessageReactionData(emoji: '🔥', count: 1, hasReacted: false)],
                      ),
                      MiighoMessageItem(
                        id: '1',
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Réaction : $emoji'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // Chat Input Bar
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
  }
}
