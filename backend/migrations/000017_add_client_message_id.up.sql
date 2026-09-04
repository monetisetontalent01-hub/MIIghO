-- Migration 000017: Add client_message_id for message idempotency
-- Allows retries without creating duplicate messages
ALTER TABLE messages ADD COLUMN IF NOT EXISTS client_message_id VARCHAR(64);

-- Unique index per conversation for idempotency:
-- same client_message_id within a conversation cannot produce two rows.
CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_client_message_id
    ON messages (conversation_id, client_message_id)
    WHERE client_message_id IS NOT NULL;
