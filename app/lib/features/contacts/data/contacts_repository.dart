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

  /// Fetch local address book contacts (loads remote synced contacts or local cache)
  Future<List<Contact>> fetchLocalContacts() async {
    if (_cachedContacts.isNotEmpty) {
      return _cachedContacts;
    }
    return fetchRemoteContacts();
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
        if (data is Map<String, dynamic> && data['matched_contacts'] is List) {
          final matches = data['matched_contacts'] as List;
          final registeredUsers = matches.map((item) {
            final m = item as Map<String, dynamic>;
            return Contact(
              id: m['user_id'] as String? ?? '',
              userId: m['user_id'] as String?,
              displayName: m['phone_number'] as String? ?? 'Utilisateur MÏÏghO',
              phoneNumber: m['phone_number'] as String? ?? '',
              isMiighoUser: true,
            );
          }).toList();

          _cachedContacts = registeredUsers;
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
      // Return cached contacts
    }
    return _cachedContacts;
  }

  /// Search contacts locally and remotely via backend
  Future<List<Contact>> searchContacts(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return _cachedContacts;
    }

    try {
      final response = await apiClient.get(
        '/contacts/search',
        queryParameters: {'q': trimmed},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] ?? response.data;
        if (data is List) {
          final remoteResults = data.map((json) => Contact.fromJson(json as Map<String, dynamic>)).toList();
          if (remoteResults.isNotEmpty) {
            return remoteResults;
          }
        }
      }
    } catch (_) {
      // Offline fallback
    }

    // Local filter fallback
    final lowerQuery = trimmed.toLowerCase();
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
