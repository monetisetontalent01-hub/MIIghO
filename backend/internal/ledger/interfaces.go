package ledger

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// AccountType defines the nature of the ledger account.
type AccountType string

const (
	Asset     AccountType = "asset"
	Liability AccountType = "liability"
	Revenue   AccountType = "revenue"
	Expense   AccountType = "expense"
	Equity    AccountType = "equity"
)

// TransactionType defines business operation types for journal entries.
type TransactionType string

const (
	P2PTransfer        TransactionType = "p2p_transfer"
	MoMoCashIn         TransactionType = "momo_cash_in"
	MoMoCashOut        TransactionType = "momo_cash_out"
	MarketplaceEscrow  TransactionType = "marketplace_escrow"
	MarketplaceRelease TransactionType = "marketplace_release"
	Fee                TransactionType = "fee"
	MerchantPayment    TransactionType = "merchant_payment"
	MerchantRefund     TransactionType = "merchant_refund"
)

// LedgerAccount represents an account in the double-entry system.
type LedgerAccount struct {
	ID          uuid.UUID   `json:"id"`
	UserID      *uuid.UUID  `json:"user_id,omitempty"` // nil for system accounts
	Currency    string      `json:"currency"`
	AccountType AccountType `json:"account_type"`
	Name        string      `json:"name"`
	CreatedAt   time.Time   `json:"created_at"`
}

// JournalEntry represents a single business transaction which will contain multiple postings.
// Invariant: SUM(Credits) == SUM(Debits) for every journal entry.
type JournalEntry struct {
	ID              uuid.UUID       `json:"id"`
	TransactionType TransactionType `json:"transaction_type"`
	ReferenceID     string          `json:"reference_id"` // External reference (e.g. MoMo tx ID)
	Description     string          `json:"description"`
	CreatedAt       time.Time       `json:"created_at"`
}

// LedgerPosting represents a single credit or debit in a journal entry.
type LedgerPosting struct {
	ID             uuid.UUID `json:"id"`
	JournalEntryID uuid.UUID `json:"journal_entry_id"`
	AccountID      uuid.UUID `json:"account_id"`
	Amount         int64     `json:"amount"` // Stored in smallest currency unit (e.g. cents)
	IsCredit       bool      `json:"is_credit"`
	CreatedAt      time.Time `json:"created_at"`
}

// LedgerService defines the interface for double-entry accounting operations.
// These interfaces will be implemented when MÏÏghOPay is built.
type LedgerService interface {
	CreateAccount(ctx context.Context, userID *uuid.UUID, currency string, accountType AccountType) (*LedgerAccount, error)
	PostEntry(ctx context.Context, entry *JournalEntry, postings []*LedgerPosting) error
	GetBalance(ctx context.Context, accountID uuid.UUID) (int64, error)
	GetStatement(ctx context.Context, accountID uuid.UUID, from, to time.Time, cursor string, limit int) ([]*LedgerPosting, string, error)
}

// PaymentRequest represents a request to a PSP.
type PaymentRequest struct {
	ReferenceID string `json:"reference_id"`
	Status      string `json:"status"` // "pending", "success", "failed"
}

// PaymentStatus represents the result of a payment check.
type PaymentStatus struct {
	ReferenceID string `json:"reference_id"`
	Status      string `json:"status"`
	Reason      string `json:"reason,omitempty"`
}

// PaymentGateway interface for PSP adapter pattern.
type PaymentGateway interface {
	InitiateCollection(ctx context.Context, phone string, amount int64, currency, reference string) (*PaymentRequest, error)
	CheckStatus(ctx context.Context, referenceID string) (*PaymentStatus, error)
	InitiateDisbursement(ctx context.Context, phone string, amount int64, currency, reference string) (*PaymentRequest, error)
}
