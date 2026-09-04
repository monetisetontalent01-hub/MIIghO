package contact

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
)

type ContactService struct {
	repo ContactRepository
}

func NewContactService(repo ContactRepository) *ContactService {
	return &ContactService{repo: repo}
}

func (s *ContactService) SyncContacts(ctx context.Context, ownerID uuid.UUID, phones []string) (*SyncContactsResponse, error) {
	matches, err := s.repo.BatchFindUsersByPhone(ctx, phones)
	if err != nil {
		return nil, err
	}

	for _, match := range matches {
		c := &Contact{
			OwnerID:   ownerID,
			UserID:    match.UserID,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		}
		_ = s.repo.UpsertContact(ctx, c)
	}

	return &SyncContactsResponse{MatchedContacts: matches}, nil
}

func (s *ContactService) ListContacts(ctx context.Context, ownerID uuid.UUID) ([]*Contact, error) {
	return s.repo.ListContacts(ctx, ownerID)
}

func (s *ContactService) ListContactUsers(ctx context.Context, ownerID uuid.UUID) ([]ContactUser, error) {
	return s.repo.ListContactUsers(ctx, ownerID)
}

func (s *ContactService) SearchUsers(ctx context.Context, currentUserID uuid.UUID, query string) ([]ContactUser, error) {
	return s.repo.SearchUsers(ctx, currentUserID, query)
}

func (s *ContactService) BlockUser(ctx context.Context, ownerID, userID uuid.UUID) error {
	return s.repo.UpdateContactStatus(ctx, ownerID, userID, true, false)
}

func (s *ContactService) UnblockUser(ctx context.Context, ownerID, userID uuid.UUID) error {
	return s.repo.UpdateContactStatus(ctx, ownerID, userID, false, false)
}

func (s *ContactService) FavoriteUser(ctx context.Context, ownerID, userID uuid.UUID) error {
	return s.repo.UpdateContactStatus(ctx, ownerID, userID, false, true)
}

// ---- Contact Request business rules ----

// SendContactRequest creates a contact request with business rule validations.
func (s *ContactService) SendContactRequest(ctx context.Context, senderID, recipientID uuid.UUID) (*ContactRequest, error) {
	// Rule: cannot send request to yourself
	if senderID == recipientID {
		return nil, errors.New("cannot send a contact request to yourself")
	}

	// Rule: check if already contacts (idempotent — already accepted)
	areContacts, err := s.repo.AreContacts(ctx, senderID, recipientID)
	if err != nil {
		return nil, err
	}
	if areContacts {
		return nil, errors.New("already contacts")
	}

	// Rule: check for reciprocal pending request → auto-accept
	relStatus, err := s.repo.GetRelationshipStatus(ctx, senderID, recipientID)
	if err != nil {
		return nil, err
	}
	if relStatus == RelPendingReceived {
		// The other user already sent us a request — auto-accept it
		requests, err := s.repo.GetContactRequests(ctx, senderID, "incoming")
		if err != nil {
			return nil, err
		}
		for _, req := range requests {
			if req.SenderID == recipientID {
				if err := s.repo.AcceptContactRequest(ctx, req.ID, senderID); err != nil {
					return nil, err
				}
				// Return the accepted request
				accepted, _ := s.repo.GetContactRequest(ctx, req.ID)
				return accepted, nil
			}
		}
	}

	// Create the request
	return s.repo.CreateContactRequest(ctx, senderID, recipientID)
}

// GetContactRequests returns pending requests for a user.
func (s *ContactService) GetContactRequests(ctx context.Context, userID uuid.UUID, direction string) ([]ContactRequest, error) {
	if direction != "incoming" && direction != "outgoing" {
		direction = "incoming"
	}
	return s.repo.GetContactRequests(ctx, userID, direction)
}

// AcceptContactRequest accepts a pending contact request.
func (s *ContactService) AcceptContactRequest(ctx context.Context, requestID, recipientID uuid.UUID) error {
	return s.repo.AcceptContactRequest(ctx, requestID, recipientID)
}

// RejectContactRequest rejects a pending contact request.
func (s *ContactService) RejectContactRequest(ctx context.Context, requestID, recipientID uuid.UUID) error {
	return s.repo.RejectContactRequest(ctx, requestID, recipientID)
}

// AreContacts checks if two users are mutual contacts (authorized to chat).
func (s *ContactService) AreContacts(ctx context.Context, userA, userB uuid.UUID) (bool, error) {
	return s.repo.AreContacts(ctx, userA, userB)
}
