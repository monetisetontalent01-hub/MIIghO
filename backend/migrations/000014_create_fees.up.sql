-- Phase 3A.5 — Create Merchant Commissions & Fee Rules Schema
-- Strictly append-only, ON DELETE RESTRICT to protect financial and audit integrity.

-- 1. Fee Rules Table (Tariff rules for operations)
CREATE TABLE IF NOT EXISTS fee_rules (
    id UUID PRIMARY KEY,
    business_id UUID REFERENCES businesses(id) ON DELETE RESTRICT, -- NULL for global system default rule
    transaction_type VARCHAR(50) NOT NULL, -- e.g. 'merchant_payment', 'merchant_settlement'
    fee_type VARCHAR(30) NOT NULL CHECK (fee_type IN ('FIXED', 'PERCENTAGE', 'HYBRID')),
    fixed_amount BIGINT NOT NULL DEFAULT 0 CHECK (fixed_amount >= 0),
    percentage_bps BIGINT NOT NULL DEFAULT 0 CHECK (percentage_bps >= 0 AND percentage_bps <= 10000), -- Basis points: 100 bps = 1.00%
    minimum_fee BIGINT NOT NULL DEFAULT 0 CHECK (minimum_fee >= 0),
    maximum_fee BIGINT NOT NULL DEFAULT 0 CHECK (maximum_fee >= 0), -- 0 = no cap
    currency VARCHAR(10) NOT NULL DEFAULT 'FCFA',
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'ARCHIVED')),
    is_refundable BOOLEAN NOT NULL DEFAULT FALSE,
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fee_rules_business_id ON fee_rules(business_id);
CREATE INDEX IF NOT EXISTS idx_fee_rules_tx_type ON fee_rules(transaction_type);
CREATE INDEX IF NOT EXISTS idx_fee_rules_status ON fee_rules(status);
CREATE INDEX IF NOT EXISTS idx_fee_rules_lookup ON fee_rules(business_id, transaction_type, currency, status);

-- 2. Fee Transactions Table (Collected commissions ledgerized on source transactions)
CREATE TABLE IF NOT EXISTS fee_transactions (
    id UUID PRIMARY KEY,
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE RESTRICT,
    fee_rule_id UUID REFERENCES fee_rules(id) ON DELETE RESTRICT,
    source_transaction_type VARCHAR(50) NOT NULL, -- e.g. 'merchant_payment', 'merchant_settlement'
    source_transaction_id UUID NOT NULL, -- e.g. payment_intent_id or settlement_id
    gross_amount BIGINT NOT NULL CHECK (gross_amount > 0),
    fee_amount BIGINT NOT NULL CHECK (fee_amount >= 0),
    currency VARCHAR(10) NOT NULL DEFAULT 'FCFA',
    status VARCHAR(30) NOT NULL DEFAULT 'COLLECTED' CHECK (status IN ('PENDING', 'COLLECTED', 'REFUNDED', 'WAIVED', 'FAILED')),
    is_refundable BOOLEAN NOT NULL DEFAULT FALSE,
    refunded_fee_amount BIGINT NOT NULL DEFAULT 0 CHECK (refunded_fee_amount >= 0),
    idempotency_key VARCHAR(255),
    journal_entry_id UUID REFERENCES journal_entries(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    collected_at TIMESTAMPTZ,
    CONSTRAINT uq_fee_tx_source UNIQUE (source_transaction_id, source_transaction_type)
);

CREATE INDEX IF NOT EXISTS idx_fee_transactions_business_id ON fee_transactions(business_id);
CREATE INDEX IF NOT EXISTS idx_fee_transactions_source ON fee_transactions(source_transaction_id, source_transaction_type);
CREATE INDEX IF NOT EXISTS idx_fee_transactions_status ON fee_transactions(status);
CREATE INDEX IF NOT EXISTS idx_fee_transactions_idempotency_key ON fee_transactions(idempotency_key);
