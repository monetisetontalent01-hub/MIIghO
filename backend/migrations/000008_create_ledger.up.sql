CREATE TABLE ledger_accounts (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    type VARCHAR(50) NOT NULL, -- liability, asset, equity
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE journal_entries (
    id UUID PRIMARY KEY,
    description VARCHAR(255) NOT NULL,
    reference_id VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE ledger_postings (
    id UUID PRIMARY KEY,
    journal_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES ledger_accounts(id) ON DELETE RESTRICT,
    amount NUMERIC(19, 4) NOT NULL,
    direction VARCHAR(2) NOT NULL, -- 'CR' for Credit, 'DR' for Debit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ledger_postings_journal_id ON ledger_postings(journal_id);
CREATE INDEX idx_ledger_postings_account_id ON ledger_postings(account_id);
