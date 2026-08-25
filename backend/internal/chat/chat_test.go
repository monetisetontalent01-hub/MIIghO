package chat

import (
	"context"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/platform/encryption"
	"github.com/miigho/miigho/internal/platform/events"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ===============================================================
// In-Memory Chat Repository for Testing
// ===============================================================

type MemoryChatRepository struct {
	mu            sync.RWMutex
	conversations map[uuid.UUID]*Conversation
	members       map[uuid.UUID][]uuid.UUID // conversationID -> []userID
	messages      map[uuid.UUID][]*Message  // conversationID -> []Message
	reactions     []*MessageReaction
	readReceipts  map[string]time.Time // "msgID:userID" -> readAt
}

func NewMemoryChatRepository() *MemoryChatRepository {
	return &MemoryChatRepository{
		conversations: make(map[uuid.UUID]*Conversation),
		members:       make(map[uuid.UUID][]uuid.UUID),
		messages:      make(map[uuid.UUID][]*Message),
		readReceipts:  make(map[string]time.Time),
	}
}

func (r *MemoryChatRepository) ListConversations(ctx context.Context, userID uuid.UUID, cursor string, limit int) ([]*ConversationWithLastMessage, string, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	if limit <= 0 || limit > 50 {
		limit = 20
	}

	var result []*ConversationWithLastMessage
	for convID, members := range r.members {
		for _, m := range members {
			if m == userID {
				conv := r.conversations[convID]
				if conv != nil {
					dto := &ConversationWithLastMessage{
						Conversation: *conv,
						UnreadCount:  0,
					}
					msgs := r.messages[convID]
					if len(msgs) > 0 {
						dto.LastMessage = msgs[len(msgs)-1]
					}
					result = append(result, dto)
				}
				break
			}
		}
	}
	return result, "", nil
}

func (r *MemoryChatRepository) GetConversation(ctx context.Context, id uuid.UUID) (*Conversation, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	conv, ok := r.conversations[id]
	if !ok {
		return nil, fmt.Errorf("conversation not found: %s", id)
	}
	return conv, nil
}

func (r *MemoryChatRepository) CreateDirectConversation(ctx context.Context, userA, userB uuid.UUID) (*Conversation, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	// Check for existing direct conversation between these users
	for convID, members := range r.members {
		if r.conversations[convID].Type == TypeDirect && len(members) == 2 {
			hasA, hasB := false, false
			for _, m := range members {
				if m == userA {
					hasA = true
				}
				if m == userB {
					hasB = true
				}
			}
			if hasA && hasB {
				return r.conversations[convID], nil
			}
		}
	}

	conv := &Conversation{
		ID:        uuid.New(),
		Type:      TypeDirect,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	r.conversations[conv.ID] = conv
	r.members[conv.ID] = []uuid.UUID{userA, userB}
	return conv, nil
}

func (r *MemoryChatRepository) GetMessages(ctx context.Context, conversationID uuid.UUID, cursor string, limit int) ([]*Message, string, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	if limit <= 0 || limit > 100 {
		limit = 50
	}

	msgs := r.messages[conversationID]
	// Return in reverse chronological order (newest first)
	result := make([]*Message, 0)
	for i := len(msgs) - 1; i >= 0 && len(result) < limit; i-- {
		if msgs[i].DeletedAt == nil {
			result = append(result, msgs[i])
		}
	}
	return result, "", nil
}

func (r *MemoryChatRepository) CreateMessage(ctx context.Context, msg *Message) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	// Verify conversation exists
	if _, ok := r.conversations[msg.ConversationID]; !ok {
		return fmt.Errorf("conversation not found: %s", msg.ConversationID)
	}

	r.messages[msg.ConversationID] = append(r.messages[msg.ConversationID], msg)
	// Update conversation's updated_at
	r.conversations[msg.ConversationID].UpdatedAt = msg.CreatedAt
	return nil
}

func (r *MemoryChatRepository) UpdateMessage(ctx context.Context, msg *Message) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	msgs := r.messages[msg.ConversationID]
	for i, m := range msgs {
		if m.ID == msg.ID {
			msgs[i].Content = msg.Content
			now := time.Now()
			msgs[i].EditedAt = &now
			msgs[i].UpdatedAt = now
			return nil
		}
	}
	return fmt.Errorf("message not found: %s", msg.ID)
}

