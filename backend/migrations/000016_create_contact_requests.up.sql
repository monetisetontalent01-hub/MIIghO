-- Migration 000016: Create contact_requests table for mutual contact authorization
CREATE TABLE IF NOT EXISTS contact_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_contact_request_status CHECK (status IN ('pending', 'accepted', 'rejected')),
    CONSTRAINT chk_no_self_request CHECK (sender_id != recipient_id),
    CONSTRAINT unique_contact_request UNIQUE (sender_id, recipient_id)
);

CREATE INDEX IF NOT EXISTS idx_contact_requests_recipient_status ON contact_requests(recipient_id, status);
CREATE INDEX IF NOT EXISTS idx_contact_requests_sender_status ON contact_requests(sender_id, status);
