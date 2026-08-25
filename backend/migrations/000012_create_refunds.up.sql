-- Phase 3A.3 — Create Refunds Schema
-- Strictly append-only, ON DELETE RESTRICT to protect financial and audit integrity.

CREATE TABLE IF NOT EXISTS refunds (
    id UUID PRIMARY KEY,
    payment_intent_id UUID NOT NULL REFERENCES payment_intents(id) ON DELETE RESTRICT,
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE RESTRICT,
    payer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    amount BIGINT NOT NULL CHECK (amount > 0),
    currency VARCHAR(10) NOT NULL DEFAULT 'FCFA',
    status VARCHAR(50) NOT NULL DEFAULT 'REQUESTED' CHECK (status IN ('REQUESTED', 'SUCCEEDED', 'FAILED', 'CANCELLED')),
    reason TEXT,
    idempotency_key VARCHAR(255),
    journal_entry_id UUID REFERENCES journal_entries(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_refunds_payment_intent_id ON refunds(payment_intent_id);
CREATE INDEX IF NOT EXISTS idx_refunds_business_id ON refunds(business_id);
CREATE INDEX IF NOT EXISTS idx_refunds_payer_user_id ON refunds(payer_user_id);
CREATE INDEX IF NOT EXISTS idx_refunds_status ON refunds(status);
CREATE INDEX IF NOT EXISTS idx_refunds_idempotency_key ON refunds(idempotency_key);