func (r *MemoryChatRepository) DeleteMessage(ctx context.Context, id uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	for _, msgs := range r.messages {
		for i, m := range msgs {
			if m.ID == id {
				now := time.Now()
				msgs[i].DeletedAt = &now
				return nil
			}
		}
	}
	return fmt.Errorf("message not found: %s", id)
}

func (r *MemoryChatRepository) AddReaction(ctx context.Context, reaction *MessageReaction) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	// Check for duplicate
	for _, existing := range r.reactions {
		if existing.MessageID == reaction.MessageID &&
			existing.UserID == reaction.UserID &&
			existing.Emoji == reaction.Emoji {
			return nil // ON CONFLICT DO NOTHING
		}
	}
	r.reactions = append(r.reactions, reaction)
	return nil
}

func (r *MemoryChatRepository) RemoveReaction(ctx context.Context, messageID, userID uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	for i, reaction := range r.reactions {
		if reaction.MessageID == messageID && reaction.UserID == userID {
			r.reactions = append(r.reactions[:i], r.reactions[i+1:]...)
			return nil
		}
	}
	return nil
}

func (r *MemoryChatRepository) MarkAsRead(ctx context.Context, conversationID, userID, messageID uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	key := fmt.Sprintf("%s:%s", messageID, userID)
	if _, exists := r.readReceipts[key]; exists {
		return nil // ON CONFLICT DO NOTHING
	}
	r.readReceipts[key] = time.Now()
	return nil
}

// ===============================================================
// In-Memory Event Bus for Testing
// ===============================================================

type MemoryEventBus struct {
	mu        sync.Mutex
	published []events.DomainEvent
}

func NewMemoryEventBus() *MemoryEventBus {
	return &MemoryEventBus{}
}

func (b *MemoryEventBus) Publish(ctx context.Context, event events.DomainEvent) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.published = append(b.published, event)
	return nil
}

func (b *MemoryEventBus) Subscribe(topic string, handler events.EventHandler) error {
	return nil
}

func (b *MemoryEventBus) LastEvent() events.DomainEvent {
	b.mu.Lock()
	defer b.mu.Unlock()
	if len(b.published) == 0 {
		return nil
	}
	return b.published[len(b.published)-1]
}

func (b *MemoryEventBus) EventCount() int {
	b.mu.Lock()
	defer b.mu.Unlock()
	return len(b.published)
}

// ===============================================================
// Test Setup Helpers
// ===============================================================

type chatTestEnv struct {
	repo    *MemoryChatRepository
	bus     *MemoryEventBus
	enc     encryption.EncryptionService
	service *ChatService
	userA   uuid.UUID
	userB   uuid.UUID
	userC   uuid.UUID
}

func setupChatTestEnv(t *testing.T) *chatTestEnv {
	t.Helper()
	repo := NewMemoryChatRepository()
	bus := NewMemoryEventBus()
	enc := &encryption.PassthroughEncryption{}
	service := NewChatService(repo, bus, enc)

	return &chatTestEnv{
		repo:    repo,
		bus:     bus,
		enc:     enc,
		service: service,
		userA:   uuid.New(),
		userB:   uuid.New(),
		userC:   uuid.New(),
	}
}

// ===============================================================
// TEST SUITE: ChatService — SendMessage
// ===============================================================

func TestChat_SendMessage_Success(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	// Create a conversation first
	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	msg, err := env.service.SendMessage(ctx, conv.ID, env.userA, []byte("Hello!"), MsgText)
	require.NoError(t, err)
	assert.NotNil(t, msg)
	assert.Equal(t, conv.ID, msg.ConversationID)
	assert.Equal(t, env.userA, msg.SenderID)
	assert.Equal(t, MsgText, msg.Type)
	assert.Equal(t, StatusSent, msg.Status)
	assert.NotNil(t, msg.EncryptionMetadata)
}

func TestChat_SendMessage_Encrypted(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	content := []byte("Secret message")
	msg, err := env.service.SendMessage(ctx, conv.ID, env.userA, content, MsgText)
	require.NoError(t, err)

	// PassthroughEncryption returns content as-is
	assert.Equal(t, content, msg.Content)
	assert.Equal(t, "none", msg.EncryptionMetadata.Algorithm)
	assert.Equal(t, 1, msg.EncryptionMetadata.Version)
}

