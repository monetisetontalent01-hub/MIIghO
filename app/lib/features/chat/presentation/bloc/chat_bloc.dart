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
  final String recipientId;
  CreateConversationEvent({required this.recipientId});
}

class CreateGroupEvent extends ChatEvent {
  final String name;
  final List<String> memberIds;
  CreateGroupEvent({required this.name, required this.memberIds});
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

class RemoveReactionEvent extends ChatEvent {
  final String conversationId;
  final String messageId;
  final String emoji;
  RemoveReactionEvent({
    required this.conversationId,
    required this.messageId,
    required this.emoji,
  });
}

class EditMessageEvent extends ChatEvent {
  final String conversationId;
  final String messageId;
  final String newContent;
  EditMessageEvent({
    required this.conversationId,
    required this.messageId,
    required this.newContent,
  });
}

class DeleteMessageEvent extends ChatEvent {
  final String conversationId;
  final String messageId;
  DeleteMessageEvent({
    required this.conversationId,
    required this.messageId,
  });
}

class MarkConversationReadEvent extends ChatEvent {
  final String conversationId;
  final String messageId;
  MarkConversationReadEvent({
    required this.conversationId,
    required this.messageId,
  });
}

class SendTypingEvent extends ChatEvent {
  final String conversationId;
  final bool isTyping;
  SendTypingEvent({required this.conversationId, required this.isTyping});
}

class WsEnvelopeReceivedEvent extends ChatEvent {
  final Map<String, dynamic> envelope;
  WsEnvelopeReceivedEvent(this.envelope);
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
  final bool isPeerTyping;
  final String? peerTypingName;

  MessagesLoaded({
    required this.conversationId,
    required this.messages,
    this.isPeerTyping = false,
    this.peerTypingName,
  });

  MessagesLoaded copyWith({
    String? conversationId,
    List<MiighoMessageItem>? messages,
    bool? isPeerTyping,
    String? peerTypingName,
  }) {
    return MessagesLoaded(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      isPeerTyping: isPeerTyping ?? this.isPeerTyping,
      peerTypingName: peerTypingName ?? this.peerTypingName,
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
    on<CreateGroupEvent>(_onCreateGroup);
    on<TogglePinConversationEvent>(_onTogglePinConversation);
    on<ToggleMuteConversationEvent>(_onToggleMuteConversation);
    on<AddReactionEvent>(_onAddReaction);
    on<RemoveReactionEvent>(_onRemoveReaction);
    on<EditMessageEvent>(_onEditMessage);
    on<DeleteMessageEvent>(_onDeleteMessage);
    on<MarkConversationReadEvent>(_onMarkConversationRead);
    on<SendTypingEvent>(_onSendTyping);
    on<WsEnvelopeReceivedEvent>(_onWsEnvelopeReceived);

    // Automatically connect WebSocket with user session
    chatRepository.connectWebSocket();

    _wsSubscription = chatRepository.wsClient.messages.listen((msg) {
      if (msg is Map<String, dynamic>) {
        add(WsEnvelopeReceivedEvent(msg));
      }
    });
  }

  Future<void> _onLoadConversations(LoadConversations event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    try {
      final conversations = await chatRepository.getConversations();
      _allConversations = List.from(conversations);
      emit(ConversationsLoaded(_allConversations));
    } catch (e) {
      emit(ChatError('Impossible de charger les conversations: $e'));
    }
  }

  Future<void> _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    try {
      final messages = await chatRepository.getMessages(event.conversationId);
      emit(MessagesLoaded(conversationId: event.conversationId, messages: messages));
    } catch (e) {
      emit(ChatError('Impossible de charger les messages: $e'));
    }
  }

  Future<void> _onSendTextMessage(SendTextMessage event, Emitter<ChatState> emit) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMessage = MiighoMessageItem(
      id: tempId,
      conversationId: event.conversationId,
      content: event.content,
      isMe: true,
      type: MessageBubbleType.text,
      status: MessageDeliveryStatus.sending,
      timestamp: DateTime.now(),
      replyToId: event.replyToId,
    );

    final currentState = state;
    if (currentState is MessagesLoaded && currentState.conversationId == event.conversationId) {
      emit(currentState.copyWith(messages: [optimisticMessage, ...currentState.messages]));
    } else {
      emit(MessagesLoaded(
        conversationId: event.conversationId,
        messages: [optimisticMessage],
      ));
    }

