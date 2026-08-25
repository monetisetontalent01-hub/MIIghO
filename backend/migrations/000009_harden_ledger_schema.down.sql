-- Phase 3A.0 — Revert Ledger Baseline Hardening Migration

-- 1. Remove Unique Idempotency Index
DROP INDEX IF EXISTS idx_journal_entries_reference_id_unique;

-- 2. Drop added columns
ALTER TABLE journal_entries
    DROP COLUMN IF EXISTS transaction_type;

ALTER TABLE ledger_accounts
    DROP COLUMN IF EXISTS name;

-- 3. Restore previous Foreign Key constraint with CASCADE
ALTER TABLE ledger_postings
    DROP CONSTRAINT IF EXISTS ledger_postings_journal_id_fkey;

ALTER TABLE ledger_postings
    ADD CONSTRAINT ledger_postings_journal_id_fkey
    FOREIGN KEY (journal_id) REFERENCES journal_entries(id) ON DELETE CASCADE;

-- 4. Drop check constraints
ALTER TABLE ledger_postings
    DROP CONSTRAINT IF EXISTS chk_ledger_postings_direction;

ALTER TABLE ledger_postings
    DROP CONSTRAINT IF EXISTS chk_ledger_postings_amount_positive;

-- 5. Revert amount to NUMERIC(19,4)
ALTER TABLE ledger_postings
    ALTER COLUMN amount TYPE NUMERIC(19, 4) USING (amount::NUMERIC(19, 4));
