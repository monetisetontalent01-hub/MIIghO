-- Phase 3A.0 — Ledger Baseline Hardening Migration
-- Harmonizes integer amounts to BIGINT, removes CASCADE deletes to enforce Append-Only, and adds database-level constraints.

-- 1. Alter ledger_postings.amount to BIGINT
ALTER TABLE ledger_postings
    ALTER COLUMN amount TYPE BIGINT USING (amount::BIGINT);

-- 2. Add CHECK constraint for strictly positive amounts (> 0)
ALTER TABLE ledger_postings
    ADD CONSTRAINT chk_ledger_postings_amount_positive CHECK (amount > 0);

-- 3. Add CHECK constraint for valid direction ('CR' or 'DR')
ALTER TABLE ledger_postings
    ADD CONSTRAINT chk_ledger_postings_direction CHECK (direction IN ('CR', 'DR'));

-- 4. Remove ON DELETE CASCADE on journal_id to enforce Append-Only ledger integrity
ALTER TABLE ledger_postings
    DROP CONSTRAINT IF EXISTS ledger_postings_journal_id_fkey;

ALTER TABLE ledger_postings
    ADD CONSTRAINT ledger_postings_journal_id_fkey
    FOREIGN KEY (journal_id) REFERENCES journal_entries(id) ON DELETE RESTRICT;

-- 5. Add missing name column to ledger_accounts and transaction_type to journal_entries for full Go struct symmetry
ALTER TABLE ledger_accounts
    ADD COLUMN IF NOT EXISTS name VARCHAR(255) NOT NULL DEFAULT 'Compte';

ALTER TABLE journal_entries
    ADD COLUMN IF NOT EXISTS transaction_type VARCHAR(50) NOT NULL DEFAULT 'p2p_transfer';

-- 6. Enforce Unique Idempotency Key at database level
CREATE UNIQUE INDEX IF NOT EXISTS idx_journal_entries_reference_id_unique
    ON journal_entries(reference_id)
    WHERE reference_id IS NOT NULL AND reference_id != '';
