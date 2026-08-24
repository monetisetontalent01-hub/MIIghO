import '../../../shared/widgets/conversation_tile.dart' show MessageDeliveryStatus, ConversationMessageType;
import '../presentation/widgets/message_bubble.dart' show MessageBubbleType, MessageReactionData, MessageReplyData;

class MiighoConversation {
  final String id;
  final String title;
  final String subtitle;
  final String? avatarUrl;
  final DateTime updatedAt;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final bool isGroup;
  final bool isOnline;
  final bool isTyping;
  final String? typingUserName;
  final bool isLastMessageFromMe;
  final MessageDeliveryStatus? lastMessageStatus;
  final ConversationMessageType messageType;
  final bool isVerified;

  const MiighoConversation({
    required this.id,
    required this.title,
    required this.subtitle,
    this.avatarUrl,
    required this.updatedAt,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isGroup = false,
    this.isOnline = false,
    this.isTyping = false,
    this.typingUserName,
    this.isLastMessageFromMe = false,
    this.lastMessageStatus,
    this.messageType = ConversationMessageType.text,
    this.isVerified = false,
  });

  factory MiighoConversation.fromJson(Map<String, dynamic> json) {
    return MiighoConversation(
      id: json['id'] as String,
      title: json['name'] as String? ?? 'Discussion',
      subtitle: json['last_message']?['content'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
      unreadCount: json['unread_count'] as int? ?? 0,
      isGroup: json['type'] == 'group',
    );
  }
}

class MiighoMessageItem {
  final String id;
  final String conversationId;
  final String content;
  final bool isMe;
  final MessageBubbleType type;
  final MessageDeliveryStatus status;
  final DateTime timestamp;
  final String? mediaPath;
  final String? mediaUrl;
  final String? mediaFileName;
  final int? mediaFileSize;
  final Duration? mediaDuration;
  final MessageReplyData? replyData;
  final List<MessageReactionData> reactions;

  const MiighoMessageItem({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.isMe,
    this.type = MessageBubbleType.text,
    this.status = MessageDeliveryStatus.sent,
    required this.timestamp,
    this.mediaPath,
    this.mediaUrl,
    this.mediaFileName,
    this.mediaFileSize,
    this.mediaDuration,
    this.replyData,
    this.reactions = const [],
  });

  MiighoMessageItem copyWith({
    String? id,
    String? conversationId,
    String? content,
    bool? isMe,
    MessageBubbleType? type,
    MessageDeliveryStatus? status,
    DateTime? timestamp,
    String? mediaPath,
    String? mediaUrl,
    String? mediaFileName,
    int? mediaFileSize,
    Duration? mediaDuration,
    MessageReplyData? replyData,
    List<MessageReactionData>? reactions,
  }) {
    return MiighoMessageItem(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      content: content ?? this.content,
      isMe: isMe ?? this.isMe,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaFileName: mediaFileName ?? this.mediaFileName,
      mediaFileSize: mediaFileSize ?? this.mediaFileSize,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      replyData: replyData ?? this.replyData,
      reactions: reactions ?? this.reactions,
    );
  }
}
