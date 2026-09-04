package contact

import (
	"time"

	"github.com/google/uuid"
)

// ContactRequestStatus represents the state of a contact request.
type ContactRequestStatus string

const (
	StatusPending  ContactRequestStatus = "pending"
	StatusAccepted ContactRequestStatus = "accepted"
	StatusRejected ContactRequestStatus = "rejected"
)

// RelationshipStatus describes the relationship between the current user and another user.
type RelationshipStatus string

const (
	RelNone            RelationshipStatus = "none"
	RelPendingSent     RelationshipStatus = "pending_sent"
	RelPendingReceived RelationshipStatus = "pending_received"
	RelAccepted        RelationshipStatus = "accepted"
	RelRejected        RelationshipStatus = "rejected"
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

type ContactRequest struct {
	ID          uuid.UUID            `json:"id"`
	SenderID    uuid.UUID            `json:"sender_id"`
	RecipientID uuid.UUID            `json:"recipient_id"`
	Status      ContactRequestStatus `json:"status"`
	CreatedAt   time.Time            `json:"created_at"`
	UpdatedAt   time.Time            `json:"updated_at"`
	// Enriched fields (populated by queries, not stored in contact_requests)
	SenderName    string  `json:"sender_name,omitempty"`
	RecipientName string  `json:"recipient_name,omitempty"`
	SenderAvatar  *string `json:"sender_avatar,omitempty"`
}

type SyncContactsRequest struct {
	PhoneNumbers []string `json:"phone_numbers"`
}

type SyncContactsResponse struct {
	MatchedContacts []MatchedContact `json:"matched_contacts"`
}

type ContactUser struct {
	ID                 uuid.UUID          `json:"id"`
	PhoneNumber        string             `json:"phone_number"`
	DisplayName        string             `json:"display_name"`
	AvatarURL          *string            `json:"avatar_url,omitempty"`
	StatusMessage      *string            `json:"status_message,omitempty"`
	MiighoID           string             `json:"miigho_id,omitempty"`
	RelationshipStatus RelationshipStatus `json:"relationship_status,omitempty"`
	IsMiighoUser       bool               `json:"is_miigho_user"`
	IsFavorite         bool               `json:"is_favorite"`
	IsBlocked          bool               `json:"is_blocked"`
}

type MatchedContact struct {
	PhoneNumber string    `json:"phone_number"`
	UserID      uuid.UUID `json:"user_id"`
}
