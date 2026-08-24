import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_database.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/contact_model.dart';

/// Repository handling contact synchronization, searching, blocking, and favorites.
class ContactsRepository {
  final ApiClient apiClient;
  final SecureStorageService secureStorage;
  final MiighoDatabase database;

  // In-memory cache for offline-first responsiveness
  List<Contact> _cachedContacts = [];

  ContactsRepository({
    required this.apiClient,
    required this.secureStorage,
    required this.database,
  });

  /// Get locally cached or in-memory contacts
  List<Contact> get cachedContacts => List.unmodifiable(_cachedContacts);

  /// Fetch local address book contacts (simulated device phonebook for African context)
  Future<List<Contact>> fetchLocalContacts() async {
    // In production, flutter_contacts or fast_contacts would extract OS phonebook.
    // We provide a realistic African phonebook dataset if local cache is empty.
    if (_cachedContacts.isNotEmpty) {
      return _cachedContacts;
    }

    final localList = [
      const Contact(
        id: 'c1',
        userId: 'usr_amina',
        displayName: 'Amina Diallo',
        phoneNumber: '+221771234567',
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        bio: 'Entrepreneure & Tech Enthusiast | Dakar 🇸🇳',
        isMiighoUser: true,
        isFavorite: true,
        isOnline: true,
      ),
      const Contact(
        id: 'c2',
        userId: 'usr_kofi',
        displayName: 'Kofi Mensah',
        phoneNumber: '+233241234567',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        bio: 'Software Engineer @ MÏÏghO Accra 🇬🇭',
        isMiighoUser: true,
        isFavorite: true,
        isOnline: false,
      ),
      const Contact(
        id: 'c3',
        userId: 'usr_fatou',
        displayName: 'Fatou Sow',
        phoneNumber: '+221782345678',
        avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150',
        bio: 'Designer UI/UX • Dakar 🇸🇳',
        isMiighoUser: true,
        isFavorite: false,
        isOnline: true,
      ),
      const Contact(
        id: 'c4',
        userId: 'usr_samuel',
        displayName: 'Samuel Eto\'o Junior',
        phoneNumber: '+237691234567',
        avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
        bio: 'Finance & Mobile Money Douala 🇨🇲',
        isMiighoUser: true,
        isFavorite: false,
        isOnline: false,
      ),
      const Contact(
        id: 'c5',
        userId: 'usr_zainab',
        displayName: 'Zainab Al-Mansoor',
        phoneNumber: '+212612345678',
        avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150',
        bio: 'Casablanca 🇲🇦 • E-commerce manager',
        isMiighoUser: true,
        isFavorite: true,
        isOnline: true,
      ),
      const Contact(
        id: 'c6',
        userId: 'usr_kwame',
        displayName: 'Kwame Nkrumah',
        phoneNumber: '+233201234567',
        avatarUrl: null,
        bio: 'Pan-African Community Builder 🇬🇭',
        isMiighoUser: true,
        isFavorite: false,
        isOnline: false,
      ),
      const Contact(
        id: 'c7',
        userId: null,
        displayName: 'Awa Traoré',
        phoneNumber: '+22376123456',
        avatarUrl: null,
        bio: null,
        isMiighoUser: false,
        isFavorite: false,
      ),
      const Contact(
        id: 'c8',
        userId: null,
        displayName: 'Bakary Cissé',
        phoneNumber: '+2250712345678',
        avatarUrl: null,
        bio: null,
        isMiighoUser: false,
        isFavorite: false,
      ),
      const Contact(
        id: 'c9',
        userId: null,
        displayName: 'Chinedu Okeke',
        phoneNumber: '+2348012345678',
        avatarUrl: null,
        bio: null,
        isMiighoUser: false,
        isFavorite: false,
      ),
      const Contact(
        id: 'c10',
        userId: null,
        displayName: 'Moussa Diop',
        phoneNumber: '+221709876543',
        avatarUrl: null,
        bio: null,
        isMiighoUser: false,
        isFavorite: false,
      ),
    ];

    _cachedContacts = localList;
    return _cachedContacts;
  }

  /// Sync phone numbers with MÏÏghO backend to discover registered users
  Future<List<Contact>> syncContacts(List<String> phoneNumbers) async {
    try {
      final response = await apiClient.post(
        '/contacts/sync',
        data: {'phone_numbers': phoneNumbers},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] ?? response.data;
        if (data is List) {
          final registeredUsers = data.map((item) => Contact.fromJson(item as Map<String, dynamic>)).toList();
          
          // Merge remote users with local contacts
          _cachedContacts = _cachedContacts.map((localContact) {
            final match = registeredUsers.firstWhere(
              (r) => r.phoneNumber == localContact.phoneNumber,
              orElse: () => localContact,
            );
            return match;
          }).toList();
        }
      }
    } catch (e) {
      // Offline fallback: keep existing cache
    }

    return _cachedContacts;
  }

  /// Fetch registered contacts list from server
  Future<List<Contact>> fetchRemoteContacts() async {
    try {
      final response = await apiClient.get('/contacts');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] ?? response.data;
        if (data is List) {
          final contacts = data.map((json) => Contact.fromJson(json as Map<String, dynamic>)).toList();
          _cachedContacts = contacts;
          return contacts;
        }
      }
    } catch (e) {
      // Fallback to local
    }
    return fetchLocalContacts();
  }

  /// Search contacts locally and remotely
  Future<List<Contact>> searchContacts(String query) async {
    if (query.trim().isEmpty) {
      return _cachedContacts;
    }

    final lowerQuery = query.toLowerCase().trim();
    return _cachedContacts.where((c) {
      final matchName = c.displayName.toLowerCase().contains(lowerQuery);
      final matchPhone = c.phoneNumber.contains(lowerQuery);
      final matchBio = c.bio?.toLowerCase().contains(lowerQuery) ?? false;
      return matchName || matchPhone || matchBio;
    }).toList();
  }

  /// Toggle favorite status of a contact
  Future<void> toggleFavorite(String contactId) async {
    final index = _cachedContacts.indexWhere((c) => c.id == contactId);
    if (index != -1) {
      final contact = _cachedContacts[index];
      final newStatus = !contact.isFavorite;
      _cachedContacts[index] = contact.copyWith(isFavorite: newStatus);

      try {
        await apiClient.post('/contacts/$contactId/favorite', data: {'is_favorite': newStatus});
      } catch (_) {
        // Optimistic UI state kept locally
      }
    }
  }

  /// Block or unblock a user
  Future<void> blockUser(String contactId, {bool block = true}) async {
    final index = _cachedContacts.indexWhere((c) => c.id == contactId);
    if (index != -1) {
      final contact = _cachedContacts[index];
      _cachedContacts[index] = contact.copyWith(isBlocked: block);

      try {
        await apiClient.post('/contacts/$contactId/block', data: {'is_blocked': block});
      } catch (_) {
        // Optimistic state
      }
    }
  }

  /// Format an invite message with MÏÏghO download link
  String getInviteMessage(String contactName) {
    return 'Salut $contactName ! Rejoins-moi sur MÏÏghO, la super-application africaine sécurisée et économique. Télécharge-la ici : https://miigho.africa/app';
  }
}
