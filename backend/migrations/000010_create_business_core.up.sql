-- Phase 3A.1 — Create MÏÏghO Business Core Tables
-- Establishes businesses, business_members, and business_accounts with strict foreign keys and zero cascading deletes.

-- 1. Businesses Table
CREATE TABLE IF NOT EXISTS businesses (
    id UUID PRIMARY KEY,
    owner_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    legal_name VARCHAR(255) NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    business_type VARCHAR(100) NOT NULL DEFAULT 'RETAIL',
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'CLOSED')),
    phone VARCHAR(50),
    email VARCHAR(255),
    country VARCHAR(10) NOT NULL DEFAULT 'CI',
    currency VARCHAR(10) NOT NULL DEFAULT 'FCFA',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_businesses_owner_user_id ON businesses(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_businesses_status ON businesses(status);

-- 2. Business Members Table
CREATE TABLE IF NOT EXISTS business_members (
    id UUID PRIMARY KEY,
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    role VARCHAR(50) NOT NULL CHECK (role IN ('OWNER', 'ADMIN', 'MANAGER', 'CASHIER')),
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_business_members_business_user UNIQUE(business_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_business_members_business_id ON business_members(business_id);
CREATE INDEX IF NOT EXISTS idx_business_members_user_id ON business_members(user_id);

-- 3. Business Accounts Table (1:1 with Business, 1:1 with Ledger Account)
CREATE TABLE IF NOT EXISTS business_accounts (
    id UUID PRIMARY KEY,
    business_id UUID NOT NULL UNIQUE REFERENCES businesses(id) ON DELETE RESTRICT,
    ledger_account_id UUID NOT NULL UNIQUE REFERENCES ledger_accounts(id) ON DELETE RESTRICT,
    currency VARCHAR(10) NOT NULL DEFAULT 'FCFA',
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED', 'CLOSED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_business_accounts_business_id ON business_accounts(business_id);
CREATE INDEX IF NOT EXISTS idx_business_accounts_ledger_account_id ON business_accounts(ledger_account_id);
