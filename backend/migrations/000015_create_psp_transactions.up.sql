-- Migration: Create PSP Transactions and Webhook Events Tables
-- Phase 3A.6: PSP Gateway Abstraction & Sandbox Provider

CREATE TABLE IF NOT EXISTS psp_transactions (
    id UUID PRIMARY KEY,
    provider VARCHAR(50) NOT NULL,
    operation_type VARCHAR(50) NOT NULL, -- payment, refund, payout
    internal_reference VARCHAR(255) NOT NULL,
    psp_transaction_id VARCHAR(255) NOT NULL,
    payment_intent_id UUID REFERENCES payment_intents(id) ON DELETE RESTRICT,
    refund_id UUID REFERENCES refunds(id) ON DELETE RESTRICT,
    settlement_id UUID REFERENCES settlements(id) ON DELETE RESTRICT,
    amount BIGINT NOT NULL CHECK (amount > 0),
    currency VARCHAR(10) NOT NULL,
    status VARCHAR(30) NOT NULL, -- PENDING, PROCESSING, SUCCEEDED, FAILED, CANCELLED, EXPIRED, UNKNOWN
    idempotency_key VARCHAR(255),
    request_reference VARCHAR(255),
    response_reference VARCHAR(255),
    failure_code VARCHAR(100),
    failure_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    CONSTRAINT uq_psp_tx_provider_pspid UNIQUE (provider, psp_transaction_id)
);

CREATE INDEX IF NOT EXISTS idx_psp_tx_internal_ref ON psp_transactions(internal_reference);
CREATE INDEX IF NOT EXISTS idx_psp_tx_payment_intent ON psp_transactions(payment_intent_id);
CREATE INDEX IF NOT EXISTS idx_psp_tx_refund ON psp_transactions(refund_id);
CREATE INDEX IF NOT EXISTS idx_psp_tx_settlement ON psp_transactions(settlement_id);
CREATE INDEX IF NOT EXISTS idx_psp_tx_idempotency ON psp_transactions(provider, idempotency_key);
CREATE INDEX IF NOT EXISTS idx_psp_tx_status ON psp_transactions(status);

CREATE TABLE IF NOT EXISTS psp_webhook_events (
    id UUID PRIMARY KEY,
    provider VARCHAR(50) NOT NULL,
    event_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    payload TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'RECEIVED', -- RECEIVED, PROCESSED, FAILED, IGNORED
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    error_message TEXT,
    CONSTRAINT uq_psp_webhook_event UNIQUE (provider, event_id)
);

CREATE INDEX IF NOT EXISTS idx_psp_webhook_provider_event ON psp_webhook_events(provider, event_id);
CREATE INDEX IF NOT EXISTS idx_psp_webhook_status ON psp_webhook_events(status);
