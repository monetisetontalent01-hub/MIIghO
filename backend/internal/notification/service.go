package notification

import (
	"context"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
)

// NotificationService defines operations for sending push notifications.
type NotificationService interface {
	SendPush(ctx context.Context, userID uuid.UUID, title, body string, data map[string]string) error
	SendToConversation(ctx context.Context, conversationID, excludeUserID uuid.UUID, title, body string, data map[string]string) error
}

// FCMNotificationService is an implementation using Firebase Admin SDK (mocked for MVP).
type FCMNotificationService struct{}

func NewFCMNotificationService() *FCMNotificationService {
	return &FCMNotificationService{}
}

func (s *FCMNotificationService) SendPush(ctx context.Context, userID uuid.UUID, title, body string, data map[string]string) error {
	// For MVP: log-based implementation
	log.Info().
		Str("user_id", userID.String()).
		Str("title", title).
		Str("body", body).
		Interface("data", data).
		Msg("Sent push notification")
	return nil
}

func (s *FCMNotificationService) SendToConversation(ctx context.Context, conversationID, excludeUserID uuid.UUID, title, body string, data map[string]string) error {
	log.Info().
		Str("conversation_id", conversationID.String()).
		Str("exclude_user", excludeUserID.String()).
		Str("title", title).
		Msg("Sent push notification to conversation")
	return nil
}
