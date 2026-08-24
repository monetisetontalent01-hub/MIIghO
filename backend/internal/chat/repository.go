package chat

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ChatRepository defines operations on chat entities.
type ChatRepository interface {
	ListConversations(ctx context.Context, userID uuid.UUID, cursor string, limit int) ([]*ConversationWithLastMessage, string, error)
	GetConversation(ctx context.Context, id uuid.UUID) (*Conversation, error)
	CreateDirectConversation(ctx context.Context, userA, userB uuid.UUID) (*Conversation, error)
	GetMessages(ctx context.Context, conversationID uuid.UUID, cursor string, limit int) ([]*Message, string, error)
	CreateMessage(ctx context.Context, msg *Message) error
	UpdateMessage(ctx context.Context, msg *Message) error
	DeleteMessage(ctx context.Context, id uuid.UUID) error
	AddReaction(ctx context.Context, reaction *MessageReaction) error
	RemoveReaction(ctx context.Context, messageID, userID uuid.UUID) error
	MarkAsRead(ctx context.Context, conversationID, userID, messageID uuid.UUID) error
}

// PostgresChatRepository implements ChatRepository.
type PostgresChatRepository struct {
	pool *pgxpool.Pool
}

func NewPostgresChatRepository(pool *pgxpool.Pool) *PostgresChatRepository {
	return &PostgresChatRepository{pool: pool}
}

func (r *PostgresChatRepository) ListConversations(ctx context.Context, userID uuid.UUID, cursor string, limit int) ([]*ConversationWithLastMessage, string, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	query := `
		SELECT c.id, c.type, c.name, c.avatar_url, c.created_at, c.updated_at
		FROM conversations c
		INNER JOIN conversation_members cm ON cm.conversation_id = c.id
		WHERE cm.user_id = $1
		ORDER BY c.updated_at DESC
		LIMIT $2
	`
	rows, err := r.pool.Query(ctx, query, userID, limit)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	var result []*ConversationWithLastMessage
	for rows.Next() {
		var conv Conversation
		if err := rows.Scan(&conv.ID, &conv.Type, &conv.Name, &conv.AvatarURL, &conv.CreatedAt, &conv.UpdatedAt); err != nil {
			return nil, "", err
		}
		dto := &ConversationWithLastMessage{
			Conversation: conv,
			UnreadCount:  0,
		}
		result = append(result, dto)
	}

	return result, "", nil
}

func (r *PostgresChatRepository) GetConversation(ctx context.Context, id uuid.UUID) (*Conversation, error) {
	var conv Conversation
	query := "SELECT id, type, name, avatar_url, created_at, updated_at FROM conversations WHERE id = $1"
	err := r.pool.QueryRow(ctx, query, id).Scan(&conv.ID, &conv.Type, &conv.Name, &conv.AvatarURL, &conv.CreatedAt, &conv.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &conv, nil
}

func (r *PostgresChatRepository) CreateDirectConversation(ctx context.Context, userA, userB uuid.UUID) (*Conversation, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	convID := uuid.New()
	now := time.Now()

	_, err = tx.Exec(ctx, "INSERT INTO conversations (id, type, created_at, updated_at) VALUES ($1, $2, $3, $4)",
		convID, string(TypeDirect), now, now)
	if err != nil {
		return nil, err
	}

	_, err = tx.Exec(ctx, "INSERT INTO conversation_members (conversation_id, user_id, role, joined_at) VALUES ($1, $2, 'member', $3), ($1, $4, 'member', $3)",
		convID, userA, now, userB)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}

	return &Conversation{
		ID:        convID,
		Type:      TypeDirect,
		CreatedAt: now,
		UpdatedAt: now,
	}, nil
}

func (r *PostgresChatRepository) GetMessages(ctx context.Context, conversationID uuid.UUID, cursor string, limit int) ([]*Message, string, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	query := `
		SELECT id, conversation_id, sender_id, type, COALESCE(content, ''), reply_to, created_at, updated_at, deleted_at
		FROM messages
		WHERE conversation_id = $1 AND deleted_at IS NULL
		ORDER BY created_at DESC
		LIMIT $2
	`
	rows, err := r.pool.Query(ctx, query, conversationID, limit)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	var messages []*Message
	for rows.Next() {
		var m Message
		var contentStr string
		if err := rows.Scan(&m.ID, &m.ConversationID, &m.SenderID, &m.Type, &contentStr, &m.ReplyToID, &m.CreatedAt, &m.UpdatedAt, &m.DeletedAt); err != nil {
			return nil, "", err
		}
		m.Content = []byte(contentStr)
		m.Status = StatusSent
		messages = append(messages, &m)
	}

	return messages, "", nil
}

func (r *PostgresChatRepository) CreateMessage(ctx context.Context, msg *Message) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	query := `
		INSERT INTO messages (id, conversation_id, sender_id, type, content, reply_to, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`
	_, err = tx.Exec(ctx, query, msg.ID, msg.ConversationID, msg.SenderID, string(msg.Type), string(msg.Content), msg.ReplyToID, msg.CreatedAt, msg.CreatedAt)
	if err != nil {
		return err
	}

	// Update conversation's updated_at
	_, err = tx.Exec(ctx, "UPDATE conversations SET updated_at = $1 WHERE id = $2", msg.CreatedAt, msg.ConversationID)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}

func (r *PostgresChatRepository) UpdateMessage(ctx context.Context, msg *Message) error {
	query := "UPDATE messages SET content = $1, updated_at = $2 WHERE id = $3 AND created_at = $4"
	_, err := r.pool.Exec(ctx, query, string(msg.Content), time.Now(), msg.ID, msg.CreatedAt)
	return err
}

func (r *PostgresChatRepository) DeleteMessage(ctx context.Context, id uuid.UUID) error {
	query := "UPDATE messages SET deleted_at = $1 WHERE id = $2"
	_, err := r.pool.Exec(ctx, query, time.Now(), id)
	return err
}

func (r *PostgresChatRepository) AddReaction(ctx context.Context, reaction *MessageReaction) error {
	query := `
		INSERT INTO message_reactions (message_id, message_created_at, user_id, emoji, created_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT DO NOTHING
	`
	_, err := r.pool.Exec(ctx, query, reaction.MessageID, reaction.CreatedAt, reaction.UserID, reaction.Emoji, reaction.CreatedAt)
	return err
}

func (r *PostgresChatRepository) RemoveReaction(ctx context.Context, messageID, userID uuid.UUID) error {
	query := "DELETE FROM message_reactions WHERE message_id = $1 AND user_id = $2"
	_, err := r.pool.Exec(ctx, query, messageID, userID)
	return err
}

func (r *PostgresChatRepository) MarkAsRead(ctx context.Context, conversationID, userID, messageID uuid.UUID) error {
	now := time.Now()
	query := `
		INSERT INTO read_receipts (message_id, message_created_at, user_id, read_at)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT DO NOTHING
	`
	_, err := r.pool.Exec(ctx, query, messageID, now, userID, now)
	return err
}
