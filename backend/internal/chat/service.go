package chat

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/internal/platform/encryption"
	"github.com/miigho/miigho/internal/platform/events"
)

type ChatService struct {
	repo       ChatRepository
	eventBus   events.EventBus
	encryption encryption.EncryptionService
	hub        *Hub
}

func NewChatService(repo ChatRepository, eb events.EventBus, enc encryption.EncryptionService) *ChatService {
	return &ChatService{
		repo:       repo,
		eventBus:   eb,
		encryption: enc,
	}
}

func (s *ChatService) SetHub(hub *Hub) {
	s.hub = hub
}

func (s *ChatService) IsMember(ctx context.Context, convID, userID uuid.UUID) (bool, error) {
	return s.repo.IsMember(ctx, convID, userID)
}

func (s *ChatService) GetConversation(ctx context.Context, convID, userID uuid.UUID) (*Conversation, error) {
	isMember, err := s.repo.IsMember(ctx, convID, userID)
	if err != nil {
		return nil, err
	}
	if !isMember {
		return nil, common.ErrForbidden
	}
	return s.repo.GetConversation(ctx, convID)
}

func (s *ChatService) CreateDirectConversation(ctx context.Context, userA, userB uuid.UUID) (*Conversation, error) {
	conv, err := s.repo.CreateDirectConversation(ctx, userA, userB)
	if err != nil {
		return nil, err
	}
	ev := events.ConversationCreated{
		ConversationID: conv.ID.String(),
	}
	_ = s.eventBus.Publish(ctx, ev)
	s.broadcastToConversation(ctx, conv.ID, "conversation.created", conv)
	return conv, nil
}

func (s *ChatService) CreateGroupConversation(ctx context.Context, creatorID uuid.UUID, name string, memberIDs []uuid.UUID) (*Conversation, error) {
	conv, err := s.repo.CreateGroupConversation(ctx, creatorID, name, memberIDs)
	if err != nil {
		return nil, err
	}
	ev := events.GroupCreated{
		GroupID: conv.ID.String(),
	}
	_ = s.eventBus.Publish(ctx, ev)
	s.broadcastToConversation(ctx, conv.ID, "group.created", conv)
	return conv, nil
}

