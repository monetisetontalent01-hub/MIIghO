-- Rollback migration 000017
DROP INDEX IF EXISTS idx_messages_client_message_id;
ALTER TABLE messages DROP COLUMN IF EXISTS client_message_id;
