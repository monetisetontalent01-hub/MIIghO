import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:miigho/core/network/api_client.dart';
import 'package:miigho/core/network/ws_client.dart';
import 'package:miigho/core/storage/secure_storage.dart';
import 'package:miigho/features/chat/data/chat_repository.dart';
import 'package:miigho/features/chat/models/chat_models.dart';
import 'package:miigho/features/chat/presentation/bloc/chat_bloc.dart';

class ControllableChatRepository implements ChatRepository {
  final StreamController<dynamic> _wsController = StreamController<dynamic>.broadcast();
  final StreamController<String> _wsStateController = StreamController<String>.broadcast();

  Completer<List<MiighoMessageItem>>? completer1;
  Completer<List<MiighoMessageItem>>? completer2;
  int getMessagesCallCount = 0;

  @override
  late final WsClient wsClient = _MockWsClient(_wsController.stream, _wsStateController.stream);

  @override
  ApiClient get apiClient => throw UnimplementedError();

  @override
  final SecureStorageService secureStorage = SecureStorageService.inMemory();

  @override
  void disconnectWebSocket() {}

  @override
  Future<List<MiighoMessageItem>> getMessages(String conversationId) async {
    getMessagesCallCount++;
    if (getMessagesCallCount == 1) {
      completer1 = Completer<List<MiighoMessageItem>>();
      return completer1!.future;
    } else {
      completer2 = Completer<List<MiighoMessageItem>>();
      return completer2!.future;
    }
  }

  @override
  Future<List<MiighoConversation>> getConversations() async => [
    MiighoConversation(
      id: 'conv_race',
      title: 'Race Test Conversation',
      subtitle: 'Init',
      updatedAt: DateTime.now().toUtc(),
    ),
  ];

  @override
  Future<MiighoConversation?> getConversation(String conversationId) async => MiighoConversation(
    id: conversationId,
    title: 'Race Test Conversation',
    subtitle: 'Init',
    updatedAt: DateTime.now().toUtc(),
  );

  @override
  Future<void> connectWebSocket() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  void simulateIncomingWs(Map<String, dynamic> envelope) {
    _wsController.add(envelope);
  }
}

class _MockWsClient implements WsClient {
  final Stream<dynamic> _messages;
  final Stream<String> _connectionState;

  _MockWsClient(this._messages, this._connectionState);

  @override
  Stream<dynamic> get messages => _messages;

  @override
  Stream<String> get connectionState => _connectionState;

  @override
  bool get isConnected => true;

  @override
  Future<void> connect() async {}

  @override
  void disconnect() {}

  @override
  void send(Map<String, dynamic> envelope) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PREUVE P0-2 — REST/WS RACE CONDITION & STALE GENERATION REJECTION', () async {
    print('\n================================================================');
    print('PREUVE P0-2 : TEST FORMEL DE RACE CONDITION REST/WS');
    print('================================================================');

    final repo = ControllableChatRepository();
    await repo.secureStorage.saveUser('my_user_id', '+243812345678');
    final bloc = ChatBloc(chatRepository: repo);

    // Initialiser les conversations
    bloc.add(LoadConversations());
    await Future.delayed(const Duration(milliseconds: 50));

    final convId = 'conv_race';

    // 1. Déclencher LoadMessages #1 (Requête REST lente)
    print('\n[ÉTAPE 1] Déclenchement de LoadMessages #1 (Requête REST lente)...');
    bloc.add(LoadMessages(convId));
    await Future.delayed(const Duration(milliseconds: 50));
    print('  -> LoadMessages #1 en cours, appel getMessages() #1 initié.');
    print('  -> Generation attendue pour #1 = 1');

    // 2. Arrivée d\'un message temps réel par WebSocket pendant que #1 est en vol
    print('\n[ÉTAPE 2] Arrivée d\'un nouveau message WebSocket en vol...');
    final wsMessageId = 'ws_msg_urgent_100';
    repo.simulateIncomingWs({
      'type': 'message.created',
      'conversation_id': convId,
      'data': {
        'id': wsMessageId,
        'conversation_id': convId,
        'sender_id': 'peer_user',
        'content': 'Message WebSocket reçu pendant la requête REST lente',
        'type': 'text',
        'status': 'sent',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }
    });
    await Future.delayed(const Duration(milliseconds: 100));