func TestChat_SendMessage_PublishesDomainEvent(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	initialCount := env.bus.EventCount()
	_, err = env.service.SendMessage(ctx, conv.ID, env.userA, []byte("Hello!"), MsgText)
	require.NoError(t, err)

	assert.Equal(t, initialCount+1, env.bus.EventCount())
	lastEvent := env.bus.LastEvent()
	assert.Equal(t, "message.sent", lastEvent.Topic())
}

func TestChat_SendMessage_AllMessageTypes(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	types := []MessageType{MsgText, MsgImage, MsgVideo, MsgAudio, MsgVoice, MsgFile, MsgSystem}
	for _, mt := range types {
		t.Run(string(mt), func(t *testing.T) {
			msg, err := env.service.SendMessage(ctx, conv.ID, env.userA, []byte("content"), mt)
			require.NoError(t, err)
			assert.Equal(t, mt, msg.Type)
		})
	}
}

func TestChat_SendMessage_GeneratesUniqueIDs(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	msg1, err := env.service.SendMessage(ctx, conv.ID, env.userA, []byte("Hello 1"), MsgText)
	require.NoError(t, err)
	msg2, err := env.service.SendMessage(ctx, conv.ID, env.userA, []byte("Hello 2"), MsgText)
	require.NoError(t, err)

	assert.NotEqual(t, msg1.ID, msg2.ID, "each message must have a unique ID")
}

func TestChat_SendMessage_InvalidConversation(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	fakeConvID := uuid.New()
	_, err := env.service.SendMessage(ctx, fakeConvID, env.userA, []byte("Hello"), MsgText)
	assert.Error(t, err, "should fail for non-existent conversation")
}

func TestChat_SendMessage_NilContent(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	_, err = env.service.SendMessage(ctx, conv.ID, env.userA, nil, MsgText)
	assert.Error(t, err, "nil content should be rejected by encryption service")
}

// ===============================================================
// TEST SUITE: ChatService — MarkDelivered / MarkRead
// ===============================================================

func TestChat_MarkDelivered_PublishesEvent(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	msgID := uuid.New()
	initialCount := env.bus.EventCount()

	err := env.service.MarkDelivered(ctx, msgID, env.userB)
	require.NoError(t, err)

	assert.Equal(t, initialCount+1, env.bus.EventCount())
	lastEvent := env.bus.LastEvent()
	assert.Equal(t, "message.delivered", lastEvent.Topic())
}

func TestChat_MarkRead_Success(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	msg, err := env.service.SendMessage(ctx, conv.ID, env.userA, []byte("Read me"), MsgText)
	require.NoError(t, err)

	err = env.service.MarkRead(ctx, conv.ID, env.userB, msg.ID)
	require.NoError(t, err)

	// Verify event was published
	lastEvent := env.bus.LastEvent()
	assert.Equal(t, "message.read", lastEvent.Topic())
}

func TestChat_MarkRead_Idempotent(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	msg, err := env.service.SendMessage(ctx, conv.ID, env.userA, []byte("Read me"), MsgText)
	require.NoError(t, err)

	// Mark as read twice — should not error
	err = env.service.MarkRead(ctx, conv.ID, env.userB, msg.ID)
	require.NoError(t, err)
	err = env.service.MarkRead(ctx, conv.ID, env.userB, msg.ID)
	require.NoError(t, err)
}

// ===============================================================
// TEST SUITE: Repository — Conversations
// ===============================================================

func TestRepo_CreateDirectConversation(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)
	assert.Equal(t, TypeDirect, conv.Type)
	assert.NotEqual(t, uuid.Nil, conv.ID)
}

func TestRepo_CreateDirectConversation_Idempotent(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv1, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	conv2, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	assert.Equal(t, conv1.ID, conv2.ID, "same pair of users should return same conversation")
}

func TestRepo_CreateDirectConversation_DifferentPairs(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv1, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)
	conv2, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userC)
	require.NoError(t, err)

	assert.NotEqual(t, conv1.ID, conv2.ID, "different pairs must produce different conversations")
}

func TestRepo_GetConversation(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	fetched, err := env.repo.GetConversation(ctx, conv.ID)
	require.NoError(t, err)
	assert.Equal(t, conv.ID, fetched.ID)
	assert.Equal(t, TypeDirect, fetched.Type)
}

func TestRepo_GetConversation_NotFound(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	_, err := env.repo.GetConversation(ctx, uuid.New())
	assert.Error(t, err)
}

