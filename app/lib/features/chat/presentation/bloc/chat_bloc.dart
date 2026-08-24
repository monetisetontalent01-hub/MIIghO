import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/chat_repository.dart';
import '../../models/chat_models.dart';
import '../../presentation/widgets/message_bubble.dart' show MessageBubbleType, MessageReactionData;
import '../../../shared/widgets/conversation_tile.dart' show MessageDeliveryStatus;

// Events
abstract class ChatEvent {}

class LoadConversations extends ChatEvent {}

class LoadMessages extends ChatEvent {
  final String conversationId;
  LoadMessages(this.conversationId);
}

class SendTextMessage extends ChatEvent {
  final String conversationId;
  final String content;
  final String? replyToId;
  SendTextMessage({
    required this.conversationId,
    required this.content,
    this.replyToId,
  });
}

class SendVoiceMessage extends ChatEvent {
  final String conversationId;
  final String audioPath;
  final Duration duration;
  final String? replyToId;
  SendVoiceMessage({
    required this.conversationId,
    required this.audioPath,
    required this.duration,
    this.replyToId,
  });
}

class SendMediaMessage extends ChatEvent {
  final String conversationId;
  final String filePath;
  final String mediaType;
  final String? caption;
  final String? replyToId;
  SendMediaMessage({
    required this.conversationId,
    required this.filePath,
    required this.mediaType,
    this.caption,
    this.replyToId,
  });
}

class CreateConversationEvent extends ChatEvent {
  final String title;
  final bool isGroup;
  final String? initialMessage;
  CreateConversationEvent({
    required this.title,
    required this.isGroup,
    this.initialMessage,
  });
}

class TogglePinConversationEvent extends ChatEvent {
  final String conversationId;
  TogglePinConversationEvent(this.conversationId);
}

class ToggleMuteConversationEvent extends ChatEvent {
  final String conversationId;
  ToggleMuteConversationEvent(this.conversationId);
}

class AddReactionEvent extends ChatEvent {
  final String conversationId;
  final String messageId;
  final String emoji;
  AddReactionEvent({
    required this.conversationId,
    required this.messageId,
    required this.emoji,
  });
}

class MessageReceivedEvent extends ChatEvent {
  final MiighoMessageItem message;
  MessageReceivedEvent(this.message);
}

// States
abstract class ChatState {}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ConversationsLoaded extends ChatState {
  final List<MiighoConversation> conversations;
  final String? activeConversationId;

  ConversationsLoaded(this.conversations, {this.activeConversationId});

  ConversationsLoaded copyWith({
    List<MiighoConversation>? conversations,
    String? activeConversationId,
  }) {
    return ConversationsLoaded(
      conversations ?? this.conversations,
      activeConversationId: activeConversationId ?? this.activeConversationId,
    );
  }
}

class MessagesLoaded extends ChatState {
  final String conversationId;
  final List<MiighoMessageItem> messages;
  MessagesLoaded({required this.conversationId, required this.messages});

  MessagesLoaded copyWith({
    String? conversationId,
    List<MiighoMessageItem>? messages,
  }) {
    return MessagesLoaded(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
    );
  }
}

class ChatError extends ChatState {
  final String message;
  ChatError(this.message);
}

