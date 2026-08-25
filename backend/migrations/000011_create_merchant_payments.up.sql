-- Phase 3A.2 — Create Merchant QR & Payment Intents Schema
-- Strictly append-only, ON DELETE RESTRICT to protect financial and audit integrity.

-- 1. Merchant QR Codes Table
CREATE TABLE IF NOT EXISTS merchant_qr_codes (
    id UUID PRIMARY KEY,
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE RESTRICT,
    code VARCHAR(100) UNIQUE NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'DISABLED', 'REVOKED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_merchant_qr_codes_business_id ON merchant_qr_codes(business_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_merchant_qr_codes_code ON merchant_qr_codes(code);
CREATE INDEX IF NOT EXISTS idx_merchant_qr_codes_status ON merchant_qr_codes(status);

-- 2. Payment Intents Table
CREATE TABLE IF NOT EXISTS payment_intents (
    id UUID PRIMARY KEY,
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE RESTRICT,
    payer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    merchant_qr_id UUID REFERENCES merchant_qr_codes(id) ON DELETE RESTRICT,
    amount BIGINT NOT NULL CHECK (amount > 0),
    currency VARCHAR(10) NOT NULL DEFAULT 'FCFA',
    status VARCHAR(50) NOT NULL DEFAULT 'CREATED' CHECK (status IN ('CREATED', 'CONFIRMED', 'SUCCEEDED', 'FAILED', 'CANCELLED', 'EXPIRED')),
    idempotency_key VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    confirmed_at TIMESTAMPTZ,
    journal_entry_id UUID REFERENCES journal_entries(id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_payment_intents_business_id ON payment_intents(business_id);
CREATE INDEX IF NOT EXISTS idx_payment_intents_payer_user_id ON payment_intents(payer_user_id);
CREATE INDEX IF NOT EXISTS idx_payment_intents_status ON payment_intents(status);
CREATE INDEX IF NOT EXISTS idx_payment_intents_idempotency_key ON payment_intents(idempotency_key);
