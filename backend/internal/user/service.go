package user

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/pkg/cache"
)

// UserService provides business logic for user management.
type UserService struct {
	repo   UserRepository
	valkey *cache.ValkeyClient
}

func NewUserService(repo UserRepository, valkey *cache.ValkeyClient) *UserService {
	return &UserService{repo: repo, valkey: valkey}
}

func (s *UserService) GetProfile(ctx context.Context, id uuid.UUID) (*UserProfile, error) {
	profile, err := s.repo.GetProfile(ctx, id)
	if err != nil {
		return nil, err
	}
	if profile == nil {
		return nil, common.ErrNotFound
	}
	return profile, nil
}

func (s *UserService) UpdateProfile(ctx context.Context, id uuid.UUID, req *UpdateProfileRequest) (*UserProfile, error) {
	profile, err := s.GetProfile(ctx, id)
	if err != nil {
		return nil, err
	}

	if req.FirstName != nil {
		profile.FirstName = *req.FirstName
	}
	if req.LastName != nil {
		profile.LastName = *req.LastName
	}
	if req.StatusMessage != nil {
		profile.StatusMessage = *req.StatusMessage
	}
	if req.Language != nil {
		profile.Language = *req.Language
	}

	if err := s.repo.UpdateProfile(ctx, profile); err != nil {
		return nil, err
	}

	return profile, nil
}

func (s *UserService) UpdateAvatar(ctx context.Context, id uuid.UUID, avatarURL string) error {
	return s.repo.UpdateAvatar(ctx, id, avatarURL)
}

func (s *UserService) GetPresence(ctx context.Context, userID uuid.UUID) (*UserPresence, error) {
	status, _ := s.valkey.GetPresence(ctx, userID.String())
	if status == "" {
		status = "offline"
	}
	return &UserPresence{
		UserID:     userID,
		Status:     status,
		LastSeenAt: time.Now(),
	}, nil
}

func (s *UserService) SetPresence(ctx context.Context, userID uuid.UUID, status string) error {
	return s.valkey.SetPresence(ctx, userID.String(), status, 5*time.Minute)
}

func (s *UserService) SearchByPhone(ctx context.Context, phone string) (*UserProfile, error) {
	profile, err := s.repo.SearchByPhone(ctx, phone)
	if err != nil {
		return nil, err
	}
	if profile == nil {
		return nil, common.ErrNotFound
	}
	return profile, nil
}