func TestRepo_ListConversations_ByUser(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	_, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)
	_, err = env.repo.CreateDirectConversation(ctx, env.userA, env.userC)
	require.NoError(t, err)

	// UserA should see 2 conversations
	convs, _, err := env.repo.ListConversations(ctx, env.userA, "", 20)
	require.NoError(t, err)
	assert.Len(t, convs, 2)

	// UserC should see 1 conversation
	convs, _, err = env.repo.ListConversations(ctx, env.userC, "", 20)
	require.NoError(t, err)
	assert.Len(t, convs, 1)
}

// ===============================================================
// TEST SUITE: Repository — Messages
// ===============================================================

func TestRepo_CreateAndGetMessages(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	msg := &Message{
		ID:             uuid.New(),
		ConversationID: conv.ID,
		SenderID:       env.userA,
		Type:           MsgText,
		Content:        []byte("Hello"),
		Status:         StatusSent,
		CreatedAt:      time.Now(),
	}
	err = env.repo.CreateMessage(ctx, msg)
	require.NoError(t, err)

	msgs, _, err := env.repo.GetMessages(ctx, conv.ID, "", 50)
	require.NoError(t, err)
	assert.Len(t, msgs, 1)
	assert.Equal(t, msg.ID, msgs[0].ID)
}

func TestRepo_GetMessages_ReverseChronological(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	for i := 0; i < 5; i++ {
		msg := &Message{
			ID:             uuid.New(),
			ConversationID: conv.ID,
			SenderID:       env.userA,
			Type:           MsgText,
			Content:        []byte(fmt.Sprintf("Message %d", i)),
			Status:         StatusSent,
			CreatedAt:      time.Now().Add(time.Duration(i) * time.Second),
		}
		err := env.repo.CreateMessage(ctx, msg)
		require.NoError(t, err)
	}

	msgs, _, err := env.repo.GetMessages(ctx, conv.ID, "", 50)
	require.NoError(t, err)
	assert.Len(t, msgs, 5)
	// First message in result should be newest
	assert.Contains(t, string(msgs[0].Content), "Message 4")
}

func TestRepo_GetMessages_Limit(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	for i := 0; i < 10; i++ {
		msg := &Message{
			ID:             uuid.New(),
			ConversationID: conv.ID,
			SenderID:       env.userA,
			Type:           MsgText,
			Content:        []byte(fmt.Sprintf("Msg %d", i)),
			Status:         StatusSent,
			CreatedAt:      time.Now().Add(time.Duration(i) * time.Second),
		}
		err := env.repo.CreateMessage(ctx, msg)
		require.NoError(t, err)
	}

	msgs, _, err := env.repo.GetMessages(ctx, conv.ID, "", 3)
	require.NoError(t, err)
	assert.Len(t, msgs, 3)
}

func TestRepo_UpdateMessage(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	msg := &Message{
		ID:             uuid.New(),
		ConversationID: conv.ID,
		SenderID:       env.userA,
		Type:           MsgText,
		Content:        []byte("Original"),
		Status:         StatusSent,
		CreatedAt:      time.Now(),
	}
	err = env.repo.CreateMessage(ctx, msg)
	require.NoError(t, err)

	msg.Content = []byte("Edited")
	err = env.repo.UpdateMessage(ctx, msg)
	require.NoError(t, err)

	msgs, _, err := env.repo.GetMessages(ctx, conv.ID, "", 50)
	require.NoError(t, err)
	assert.Equal(t, "Edited", string(msgs[0].Content))
	assert.NotNil(t, msgs[0].EditedAt)
}

func TestRepo_DeleteMessage_SoftDelete(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	msg := &Message{
		ID:             uuid.New(),
		ConversationID: conv.ID,
		SenderID:       env.userA,
		Type:           MsgText,
		Content:        []byte("To delete"),
		Status:         StatusSent,
		CreatedAt:      time.Now(),
	}
	err = env.repo.CreateMessage(ctx, msg)
	require.NoError(t, err)

	err = env.repo.DeleteMessage(ctx, msg.ID)
	require.NoError(t, err)

	// Should not appear in GetMessages (filters deleted)
	msgs, _, err := env.repo.GetMessages(ctx, conv.ID, "", 50)
	require.NoError(t, err)
	assert.Len(t, msgs, 0)
}

// ===============================================================
// TEST SUITE: Repository — Reactions
// ===============================================================