func (s *ChatService) SendMessage(ctx context.Context, convID, senderID uuid.UUID, content []byte, msgType MessageType, replyToID *uuid.UUID, metadata map[string]interface{}) (*Message, error) {
	if len(content) == 0 && msgType == MsgText {
		return nil, errors.New("content cannot be empty")
	}

	// Verify sender is member of conversation (IDOR prevention)
	isMember, err := s.repo.IsMember(ctx, convID, senderID)
	if err != nil {
		return nil, err
	}
	if !isMember {
		return nil, common.ErrForbidden
	}

	// Encrypt
	ciphertext, meta, err := s.encryption.Encrypt(content, uuid.Nil)
	if err != nil {
		return nil, err
	}

	now := time.Now()
	msg := &Message{
		ID:                 uuid.New(),
		ConversationID:     convID,
		SenderID:           senderID,
		ReplyToID:          replyToID,
		Type:               msgType,
		Content:            ciphertext,
		Metadata:           metadata,
		EncryptionMetadata: meta,
		Status:             StatusSent,
		CreatedAt:          now,
		UpdatedAt:          now,
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

	// Broadcast via WebSocket Hub
	s.broadcastToConversation(ctx, convID, "message.sent", msg)

	return msg, nil
}

func (s *ChatService) EditMessage(ctx context.Context, msgID, userID uuid.UUID, newContent []byte) (*Message, error) {
	if len(newContent) == 0 {
		return nil, errors.New("content cannot be empty")
	}

	msg, err := s.repo.GetMessage(ctx, msgID)
	if err != nil {
		return nil, err
	}
	if msg.DeletedAt != nil {
		return nil, errors.New("cannot edit deleted message")
	}

	// Authorization: only sender can edit their message
	if msg.SenderID != userID {
		return nil, common.ErrForbidden
	}

	msg.Content = newContent
	now := time.Now()
	msg.EditedAt = &now
	msg.UpdatedAt = now

	if err := s.repo.UpdateMessage(ctx, msg); err != nil {
		return nil, err
	}

	ev := events.MessageUpdated{
		MessageID:      msgID.String(),
		ConversationID: msg.ConversationID.String(),
		SenderID:       userID.String(),
		Content:        string(newContent),
		EditedAt:       now.Format(time.RFC3339),
	}
	_ = s.eventBus.Publish(ctx, ev)

	s.broadcastToConversation(ctx, msg.ConversationID, "message.updated", msg)

	return msg, nil
}

func (s *ChatService) DeleteMessage(ctx context.Context, msgID, userID uuid.UUID) error {
	msg, err := s.repo.GetMessage(ctx, msgID)
	if err != nil {
		return err
	}

	// Authorization: only sender can delete their message
	if msg.SenderID != userID {
		return common.ErrForbidden
	}

	if err := s.repo.DeleteMessage(ctx, msgID); err != nil {
		return err
	}

	now := time.Now()
	ev := events.MessageDeleted{
		MessageID:      msgID.String(),
		ConversationID: msg.ConversationID.String(),
		SenderID:       userID.String(),
		DeletedAt:      now.Format(time.RFC3339),
	}
	_ = s.eventBus.Publish(ctx, ev)

	s.broadcastToConversation(ctx, msg.ConversationID, "message.deleted", map[string]string{
		"message_id":      msgID.String(),
		"conversation_id": msg.ConversationID.String(),
	})

	return nil
}

func (s *ChatService) AddReaction(ctx context.Context, msgID, userID uuid.UUID, emoji string) error {
	msg, err := s.repo.GetMessage(ctx, msgID)
	if err != nil {
		return err
	}

	// Check user is member of conversation
	isMember, err := s.repo.IsMember(ctx, msg.ConversationID, userID)
	if err != nil {
		return err
	}
	if !isMember {
		return common.ErrForbidden
	}

	reaction := &MessageReaction{
		MessageID: msgID,
		UserID:    userID,
		Emoji:     emoji,
		CreatedAt: time.Now(),
	}

	if err := s.repo.AddReaction(ctx, reaction); err != nil {
		return err
	}

	ev := events.ReactionAdded{
		MessageID:      msgID.String(),
		ConversationID: msg.ConversationID.String(),
		UserID:         userID.String(),
		Emoji:          emoji,
	}
	_ = s.eventBus.Publish(ctx, ev)

	s.broadcastToConversation(ctx, msg.ConversationID, "reaction.added", reaction)

	return nil
}

func (s *ChatService) RemoveReaction(ctx context.Context, msgID, userID uuid.UUID, emoji string) error {
	msg, err := s.repo.GetMessage(ctx, msgID)
	if err != nil {
		return err
	}

	isMember, err := s.repo.IsMember(ctx, msg.ConversationID, userID)
	if err != nil {
		return err
	}
	if !isMember {
		return common.ErrForbidden
	}

	if err := s.repo.RemoveReaction(ctx, msgID, userID); err != nil {
		return err
	}

	ev := events.ReactionRemoved{
		MessageID:      msgID.String(),
		ConversationID: msg.ConversationID.String(),
		UserID:         userID.String(),
		Emoji:          emoji,
	}
	_ = s.eventBus.Publish(ctx, ev)

	s.broadcastToConversation(ctx, msg.ConversationID, "reaction.removed", map[string]string{
		"message_id": msgID.String(),
		"user_id":    userID.String(),
		"emoji":      emoji,
	})

	return nil
}

func (s *ChatService) MarkDelivered(ctx context.Context, msgID, userID uuid.UUID) error {
	ev := events.MessageDelivered{
		MessageID: msgID.String(),
		UserID:    userID.String(),
	}
	return s.eventBus.Publish(ctx, ev)
}

func (s *ChatService) MarkRead(ctx context.Context, convID, userID, msgID uuid.UUID) error {
	// IDOR check: verify user is member of conversation
	isMember, err := s.repo.IsMember(ctx, convID, userID)
	if err != nil {
		return err
	}
	if !isMember {
		return common.ErrForbidden
	}

	if err := s.repo.MarkAsRead(ctx, convID, userID, msgID); err != nil {
		return err
	}
	ev := events.MessageRead{
		MessageID: msgID.String(),
		UserID:    userID.String(),
	}
	_ = s.eventBus.Publish(ctx, ev)

	s.broadcastToConversation(ctx, convID, "message.read", map[string]string{
		"message_id":      msgID.String(),
		"conversation_id": convID.String(),
		"user_id":         userID.String(),
	})

	return nil
}

func (s *ChatService) broadcastToConversation(ctx context.Context, convID uuid.UUID, eventType string, data interface{}) {
	if s.hub == nil {
		return
	}

	members, err := s.repo.GetConversationMembers(ctx, convID)
	if err != nil || len(members) == 0 {
		return
	}

	envelope := WsEnvelope{
		Type:           eventType,
		ConversationID: convID.String(),
		Data:           data,
		Timestamp:      time.Now(),
	}

	payload, err := json.Marshal(envelope)
	if err != nil {
		return
	}

	s.hub.BroadcastToUsers(members, payload)
}
