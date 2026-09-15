import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/chat_repository.dart';
import '../../models/chat_models.dart';
import '../../presentation/widgets/message_bubble.dart' show MessageBubbleType, MessageReactionData;
import 'package:miigho/shared/widgets/conversation_tile.dart' show MessageDeliveryStatus;

// ==========================================
// EVENTS
// ==========================================
abstract class ChatEvent {}

class LoadConversations extends ChatEvent {
  /// If true, this is a background refresh that should not show loading indicators.
  final bool isBackground;
  LoadConversations({this.isBackground = false});
}

class ResetChatStateEvent extends ChatEvent {}

class LoadMessages extends ChatEvent {
  final String conversationId;
  /// If true, this is a background refresh (e.g., after WS reconnect).
  final bool isBackground;
  LoadMessages(this.conversationId, {this.isBackground = false});
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

/// Internal event triggered when WebSocket reconnects after disconnection.
class _WsReconnectedEvent extends ChatEvent {}

// ==========================================
// STATES — Composite Architecture
// ==========================================

/// Base state class.
abstract class ChatState {
  /// Convenience: always returns conversations from state (empty if not loaded).
  List<MiighoConversation> get conversations => const [];
}

/// Initial state before any data is loaded.
class ChatInitial extends ChatState {}

/// Loading indicator state — only used for initial load, never for background refreshes.
class ChatLoading extends ChatState {}

/// Error state preserves conversation data for resilient display.
class ChatError extends ChatState {
  final String message;
  final List<MiighoConversation> _conversations;

  ChatError(this.message, {List<MiighoConversation> conversations = const []})
      : _conversations = conversations;

  @override
  List<MiighoConversation> get conversations => _conversations;
}

/// COMPOSITE STATE: Conversations are always preserved.
/// When viewing the conversation list, `activeConversationId` is null and `messages` is empty.
/// When viewing a chat, `activeConversationId` is set and `messages` are loaded.
/// This eliminates the previous mutual-exclusion bug between ConversationsLoaded/MessagesLoaded.
class ConversationsLoaded extends ChatState {
  @override
  final List<MiighoConversation> conversations;
  final String? activeConversationId;
  final List<MiighoMessageItem> messages;
  final MiighoConversation? activeConversation;
  final bool isPeerTyping;
  final String? peerTypingName;
  final bool isLoadingMessages;

  ConversationsLoaded(
    this.conversations, {
    this.activeConversationId,
    this.messages = const [],
    this.activeConversation,
    this.isPeerTyping = false,
    this.peerTypingName,
    this.isLoadingMessages = false,
  });

  ConversationsLoaded copyWith({
    List<MiighoConversation>? conversations,
    String? activeConversationId,
    List<MiighoMessageItem>? messages,
    MiighoConversation? activeConversation,
    bool? isPeerTyping,
    String? peerTypingName,
    bool? isLoadingMessages,
    bool clearActiveConversation = false,
  }) {
    return ConversationsLoaded(
      conversations ?? this.conversations,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      messages: messages ?? this.messages,
      activeConversation: clearActiveConversation ? null : (activeConversation ?? this.activeConversation),
      isPeerTyping: isPeerTyping ?? this.isPeerTyping,
      peerTypingName: peerTypingName ?? this.peerTypingName,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
    );
  }

  /// Convenience getter — is there an active conversation being viewed?
  bool get hasActiveConversation => activeConversationId != null;
}

/// Backward-compatibility alias — UI code checking `state is MessagesLoaded`
/// will continue to work. This is a sub-view of ConversationsLoaded
/// where an active conversation is set.
/// NOTE: This is NOT a separate class. The check `state is MessagesLoaded`
/// should be replaced with `state is ConversationsLoaded && state.hasActiveConversation`.
/// For now, we use a typedef-style alias.
typedef MessagesLoaded = ConversationsLoaded;

// ==========================================
// BLOC
// ==========================================
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository chatRepository;
  StreamSubscription? _wsSubscription;
  StreamSubscription? _wsStateSubscription;

  /// Internal cache of conversations — always persisted across state transitions.
  List<MiighoConversation> _allConversations = [];

  /// Track WebSocket connection transitions for reconnection detection (P0-1).
  bool _wasConnected = false;
  bool _wasDisconnectedAfterConnected = false;

  /// Generation counters for REST race condition protection (P0-2).
  int _conversationsGeneration = 0;
  final Map<String, int> _messagesGenerations = {};

