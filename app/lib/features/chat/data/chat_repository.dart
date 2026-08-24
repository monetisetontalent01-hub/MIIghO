import 'dart:async';
import '../../../core/network/api_client.dart';
import '../../../core/network/ws_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/chat_models.dart';
import '../../../shared/widgets/conversation_tile.dart' show MessageDeliveryStatus;
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

  Future<List<MiighoConversation>> getConversations() async {
    try {
      final response = await apiClient.get('/chat/conversations');
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        return (data['data'] as List)
            .map((c) => MiighoConversation.fromJson(c as Map<String, dynamic>))
            .toList();
      }
      return _getFallbackConversations();
    } catch (_) {
      return _getFallbackConversations();
    }
  }

  Future<List<MiighoMessageItem>> getMessages(String conversationId) async {
    try {
      final response = await apiClient.get('/chat/conversations/$conversationId/messages');
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        final currentUserId = await secureStorage.getUserId();
        return (data['data'] as List).map((m) {
          final map = m as Map<String, dynamic>;
          final senderId = map['sender_id'] as String?;
          final isMe = senderId != null && senderId == currentUserId;
          return MiighoMessageItem(
            id: map['id'] as String,
            conversationId: conversationId,
            content: map['content'] as String? ?? '',
            isMe: isMe,
            status: MessageDeliveryStatus.read,
            timestamp: map['created_at'] != null
                ? DateTime.parse(map['created_at'])
                : DateTime.now(),
          );
        }).toList();
      }
      return _getFallbackMessages(conversationId);
    } catch (_) {
      return _getFallbackMessages(conversationId);
    }
  }

  Future<void> sendMessage({
    required String conversationId,
    required String content,
    MessageBubbleType type = MessageBubbleType.text,
    String? mediaPath,
  }) async {
    // Send through WebSocket for real-time low bandwidth
    wsClient.sendMessage({
      'type': 'SendMessage',
      'conversation_id': conversationId,
      'content': content,
      'msg_type': type.name,
      'media_path': mediaPath,
    });
  }

  List<MiighoConversation> _getFallbackConversations() {
    return [
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

  List<MiighoMessageItem> _getFallbackMessages(String conversationId) {
    return [
      MiighoMessageItem(
        id: '1',
        conversationId: conversationId,
        content: 'Bonjour ! Bienvenue sur MÏÏghO, l\'écosystème numérique africain.',
        isMe: false,
        status: MessageDeliveryStatus.read,
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      ),
      MiighoMessageItem(
        id: '2',
        conversationId: conversationId,
        content: 'Merci ! L\'application est très fluide et rapide.',
        isMe: true,
        status: MessageDeliveryStatus.read,
        timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
      ),
    ];
  }
}
