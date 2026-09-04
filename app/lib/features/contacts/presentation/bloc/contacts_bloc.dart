import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/contacts_repository.dart';
import '../../models/contact_model.dart';

// ==========================================
// EVENTS
// ==========================================

abstract class ContactsEvent extends Equatable {
  const ContactsEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load of contacts from local store/backend
class LoadContacts extends ContactsEvent {
  const LoadContacts();
}

/// Trigger full network synchronization with backend
class SyncContacts extends ContactsEvent {
  const SyncContacts();
}

/// Filter/Search contacts by query string
class SearchContacts extends ContactsEvent {
  final String query;

  const SearchContacts(this.query);

  @override
  List<Object?> get props => [query];
}

/// Toggle favorite status of a contact
class ToggleFavorite extends ContactsEvent {
  final String contactId;

  const ToggleFavorite(this.contactId);

  @override
  List<Object?> get props => [contactId];
}

/// Block a user
class BlockUser extends ContactsEvent {
  final String contactId;

  const BlockUser(this.contactId);

  @override
  List<Object?> get props => [contactId];
}

/// Unblock a user
class UnblockUser extends ContactsEvent {
  final String contactId;

  const UnblockUser(this.contactId);

  @override
  List<Object?> get props => [contactId];
}

/// Send a contact authorization request
class SendContactRequestEvent extends ContactsEvent {
  final String recipientId;

  const SendContactRequestEvent(this.recipientId);

  @override
  List<Object?> get props => [recipientId];
}

/// Load pending incoming and outgoing contact requests
class LoadContactRequestsEvent extends ContactsEvent {
  const LoadContactRequestsEvent();
}

/// Accept an incoming contact request
class AcceptContactRequestEvent extends ContactsEvent {
  final String requestId;