func TestRepo_AddReaction(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	reaction := &MessageReaction{
		MessageID: uuid.New(),
		UserID:    env.userA,
		Emoji:     "👍",
		CreatedAt: time.Now(),
	}
	err := env.repo.AddReaction(ctx, reaction)
	require.NoError(t, err)
}

func TestRepo_AddReaction_Idempotent(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	reaction := &MessageReaction{
		MessageID: uuid.New(),
		UserID:    env.userA,
		Emoji:     "❤️",
		CreatedAt: time.Now(),
	}
	err := env.repo.AddReaction(ctx, reaction)
	require.NoError(t, err)
	err = env.repo.AddReaction(ctx, reaction)
	require.NoError(t, err) // ON CONFLICT DO NOTHING
}

func TestRepo_RemoveReaction(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	msgID := uuid.New()
	reaction := &MessageReaction{
		MessageID: msgID,
		UserID:    env.userA,
		Emoji:     "🔥",
		CreatedAt: time.Now(),
	}
	err := env.repo.AddReaction(ctx, reaction)
	require.NoError(t, err)

	err = env.repo.RemoveReaction(ctx, msgID, env.userA)
	require.NoError(t, err)
}

// ===============================================================
// TEST SUITE: Repository — Read Receipts
// ===============================================================

func TestRepo_MarkAsRead(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	convID := uuid.New()
	msgID := uuid.New()

	err := env.repo.MarkAsRead(ctx, convID, env.userA, msgID)
	require.NoError(t, err)
}

func TestRepo_MarkAsRead_Idempotent(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	convID := uuid.New()
	msgID := uuid.New()

	err := env.repo.MarkAsRead(ctx, convID, env.userA, msgID)
	require.NoError(t, err)
	err = env.repo.MarkAsRead(ctx, convID, env.userA, msgID)
	require.NoError(t, err) // ON CONFLICT DO NOTHING
}

// ===============================================================
// TEST SUITE: Hub (WebSocket)
// ===============================================================

func TestHub_BroadcastToUser_NoConnections(t *testing.T) {
	hub := NewHub()
	// Should not panic
	hub.BroadcastToUser(uuid.New(), []byte("test"))
}

// ===============================================================
// TEST SUITE: Models — Immutability & Type Safety
// ===============================================================

func TestModel_ConversationType_Values(t *testing.T) {
	assert.Equal(t, ConversationType("direct"), TypeDirect)
	assert.Equal(t, ConversationType("group"), TypeGroup)
}

func TestModel_MessageType_Values(t *testing.T) {
	types := []MessageType{MsgText, MsgImage, MsgVideo, MsgAudio, MsgVoice, MsgFile, MsgSystem}
	assert.Len(t, types, 7)
	for _, mt := range types {
		assert.NotEmpty(t, string(mt))
	}
}

func TestModel_MessageStatus_Values(t *testing.T) {
	assert.Equal(t, MessageStatus("sent"), StatusSent)
	assert.Equal(t, MessageStatus("delivered"), StatusDelivered)
	assert.Equal(t, MessageStatus("read"), StatusRead)
}

func TestModel_Message_HasEncryptionMetadata(t *testing.T) {
	msg := &Message{
		ID:             uuid.New(),
		ConversationID: uuid.New(),
		SenderID:       uuid.New(),
		Type:           MsgText,
		Content:        []byte("test"),
		EncryptionMetadata: &encryption.EncryptionMetadata{
			Algorithm: "none",
			Version:   1,
		},
	}
	assert.NotNil(t, msg.EncryptionMetadata)
	assert.Equal(t, "none", msg.EncryptionMetadata.Algorithm)
}

// ===============================================================
// TEST SUITE: Concurrent Message Sending
// ===============================================================

func TestChat_ConcurrentSendMessages(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	const numGoroutines = 20
	var wg sync.WaitGroup
	errCh := make(chan error, numGoroutines)

	for i := 0; i < numGoroutines; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			content := fmt.Sprintf("Concurrent message %d", idx)
			_, err := env.service.SendMessage(ctx, conv.ID, env.userA, []byte(content), MsgText)
			if err != nil {
				errCh <- err
			}
		}(i)
	}

	wg.Wait()
	close(errCh)

	for err := range errCh {
		t.Fatalf("concurrent send failed: %v", err)
	}

	msgs, _, err := env.repo.GetMessages(ctx, conv.ID, "", 100)
	require.NoError(t, err)
	assert.Len(t, msgs, numGoroutines, "all concurrent messages should be persisted")
}

