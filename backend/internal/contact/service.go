package contact

import (
	"context"
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
	return s.repo.UpdateContactStatus(ctx, ownerID, userID, false, false) // Note: isFav state lost in this simple stub
}

func (s *ContactService) FavoriteUser(ctx context.Context, ownerID, userID uuid.UUID) error {
	return s.repo.UpdateContactStatus(ctx, ownerID, userID, false, true)
}
