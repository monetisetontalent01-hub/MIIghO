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
	IsMember(ctx context.Context, conversationID, userID uuid.UUID) (bool, error)
	GetConversationMembers(ctx context.Context, conversationID uuid.UUID) ([]uuid.UUID, error)
	CreateDirectConversation(ctx context.Context, userA, userB uuid.UUID) (*Conversation, error)
	CreateGroupConversation(ctx context.Context, creatorID uuid.UUID, name string, memberIDs []uuid.UUID) (*Conversation, error)
	GetMessages(ctx context.Context, conversationID uuid.UUID, cursor string, limit int) ([]*Message, string, error)
	GetMessage(ctx context.Context, messageID uuid.UUID) (*Message, error)
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

func (r *PostgresChatRepository) IsMember(ctx context.Context, conversationID, userID uuid.UUID) (bool, error) {
	var exists bool
	query := "SELECT EXISTS(SELECT 1 FROM conversation_members WHERE conversation_id = $1 AND user_id = $2)"
	err := r.pool.QueryRow(ctx, query, conversationID, userID).Scan(&exists)
	return exists, err
}

func (r *PostgresChatRepository) GetConversationMembers(ctx context.Context, conversationID uuid.UUID) ([]uuid.UUID, error) {
	query := "SELECT user_id FROM conversation_members WHERE conversation_id = $1"
	rows, err := r.pool.Query(ctx, query, conversationID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []uuid.UUID
	for rows.Next() {
		var uid uuid.UUID
		if err := rows.Scan(&uid); err != nil {
			return nil, err
		}
		members = append(members, uid)
	}
	return members, nil
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

		// Fetch last message for each conversation
		var lastMsg *Message
		lastMsgQuery := `
			SELECT id, conversation_id, sender_id, type, COALESCE(content, ''), reply_to, created_at, updated_at, deleted_at
			FROM messages
			WHERE conversation_id = $1 AND deleted_at IS NULL
			ORDER BY created_at DESC
			LIMIT 1
		`
		var m Message
		var contentStr string
		err := r.pool.QueryRow(ctx, lastMsgQuery, conv.ID).Scan(
			&m.ID, &m.ConversationID, &m.SenderID, &m.Type, &contentStr, &m.ReplyToID, &m.CreatedAt, &m.UpdatedAt, &m.DeletedAt,
		)
		if err == nil {
			m.Content = []byte(contentStr)
			m.Status = StatusSent
			lastMsg = &m
		}

		// Calculate unread count (messages not sent by user and not read by user)
		var unreadCount int
		unreadQuery := `
			SELECT COUNT(*)
			FROM messages m
			WHERE m.conversation_id = $1
			  AND m.sender_id != $2
			  AND m.deleted_at IS NULL
			  AND NOT EXISTS (
			      SELECT 1 FROM read_receipts rr
			      WHERE rr.message_id = m.id AND rr.user_id = $2
			  )
		`
		_ = r.pool.QueryRow(ctx, unreadQuery, conv.ID, userID).Scan(&unreadCount)

		dto := &ConversationWithLastMessage{
			Conversation: conv,
			LastMessage:  lastMsg,
			UnreadCount:  unreadCount,
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
	// Check for existing direct conversation between these users
	existingQuery := `
		SELECT c.id, c.type, c.name, c.avatar_url, c.created_at, c.updated_at
		FROM conversations c
		JOIN conversation_members cm1 ON cm1.conversation_id = c.id AND cm1.user_id = $1
		JOIN conversation_members cm2 ON cm2.conversation_id = c.id AND cm2.user_id = $2
		WHERE c.type = 'direct'
		LIMIT 1
	`
	var conv Conversation
	err := r.pool.QueryRow(ctx, existingQuery, userA, userB).Scan(&conv.ID, &conv.Type, &conv.Name, &conv.AvatarURL, &conv.CreatedAt, &conv.UpdatedAt)
	if err == nil {
		return &conv, nil
	}

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

func (r *PostgresChatRepository) CreateGroupConversation(ctx context.Context, creatorID uuid.UUID, name string, memberIDs []uuid.UUID) (*Conversation, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	convID := uuid.New()
	now := time.Now()

	_, err = tx.Exec(ctx, "INSERT INTO conversations (id, type, name, created_at, updated_at) VALUES ($1, $2, $3, $4, $5)",
		convID, string(TypeGroup), name, now, now)
	if err != nil {
		return nil, err
	}

	// Insert creator as admin
	_, err = tx.Exec(ctx, "INSERT INTO conversation_members (conversation_id, user_id, role, joined_at) VALUES ($1, $2, 'admin', $3)",
		convID, creatorID, now)
	if err != nil {
		return nil, err
	}

	// Insert other members
	for _, mID := range memberIDs {
		if mID == creatorID {
			continue
		}
		_, err = tx.Exec(ctx, "INSERT INTO conversation_members (conversation_id, user_id, role, joined_at) VALUES ($1, $2, 'member', $3) ON CONFLICT DO NOTHING",
			convID, mID, now)
		if err != nil {
			return nil, err
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}

	return &Conversation{
		ID:        convID,
		Type:      TypeGroup,
		Name:      &name,
		CreatedAt: now,
		UpdatedAt: now,
	}, nil
}

func (r *PostgresChatRepository) GetMessages(ctx context.Context, conversationID uuid.UUID, cursor string, limit int) ([]*Message, string, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	query := `
		SELECT m.id, m.conversation_id, m.sender_id, m.type, COALESCE(m.content, ''), m.reply_to, m.created_at, m.updated_at, m.deleted_at,
		       CASE WHEN EXISTS (SELECT 1 FROM read_receipts rr WHERE rr.message_id = m.id) THEN 'read' ELSE 'sent' END AS status
		FROM messages m
		WHERE m.conversation_id = $1 AND m.deleted_at IS NULL
		ORDER BY m.created_at DESC
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
		var statusStr string
		if err := rows.Scan(&m.ID, &m.ConversationID, &m.SenderID, &m.Type, &contentStr, &m.ReplyToID, &m.CreatedAt, &m.UpdatedAt, &m.DeletedAt, &statusStr); err != nil {
			return nil, "", err
		}
		m.Content = []byte(contentStr)
		m.Status = MessageStatus(statusStr)

		// Fetch reactions for this message
		reactQuery := "SELECT message_id, user_id, emoji, created_at FROM message_reactions WHERE message_id = $1"
		rRows, rErr := r.pool.Query(ctx, reactQuery, m.ID)
		if rErr == nil {
			for rRows.Next() {
				var react MessageReaction
				if scanErr := rRows.Scan(&react.MessageID, &react.UserID, &react.Emoji, &react.CreatedAt); scanErr == nil {
					m.Reactions = append(m.Reactions, react)
				}
			}
			rRows.Close()
		}

		messages = append(messages, &m)
	}

	return messages, "", nil
}

func (r *PostgresChatRepository) GetMessage(ctx context.Context, messageID uuid.UUID) (*Message, error) {
	query := `
		SELECT m.id, m.conversation_id, m.sender_id, m.type, COALESCE(m.content, ''), m.reply_to, m.created_at, m.updated_at, m.deleted_at,
		       CASE WHEN EXISTS (SELECT 1 FROM read_receipts rr WHERE rr.message_id = m.id) THEN 'read' ELSE 'sent' END AS status
		FROM messages m
		WHERE m.id = $1
	`
	var m Message
	var contentStr string
	var statusStr string
	err := r.pool.QueryRow(ctx, query, messageID).Scan(
		&m.ID, &m.ConversationID, &m.SenderID, &m.Type, &contentStr, &m.ReplyToID, &m.CreatedAt, &m.UpdatedAt, &m.DeletedAt, &statusStr,
	)
	if err != nil {
		return nil, err
	}
	m.Content = []byte(contentStr)
	m.Status = MessageStatus(statusStr)
	return &m, nil
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
	query := "UPDATE messages SET content = $1, updated_at = $2, edited_at = $2 WHERE id = $3 AND deleted_at IS NULL"
	now := time.Now()
	_, err := r.pool.Exec(ctx, query, string(msg.Content), now, msg.ID)
	return err
}

func (r *PostgresChatRepository) DeleteMessage(ctx context.Context, id uuid.UUID) error {
	query := "UPDATE messages SET deleted_at = $1 WHERE id = $2 AND deleted_at IS NULL"
	_, err := r.pool.Exec(ctx, query, time.Now(), id)
	return err
}

func (r *PostgresChatRepository) AddReaction(ctx context.Context, reaction *MessageReaction) error {
	query := `
		INSERT INTO message_reactions (message_id, message_created_at, user_id, emoji, created_at)
		VALUES ($1, (SELECT created_at FROM messages WHERE id = $1 LIMIT 1), $2, $3, $4)
		ON CONFLICT DO NOTHING
	`
	_, err := r.pool.Exec(ctx, query, reaction.MessageID, reaction.UserID, reaction.Emoji, reaction.CreatedAt)
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
		VALUES ($1, (SELECT created_at FROM messages WHERE id = $1 LIMIT 1), $2, $3)
		ON CONFLICT DO NOTHING
	`
	_, err := r.pool.Exec(ctx, query, messageID, userID, now)
	return err
}