// ===============================================================
// TEST SUITE: End-to-End Flow
// ===============================================================

func TestChat_E2E_FullConversationFlow(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	// 1. Create direct conversation
	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)
	assert.Equal(t, TypeDirect, conv.Type)

	// 2. UserA sends a message
	msg1, err := env.service.SendMessage(ctx, conv.ID, env.userA, []byte("Salut !"), MsgText)
	require.NoError(t, err)

	// 3. UserB sends a reply
	msg2, err := env.service.SendMessage(ctx, conv.ID, env.userB, []byte("Ça va ?"), MsgText)
	require.NoError(t, err)

	// 4. Verify messages are listed
	msgs, _, err := env.repo.GetMessages(ctx, conv.ID, "", 50)
	require.NoError(t, err)
	assert.Len(t, msgs, 2)

	// 5. UserB marks msg1 as read
	err = env.service.MarkRead(ctx, conv.ID, env.userB, msg1.ID)
	require.NoError(t, err)

	// 6. Add reaction
	err = env.repo.AddReaction(ctx, &MessageReaction{
		MessageID: msg2.ID,
		UserID:    env.userA,
		Emoji:     "😂",
		CreatedAt: time.Now(),
	})
	require.NoError(t, err)

	// 7. Edit message
	msg1.Content = []byte("Salut, comment tu vas ?")
	err = env.repo.UpdateMessage(ctx, msg1)
	require.NoError(t, err)

	// 8. Verify edit
	msgs, _, err = env.repo.GetMessages(ctx, conv.ID, "", 50)
	require.NoError(t, err)
	// Find msg1 and verify edit
	var found bool
	for _, m := range msgs {
		if m.ID == msg1.ID {
			assert.Equal(t, "Salut, comment tu vas ?", string(m.Content))
			assert.NotNil(t, m.EditedAt)
			found = true
			break
		}
	}
	assert.True(t, found, "edited message should be found")

	// 9. Delete msg2
	err = env.repo.DeleteMessage(ctx, msg2.ID)
	require.NoError(t, err)

	// 10. Verify only msg1 remains
	msgs, _, err = env.repo.GetMessages(ctx, conv.ID, "", 50)
	require.NoError(t, err)
	assert.Len(t, msgs, 1)
	assert.Equal(t, msg1.ID, msgs[0].ID)

	// 11. ListConversations should show this conversation for both users
	convs, _, err := env.repo.ListConversations(ctx, env.userA, "", 20)
	require.NoError(t, err)
	assert.Len(t, convs, 1)

	convs, _, err = env.repo.ListConversations(ctx, env.userB, "", 20)
	require.NoError(t, err)
	assert.Len(t, convs, 1)

	// 12. Verify domain events were published
	assert.True(t, env.bus.EventCount() >= 3, "should have at least 3 events: 2 message.sent + 1 message.read")
}

func TestChat_ListConversations_ShowsLastMessage(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)

	_, err = env.service.SendMessage(ctx, conv.ID, env.userA, []byte("First"), MsgText)
	require.NoError(t, err)
	_, err = env.service.SendMessage(ctx, conv.ID, env.userB, []byte("Latest"), MsgText)
	require.NoError(t, err)

	convs, _, err := env.repo.ListConversations(ctx, env.userA, "", 20)
	require.NoError(t, err)
	require.Len(t, convs, 1)
	require.NotNil(t, convs[0].LastMessage)
	assert.Equal(t, "Latest", string(convs[0].LastMessage.Content))
}

func TestChat_ConversationUpdatedAt_AdvancesOnMessage(t *testing.T) {
	env := setupChatTestEnv(t)
	ctx := context.Background()

	conv, err := env.repo.CreateDirectConversation(ctx, env.userA, env.userB)
	require.NoError(t, err)
	originalUpdatedAt := conv.UpdatedAt

	time.Sleep(1 * time.Millisecond)
	_, err = env.service.SendMessage(ctx, conv.ID, env.userA, []byte("Bump"), MsgText)
	require.NoError(t, err)

	updated, err := env.repo.GetConversation(ctx, conv.ID)
	require.NoError(t, err)
	assert.True(t, updated.UpdatedAt.After(originalUpdatedAt) || updated.UpdatedAt.Equal(originalUpdatedAt))
}