    try {
      final serverConfirmed = await chatRepository.sendMessage(
        conversationId: event.conversationId,
        content: event.content,
        type: MessageBubbleType.text,
        replyToId: event.replyToId,
      );

      final latestState = state;
      if (latestState is MessagesLoaded && latestState.conversationId == event.conversationId) {
        final updatedList = latestState.messages.map((m) {
          return m.id == tempId ? serverConfirmed : m;
        }).toList();
        emit(latestState.copyWith(messages: updatedList));
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
    } catch (e) {
      // Reconcile as failed (no fake success)
      final latestState = state;
      if (latestState is MessagesLoaded && latestState.conversationId == event.conversationId) {
        final updatedList = latestState.messages.map((m) {
          return m.id == tempId ? m.copyWith(status: MessageDeliveryStatus.failed) : m;
        }).toList();
        emit(latestState.copyWith(messages: updatedList));
      }
    }
  }

  Future<void> _onSendVoiceMessage(SendVoiceMessage event, Emitter<ChatState> emit) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMessage = MiighoMessageItem(
      id: tempId,
      conversationId: event.conversationId,
      content: 'Message vocal (${event.duration.inSeconds}s)',
      isMe: true,
      type: MessageBubbleType.voice,
      mediaPath: event.audioPath,
      mediaDuration: event.duration,
      status: MessageDeliveryStatus.sending,
      timestamp: DateTime.now(),
    );

    final currentState = state;
    if (currentState is MessagesLoaded && currentState.conversationId == event.conversationId) {
      emit(currentState.copyWith(messages: [optimisticMessage, ...currentState.messages]));
    } else {
      emit(MessagesLoaded(
        conversationId: event.conversationId,
        messages: [optimisticMessage],
      ));
    }

    try {
      final serverConfirmed = await chatRepository.sendMessage(
        conversationId: event.conversationId,
        content: 'Audio',
        type: MessageBubbleType.voice,
        mediaPath: event.audioPath,
        mediaDuration: event.duration,
        replyToId: event.replyToId,
        metadata: {'duration_seconds': event.duration.inSeconds},
      );

      final latestState = state;
      if (latestState is MessagesLoaded && latestState.conversationId == event.conversationId) {
        final updatedList = latestState.messages.map((m) {
          return m.id == tempId ? serverConfirmed : m;
        }).toList();
        emit(latestState.copyWith(messages: updatedList));
      }
    } catch (_) {
      final latestState = state;
      if (latestState is MessagesLoaded && latestState.conversationId == event.conversationId) {
        final updatedList = latestState.messages.map((m) {
          return m.id == tempId ? m.copyWith(status: MessageDeliveryStatus.failed) : m;
        }).toList();
        emit(latestState.copyWith(messages: updatedList));
      }
    }
  }

  Future<void> _onSendMediaMessage(SendMediaMessage event, Emitter<ChatState> emit) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final type = event.mediaType == 'video'
        ? MessageBubbleType.video
        : (event.mediaType == 'document' ? MessageBubbleType.document : MessageBubbleType.image);

    final optimisticMessage = MiighoMessageItem(
      id: tempId,
      conversationId: event.conversationId,
      content: event.caption ?? '',
      isMe: true,
      type: type,
      mediaPath: event.filePath,
      mediaFileName: event.filePath.split('/').last,
      status: MessageDeliveryStatus.sending,
      timestamp: DateTime.now(),
      replyToId: event.replyToId,
    );

    final currentState = state;
    if (currentState is MessagesLoaded && currentState.conversationId == event.conversationId) {
      emit(currentState.copyWith(messages: [optimisticMessage, ...currentState.messages]));
    } else {
      emit(MessagesLoaded(
        conversationId: event.conversationId,
        messages: [optimisticMessage],
      ));
    }

