import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/conversation_tile.dart' show MessageDeliveryStatus;
import '../../../../shared/widgets/miigho_avatar.dart';
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

  final List<Map<String, dynamic>> _messages = [
    {
      'id': '1',
      'content': 'Bonjour ! Bienvenue sur MÏÏghO, l\'écosystème numérique africain.',
      'isMe': false,
      'type': MessageBubbleType.text,
      'status': MessageDeliveryStatus.read,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 25)),
      'reactions': [
        const MessageReactionData(emoji: '👋', count: 2, hasReacted: true),
      ],
    },
    {
      'id': '2',
      'content': 'Merci beaucoup ! L\'application est très fluide et rapide.',
      'isMe': true,
      'type': MessageBubbleType.text,
      'status': MessageDeliveryStatus.read,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 20)),
      'reactions': [
        const MessageReactionData(emoji: '🔥', count: 1, hasReacted: false),
      ],
    },
    {
      'id': '3',
      'content': 'Voici le document d\'architecture pour le volet Mobile Money.',
      'isMe': false,
      'type': MessageBubbleType.document,
      'mediaFileName': 'architecture_technique_v1.pdf',
      'mediaFileSize': 2450000,
      'status': MessageDeliveryStatus.read,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 15)),
      'reactions': <MessageReactionData>[],
    },
    {
      'id': '4',
      'content': 'Message vocal (0:18)',
      'isMe': true,
      'type': MessageBubbleType.voice,
      'mediaDuration': const Duration(seconds: 18),
      'status': MessageDeliveryStatus.read,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 8)),
      'reactions': <MessageReactionData>[],
    },
    {
      'id': '5',
      'content': 'Parfait, nous validons cette étape. On passe à la suite !',
      'isMe': false,
      'type': MessageBubbleType.text,
      'status': MessageDeliveryStatus.read,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 2)),
      'reactions': [
        const MessageReactionData(emoji: '👍', count: 1, hasReacted: true),
      ],
    },
  ];

  void _handleSendMessage(String text, {String? replyToId}) {
    setState(() {
      _messages.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'content': text,
        'isMe': true,
        'type': MessageBubbleType.text,
        'status': MessageDeliveryStatus.sent,
        'timestamp': DateTime.now(),
        'replyData': _replyData,
        'reactions': <MessageReactionData>[],
      });
      _replyData = null;
    });
  }

  void _handleSendVoice(String audioPath, Duration duration, {String? replyToId}) {
    setState(() {
      _messages.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'content': 'Message vocal (${duration.inSeconds}s)',
        'isMe': true,
        'type': MessageBubbleType.voice,
        'mediaPath': audioPath,
        'mediaDuration': duration,
        'status': MessageDeliveryStatus.sent,
        'timestamp': DateTime.now(),
        'replyData': _replyData,
        'reactions': <MessageReactionData>[],
      });
      _replyData = null;
    });
  }

  void _handleSendMedia(String filePath, String mediaType, {String? caption, String? replyToId}) {
    setState(() {
      _messages.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'content': caption ?? '',
        'isMe': true,
        'type': mediaType == 'video'
            ? MessageBubbleType.video
            : (mediaType == 'document' ? MessageBubbleType.document : MessageBubbleType.image),
        'mediaPath': filePath,
        'mediaFileName': filePath.split('/').last,
        'status': MessageDeliveryStatus.sent,
        'timestamp': DateTime.now(),
        'replyData': _replyData,
        'reactions': <MessageReactionData>[],
      });
      _replyData = null;
    });
  }

  void _setReplyMessage(Map<String, dynamic> msg) {
    setState(() {
      _replyData = MessageReplyData(
        id: msg['id'] as String,
        senderName: msg['isMe'] == true ? 'Vous' : 'Contact ${widget.conversationId}',
        content: msg['content'] as String,
        type: msg['type'] as MessageBubbleType,
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
            // Message List
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return MessageBubble(
                    id: msg['id'] as String,
                    content: msg['content'] as String,
                    isMe: msg['isMe'] as bool,
                    type: msg['type'] as MessageBubbleType,
                    status: msg['status'] as MessageDeliveryStatus,
                    timestamp: msg['timestamp'] as DateTime,
                    mediaPath: msg['mediaPath'] as String?,
                    mediaUrl: msg['mediaUrl'] as String?,
                    mediaFileName: msg['mediaFileName'] as String?,
                    mediaFileSize: msg['mediaFileSize'] as int?,
                    mediaDuration: msg['mediaDuration'] as Duration?,
                    replyData: msg['replyData'] as MessageReplyData?,
                    reactions: (msg['reactions'] as List<MessageReactionData>?) ?? const [],
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