  ChatBloc({required this.chatRepository}) : super(ChatInitial()) {
    _wasConnected = chatRepository.wsClient.isConnected;
    _wasDisconnectedAfterConnected = false;

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
    on<ResetChatStateEvent>(_onResetChatState);
    on<_WsReconnectedEvent>(_onWsReconnected);

    // ─── Phase 1: NO connectWebSocket() here ───
    // app.dart is the sole authority for WebSocket lifecycle.
    // We only subscribe to incoming WS messages here.

    _wsSubscription = chatRepository.wsClient.messages.listen((msg) {
      if (msg is Map<String, dynamic>) {
        add(WsEnvelopeReceivedEvent(msg));
      }
    });

    // ─── P0-1: Listen to WebSocket connectionState with explicit state machine ───
    _wsStateSubscription = chatRepository.wsClient.connectionState.listen((wsState) {
      if (wsState == 'disconnected' || wsState == 'reconnecting') {
        if (_wasConnected) {
          _wasDisconnectedAfterConnected = true;
        }
      } else if (wsState == 'connected') {
        if (_wasConnected && _wasDisconnectedAfterConnected) {
          // Vraie transition : CONNECTED -> DISCONNECTED/RECONNECTING -> CONNECTED
          _wasDisconnectedAfterConnected = false;
          add(_WsReconnectedEvent());
        } else if (!_wasConnected) {
          // Première connexion initiale
          _wasConnected = true;
          _wasDisconnectedAfterConnected = false;
        }
        // Si _wasConnected && !_wasDisconnectedAfterConnected : CONNECTED redondant, ne rien faire.
      }
    });
  }

  void _onResetChatState(ResetChatStateEvent event, Emitter<ChatState> emit) {
    _allConversations.clear();
    _wasConnected = false;
    _wasDisconnectedAfterConnected = false;
    _conversationsGeneration++;
    _messagesGenerations.clear();
    emit(ChatInitial());
  }

  /// ─── Phase 4 & P0-2: Reconciliation after WS reconnection with generation tracking ───
  Future<void> _onWsReconnected(_WsReconnectedEvent event, Emitter<ChatState> emit) async {
    final convGen = ++_conversationsGeneration;
    try {
      final currentState = state;
      final activeId = (currentState is ConversationsLoaded) ? currentState.activeConversationId : null;

      // 1. Immediately reload messages for active conversation in parallel (fast path)
      Future<void>? msgReloadFuture;
      if (activeId != null) {
        final msgGen = (_messagesGenerations[activeId] ?? 0) + 1;
        _messagesGenerations[activeId] = msgGen;

        msgReloadFuture = () async {
          try {
            final rawMessages = await chatRepository.getMessages(activeId);
            if (msgGen != _messagesGenerations[activeId]) return;
            final latest = _currentCompositeState();
            final currentMsgs = latest.activeConversationId == activeId ? latest.messages : const <MiighoMessageItem>[];
            final messages = _sortAndDeduplicate([...rawMessages, ...currentMsgs]);

            MiighoConversation? conv;
            final idx = _allConversations.indexWhere((c) => c.id == activeId);
            if (idx != -1) {
              conv = _allConversations[idx];
            }
            emit(latest.copyWith(
              conversations: List.from(_allConversations),
              messages: messages,
              activeConversation: conv,
            ));
          } catch (_) {}
        }();
      }

      // 2. Concurrently reload conversations list in background
      final conversations = await chatRepository.getConversations();
      if (convGen != _conversationsGeneration) return;
      _allConversations = List.from(conversations);

      final latestState = _currentCompositeState();
      emit(latestState.copyWith(conversations: List.from(_allConversations)));

      if (msgReloadFuture != null) {
        await msgReloadFuture;
      }
    } catch (_) {
      // Silently fail — don't disrupt current UI
    }
  }