  const AcceptContactRequestEvent(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

/// Reject an incoming contact request
class RejectContactRequestEvent extends ContactsEvent {
  final String requestId;

  const RejectContactRequestEvent(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

// ==========================================
// STATES
// ==========================================

abstract class ContactsState extends Equatable {
  const ContactsState();

  @override
  List<Object?> get props => [];
}

class ContactsInitial extends ContactsState {}

class ContactsLoading extends ContactsState {}

class ContactsLoaded extends ContactsState {
  final List<Contact> allContacts;
  final List<Contact> favorites;
  final List<Contact> miighoContacts;
  final List<Contact> nonMiighoContacts;
  final List<Contact> searchResults;
  final List<ContactRequest> incomingRequests;
  final List<ContactRequest> outgoingRequests;
  final String searchQuery;
  final bool isSyncing;

  const ContactsLoaded({
    required this.allContacts,
    required this.favorites,
    required this.miighoContacts,
    required this.nonMiighoContacts,
    required this.searchResults,
    this.incomingRequests = const [],
    this.outgoingRequests = const [],
    this.searchQuery = '',
    this.isSyncing = false,
  });

  bool get isSearching => searchQuery.trim().isNotEmpty;
  int get pendingRequestsCount => incomingRequests.where((r) => r.isPending).length;

  ContactsLoaded copyWith({
    List<Contact>? allContacts,
    List<Contact>? favorites,
    List<Contact>? miighoContacts,
    List<Contact>? nonMiighoContacts,
    List<Contact>? searchResults,
    List<ContactRequest>? incomingRequests,
    List<ContactRequest>? outgoingRequests,
    String? searchQuery,
    bool? isSyncing,
  }) {
    return ContactsLoaded(
      allContacts: allContacts ?? this.allContacts,
      favorites: favorites ?? this.favorites,
      miighoContacts: miighoContacts ?? this.miighoContacts,
      nonMiighoContacts: nonMiighoContacts ?? this.nonMiighoContacts,
      searchResults: searchResults ?? this.searchResults,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      outgoingRequests: outgoingRequests ?? this.outgoingRequests,
      searchQuery: searchQuery ?? this.searchQuery,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  @override
  List<Object?> get props => [
        allContacts,
        favorites,
        miighoContacts,
        nonMiighoContacts,
        searchResults,
        incomingRequests,
        outgoingRequests,
        searchQuery,
        isSyncing,
      ];
}

class ContactsError extends ContactsState {
  final String message;

  const ContactsError(this.message);

  @override
  List<Object?> get props => [message];
}

// ==========================================
// BLOC
// ==========================================

class ContactsBloc extends Bloc<ContactsEvent, ContactsState> {
  final ContactsRepository repository;

  ContactsBloc({required this.repository}) : super(ContactsInitial()) {
    on<LoadContacts>(_onLoadContacts);
    on<SyncContacts>(_onSyncContacts);
    on<SearchContacts>(_onSearchContacts);
    on<ToggleFavorite>(_onToggleFavorite);
    on<BlockUser>(_onBlockUser);
    on<UnblockUser>(_onUnblockUser);
    on<SendContactRequestEvent>(_onSendContactRequest);
    on<LoadContactRequestsEvent>(_onLoadContactRequests);
    on<AcceptContactRequestEvent>(_onAcceptContactRequest);
    on<RejectContactRequestEvent>(_onRejectContactRequest);
  }

  Future<void> _onLoadContacts(LoadContacts event, Emitter<ContactsState> emit) async {
    emit(ContactsLoading());
    try {
      final contacts = await repository.fetchLocalContacts();
      final incoming = await repository.getIncomingRequests();
      final outgoing = await repository.getOutgoingRequests();
      _emitCategorizedContacts(
        emit,
        contacts,
        searchQuery: '',
        incomingRequests: incoming,
        outgoingRequests: outgoing,
      );
    } catch (e) {
      emit(ContactsError('Impossible de charger les contacts : ${e.toString()}'));
    }
  }

  Future<void> _onSyncContacts(SyncContacts event, Emitter<ContactsState> emit) async {
    if (state is ContactsLoaded) {
      final currentState = state as ContactsLoaded;
      emit(currentState.copyWith(isSyncing: true));

      try {
        final phoneNumbers = currentState.allContacts.map((c) => c.phoneNumber).toList();
        final syncedContacts = await repository.syncContacts(phoneNumbers);
        final incoming = await repository.getIncomingRequests();
        final outgoing = await repository.getOutgoingRequests();
        _emitCategorizedContacts(
          emit,
          syncedContacts,
          searchQuery: currentState.searchQuery,
          incomingRequests: incoming,
          outgoingRequests: outgoing,
        );
      } catch (e) {
        emit(currentState.copyWith(isSyncing: false));
      }
    }
  }

  Future<void> _onSearchContacts(SearchContacts event, Emitter<ContactsState> emit) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      if (state is ContactsLoaded) {
        final currentState = state as ContactsLoaded;
        emit(currentState.copyWith(
          searchQuery: '',
          searchResults: currentState.allContacts,
        ));
      }
      return;
    }

    try {
      final results = await repository.searchContacts(query);
      if (state is ContactsLoaded) {
        final currentState = state as ContactsLoaded;
        _emitCategorizedContacts(
          emit,
          results,
          searchQuery: event.query,
          incomingRequests: currentState.incomingRequests,
          outgoingRequests: currentState.outgoingRequests,
        );
      } else {
        _emitCategorizedContacts(emit, results, searchQuery: event.query);
      }
    } catch (_) {
      if (state is ContactsLoaded) {
        final currentState = state as ContactsLoaded;
        final lowerQuery = query.toLowerCase();
        final filtered = currentState.allContacts.where((c) {
          final nameMatch = c.displayName.toLowerCase().contains(lowerQuery);
          final phoneMatch = c.phoneNumber.contains(lowerQuery);
          return nameMatch || phoneMatch;
        }).toList();

        emit(currentState.copyWith(
          searchQuery: event.query,
          searchResults: filtered,
        ));
      }
    }
  }

  Future<void> _onToggleFavorite(ToggleFavorite event, Emitter<ContactsState> emit) async {
    if (state is ContactsLoaded) {
      final currentState = state as ContactsLoaded;
      await repository.toggleFavorite(event.contactId);
      final updatedList = repository.cachedContacts;
      _emitCategorizedContacts(
        emit,
        updatedList,
        searchQuery: currentState.searchQuery,
        incomingRequests: currentState.incomingRequests,
        outgoingRequests: currentState.outgoingRequests,
      );
    }
  }

  Future<void> _onBlockUser(BlockUser event, Emitter<ContactsState> emit) async {
    if (state is ContactsLoaded) {
      final currentState = state as ContactsLoaded;
      await repository.blockUser(event.contactId, block: true);
      final updatedList = repository.cachedContacts;
      _emitCategorizedContacts(
        emit,
        updatedList,
        searchQuery: currentState.searchQuery,
        incomingRequests: currentState.incomingRequests,
        outgoingRequests: currentState.outgoingRequests,
      );
    }
  }

  Future<void> _onUnblockUser(UnblockUser event, Emitter<ContactsState> emit) async {
    if (state is ContactsLoaded) {
      final currentState = state as ContactsLoaded;
      await repository.blockUser(event.contactId, block: false);
      final updatedList = repository.cachedContacts;
      _emitCategorizedContacts(
        emit,
        updatedList,
        searchQuery: currentState.searchQuery,
        incomingRequests: currentState.incomingRequests,
        outgoingRequests: currentState.outgoingRequests,
      );
    }
  }

  Future<void> _onSendContactRequest(SendContactRequestEvent event, Emitter<ContactsState> emit) async {
    try {
      await repository.sendContactRequest(event.recipientId);
      // Reload requests
      final incoming = await repository.getIncomingRequests();
      final outgoing = await repository.getOutgoingRequests();
      if (state is ContactsLoaded) {
        final currentState = state as ContactsLoaded;
        // Update the target contact's relationshipStatus to pending_sent in searchResults
        final updatedResults = currentState.searchResults.map((c) {
          if (c.userId == event.recipientId || c.id == event.recipientId) {
            return c.copyWith(relationshipStatus: 'pending_sent');
          }
          return c;
        }).toList();
        emit(currentState.copyWith(
          searchResults: updatedResults,
          incomingRequests: incoming,
          outgoingRequests: outgoing,
        ));
      }
    } catch (_) {
      // Keep state
    }
  }

  Future<void> _onLoadContactRequests(LoadContactRequestsEvent event, Emitter<ContactsState> emit) async {
    if (state is ContactsLoaded) {
      final currentState = state as ContactsLoaded;
      final incoming = await repository.getIncomingRequests();
      final outgoing = await repository.getOutgoingRequests();
      emit(currentState.copyWith(
        incomingRequests: incoming,
        outgoingRequests: outgoing,
      ));
    }
  }

  Future<void> _onAcceptContactRequest(AcceptContactRequestEvent event, Emitter<ContactsState> emit) async {
    await repository.acceptContactRequest(event.requestId);
    add(const LoadContacts());
  }

  Future<void> _onRejectContactRequest(RejectContactRequestEvent event, Emitter<ContactsState> emit) async {
    await repository.rejectContactRequest(event.requestId);
    add(const LoadContacts());
  }

  void _emitCategorizedContacts(
    Emitter<ContactsState> emit,
    List<Contact> contacts, {
    required String searchQuery,
    List<ContactRequest> incomingRequests = const [],
    List<ContactRequest> outgoingRequests = const [],
  }) {
    // Sort alphabetically by displayName
    final sorted = List<Contact>.from(contacts)
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    final activeContacts = sorted.where((c) => !c.isBlocked).toList();
    final favorites = activeContacts.where((c) => c.isFavorite).toList();
    final miighoContacts = activeContacts.where((c) => c.isMiighoUser).toList();
    final nonMiighoContacts = activeContacts.where((c) => !c.isMiighoUser).toList();

    List<Contact> searchResults = activeContacts;
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      final qNorm = q.replaceAll('+', '').replaceAll(' ', '');
      searchResults = activeContacts.where((c) {
        final phoneNorm = c.phoneNumber.replaceAll('+', '').replaceAll(' ', '');
        return c.displayName.toLowerCase().contains(q) ||
            c.phoneNumber.contains(q) ||
            (qNorm.isNotEmpty && phoneNorm.contains(qNorm));
      }).toList();
    }

    emit(ContactsLoaded(
      allContacts: activeContacts,
      favorites: favorites,
      miighoContacts: miighoContacts,
      nonMiighoContacts: nonMiighoContacts,
      searchResults: searchResults,
      incomingRequests: incomingRequests,
      outgoingRequests: outgoingRequests,
      searchQuery: searchQuery,
      isSyncing: false,
    ));
  }
}
