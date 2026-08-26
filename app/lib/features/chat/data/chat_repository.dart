import 'dart:async';
import '../../../core/network/api_client.dart';
import '../../../core/network/ws_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/chat_models.dart';
import '../presentation/widgets/message_bubble.dart' show MessageBubbleType;

class ChatRepository {
  final ApiClient apiClient;
  final WsClient wsClient;
  final SecureStorageService secureStorage;

  ChatRepository({
    required this.apiClient,
    required this.wsClient,
    required this.secureStorage,
  });

  /// Connects WebSocket with the authenticated session token.
  Future<void> connectWebSocket() async {
    final token = await secureStorage.getAccessToken() ?? await secureStorage.getUserId();
    if (token != null && token.isNotEmpty) {
      wsClient.connectWithToken(token);
    } else {
      wsClient.connect();
    }
  }

  /// Retrieves list of user's active conversations from the backend server.
  Future<List<MiighoConversation>> getConversations() async {
    final response = await apiClient.get('/chat/conversations');
    final data = response.data;
    if (data is Map<String, dynamic> && data['data'] is List) {
      return (data['data'] as List)
          .map((c) => MiighoConversation.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Retrieves a single conversation by ID from the backend server.
  Future<MiighoConversation?> getConversation(String conversationId) async {
    final response = await apiClient.get('/chat/conversations/$conversationId');
    final data = response.data;
    if (data is Map<String, dynamic> && data['data'] != null) {
      return MiighoConversation.fromJson(data['data'] as Map<String, dynamic>);
    }
    return null;
  }

  /// Retrieves paginated messages for a conversation from the backend server.
  Future<List<MiighoMessageItem>> getMessages(String conversationId) async {
    final response = await apiClient.get('/chat/conversations/$conversationId/messages');
    final data = response.data;
    if (data is Map<String, dynamic> && data['data'] is List) {
      final currentUserId = await secureStorage.getUserId() ?? '';
      return (data['data'] as List).map((m) {
        return MiighoMessageItem.fromJson(m as Map<String, dynamic>, currentUserId: currentUserId);
      }).toList();
    }
    return [];
  }

  /// Persists a new message to the backend and returns the official server message item.
  Future<MiighoMessageItem> sendMessage({
    required String conversationId,
    required String content,
    MessageBubbleType type = MessageBubbleType.text,
    String? replyToId,
    String? mediaPath,
    String? mediaUrl,
    Duration? mediaDuration,
    Map<String, dynamic>? metadata,
  }) async {
    final body = {
      'content': content,
      'type': type.name,
      if (replyToId != null && replyToId.isNotEmpty) 'reply_to_id': replyToId,
      'metadata': {
        if (mediaUrl != null) 'media_url': mediaUrl,
        if (mediaDuration != null) 'duration_seconds': mediaDuration.inSeconds,
        if (metadata != null) ...metadata,
      },
    };

    final response = await apiClient.post(
      '/chat/conversations/$conversationId/messages',
      data: body,
    );

    final currentUserId = await secureStorage.getUserId() ?? '';
    final data = response.data;
    if (data is Map<String, dynamic> && data['data'] != null) {
      return MiighoMessageItem.fromJson(
        data['data'] as Map<String, dynamic>,
        currentUserId: currentUserId,
      );
    }

    throw Exception('Invalid server response for sendMessage');
  }

  /// Creates a new direct conversation with a recipient user on the backend.
  Future<MiighoConversation> createConversation(String recipientId) async {
    final response = await apiClient.post(
      '/chat/conversations',
      data: {'recipient_id': recipientId},
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['data'] != null) {
      return MiighoConversation.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw Exception('Failed to create conversation with recipient $recipientId');
  }

  /// Creates a new group conversation with multiple member IDs on the backend.
  Future<MiighoConversation> createGroup(String name, List<String> memberIds) async {
    final response = await apiClient.post(
      '/chat/conversations',
      data: {
        'type': 'group',
        'name': name,
        'member_ids': memberIds,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['data'] != null) {
      return MiighoConversation.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw Exception('Failed to create group $name');
  }

  /// Marks conversation messages as read up to a message ID.
  Future<void> markRead(String conversationId, String messageId) async {
    await apiClient.post(
      '/chat/conversations/$conversationId/read',
      data: {'message_id': messageId},
    );
  }

  /// Adds an emoji reaction to a message.
  Future<void> addReaction(String messageId, String emoji) async {
    await apiClient.post(
      '/chat/messages/$messageId/reactions',
      data: {'emoji': emoji},
    );
  }

  /// Removes an emoji reaction from a message.
  Future<void> removeReaction(String messageId, String emoji) async {
    await apiClient.delete(
      '/chat/messages/$messageId/reactions?emoji=${Uri.encodeComponent(emoji)}',
    );
  }

  /// Modifies an existing message (author only).
  Future<MiighoMessageItem> editMessage(String messageId, String newContent) async {
    final response = await apiClient.patch(
      '/chat/messages/$messageId',
      data: {'content': newContent},
    );
    final currentUserId = await secureStorage.getUserId() ?? '';
    final data = response.data;
    if (data is Map<String, dynamic> && data['data'] != null) {
      return MiighoMessageItem.fromJson(
        data['data'] as Map<String, dynamic>,
        currentUserId: currentUserId,
      );
    }
    throw Exception('Failed to edit message $messageId');
  }

  /// Soft-deletes a message (author only).
  Future<void> deleteMessage(String messageId) async {
    await apiClient.delete('/chat/messages/$messageId');
  }
}