  String _formatErrorMessage(dynamic error, String fallback) {
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('429')) {
      return 'Service temporairement limité. Veuillez patienter quelques instants.';
    }
    if (errStr.contains('403')) {
      return 'Action non autorisée (vous devez être en contact).';
    }
    return '$fallback: $error';
  }

  /// Centralized sorting, deduplication, and reconciliation of messages.
  /// - Deduplicates by server ID and by clientMessageId.
  /// - Replaces optimistic message with server message (including canonical server timestamp).
  /// - Deterministically sorts messages by UTC timestamp descending (newest first for reverse: true).
  /// - If UTC timestamps are identical, tie-breaks deterministically using message ID.
  List<MiighoMessageItem> _sortAndDeduplicate(List<MiighoMessageItem> messages) {
    final Map<String, MiighoMessageItem> map = {};

    for (final msg in messages) {
      String? cmidKey;
      if (msg.clientMessageId != null && msg.clientMessageId!.isNotEmpty) {
        cmidKey = 'cmid_${msg.clientMessageId}';
      }
      final idKey = 'id_${msg.id}';

      String targetKey = cmidKey ?? idKey;
      MiighoMessageItem? existing = cmidKey != null ? map[cmidKey] : null;
      existing ??= map[idKey];

      if (existing != null) {
        final isServerConfirmed = msg.status != MessageDeliveryStatus.sending;
        final wasServerConfirmed = existing.status != MessageDeliveryStatus.sending;

        if (isServerConfirmed && !wasServerConfirmed) {
          map.remove('id_${existing.id}');
          if (existing.clientMessageId != null && existing.clientMessageId!.isNotEmpty) {
            map.remove('cmid_${existing.clientMessageId}');
          }
          map[targetKey] = msg;
        } else if (!isServerConfirmed && wasServerConfirmed) {
          // Keep existing server-confirmed message
        } else {
          map[targetKey] = msg.reactions.isNotEmpty ? msg : existing;
        }
      } else {
        map[targetKey] = msg;
      }
    }

    final list = map.values.toList();
    list.sort((a, b) {
      final cmp = b.timestamp.toUtc().compareTo(a.timestamp.toUtc());
      if (cmp != 0) return cmp;
      return b.id.compareTo(a.id);
    });

    return list;
  }

  /// Helper: get the current composite state or create a new one preserving conversations.
  ConversationsLoaded _currentCompositeState() {
    final s = state;
    if (s is ConversationsLoaded) return s;
    return ConversationsLoaded(List.from(_allConversations));
  }

  Future<void> _onLoadConversations(LoadConversations event, Emitter<ChatState> emit) async {
    final gen = ++_conversationsGeneration;

    // Only show loading spinner on initial load if no conversations exist and not already in loaded composite state
    if (_allConversations.isEmpty && !event.isBackground && state is! ConversationsLoaded) {
      emit(ChatLoading());
    }
    try {
      final conversations = await chatRepository.getConversations();
      if (gen != _conversationsGeneration) return;
      _allConversations = List.from(conversations);

      final currentState = state;
      if (currentState is ConversationsLoaded && currentState.hasActiveConversation) {
        // Preserve active conversation view, just update the conversations list
        emit(currentState.copyWith(conversations: List.from(_allConversations)));
      } else {
        emit(ConversationsLoaded(List.from(_allConversations)));
      }
    } catch (e) {
      if (gen != _conversationsGeneration) return;
      emit(ChatError(
        _formatErrorMessage(e, 'Impossible de charger les conversations'),
        conversations: List.from(_allConversations),
      ));
    }
  }

  Future<void> _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) async {
    final convId = event.conversationId;
    final gen = (_messagesGenerations[convId] ?? 0) + 1;
    _messagesGenerations[convId] = gen;

    final composite = _currentCompositeState();

    // Show loading only if not background
    if (!event.isBackground) {
      emit(composite.copyWith(
        activeConversationId: convId,
        isLoadingMessages: true,
        messages: composite.activeConversationId == convId
            ? composite.messages
            : const [],
      ));
    }

    try {
      final rawMessages = await chatRepository.getMessages(convId);
      if (gen != _messagesGenerations[convId]) {
        // Stale REST response ignored silently (P0-2)
        return;
      }

      final latestState = _currentCompositeState();
      // Safe merge: preserve any message received via WS or sent optimistically in the meantime
      final currentMessages = latestState.activeConversationId == convId
          ? latestState.messages
          : const <MiighoMessageItem>[];
      final messages = _sortAndDeduplicate([...rawMessages, ...currentMessages]);

      MiighoConversation? conv;
      final existingIdx = _allConversations.indexWhere((c) => c.id == convId);
      if (existingIdx != -1) {
        conv = _allConversations[existingIdx];
      } else {
        conv = await chatRepository.getConversation(convId);
        if (gen != _messagesGenerations[convId]) return;
      }

      emit(latestState.copyWith(
        conversations: List.from(_allConversations),
        activeConversationId: convId,
        messages: messages,
        activeConversation: conv,
        isLoadingMessages: false,
      ));
    } catch (e) {
      if (gen != _messagesGenerations[convId]) return;
      emit(ChatError(
        _formatErrorMessage(e, 'Impossible de charger les messages'),
        conversations: List.from(_allConversations),
      ));
    }
  }

  Future<void> _onSendTextMessage(SendTextMessage event, Emitter<ChatState> emit) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final clientMessageId = tempId;
    final optimisticMessage = MiighoMessageItem(
      id: tempId,
      conversationId: event.conversationId,
      content: event.content,
      isMe: true,
      type: MessageBubbleType.text,
      status: MessageDeliveryStatus.sending,
      timestamp: DateTime.now(),
      replyToId: event.replyToId,
      clientMessageId: clientMessageId,
    );

    final currentState = _currentCompositeState();
    if (currentState.activeConversationId == event.conversationId) {
      emit(currentState.copyWith(
        messages: _sortAndDeduplicate([optimisticMessage, ...currentState.messages]),
      ));
    }

    try {
      final serverConfirmed = await chatRepository.sendMessage(
        conversationId: event.conversationId,
        content: event.content,
        type: MessageBubbleType.text,
        replyToId: event.replyToId,
        clientMessageId: clientMessageId,
      );

      final latestState = _currentCompositeState();
      if (latestState.activeConversationId == event.conversationId) {
        emit(latestState.copyWith(
          messages: _sortAndDeduplicate([serverConfirmed, ...latestState.messages]),
        ));
      }

      // Update conversation subtitle in conversation list
      final idx = _allConversations.indexWhere((c) => c.id == event.conversationId);
      if (idx != -1) {
        final updated = _allConversations[idx].copyWith(
          subtitle: event.content,
          updatedAt: serverConfirmed.timestamp,
          isLastMessageFromMe: true,
          lastMessageStatus: MessageDeliveryStatus.sent,
        );
        _allConversations[idx] = updated;
      }
    } catch (e) {
      // Reconcile as failed (no fake success)
      final latestState = _currentCompositeState();
      if (latestState.activeConversationId == event.conversationId) {
        final updatedList = latestState.messages.map((m) {
          return (m.id == tempId || (m.clientMessageId != null && m.clientMessageId == clientMessageId))
              ? m.copyWith(status: MessageDeliveryStatus.failed)
              : m;
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

    final currentState = _currentCompositeState();
    if (currentState.activeConversationId == event.conversationId) {
      emit(currentState.copyWith(messages: [optimisticMessage, ...currentState.messages]));
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

      final latestState = _currentCompositeState();
      if (latestState.activeConversationId == event.conversationId) {
        final updatedList = latestState.messages.map((m) {
          return m.id == tempId ? serverConfirmed : m;
        }).toList();
        emit(latestState.copyWith(messages: updatedList));
      }
    } catch (_) {
      final latestState = _currentCompositeState();
      if (latestState.activeConversationId == event.conversationId) {
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

    final currentState = _currentCompositeState();
    if (currentState.activeConversationId == event.conversationId) {
      emit(currentState.copyWith(messages: [optimisticMessage, ...currentState.messages]));
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

      final latestState = _currentCompositeState();
      if (latestState.activeConversationId == event.conversationId) {
        final updatedList = latestState.messages.map((m) {
          return m.id == tempId ? serverConfirmed : m;
        }).toList();
        emit(latestState.copyWith(messages: updatedList));
      }
    } catch (_) {
      final latestState = _currentCompositeState();
      if (latestState.activeConversationId == event.conversationId) {
        final updatedList = latestState.messages.map((m) {
          return m.id == tempId ? m.copyWith(status: MessageDeliveryStatus.failed) : m;
        }).toList();
        emit(latestState.copyWith(messages: updatedList));
      }
    }
  }

  Future<void> _onCreateConversation(CreateConversationEvent event, Emitter<ChatState> emit) async {
    final composite = _currentCompositeState();
    emit(composite.copyWith(isLoadingMessages: true));

    try {
      final newConv = await chatRepository.createConversation(event.recipientId);
      final existingIdx = _allConversations.indexWhere((c) => c.id == newConv.id);
      if (existingIdx != -1) {
        _allConversations.removeAt(existingIdx);
      }
      _allConversations.insert(0, newConv);
      emit(ConversationsLoaded(
        List.from(_allConversations),
        activeConversationId: newConv.id,
        isLoadingMessages: false,
      ));
    } catch (e) {
      emit(ChatError(
        'Erreur création conversation: $e',
        conversations: List.from(_allConversations),
      ));
    }
  }

  Future<void> _onCreateGroup(CreateGroupEvent event, Emitter<ChatState> emit) async {
    final composite = _currentCompositeState();
    emit(composite.copyWith(isLoadingMessages: true));

    try {
      final newGroup = await chatRepository.createGroup(event.name, event.memberIds);
      _allConversations.insert(0, newGroup);
      emit(ConversationsLoaded(
        List.from(_allConversations),
        activeConversationId: newGroup.id,
        isLoadingMessages: false,
      ));
    } catch (e) {
      emit(ChatError(
        'Erreur création groupe: $e',
        conversations: List.from(_allConversations),
      ));
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
      final composite = _currentCompositeState();
      emit(composite.copyWith(conversations: List.from(_allConversations)));
    }
  }

  void _onToggleMuteConversation(ToggleMuteConversationEvent event, Emitter<ChatState> emit) {
    final idx = _allConversations.indexWhere((c) => c.id == event.conversationId);
    if (idx != -1) {
      final item = _allConversations[idx];
      _allConversations[idx] = item.copyWith(isMuted: !item.isMuted);
      final composite = _currentCompositeState();
      emit(composite.copyWith(conversations: List.from(_allConversations)));
    }
  }

  Future<void> _onAddReaction(AddReactionEvent event, Emitter<ChatState> emit) async {
    final currentState = _currentCompositeState();
    if (currentState.activeConversationId == event.conversationId) {
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
    final currentState = _currentCompositeState();
    if (currentState.activeConversationId == event.conversationId) {
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
    final currentState = _currentCompositeState();
    if (currentState.activeConversationId == event.conversationId) {
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
    final currentState = _currentCompositeState();
    if (currentState.activeConversationId == event.conversationId) {
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

          final currentState = _currentCompositeState();

          // Always update messages if viewing this conversation
          if (currentState.activeConversationId == convId) {
            emit(currentState.copyWith(
              messages: _sortAndDeduplicate([newMsg, ...currentState.messages]),
              conversations: List.from(_allConversations), // ensure up-to-date
            ));
          }

          // Always update conversations list (even when viewing messages!)
          final idx = _allConversations.indexWhere((c) => c.id == convId);
          if (idx != -1) {
            final old = _allConversations[idx];
            final updated = old.copyWith(
              subtitle: newMsg.content,
              updatedAt: newMsg.timestamp,
              isLastMessageFromMe: newMsg.isMe,
              lastMessageStatus: newMsg.status,
              unreadCount: (currentState.activeConversationId == convId)
                  ? 0
                  : old.unreadCount + 1,
            );
            _allConversations[idx] = updated;

            // Re-emit with updated conversations if we haven't already
            if (currentState.activeConversationId != convId) {
              emit(currentState.copyWith(conversations: List.from(_allConversations)));
            }
          } else if (convId != null && convId.isNotEmpty) {
            // New conversation received via WS that is not yet in local cache
            try {
              final newConv = await chatRepository.getConversation(convId);
              if (newConv != null) {
                final updated = newConv.copyWith(
                  subtitle: newMsg.content,
                  updatedAt: newMsg.timestamp,
                  isLastMessageFromMe: newMsg.isMe,
                  lastMessageStatus: newMsg.status,
                  unreadCount: (currentState.activeConversationId == convId) ? 0 : 1,
                );
                _allConversations.insert(0, updated);
                if (currentState.activeConversationId != convId) {
                  emit(currentState.copyWith(conversations: List.from(_allConversations)));
                }
              }
            } catch (_) {}
          }
        }
        break;

      case 'message.read':
        final currentState = _currentCompositeState();
        if (currentState.activeConversationId == convId) {
          final updated = currentState.messages.map((m) {
            return m.isMe ? m.copyWith(status: MessageDeliveryStatus.read) : m;
          }).toList();
          emit(currentState.copyWith(messages: updated));
        }
        break;

      case 'message.delivered':
        final currentState = _currentCompositeState();
        if (currentState.activeConversationId == convId) {
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
          final currentState = _currentCompositeState();
          if (currentState.activeConversationId == convId && msgId != null) {
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
        final currentState = _currentCompositeState();
        if (currentState.activeConversationId == convId && msgId != null) {
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

          final currentState = _currentCompositeState();
          if (currentState.activeConversationId == convId && msgId != null && emoji != null) {
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

          final currentState = _currentCompositeState();
          if (currentState.activeConversationId == convId && msgId != null && emoji != null) {
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
        final currentState = _currentCompositeState();
        if (currentState.activeConversationId == convId) {
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
    _wsStateSubscription?.cancel();
    return super.close();
  }
}
