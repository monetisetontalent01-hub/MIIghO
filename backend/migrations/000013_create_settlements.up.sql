-- Phase 3A.4 — Create Merchant Settlement Schema
-- Strictly append-only, ON DELETE RESTRICT to protect financial and audit integrity.

-- 1. Settlements Table
CREATE TABLE IF NOT EXISTS settlements (
    id UUID PRIMARY KEY,
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE RESTRICT,
    total_amount BIGINT NOT NULL CHECK (total_amount > 0),
    currency VARCHAR(10) NOT NULL DEFAULT 'FCFA',
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSING', 'SUCCEEDED', 'FAILED', 'CANCELLED')),
    idempotency_key VARCHAR(255),
    journal_entry_id UUID REFERENCES journal_entries(id) ON DELETE RESTRICT,
    failure_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_settlements_business_id ON settlements(business_id);
CREATE INDEX IF NOT EXISTS idx_settlements_status ON settlements(status);
CREATE INDEX IF NOT EXISTS idx_settlements_idempotency_key ON settlements(idempotency_key);

-- 2. Settlement Items Table (Each payment transaction in the batch)
CREATE TABLE IF NOT EXISTS settlement_items (
    id UUID PRIMARY KEY,
    settlement_id UUID NOT NULL REFERENCES settlements(id) ON DELETE RESTRICT,
    payment_intent_id UUID NOT NULL REFERENCES payment_intents(id) ON DELETE RESTRICT,
    gross_amount BIGINT NOT NULL CHECK (gross_amount > 0),
    refund_amount BIGINT NOT NULL DEFAULT 0 CHECK (refund_amount >= 0),
    net_amount BIGINT NOT NULL CHECK (net_amount > 0),
    currency VARCHAR(10) NOT NULL DEFAULT 'FCFA',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_settlement_items_settlement_id ON settlement_items(settlement_id);
CREATE INDEX IF NOT EXISTS idx_settlement_items_payment_intent_id ON settlement_items(payment_intent_id);
