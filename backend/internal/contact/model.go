package contact

import (
	"time"

	"github.com/google/uuid"
)

type Contact struct {
	OwnerID   uuid.UUID `json:"owner_id"`
	UserID    uuid.UUID `json:"user_id"`
	Alias     string    `json:"alias"` // Optional custom name
	IsBlocked bool      `json:"is_blocked"`
	IsFav     bool      `json:"is_favorite"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type SyncContactsRequest struct {
	PhoneNumbers []string `json:"phone_numbers"`
}

type SyncContactsResponse struct {
	MatchedContacts []MatchedContact `json:"matched_contacts"`
}

type ContactUser struct {
	ID            uuid.UUID `json:"id"`
	PhoneNumber   string    `json:"phone_number"`
	DisplayName   string    `json:"display_name"`
	AvatarURL     *string   `json:"avatar_url,omitempty"`
	StatusMessage *string   `json:"status_message,omitempty"`
	IsMiighoUser  bool      `json:"is_miigho_user"`
	IsFavorite    bool      `json:"is_favorite"`
	IsBlocked     bool      `json:"is_blocked"`
}

type MatchedContact struct {
	PhoneNumber string    `json:"phone_number"`
	UserID      uuid.UUID `json:"user_id"`
}

