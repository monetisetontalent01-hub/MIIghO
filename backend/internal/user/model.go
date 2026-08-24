package user

import (
	"time"

	"github.com/google/uuid"
)

// UserProfile represents the public/private profile of a user.
type UserProfile struct {
	ID            uuid.UUID  `json:"id"`
	PhoneNumber   string     `json:"phone_number"`
	FirstName     string     `json:"first_name"`
	LastName      string     `json:"last_name"`
	AvatarURL     string     `json:"avatar_url"`
	StatusMessage string     `json:"status_message"`
	Language      string     `json:"language"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
	DeletedAt     *time.Time `json:"deleted_at,omitempty"`
}

// UpdateProfileRequest defines the fields that can be updated.
type UpdateProfileRequest struct {
	FirstName     *string `json:"first_name"`
	LastName      *string `json:"last_name"`
	StatusMessage *string `json:"status_message"`
	Language      *string `json:"language"`
}

// UserPresence represents the real-time presence of a user.
type UserPresence struct {
	UserID     uuid.UUID `json:"user_id"`
	Status     string    `json:"status"`
	LastSeenAt time.Time `json:"last_seen_at"`
}