    var stateAfterWs = bloc.state as ConversationsLoaded;
    print('  -> Messages dans le state après WS: ${stateAfterWs.messages.length}');
    expect(stateAfterWs.messages.any((m) => m.id == wsMessageId), true);
    print('  -> Message WS correctement inséré dans le state : $wsMessageId');

    // 3. Déclencher LoadMessages #2 (Nouvelle requête plus récente)
    print('\n[ÉTAPE 3] Déclenchement de LoadMessages #2...');
    bloc.add(LoadMessages(convId));
    await Future.delayed(const Duration(milliseconds: 50));
    print('  -> LoadMessages #2 en cours, appel getMessages() #2 initié.');
    print('  -> Generation attendue pour #2 = 2');

    // 4. La réponse #2 termine EN PREMIER
    print('\n[ÉTAPE 4] La réponse #2 (plus récente) termine en premier...');
    final msgFromGen2 = MiighoMessageItem(
      id: 'msg_from_gen2',
      conversationId: convId,
      content: 'Message chargé par la requête #2',
      isMe: false,
      timestamp: DateTime.now().toUtc(),
    );
    repo.completer2!.complete([msgFromGen2]);
    await Future.delayed(const Duration(milliseconds: 100));

    var stateAfterGen2 = bloc.state as ConversationsLoaded;
    print('  -> State après complétion de #2 : ${stateAfterGen2.messages.length} messages');
    final hasMsg2 = stateAfterGen2.messages.any((m) => m.id == 'msg_from_gen2');
    final hasWs = stateAfterGen2.messages.any((m) => m.id == wsMessageId);
    print('  -> msg_from_gen2 présent: $hasMsg2');
    print('  -> ws_msg_urgent_100 conservé (fusion safe): $hasWs');
    expect(hasMsg2, true);
    expect(hasWs, true);

    // 5. La réponse #1 termine ENSUITE (avec des données anciennes / obsolètes)
    print('\n[ÉTAPE 5] La réponse #1 (obsolète/stale) termine après #2...');
    final staleMsg = MiighoMessageItem(
      id: 'stale_old_msg',
      conversationId: convId,
      content: 'Message ancien qui ne doit PAS écraser l\'état récent',
      isMe: false,
      timestamp: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
    );
    repo.completer1!.complete([staleMsg]);
    await Future.delayed(const Duration(milliseconds: 100));

    var finalState = bloc.state as ConversationsLoaded;
    print('\n[VÉRIFICATION FINALE]');
    print('  -> Nombre de messages final : ${finalState.messages.length}');
    final staleMsgPresent = finalState.messages.any((m) => m.id == 'stale_old_msg');
    print('  -> Le message stale_old_msg a été rejeté/ignoré : ${!staleMsgPresent}');
    print('  -> Le message WS récent est toujours présent : ${finalState.messages.any((m) => m.id == wsMessageId)}');
    print('  -> Le message de Gen #2 est toujours présent : ${finalState.messages.any((m) => m.id == 'msg_from_gen2')}');

    expect(staleMsgPresent, false, reason: 'Le message de la requête #1 DOIT être ignoré car sa génération est obsolète');
    expect(finalState.messages.any((m) => m.id == wsMessageId), true);
    expect(finalState.messages.any((m) => m.id == 'msg_from_gen2'), true);

    print('\n================================================================');
    print('RÉSULTAT OFFICIEL :');
    print('Generation #1 = 1');
    print('Generation #2 = 2');
    print('Résultat de #1 = stale/ignored (génération 1 != génération courante 2)');
    print('Résultat final = ÉTAT EXACT PRÉSERVÉ, AUCUNE RÉGRESSION');
    print('================================================================\n');

    await bloc.close();
  });
}
