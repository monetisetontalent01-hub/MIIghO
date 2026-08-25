package chat

import (
	"time"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/platform/encryption"
)

type ConversationType string

const (
	TypeDirect ConversationType = "direct"
	TypeGroup  ConversationType = "group"
)

type MessageType string

const (
	MsgText   MessageType = "text"
	MsgImage  MessageType = "image"
	MsgVideo  MessageType = "video"
	MsgAudio  MessageType = "audio"
	MsgVoice  MessageType = "voice"
	MsgFile   MessageType = "file"
	MsgSystem MessageType = "system"
)

type MessageStatus string

const (
	StatusSent      MessageStatus = "sent"
	StatusDelivered MessageStatus = "delivered"
	StatusRead      MessageStatus = "read"
)

// Conversation represents a chat thread (direct or group).
type Conversation struct {
	ID        uuid.UUID        `json:"id"`
	Type      ConversationType `json:"type"`
	Name      *string          `json:"name"`
	AvatarURL *string          `json:"avatar_url"`
	CreatedBy uuid.UUID        `json:"created_by"`
	CreatedAt time.Time        `json:"created_at"`
	UpdatedAt time.Time        `json:"updated_at"`
}

// ConversationMember represents a participant in a conversation.
type ConversationMember struct {
	ConversationID uuid.UUID `json:"conversation_id"`
	UserID         uuid.UUID `json:"user_id"`
	Role           string    `json:"role"`
	JoinedAt       time.Time `json:"joined_at"`
}

// Message represents a chat message.
type Message struct {
	ID                 uuid.UUID                      `json:"id"`
	ConversationID     uuid.UUID                      `json:"conversation_id"`
	SenderID           uuid.UUID                      `json:"sender_id"`
	ReplyToID          *uuid.UUID                     `json:"reply_to_id"`
	Type               MessageType                    `json:"type"`
	Content            []byte                         `json:"content"` // Encrypted content
	Metadata           map[string]interface{}         `json:"metadata"`
	EncryptionMetadata *encryption.EncryptionMetadata `json:"encryption_metadata"`
	Status             MessageStatus                  `json:"status"`
	EditedAt           *time.Time                     `json:"edited_at"`
	UpdatedAt          time.Time                      `json:"updated_at"`
	DeletedAt          *time.Time                     `json:"deleted_at"`
	CreatedAt          time.Time                      `json:"created_at"`
}

// MessageReaction represents an emoji reaction.
type MessageReaction struct {
	MessageID uuid.UUID `json:"message_id"`
	UserID    uuid.UUID `json:"user_id"`
	Emoji     string    `json:"emoji"`
	CreatedAt time.Time `json:"created_at"`
}

// ConversationWithLastMessage is a DTO for inbox view.
type ConversationWithLastMessage struct {
	Conversation
	LastMessage *Message `json:"last_message"`
	UnreadCount int      `json:"unread_count"`
}
