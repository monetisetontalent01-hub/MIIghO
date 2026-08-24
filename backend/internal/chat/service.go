package chat

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/platform/encryption"
	"github.com/miigho/miigho/internal/platform/events"
)

type ChatService struct {
	repo         ChatRepository
	eventBus     events.EventBus
	encryption   encryption.EncryptionService
}

func NewChatService(repo ChatRepository, eb events.EventBus, enc encryption.EncryptionService) *ChatService {
	return &ChatService{
		repo:       repo,
		eventBus:   eb,
		encryption: enc,
	}
}

func (s *ChatService) SendMessage(ctx context.Context, convID, senderID uuid.UUID, content []byte, msgType MessageType) (*Message, error) {
	// Encrypt
	ciphertext, meta, err := s.encryption.Encrypt(content, uuid.Nil) // MVP ignores recipientID
	if err != nil {
		return nil, err
	}

	msg := &Message{
		ID:                 uuid.New(),
		ConversationID:     convID,
		SenderID:           senderID,
		Type:               msgType,
		Content:            ciphertext,
		EncryptionMetadata: meta,
		Status:             StatusSent,
		CreatedAt:          time.Now(),
	}

	if err := s.repo.CreateMessage(ctx, msg); err != nil {
		return nil, err
	}

	// Publish domain event
	ev := events.MessageSent{
		MessageID:      msg.ID.String(),
		ConversationID: convID.String(),
		SenderID:       senderID.String(),
	}
	_ = s.eventBus.Publish(ctx, ev)

	return msg, nil
}

func (s *ChatService) MarkDelivered(ctx context.Context, msgID, userID uuid.UUID) error {
	ev := events.MessageDelivered{
		MessageID: msgID.String(),
		UserID:    userID.String(),
	}
	return s.eventBus.Publish(ctx, ev)
}

func (s *ChatService) MarkRead(ctx context.Context, convID, userID, msgID uuid.UUID) error {
	if err := s.repo.MarkAsRead(ctx, convID, userID, msgID); err != nil {
		return err
	}
	ev := events.MessageRead{
		MessageID: msgID.String(),
		UserID:    userID.String(),
	}
	return s.eventBus.Publish(ctx, ev)
}
