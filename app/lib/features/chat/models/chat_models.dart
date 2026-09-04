import 'dart:convert';
import 'package:miigho/shared/widgets/conversation_tile.dart' show MessageDeliveryStatus, ConversationMessageType;
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
    String subtitle = json['last_message']?['content'] as String? ?? '';
    if (subtitle.isNotEmpty) {
      try {
        final decodedBytes = base64.decode(subtitle);
        subtitle = utf8.decode(decodedBytes);
      } catch (_) {
        // Kept as plain text
      }
    }
    return MiighoConversation(
      id: json['id'] as String,
      title: json['name'] as String? ?? 'Discussion',
      subtitle: subtitle,
      avatarUrl: json['avatar_url'] as String?,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
      unreadCount: json['unread_count'] as int? ?? 0,
      isGroup: json['type'] == 'group',
    );
  }

  MiighoConversation copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? avatarUrl,
    DateTime? updatedAt,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    bool? isGroup,
    bool? isOnline,
    bool? isTyping,
    String? typingUserName,
    bool? isLastMessageFromMe,
    MessageDeliveryStatus? lastMessageStatus,
    ConversationMessageType? messageType,
    bool? isVerified,
  }) {
    return MiighoConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isGroup: isGroup ?? this.isGroup,
      isOnline: isOnline ?? this.isOnline,
      isTyping: isTyping ?? this.isTyping,
      typingUserName: typingUserName ?? this.typingUserName,
      isLastMessageFromMe: isLastMessageFromMe ?? this.isLastMessageFromMe,
      lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
      messageType: messageType ?? this.messageType,
      isVerified: isVerified ?? this.isVerified,
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
  final DateTime? editedAt;
  final String? replyToId;
  final String? mediaPath;
  final String? mediaUrl;
  final String? mediaFileName;
  final int? mediaFileSize;
  final Duration? mediaDuration;
  final String? clientMessageId;
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
    this.editedAt,
    this.replyToId,
    this.clientMessageId,
    this.mediaPath,
    this.mediaUrl,
    this.mediaFileName,
    this.mediaFileSize,
    this.mediaDuration,
    this.replyData,
    this.reactions = const [],
  });

  factory MiighoMessageItem.fromJson(Map<String, dynamic> json, {required String currentUserId}) {
    final senderId = json['sender_id'] as String?;
    final isMe = senderId != null && senderId == currentUserId;
    
    // Parse message type
    final typeStr = json['type'] as String? ?? 'text';
    MessageBubbleType msgType = MessageBubbleType.text;
    switch (typeStr) {
      case 'image':
        msgType = MessageBubbleType.image;
        break;
      case 'video':
        msgType = MessageBubbleType.video;
        break;
      case 'voice':
        msgType = MessageBubbleType.voice;
        break;
      case 'audio':
        msgType = MessageBubbleType.audio;
        break;
      case 'file':
      case 'document':
        msgType = MessageBubbleType.document;
        break;
      default:
        msgType = MessageBubbleType.text;
    }

    // Parse status
    final statusStr = json['status'] as String? ?? 'sent';
    MessageDeliveryStatus msgStatus = MessageDeliveryStatus.sent;
    switch (statusStr) {
      case 'sending':
        msgStatus = MessageDeliveryStatus.sending;
        break;
      case 'sent':
        msgStatus = MessageDeliveryStatus.sent;
        break;
      case 'delivered':
        msgStatus = MessageDeliveryStatus.delivered;
        break;
      case 'read':
        msgStatus = MessageDeliveryStatus.read;
        break;
      case 'failed':
        msgStatus = MessageDeliveryStatus.failed;
        break;
    }

    // Parse reactions
    List<MessageReactionData> reactionList = [];
    if (json['reactions'] is List) {
      final rawReactions = json['reactions'] as List;
      final Map<String, List<String>> reactionMap = {};
      for (final r in rawReactions) {
        if (r is Map<String, dynamic>) {
          final emoji = r['emoji'] as String? ?? '';
          final uid = r['user_id'] as String? ?? '';
          if (emoji.isNotEmpty) {
            reactionMap.putIfAbsent(emoji, () => []).add(uid);
          }
        }
      }
      reactionList = reactionMap.entries.map((entry) {
        return MessageReactionData(
          emoji: entry.key,
          count: entry.value.length,
          hasReacted: entry.value.contains(currentUserId),
          userIds: entry.value,
        );
      }).toList();
    }

    // Parse reply_to
    final replyToId = json['reply_to'] as String? ?? json['reply_to_id'] as String?;

    // Parse metadata
    final metadata = json['metadata'] as Map<String, dynamic>?;
    final mediaUrl = metadata?['media_url'] as String? ?? json['media_url'] as String?;
    final mediaFileName = metadata?['file_name'] as String?;
    final mediaFileSize = metadata?['file_size'] as int?;
    final durationSeconds = metadata?['duration_seconds'] as int?;

    String contentStr = json['content'] as String? ?? '';
    if (contentStr.isNotEmpty) {
      try {
        final decodedBytes = base64.decode(contentStr);
        contentStr = utf8.decode(decodedBytes);
      } catch (_) {
        // Kept as plain text
      }
    }

    final clientMessageId = json['client_message_id'] as String? ?? metadata?['client_message_id'] as String?;

    return MiighoMessageItem(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String? ?? '',
      content: contentStr,
      isMe: isMe,
      type: msgType,
      status: msgStatus,
      timestamp: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      editedAt: json['edited_at'] != null ? DateTime.parse(json['edited_at']) : null,
      replyToId: replyToId,
      clientMessageId: clientMessageId,
      mediaUrl: mediaUrl,
      mediaFileName: mediaFileName,
      mediaFileSize: mediaFileSize,
      mediaDuration: durationSeconds != null ? Duration(seconds: durationSeconds) : null,
      reactions: reactionList,
    );
  }

  MiighoMessageItem copyWith({
    String? id,
    String? conversationId,
    String? content,
    bool? isMe,
    MessageBubbleType? type,
    MessageDeliveryStatus? status,
    DateTime? timestamp,
    DateTime? editedAt,
    String? replyToId,
    String? clientMessageId,
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
      editedAt: editedAt ?? this.editedAt,
      replyToId: replyToId ?? this.replyToId,
      clientMessageId: clientMessageId ?? this.clientMessageId,
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