// BLoC
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository chatRepository;
  StreamSubscription? _wsSubscription;
  List<MiighoConversation> _allConversations = [];

  ChatBloc({required this.chatRepository}) : super(ChatInitial()) {
    on<LoadConversations>(_onLoadConversations);
    on<LoadMessages>(_onLoadMessages);
    on<SendTextMessage>(_onSendTextMessage);
    on<SendVoiceMessage>(_onSendVoiceMessage);
    on<SendMediaMessage>(_onSendMediaMessage);
    on<CreateConversationEvent>(_onCreateConversation);
    on<TogglePinConversationEvent>(_onTogglePinConversation);
    on<ToggleMuteConversationEvent>(_onToggleMuteConversation);
    on<AddReactionEvent>(_onAddReaction);
    on<MessageReceivedEvent>(_onMessageReceived);

    _wsSubscription = chatRepository.wsClient.messages.listen((msg) {
      // In real protobuf parsing, unpack and trigger MessageReceivedEvent
    });
  }

  Future<void> _onLoadConversations(LoadConversations event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    try {
      final conversations = await chatRepository.getConversations();
      _allConversations = List.from(conversations);
      emit(ConversationsLoaded(_allConversations));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    try {
      final messages = await chatRepository.getMessages(event.conversationId);
      emit(MessagesLoaded(conversationId: event.conversationId, messages: messages));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onSendTextMessage(SendTextMessage event, Emitter<ChatState> emit) async {
    final currentState = state;
    final newMessage = MiighoMessageItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: event.conversationId,
      content: event.content,
      isMe: true,
      type: MessageBubbleType.text,
      status: MessageDeliveryStatus.sent,
      timestamp: DateTime.now(),
    );

    if (currentState is MessagesLoaded && currentState.conversationId == event.conversationId) {
      emit(currentState.copyWith(messages: [newMessage, ...currentState.messages]));
    }

    // Update conversation subtitle in conversation list
    final idx = _allConversations.indexWhere((c) => c.id == event.conversationId);
    if (idx != -1) {
      final updated = _allConversations[idx].copyWith(
        subtitle: event.content,
        updatedAt: DateTime.now(),
        isLastMessageFromMe: true,
        lastMessageStatus: MessageDeliveryStatus.sent,
      );
      _allConversations[idx] = updated;
    }

    await chatRepository.sendMessage(
      conversationId: event.conversationId,
      content: event.content,
      type: MessageBubbleType.text,
    );
  }

  Future<void> _onSendVoiceMessage(SendVoiceMessage event, Emitter<ChatState> emit) async {
    final currentState = state;
    final newMessage = MiighoMessageItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: event.conversationId,
      content: 'Message vocal (${event.duration.inSeconds}s)',
      isMe: true,
      type: MessageBubbleType.voice,
      mediaPath: event.audioPath,
      mediaDuration: event.duration,
      status: MessageDeliveryStatus.sent,
      timestamp: DateTime.now(),
    );

    if (currentState is MessagesLoaded && currentState.conversationId == event.conversationId) {
      emit(currentState.copyWith(messages: [newMessage, ...currentState.messages]));
    }

    await chatRepository.sendMessage(
      conversationId: event.conversationId,
      content: 'Audio',
      type: MessageBubbleType.voice,
      mediaPath: event.audioPath,
    );
  }

  Future<void> _onSendMediaMessage(SendMediaMessage event, Emitter<ChatState> emit) async {
    final currentState = state;
    final type = event.mediaType == 'video'
        ? MessageBubbleType.video
        : (event.mediaType == 'document' ? MessageBubbleType.document : MessageBubbleType.image);

    final newMessage = MiighoMessageItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: event.conversationId,
      content: event.caption ?? '',
      isMe: true,
      type: type,
      mediaPath: event.filePath,
      mediaFileName: event.filePath.split('/').last,
      status: MessageDeliveryStatus.sent,
      timestamp: DateTime.now(),
    );

    if (currentState is MessagesLoaded && currentState.conversationId == event.conversationId) {
      emit(currentState.copyWith(messages: [newMessage, ...currentState.messages]));
    }

    await chatRepository.sendMessage(
      conversationId: event.conversationId,
      content: event.caption ?? '',
      type: type,
      mediaPath: event.filePath,
    );
  }

  void _onCreateConversation(CreateConversationEvent event, Emitter<ChatState> emit) {
    final newConv = MiighoConversation(
      id: 'conv_${DateTime.now().millisecondsSinceEpoch}',
      title: event.title,
      subtitle: event.initialMessage ?? 'Nouvelle discussion créée',
      updatedAt: DateTime.now(),
      isGroup: event.isGroup,
      unreadCount: 0,
      isOnline: true,
    );
    _allConversations.insert(0, newConv);
    emit(ConversationsLoaded(List.from(_allConversations)));
  }

  void _onTogglePinConversation(TogglePinConversationEvent event, Emitter<ChatState> emit) {
    final idx = _allConversations.indexWhere((c) => c.id == event.conversationId);
    if (idx != -1) {
      final item = _allConversations[idx];
      _allConversations[idx] = item.copyWith(isPinned: !item.isPinned);
      // Sort pinned to top
      _allConversations.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      emit(ConversationsLoaded(List.from(_allConversations)));
    }
  }

  void _onToggleMuteConversation(ToggleMuteConversationEvent event, Emitter<ChatState> emit) {
    final idx = _allConversations.indexWhere((c) => c.id == event.conversationId);
    if (idx != -1) {
      final item = _allConversations[idx];
      _allConversations[idx] = item.copyWith(isMuted: !item.isMuted);
      emit(ConversationsLoaded(List.from(_allConversations)));
    }
  }

  void _onAddReaction(AddReactionEvent event, Emitter<ChatState> emit) {
    final currentState = state;
    if (currentState is MessagesLoaded && currentState.conversationId == event.conversationId) {
      final updatedMessages = currentState.messages.map((m) {
        if (m.id == event.messageId) {
          final existing = List<MessageReactionData>.from(m.reactions);
          final rIdx = existing.indexWhere((r) => r.emoji == event.emoji);
          if (rIdx != -1) {
            existing[rIdx] = MessageReactionData(
              emoji: event.emoji,
              count: existing[rIdx].count + 1,
              hasReacted: true,
            );
          } else {
            existing.add(MessageReactionData(emoji: event.emoji, count: 1, hasReacted: true));
          }
          return m.copyWith(reactions: existing);
        }
        return m;
      }).toList();
      emit(currentState.copyWith(messages: updatedMessages));
    }
  }

  void _onMessageReceived(MessageReceivedEvent event, Emitter<ChatState> emit) {
    final currentState = state;
    if (currentState is MessagesLoaded && currentState.conversationId == event.message.conversationId) {
      emit(currentState.copyWith(messages: [event.message, ...currentState.messages]));
    }
  }

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    return super.close();
  }
}
