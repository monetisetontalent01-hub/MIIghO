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

  // In-memory fallback / cache for resilient offline & demo experience
  final Map<String, List<MiighoMessageItem>> _localMessageCache = {
    'conv_0': [
      MiighoMessageItem(
        id: 'msg_0_3',
        conversationId: 'conv_0',
        content: 'Parfait, on valide les maquettes !',
        isMe: false,
        type: MessageBubbleType.text,
        status: MessageDeliveryStatus.read,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
      MiighoMessageItem(
        id: 'msg_0_2',
        conversationId: 'conv_0',
        content: 'Les fonctionnalités temps réel et la protection IDOR sont prêtes.',
        isMe: true,
        type: MessageBubbleType.text,
        status: MessageDeliveryStatus.read,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      MiighoMessageItem(
        id: 'msg_0_1',
        conversationId: 'conv_0',
        content: 'Bonjour ! Ravi de vous retrouver sur MÏÏghO Chat sécurisé.',
        isMe: false,
        type: MessageBubbleType.text,
        status: MessageDeliveryStatus.read,
        timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
      ),
    ],
    'conv_1': [
      MiighoMessageItem(
        id: 'msg_1_2',
        conversationId: 'conv_1',
        content: 'Réunion de cadrage technique à 10h',
        isMe: false,
        type: MessageBubbleType.text,
        status: MessageDeliveryStatus.read,
        timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
      ),
      MiighoMessageItem(
        id: 'msg_1_1',
        conversationId: 'conv_1',
        content: 'Bienvenue dans le canal de l\'équipe MÏÏghO Core !',
        isMe: false,
        type: MessageBubbleType.text,
        status: MessageDeliveryStatus.read,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ],
    'conv_2': [
      MiighoMessageItem(
        id: 'msg_2_2',
        conversationId: 'conv_2',
        content: 'Audio (14s)',
        isMe: false,
        type: MessageBubbleType.voice,
        mediaDuration: const Duration(seconds: 14),
        status: MessageDeliveryStatus.read,
        timestamp: DateTime.now().subtract(const Duration(minutes: 38)),
      ),
      MiighoMessageItem(
        id: 'msg_2_1',
        conversationId: 'conv_2',
        content: 'Salut Kofi ! Tu as pu tester le transfert via MÏÏghO Pay ?',
        isMe: true,
        type: MessageBubbleType.text,
        status: MessageDeliveryStatus.read,
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
    ],
  };

  final List<MiighoConversation> _defaultConversations = [
    MiighoConversation(
      id: 'conv_0',
      title: 'Amina Diallo',
      subtitle: 'Parfait, on valide les maquettes !',
      updatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      unreadCount: 0,
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
      subtitle: 'Audio (14s)',
      updatedAt: DateTime.now().subtract(const Duration(minutes: 38)),
      unreadCount: 1,
      isMuted: true,
    ),
  ];

  ChatRepository({
    required this.apiClient,
    required this.wsClient,
    required this.secureStorage,
  });

  /// Retrieves list of user's active conversations from the server or fallback.
  Future<List<MiighoConversation>> getConversations() async {
    try {
      final response = await apiClient.get('/chat/conversations');
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        final serverConvs = (data['data'] as List)
            .map((c) => MiighoConversation.fromJson(c as Map<String, dynamic>))
            .toList();
        if (serverConvs.isNotEmpty) return serverConvs;
      }
    } catch (_) {
      // Fallback gracefully on network error or offline mode
    }
    return List.from(_defaultConversations);
  }

  /// Retrieves paginated messages for a conversation.
  Future<List<MiighoMessageItem>> getMessages(String conversationId) async {
    try {
      final response = await apiClient.get('/chat/conversations/$conversationId/messages');
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        final currentUserId = await secureStorage.getUserId() ?? '';
        final serverMsgs = (data['data'] as List).map((m) {
          return MiighoMessageItem.fromJson(m as Map<String, dynamic>, currentUserId: currentUserId);
        }).toList();
        if (serverMsgs.isNotEmpty) {
          _localMessageCache[conversationId] = serverMsgs;
          return serverMsgs;
        }
      }
    } catch (_) {
      // Fallback gracefully on local cache
    }
    return List.from(_localMessageCache[conversationId] ?? []);
  }

  /// Persists a new message to the backend and returns the official or locally confirmed item.
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
    final localId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final localItem = MiighoMessageItem(
      id: localId,
      conversationId: conversationId,
      content: content,
      isMe: true,
      type: type,
      status: MessageDeliveryStatus.sent,
      timestamp: DateTime.now(),
      replyToId: replyToId,
      mediaPath: mediaPath,
      mediaUrl: mediaUrl,
      mediaDuration: mediaDuration,
    );

    // Save to local cache immediately
    final existing = _localMessageCache[conversationId] ?? [];
    _localMessageCache[conversationId] = [localItem, ...existing];

    try {
      final body = {
        'content': content,
        'type': type.name,
        if (replyToId != null) 'reply_to_id': replyToId,
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
        final serverItem = MiighoMessageItem.fromJson(
          data['data'] as Map<String, dynamic>,
          currentUserId: currentUserId,
        );
        // Replace in cache
        final list = _localMessageCache[conversationId] ?? [];
        final idx = list.indexWhere((m) => m.id == localId);
        if (idx != -1) {
          list[idx] = serverItem;
        }
        return serverItem;
      }
    } catch (_) {
      // Backend not reachable: return local item
    }

    return localItem;
  }

  /// Creates a new direct conversation with a recipient user.
  Future<MiighoConversation> createConversation(String recipientId) async {
    try {
      final response = await apiClient.post(
        '/chat/conversations',
        data: {'recipient_id': recipientId},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] != null) {
        return MiighoConversation.fromJson(data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    final newConv = MiighoConversation(
      id: 'conv_${DateTime.now().millisecondsSinceEpoch}',
      title: recipientId.length > 8 ? 'Contact ${recipientId.substring(0, 6)}' : recipientId,
      subtitle: 'Nouvelle discussion',
      updatedAt: DateTime.now(),
      isOnline: true,
    );
    _defaultConversations.insert(0, newConv);
    return newConv;
  }

  /// Creates a new group conversation with multiple member IDs.
  Future<MiighoConversation> createGroup(String name, List<String> memberIds) async {
    try {
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
    } catch (_) {}

    final newGroup = MiighoConversation(
      id: 'conv_${DateTime.now().millisecondsSinceEpoch}',
      title: name,
      subtitle: 'Groupe créé (${memberIds.length} membres)',
      updatedAt: DateTime.now(),
      isGroup: true,
    );
    _defaultConversations.insert(0, newGroup);
    return newGroup;
  }

  /// Marks conversation messages as read up to a message ID.
  Future<void> markRead(String conversationId, String messageId) async {
    try {
      await apiClient.post(
        '/chat/conversations/$conversationId/read',
        data: {'message_id': messageId},
      );
    } catch (_) {}
  }

  /// Adds an emoji reaction to a message.
  Future<void> addReaction(String messageId, String emoji) async {
    try {
      await apiClient.post(
        '/chat/messages/$messageId/reactions',
        data: {'emoji': emoji},
      );
    } catch (_) {}
  }

  /// Removes an emoji reaction from a message.
  Future<void> removeReaction(String messageId, String emoji) async {
    try {
      await apiClient.delete(
        '/chat/messages/$messageId/reactions?emoji=${Uri.encodeComponent(emoji)}',
      );
    } catch (_) {}
  }

  /// Modifies an existing message (author only).
  Future<MiighoMessageItem> editMessage(String messageId, String newContent) async {
    try {
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
    } catch (_) {}

    return MiighoMessageItem(
      id: messageId,
      conversationId: '',
      content: newContent,
      isMe: true,
      type: MessageBubbleType.text,
      status: MessageDeliveryStatus.sent,
      timestamp: DateTime.now(),
      editedAt: DateTime.now(),
    );
  }

  /// Soft-deletes a message (author only).
  Future<void> deleteMessage(String messageId) async {
    try {
      await apiClient.delete('/chat/messages/$messageId');
    } catch (_) {}
  }
}