    try {
      final serverConfirmed = await chatRepository.sendMessage(
        conversationId: event.conversationId,
        content: event.caption ?? '',
        type: type,
        mediaPath: event.filePath,
        replyToId: event.replyToId,
        metadata: {'file_name': event.filePath.split('/').last},
      );

      final latestState = state;
      if (latestState is MessagesLoaded && latestState.conversationId == event.conversationId) {
        final updatedList = latestState.messages.map((m) {
          return m.id == tempId ? serverConfirmed : m;
        }).toList();
        emit(latestState.copyWith(messages: updatedList));
      }
    } catch (_) {
      final latestState = state;
      if (latestState is MessagesLoaded && latestState.conversationId == event.conversationId) {
        final updatedList = latestState.messages.map((m) {
          return m.id == tempId ? m.copyWith(status: MessageDeliveryStatus.failed) : m;
        }).toList();
        emit(latestState.copyWith(messages: updatedList));
      }
    }
  }

  Future<void> _onCreateConversation(CreateConversationEvent event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    try {
      final newConv = await chatRepository.createConversation(event.recipientId);
      _allConversations.insert(0, newConv);
      emit(ConversationsLoaded(List.from(_allConversations), activeConversationId: newConv.id));
    } catch (e) {
      emit(ChatError('Erreur création conversation: $e'));
    }
  }

  Future<void> _onCreateGroup(CreateGroupEvent event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    try {
      final newGroup = await chatRepository.createGroup(event.name, event.memberIds);
      _allConversations.insert(0, newGroup);
      emit(ConversationsLoaded(List.from(_allConversations), activeConversationId: newGroup.id));
    } catch (e) {
      emit(ChatError('Erreur création groupe: $e'));
    }
  }

  void _onTogglePinConversation(TogglePinConversationEvent event, Emitter<ChatState> emit) {
    final idx = _allConversations.indexWhere((c) => c.id == event.conversationId);
    if (idx != -1) {
      final item = _allConversations[idx];
      _allConversations[idx] = item.copyWith(isPinned: !item.isPinned);
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

  Future<void> _onAddReaction(AddReactionEvent event, Emitter<ChatState> emit) async {
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

    try {
      await chatRepository.addReaction(event.messageId, event.emoji);
    } catch (_) {}
  }

  Future<void> _onRemoveReaction(RemoveReactionEvent event, Emitter<ChatState> emit) async {
    final currentState = state;
    if (currentState is MessagesLoaded && currentState.conversationId == event.conversationId) {
      final updatedMessages = currentState.messages.map((m) {
        if (m.id == event.messageId) {
          final existing = List<MessageReactionData>.from(m.reactions);
          final rIdx = existing.indexWhere((r) => r.emoji == event.emoji);
          if (rIdx != -1) {
            if (existing[rIdx].count > 1) {
              existing[rIdx] = MessageReactionData(
                emoji: event.emoji,
                count: existing[rIdx].count - 1,
                hasReacted: false,
              );
            } else {
              existing.removeAt(rIdx);
            }
          }
          return m.copyWith(reactions: existing);
        }
        return m;
      }).toList();
      emit(currentState.copyWith(messages: updatedMessages));
    }

    try {
      await chatRepository.removeReaction(event.messageId, event.emoji);
    } catch (_) {}
  }

  Future<void> _onEditMessage(EditMessageEvent event, Emitter<ChatState> emit) async {
    final currentState = state;
    if (currentState is MessagesLoaded && currentState.conversationId == event.conversationId) {
      final updatedMessages = currentState.messages.map((m) {
        if (m.id == event.messageId) {
          return m.copyWith(content: event.newContent, editedAt: DateTime.now());
        }
        return m;
      }).toList();
      emit(currentState.copyWith(messages: updatedMessages));
    }

    try {
      await chatRepository.editMessage(event.messageId, event.newContent);
    } catch (_) {}
  }

  Future<void> _onDeleteMessage(DeleteMessageEvent event, Emitter<ChatState> emit) async {
    final currentState = state;
    if (currentState is MessagesLoaded && currentState.conversationId == event.conversationId) {
      final updatedMessages = currentState.messages.where((m) => m.id != event.messageId).toList();
      emit(currentState.copyWith(messages: updatedMessages));
    }

    try {
      await chatRepository.deleteMessage(event.messageId);
    } catch (_) {}
  }

  Future<void> _onMarkConversationRead(MarkConversationReadEvent event, Emitter<ChatState> emit) async {
    try {
      await chatRepository.markRead(event.conversationId, event.messageId);
    } catch (_) {}
  }

  void _onSendTyping(SendTypingEvent event, Emitter<ChatState> emit) {
    chatRepository.wsClient.sendTyping(event.conversationId, event.isTyping);
  }

  Future<void> _onWsEnvelopeReceived(WsEnvelopeReceivedEvent event, Emitter<ChatState> emit) async {
    final env = event.envelope;
    final type = env['type'] as String?;
    final convId = env['conversation_id'] as String?;
    final data = env['data'];

    switch (type) {
      case 'message.sent':
      case 'message.created':
        if (data is Map<String, dynamic>) {
          final currentUserId = await chatRepository.secureStorage.getUserId() ?? '';
          final newMsg = MiighoMessageItem.fromJson(data, currentUserId: currentUserId);

          final currentState = state;
          if (currentState is MessagesLoaded && currentState.conversationId == convId) {
            // Avoid duplicate if already in list
            if (!currentState.messages.any((m) => m.id == newMsg.id)) {
              emit(currentState.copyWith(messages: [newMsg, ...currentState.messages]));
            }
          }

          // Update conversations list
          final idx = _allConversations.indexWhere((c) => c.id == convId);
          if (idx != -1) {
            final old = _allConversations[idx];
            final updated = old.copyWith(
              subtitle: newMsg.content,
              updatedAt: newMsg.timestamp,
              isLastMessageFromMe: newMsg.isMe,
              lastMessageStatus: newMsg.status,
              unreadCount: (currentState is MessagesLoaded && currentState.conversationId == convId)
                  ? 0
                  : old.unreadCount + 1,
            );
            _allConversations[idx] = updated;
          }
        }
        break;

      case 'message.read':
        final currentState = state;
        if (currentState is MessagesLoaded && currentState.conversationId == convId) {
          final updated = currentState.messages.map((m) {
            return m.isMe ? m.copyWith(status: MessageDeliveryStatus.read) : m;
          }).toList();
          emit(currentState.copyWith(messages: updated));
        }
        break;

      case 'message.delivered':
        final currentState = state;
        if (currentState is MessagesLoaded && currentState.conversationId == convId) {
          final updated = currentState.messages.map((m) {
            return (m.isMe && m.status != MessageDeliveryStatus.read)
                ? m.copyWith(status: MessageDeliveryStatus.delivered)
                : m;
          }).toList();
          emit(currentState.copyWith(messages: updated));
        }
        break;

      case 'message.updated':
        if (data is Map<String, dynamic>) {
          final msgId = data['id'] as String?;
          final newContent = data['content'] as String?;
          final currentState = state;
          if (currentState is MessagesLoaded && currentState.conversationId == convId && msgId != null) {
            final updated = currentState.messages.map((m) {
              return m.id == msgId
                  ? m.copyWith(content: newContent ?? m.content, editedAt: DateTime.now())
                  : m;
            }).toList();
            emit(currentState.copyWith(messages: updated));
          }
        }
        break;

      case 'message.deleted':
        final msgId = (data is Map<String, dynamic>) ? data['id'] as String? : data?.toString();
        final currentState = state;
        if (currentState is MessagesLoaded && currentState.conversationId == convId && msgId != null) {
          final updated = currentState.messages.where((m) => m.id != msgId).toList();
          emit(currentState.copyWith(messages: updated));
        }
        break;

      case 'reaction.added':
        if (data is Map<String, dynamic>) {
          final msgId = data['message_id'] as String?;
          final emoji = data['emoji'] as String?;
          final uid = data['user_id'] as String?;
          final currentUserId = await chatRepository.secureStorage.getUserId() ?? '';

          final currentState = state;
          if (currentState is MessagesLoaded && currentState.conversationId == convId && msgId != null && emoji != null) {
            final updated = currentState.messages.map((m) {
              if (m.id == msgId) {
                final existing = List<MessageReactionData>.from(m.reactions);
                final rIdx = existing.indexWhere((r) => r.emoji == emoji);
                if (rIdx != -1) {
                  existing[rIdx] = MessageReactionData(
                    emoji: emoji,
                    count: existing[rIdx].count + 1,
                    hasReacted: uid == currentUserId || existing[rIdx].hasReacted,
                  );
                } else {
                  existing.add(MessageReactionData(
                    emoji: emoji,
                    count: 1,
                    hasReacted: uid == currentUserId,
                  ));
                }
                return m.copyWith(reactions: existing);
              }
              return m;
            }).toList();
            emit(currentState.copyWith(messages: updated));
          }
        }
        break;

      case 'reaction.removed':
        if (data is Map<String, dynamic>) {
          final msgId = data['message_id'] as String?;
          final emoji = data['emoji'] as String?;
          final uid = data['user_id'] as String?;
          final currentUserId = await chatRepository.secureStorage.getUserId() ?? '';

          final currentState = state;
          if (currentState is MessagesLoaded && currentState.conversationId == convId && msgId != null && emoji != null) {
            final updated = currentState.messages.map((m) {
              if (m.id == msgId) {
                final existing = List<MessageReactionData>.from(m.reactions);
                final rIdx = existing.indexWhere((r) => r.emoji == emoji);
                if (rIdx != -1) {
                  if (existing[rIdx].count > 1) {
                    existing[rIdx] = MessageReactionData(
                      emoji: emoji,
                      count: existing[rIdx].count - 1,
                      hasReacted: uid == currentUserId ? false : existing[rIdx].hasReacted,
                    );
                  } else {
                    existing.removeAt(rIdx);
                  }
                }
                return m.copyWith(reactions: existing);
              }
              return m;
            }).toList();
            emit(currentState.copyWith(messages: updated));
          }
        }
        break;

      case 'user.typing':
      case 'typing.started':
      case 'typing.stopped':
        final currentState = state;
        if (currentState is MessagesLoaded && currentState.conversationId == convId) {
          bool isTyping = false;
          if (type == 'typing.started') {
            isTyping = true;
          } else if (type == 'typing.stopped') {
            isTyping = false;
          } else if (data is Map<String, dynamic>) {
            isTyping = data['is_typing'] == true;
          }
          emit(currentState.copyWith(isPeerTyping: isTyping));
        }
        break;
    }
  }

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    return super.close();
  }
}
