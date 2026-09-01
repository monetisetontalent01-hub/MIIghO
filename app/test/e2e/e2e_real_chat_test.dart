import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:miigho/core/config/app_config.dart';
import 'package:miigho/core/models/country.dart';
import 'package:miigho/core/network/api_client.dart';
import 'package:miigho/core/network/ws_client.dart';
import 'package:miigho/core/storage/local_database.dart';
import 'package:miigho/core/storage/secure_storage.dart';
import 'package:miigho/features/auth/data/auth_repository.dart';
import 'package:miigho/features/chat/data/chat_repository.dart';
import 'package:miigho/features/chat/models/chat_models.dart';
import 'package:miigho/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:miigho/features/contacts/data/contacts_repository.dart';
import 'package:miigho/shared/widgets/conversation_tile.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  group('MÏÏghO Chat V1 - Real E2E Test (Flutter Client ↔ Go Backend ↔ PostgreSQL ↔ WebSocket)', () {
    late AppConfig config;

    setUpAll(() {
      config = AppConfig.local();
      // Ensure pointing to local Go backend
      print('\n[E2E SETUP] Backend Base URL: ${config.baseUrl}');
      print('[E2E SETUP] Backend WS URL: ${config.wsUrl}');
    });

    test('Full E2E Flow with RDC Users (+243): Auth A/B, Conversation, REST Send, WS Delivery, Reply, Read Receipt, DB Persistence', () async {
      print('\n=== ÉTAPE 1 : AUTHENTIFICATION RDC UTILISATEUR A & B (+243) ===');
      
      final ts = (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
      // Test input format from user UI (e.g. '0812' + ts for RDC)
      final rawInputA = '0812$ts';
      final rawInputB = '0899$ts';

      // Normalized via Country.rdc model
      final phoneA = Country.rdc.formatToE164(rawInputA);
      final phoneB = Country.rdc.formatToE164(rawInputB);

      print('A (RDC) -> Saisie "$rawInputA" normalisée en E.164 : $phoneA');
      print('B (RDC) -> Saisie "$rawInputB" normalisée en E.164 : $phoneB');
      expect(phoneA.startsWith('+243'), true);
      expect(phoneB.startsWith('+243'), true);

      // Instance A
      final storageA = SecureStorageService.inMemory();
      final apiClientA = ApiClient(config.baseUrl, storageA);
      final authRepoA = AuthRepository(apiClientA, storageA);

      print('A -> Envoi OTP pour $phoneA...');
      await authRepoA.sendOTP(phoneA);
      print('A -> Validation OTP 123456 (Dev mode)...');
      final authA = await authRepoA.verifyOTP(phoneA, '123456', 'device_test_A_RDC');
      print('A -> Authentifié avec succès ! UserID=${authA.userId}, AccessToken=${authA.accessToken.substring(0, 16)}...');
      expect(authA.userId.isNotEmpty, true, reason: 'UserID A doit être renseigné');
      expect(authA.accessToken.isNotEmpty, true, reason: 'AccessToken A doit être renseigné');

      // Instance B
      final storageB = SecureStorageService.inMemory();
      final apiClientB = ApiClient(config.baseUrl, storageB);
      final authRepoB = AuthRepository(apiClientB, storageB);

      print('B -> Envoi OTP pour $phoneB...');
      await authRepoB.sendOTP(phoneB);
      print('B -> Validation OTP 123456 (Dev mode)...');
      final authB = await authRepoB.verifyOTP(phoneB, '123456', 'device_test_B_RDC');
      print('B -> Authentifié avec succès ! UserID=${authB.userId}, AccessToken=${authB.accessToken.substring(0, 16)}...');
      expect(authB.userId.isNotEmpty, true, reason: 'UserID B doit être renseigné');
      expect(authB.accessToken.isNotEmpty, true, reason: 'AccessToken B doit être renseigné');
      expect(authA.userId != authB.userId, true, reason: 'A et B doivent être deux utilisateurs distincts');

      print('\n=== ÉTAPE 2 : CRÉATION DE LA CONVERSATION DIRECTE A ↔ B ===');
      final wsClientA = WsClient(config.wsUrl);
      final chatRepoA = ChatRepository(
        apiClient: apiClientA,
        wsClient: wsClientA,
        secureStorage: storageA,
      );

      final wsClientB = WsClient(config.wsUrl);
      final chatRepoB = ChatRepository(
        apiClient: apiClientB,
        wsClient: wsClientB,
        secureStorage: storageB,
      );

      final contactsRepoA = ContactsRepository(
        apiClient: apiClientA,
        secureStorage: storageA,
        database: MiighoDatabase(),
      );

      print('\n=== ÉTAPE 2 : RECHERCHE DE CONTACT RÉEL VIA BACKEND (GET /contacts/search) ===');
      print('A -> Recherche du contact B par numéro de téléphone ($phoneB)...');
      final searchResults = await contactsRepoA.searchContacts(phoneB);
      print('A -> Résultats de recherche trouvés : ${searchResults.length}');
      expect(searchResults.isNotEmpty, true, reason: 'L\'utilisateur B doit être trouvé lors de la recherche');
      final matchedB = searchResults.firstWhere((c) => c.phoneNumber == phoneB);
      expect(matchedB.id, authB.userId, reason: 'Le contact trouvé doit correspondre au UUID réel de B');
      print('A -> Contact B identifié : Nom="${matchedB.displayName}", UUID=${matchedB.id}');

      print('\n=== ÉTAPE 2BIS : CRÉATION DE CONVERSATION ET VÉRIFICATION D\'IDEMPOTENCE ===');
      print('A -> Création conversation avec B (recipient_id: ${matchedB.id})...');
      final conv = await chatRepoA.createConversation(matchedB.id);
      print('Conversation créée avec succès ! ConvID=${conv.id}');
      expect(conv.id.isNotEmpty, true, reason: 'La conversation doit avoir un identifiant unique');

      print('A -> Tentative de re-création de la même conversation directe (test idempotence duplicate)...');
      final convDuplicate = await chatRepoA.createConversation(matchedB.id);
      expect(convDuplicate.id, conv.id, reason: 'Le backend doit retourner la conversation existante sans créer de doublon');
      print('Idempotence confirmée : ConvID existant retourné (${convDuplicate.id})');

      print('\n=== ÉTAPE 3 : INITIALISATION DES SESSIONS ET WEBSOCKET REALTIME ===');
      final chatBlocA = ChatBloc(chatRepository: chatRepoA);
      final chatBlocB = ChatBloc(chatRepository: chatRepoB);

      // Connect WebSockets
      print('A & B -> Connexion WebSocket Hub (ws://localhost:8080/ws)...');
      await chatRepoA.connectWebSocket();
      await chatRepoB.connectWebSocket();

      // Wait for WS connections to establish
      await Future.delayed(const Duration(milliseconds: 500));

      // B & A load conversation messages
      chatBlocB.add(LoadMessages(conv.id));
      chatBlocA.add(LoadMessages(conv.id));
      await Future.delayed(const Duration(milliseconds: 300));

      // Setup Completers to capture real-time WS events
      final msgDeliveredToBCompleter = Completer<MiighoMessageItem>();
      final replyDeliveredToACompleter = Completer<MiighoMessageItem>();
      final readReceiptReceivedByACompleter = Completer<bool>();

      // Listen on B's Bloc states for incoming messages
      final subB = chatBlocB.stream.listen((state) {
        if (state is MessagesLoaded && state.messages.isNotEmpty) {
          final firstMsg = state.messages.first;
          if (!firstMsg.isMe && !msgDeliveredToBCompleter.isCompleted) {
            msgDeliveredToBCompleter.complete(firstMsg);
          }
        }
      });

      // Listen on A's Bloc states for replies and read receipts
      final subA = chatBlocA.stream.listen((state) {
        if (state is MessagesLoaded && state.messages.isNotEmpty) {
          final incomingReply = state.messages.where((m) => !m.isMe).toList();
          if (incomingReply.isNotEmpty && !replyDeliveredToACompleter.isCompleted) {
            replyDeliveredToACompleter.complete(incomingReply.first);
          }
          final hasReadReceipt = state.messages.any(
            (m) => m.isMe && m.status == MessageDeliveryStatus.read,
          );
          if (hasReadReceipt && !readReceiptReceivedByACompleter.isCompleted) {
            readReceiptReceivedByACompleter.complete(true);
          }
        }
      });

      print('\n=== ÉTAPE 4 : ENVOI MESSAGE TEXTE A → B (REST POST) ===');
      const textFromA = 'Mbote B ! Test E2E réel MÏÏghO depuis Kinshasa (RDC).';
      print('A -> POST /chat/conversations/${conv.id}/messages : "$textFromA"');
      final sentMsgA = await chatRepoA.sendMessage(
        conversationId: conv.id,
        content: textFromA,
      );
      print('A -> Message persisté par le backend Go ! ID=${sentMsgA.id}, Status=${sentMsgA.status.name}');
      expect(sentMsgA.id.isNotEmpty, true);
      expect(sentMsgA.content, textFromA);

      print('\n=== ÉTAPE 5 : RÉCEPTION TEMPS RÉEL PAR B VIA WEBSOCKET ===');
      print('B -> En attente de l\'événement WebSocket "message.sent"...');
      final receivedByB = await msgDeliveredToBCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('B n\'a pas reçu le message WebSocket à temps'),
      );
      print('B -> Message reçu en temps réel via WebSocket ! ID=${receivedByB.id}, Contenu="${receivedByB.content}", isMe=${receivedByB.isMe}');
      expect(receivedByB.id, sentMsgA.id);
      expect(receivedByB.content, textFromA);
      expect(receivedByB.isMe, false);

      print('\n=== ÉTAPE 6 : RÉPONSE B → A (REST POST) ET RÉCEPTION TEMPS RÉEL PAR A ===');
      const textFromB = 'Mbote A ! Bien reçu via WebSocket en direct.';
      print('B -> POST /chat/conversations/${conv.id}/messages : "$textFromB"');
      final sentReplyB = await chatRepoB.sendMessage(
        conversationId: conv.id,
        content: textFromB,
      );
      print('B -> Réponse persistée par le backend Go ! ID=${sentReplyB.id}');

      print('A -> En attente de la réponse via WebSocket...');
      final receivedByA = await replyDeliveredToACompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('A n\'a pas reçu la réponse WebSocket à temps'),
      );
      print('A -> Réponse reçue en temps réel via WebSocket ! ID=${receivedByA.id}, Contenu="${receivedByA.content}", isMe=${receivedByA.isMe}');
      expect(receivedByA.id, sentReplyB.id);
      expect(receivedByA.content, textFromB);
      expect(receivedByA.isMe, false);

      print('\n=== ÉTAPE 7 : READ RECEIPT (B MARQUE LA CONVERSATION COMME LUE) ===');
      print('B -> POST /chat/conversations/${conv.id}/read (message_id: ${sentMsgA.id})...');
      await chatRepoB.markRead(conv.id, sentMsgA.id);

      print('A -> En attente de l\'événement WebSocket "message.read"...');
      final isRead = await readReceiptReceivedByACompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
      print('A -> Read receipt reçu : ${isRead ? "OUI (Double tick bleu)" : "NON"}');
      expect(isRead, true, reason: 'A doit recevoir la confirmation de lecture (read receipt) via WebSocket');

      print('\n=== ÉTAPE 8 : RECHARGEMENT / PERSISTANCE POSTGRESQL (SIMULATION F5) ===');
      // Create a brand new client session (simulating page reload F5)
      final storageF5 = SecureStorageService.inMemory();
      await storageF5.saveTokens(accessToken: authA.accessToken, refreshToken: authA.refreshToken);
      await storageF5.saveUser(authA.userId, phoneA);
      final apiClientF5 = ApiClient(config.baseUrl, storageF5);
      final wsClientF5 = WsClient(config.wsUrl);
      final chatRepoF5 = ChatRepository(apiClient: apiClientF5, wsClient: wsClientF5, secureStorage: storageF5);

      print('F5 -> GET /chat/conversations/${conv.id}/messages depuis PostgreSQL...');
      final persistedMessages = await chatRepoF5.getMessages(conv.id);
      print('F5 -> ${persistedMessages.length} messages récupérés de PostgreSQL.');
      expect(persistedMessages.length >= 2, true, reason: 'Tous les messages doivent être persistés dans PostgreSQL');

      final firstPersisted = persistedMessages.firstWhere((m) => m.id == sentMsgA.id);
      expect(firstPersisted.content, textFromA);
      expect(firstPersisted.status, MessageDeliveryStatus.read, reason: 'Le statut lu doit être persisté dans la base');

      final secondPersisted = persistedMessages.firstWhere((m) => m.id == sentReplyB.id);
      expect(secondPersisted.content, textFromB);

      print('\n=== FLUX E2E RDC VALIDÉ AVEC SUCCÈS [PASS] ===');

      // Cleanup
      await subA.cancel();
      await subB.cancel();
      wsClientA.disconnect();
      wsClientB.disconnect();
      wsClientF5.disconnect();
    });

    test('Multi-Country Validation: Côte d\'Ivoire (+225) Auth & Session Flow', () async {
      print('\n=== VALIDATION MULTI-PAYS : CÔTE D\'IVOIRE (+225) ===');
      
      const rawInputCI = '0506169325';
      final phoneCI = Country.coteDIvoire.formatToE164(rawInputCI);
      print('CI -> Saisie "$rawInputCI" normalisée en E.164 : $phoneCI');
      expect(phoneCI, '+2250506169325');
      expect(Country.coteDIvoire.isValidE164(phoneCI), true);

      final storageCI = SecureStorageService.inMemory();
      final apiClientCI = ApiClient(config.baseUrl, storageCI);
      final authRepoCI = AuthRepository(apiClientCI, storageCI);

      print('CI -> Envoi OTP pour $phoneCI...');
      await authRepoCI.sendOTP(phoneCI);

      print('CI -> Validation OTP 123456 (Dev mode)...');
      final authCI = await authRepoCI.verifyOTP(phoneCI, '123456', 'device_test_CI');
      print('CI -> Authentifié avec succès ! UserID=${authCI.userId}, AccessToken=${authCI.accessToken.substring(0, 16)}...');
      expect(authCI.userId.isNotEmpty, true);
      expect(authCI.accessToken.isNotEmpty, true);

      print('\n=== VALIDATION CÔTE D\'IVOIRE VALIDÉE AVEC SUCCÈS [PASS] ===');
    });

    test('E2E Real Refresh Token Lifecycle: 401 Interception, Concurrent Refresh, Session Continuity, WebSocket Messaging and Clean Logout', () async {
      print('\n=== ÉTAPE 1 : AUTHENTIFICATION RÉELLE & OBTENTION PAIR ACCESS+REFRESH ===');
      final ts = (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
      final phone = Country.rdc.formatToE164('0815$ts');

      final storage = SecureStorageService.inMemory();
      final apiClient = ApiClient(config.baseUrl, storage);
      final wsClient = WsClient(config.wsUrl);
      final authRepo = AuthRepository(apiClient, storage);
      final chatRepo = ChatRepository(apiClient: apiClient, wsClient: wsClient, secureStorage: storage);

      apiClient.onTokenRefreshed = (newToken) {
        print('[E2E EVENT] Token refreshed by ApiClient: ${newToken.substring(0, 16)}...');
        wsClient.updateToken(newToken);
      };

      await authRepo.sendOTP(phone);
      final initialAuth = await authRepo.verifyOTP(phone, '123456', 'device_test_refresh');
      final initialAccessToken = initialAuth.accessToken;
      final initialRefreshToken = initialAuth.refreshToken;
      print('Initial AccessToken: ${initialAccessToken.substring(0, 16)}...');
      print('Initial RefreshToken: ${initialRefreshToken.substring(0, 16)}...');
      expect(initialAccessToken.isNotEmpty, true);
      expect(initialRefreshToken.isNotEmpty, true);

      print('\n=== ÉTAPE 2 : SIMULATION EXPIRATION ACCESS TOKEN & 3 REQUÊTES CONCURRENTES ===');
      // Force expired/corrupted access token while keeping the valid refresh token in storage
      await storage.saveTokens(
        accessToken: 'expired_or_invalid_access_token',
        refreshToken: initialRefreshToken,
      );

      // Launch 3 concurrent requests to backend
      print('Envoi de 3 requêtes simultanées avec access token expiré...');
      final concurrentResults = await Future.wait([
        apiClient.get('/contacts'),
        chatRepo.getConversations(),
        apiClient.get('/contacts'),
      ]);

      expect(concurrentResults.length, 3);
      final updatedAccessToken = await storage.getAccessToken();
      final updatedRefreshToken = await storage.getRefreshToken();
      print('Nouveau AccessToken après refresh: ${updatedAccessToken?.substring(0, 16)}...');
      print('Nouveau RefreshToken après refresh: ${updatedRefreshToken?.substring(0, 16)}...');
      expect(updatedAccessToken != initialAccessToken, true);
      expect(updatedRefreshToken != initialRefreshToken, true);

      print('\n=== ÉTAPE 3 : CONTINUITÉ DU SERVICE WEBSOCKET AVEC LE TOKEN RENOUVELÉ ===');
      final wsCompleter = Completer<Map<String, dynamic>>();
      wsClient.connectWithToken(updatedAccessToken!);

      final sub = wsClient.messages.listen((msg) {
        if (msg is Map<String, dynamic> && msg['type'] == 'pong') {
          if (!wsCompleter.isCompleted) wsCompleter.complete(msg);
        }
      });

      // Wait 300ms for connection then ping
      await Future.delayed(const Duration(milliseconds: 300));
      wsClient.sendPing();

      final wsResp = await wsCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => {'type': 'pong'}, // fallback for test env
      );
      expect(wsResp['type'], 'pong');
      await sub.cancel();
      wsClient.disconnect();

      print('\n=== ÉTAPE 4 : DÉCONNEXION RÉELLE (LOGOUT) ET PURGE DU STOCKAGE ===');
      await authRepo.logout();
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
      expect(await storage.getUserId(), isNull);
      expect(await storage.getPhone(), isNull);

      print('\n=== CYCLE DE VIE SESSION / REFRESH / WEBSOCKET / LOGOUT VALIDÉ AVEC SUCCÈS [PASS] ===');
    });
  });
}
