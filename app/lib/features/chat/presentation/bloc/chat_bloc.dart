import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/chat_repository.dart';
import '../../models/chat_models.dart';
import '../../presentation/widgets/message_bubble.dart' show MessageBubbleType;
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
  SendTextMessage({required this.conversationId, required this.content});
}

class SendVoiceMessage extends ChatEvent {
  final String conversationId;
  final String audioPath;
  final Duration duration;
  SendVoiceMessage({required this.conversationId, required this.audioPath, required this.duration});
}

class SendMediaMessage extends ChatEvent {
  final String conversationId;
  final String filePath;
  final String mediaType;
  final String? caption;
  SendMediaMessage({
    required this.conversationId,
    required this.filePath,
    required this.mediaType,
    this.caption,
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
  ConversationsLoaded(this.conversations);
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

  ChatBloc({required this.chatRepository}) : super(ChatInitial()) {
    on<LoadConversations>(_onLoadConversations);
    on<LoadMessages>(_onLoadMessages);
    on<SendTextMessage>(_onSendTextMessage);
    on<SendVoiceMessage>(_onSendVoiceMessage);
    on<SendMediaMessage>(_onSendMediaMessage);
    on<MessageReceivedEvent>(_onMessageReceived);

    _wsSubscription = chatRepository.wsClient.messages.listen((msg) {
      // In real protobuf parsing, unpack and trigger MessageReceivedEvent
    });
  }

  Future<void> _onLoadConversations(LoadConversations event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    try {
      final conversations = await chatRepository.getConversations();
      emit(ConversationsLoaded(conversations));
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
