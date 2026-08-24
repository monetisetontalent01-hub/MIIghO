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

type MatchedContact struct {
	PhoneNumber string    `json:"phone_number"`
	UserID      uuid.UUID `json:"user_id"`
}
