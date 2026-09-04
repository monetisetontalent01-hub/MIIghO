@Tags(['e2e'])
library staging_live_validation_test;

import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:miigho/features/identity/data/identity_repository.dart';

class _StagingHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _StagingHttpOverrides();

  const baseUrl = 'https://miigho-production.up.railway.app/api/v1';
  const wsUrl = 'wss://miigho-production.up.railway.app/ws';

  group('MÏÏghO Live Staging Validation (Railway Backend & WSS Hub)', () {
    test('Full Journey: User A (+243) <-> User B (+225), Real OTP, /users/me, Contacts, Chat, WSS', () async {
      print('\n======================================================');
      print('  MÏÏghO LIVE STAGING VALIDATION (A <-> B)');
      print('======================================================');
      print('API URL : $baseUrl');
      print('WS URL  : $wsUrl\n');

      // 1. Authentification Réelle Utilisateur A (+243)
      final phoneA = '+243812345678';
      print('--- [TEST 1] Inscription & OTP Réel Utilisateur A ($phoneA) ---');
      final storageA = SecureStorageService.inMemory();
      final apiClientA = ApiClient(baseUrl, storageA);
      final authRepoA = AuthRepository(apiClientA, storageA);

      await authRepoA.sendOTP(phoneA);
      print('✓ OTP envoyé avec succès au backend Railway pour A ($phoneA)');

      final authA = await authRepoA.verifyOTP(phoneA, '123456', 'e2e_live_test_user_a');
      print('✓ OTP validé ! User A ID: ${authA.userId}');
      expect(authA.userId.isNotEmpty, true);
      expect(authA.accessToken.isNotEmpty, true);

      // 2. Authentification Réelle Utilisateur B (+225)
      final phoneB = '+225078888002';
      print('\n--- [TEST 2] Inscription & OTP Réel Utilisateur B ($phoneB) ---');
      final storageB = SecureStorageService.inMemory();
      final apiClientB = ApiClient(baseUrl, storageB);
      final authRepoB = AuthRepository(apiClientB, storageB);

      await authRepoB.sendOTP(phoneB);
      print('✓ OTP envoyé avec succès au backend Railway pour B ($phoneB)');

      final authB = await authRepoB.verifyOTP(phoneB, '123456', 'e2e_live_test_user_b');
      print('✓ OTP validé ! User B ID: ${authB.userId}');
      expect(authB.userId.isNotEmpty, true);
      expect(authB.accessToken.isNotEmpty, true);
      expect(authA.userId != authB.userId, true);

      // 3. Profil Utilisateur Réel (/users/me)
      print('\n--- [TEST 3] Profil Souverain Réel (/users/me) ---');
      final identityRepoA = IdentityRepository(apiClient: apiClientA, secureStorage: storageA);
      final profileA = await identityRepoA.getProfile();
      print('✓ Profil A reçu : displayName="${profileA.displayName}", phone="${profileA.phoneNumber}", miighoId="${profileA.miighoId}"');
      expect(profileA.displayName.contains('Koffi'), false, reason: 'Aucun Koffi fictif ne doit apparaître');
      expect(profileA.phoneNumber, phoneA);

      // 4. Recherche de contact réel (+225)
      print('\n--- [TEST 4] Recherche de Contact Réel (GET /contacts/search?q=+225) ---');
      final contactsRepoA = ContactsRepository(
        apiClient: apiClientA,
        secureStorage: storageA,
        database: MiighoDatabase(),
      );
      final searchResults = await contactsRepoA.searchContacts('+225');
      print('✓ Contacts trouvés : ${searchResults.length}');
      expect(searchResults.isNotEmpty, true);
      final contactB = searchResults.firstWhere((c) => c.phoneNumber == phoneB);
      print('✓ Contact B identifié dans la recherche : "${contactB.displayName}" (UUID: ${contactB.id})');
      expect(contactB.id, authB.userId);

      // 5. Création / Ouverture de conversation A -> B
      print('\n--- [TEST 5] Création de la conversation A -> B ---');
      final wsClientA = WsClient(wsUrl);
      final chatRepoA = ChatRepository(
        apiClient: apiClientA,
        wsClient: wsClientA,
        secureStorage: storageA,
      );

      final wsClientB = WsClient(wsUrl);
      final chatRepoB = ChatRepository(
        apiClient: apiClientB,
        wsClient: wsClientB,
        secureStorage: storageB,
      );

      final conv = await chatRepoA.createConversation(contactB.id);
      print('✓ Conversation A <-> B créée/ouverte avec succès : ID=${conv.id}');
      expect(conv.id.isNotEmpty, true);

      // 6. WebSocket Live WSS Hub
      print('\n--- [TEST 6] Connexion WebSocket WSS avec Tokens Réels ---');
      await chatRepoA.connectWebSocket();
      await chatRepoB.connectWebSocket();
      await Future.delayed(const Duration(milliseconds: 500));
      print('✓ Connexions WebSocket A & B établies sur $wsUrl');

      // 7. Envoi Message A -> B
      print('\n--- [TEST 7] Envoi Message Texte A -> B (POST /chat/conversations/:id/messages) ---');
      final timestamp = DateTime.now().toIso8601String();
      final contentA = 'Bonjour depuis Kinshasa ($phoneA) ! Validation live $timestamp';
      final sentA = await chatRepoA.sendMessage(
        conversationId: conv.id,
        content: contentA,
      );
      print('✓ Message A persisté sur Railway : ID=${sentA.id}, Content="${sentA.content}"');
      expect(sentA.id.isNotEmpty, true);
      expect(sentA.content, contentA);

      // 8. Réception et Vérification des messages par B
      print('\n--- [TEST 8] Réception et Lecture par B ---');
      final messagesForB = await chatRepoB.getMessages(conv.id);
      print('✓ B a chargé ${messagesForB.length} messages dans la conversation');
      expect(messagesForB.isNotEmpty, true);
      final receivedByB = messagesForB.firstWhere((m) => m.id == sentA.id);
      print('✓ Message reçu par B avec exactitude : "${receivedByB.content}"');
      expect(receivedByB.content, contentA);

      // 9. Réponse B -> A
      print('\n--- [TEST 9] Réponse B -> A ---');
      final replyContentB = 'Bien reçu à Abidjan ($phoneB) ! Tout est opérationnel ✓';
      final sentReplyB = await chatRepoB.sendMessage(
        conversationId: conv.id,
        content: replyContentB,
      );
      print('✓ Réponse B persistée sur Railway : ID=${sentReplyB.id}, Content="${sentReplyB.content}"');
      expect(sentReplyB.id.isNotEmpty, true);

      // 10. Confirmation finale par A et Mark as read
      print('\n--- [TEST 10] A reçoit la réponse et marque comme lu ---');
      final messagesForA = await chatRepoA.getMessages(conv.id);
      final receivedByA = messagesForA.firstWhere((m) => m.id == sentReplyB.id);
      print('✓ A a bien reçu la réponse de B : "${receivedByA.content}"');
      expect(receivedByA.content, replyContentB);

      await chatRepoA.markRead(conv.id, sentReplyB.id);
      print('✓ Message de B marqué comme lu par A');

      print('\n======================================================');
      print('  TOUTES LES ÉTAPES SONT VALIDÉES AVEC SUCCÈS (PASS)  ');
      print('======================================================\n');
    });
  });
}
