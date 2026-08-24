package ledger

import (
	"time"

	"github.com/google/uuid"
)

// TransactionStatus defines the lifecycle status of a financial transaction.
type TransactionStatus string

const (
	StatusPending   TransactionStatus = "PENDING"
	StatusPosted    TransactionStatus = "POSTED"
	StatusFailed    TransactionStatus = "FAILED"
	StatusCancelled TransactionStatus = "CANCELLED"
	StatusReversed  TransactionStatus = "REVERSED"
)

// Direction of posting for ledger consistency.
type PostingDirection string

const (
	Debit  PostingDirection = "DEBIT"
	Credit PostingDirection = "CREDIT"
)

// DetailedJournalEntry contains a JournalEntry and all its associated postings with account names.
type DetailedJournalEntry struct {
	Entry    *JournalEntry           `json:"entry"`
	Status   TransactionStatus       `json:"status"`
	Postings []*DetailedLedgerPosting `json:"postings"`
	TotalDebit  int64               `json:"total_debit"`
	TotalCredit int64               `json:"total_credit"`
	IsBalanced  bool                `json:"is_balanced"`
}

// DetailedLedgerPosting extends LedgerPosting with account name, direction, and formatted currency.
type DetailedLedgerPosting struct {
	ID             uuid.UUID        `json:"id"`
	JournalEntryID uuid.UUID        `json:"journal_entry_id"`
	AccountID      uuid.UUID        `json:"account_id"`
	AccountName    string           `json:"account_name"`
	AccountType    AccountType      `json:"account_type"`
	Amount         int64            `json:"amount"` // in smallest currency unit (e.g. integer FCFA or cents)
	Currency       string           `json:"currency"`
	IsCredit       bool             `json:"is_credit"`
	Direction      PostingDirection `json:"direction"`
	CreatedAt      time.Time        `json:"created_at"`
}

// WalletSummary represents the synthesized state of a user's wallet derived from ledger entries.
type WalletSummary struct {
	AccountID        uuid.UUID `json:"account_id"`
	UserID           uuid.UUID `json:"user_id"`
	MiighoID         string    `json:"miigho_id"`
	Currency         string    `json:"currency"`
	AvailableBalance int64     `json:"available_balance"`
	PendingBalance   int64     `json:"pending_balance"`
	TotalIncoming    int64     `json:"total_incoming"`
	TotalOutgoing    int64     `json:"total_outgoing"`
	IsSandbox        bool      `json:"is_sandbox"`
	LastUpdated      time.Time `json:"last_updated"`
}

// UserTransactionItem represents a user-friendly transaction for the standard UI history.
type UserTransactionItem struct {
	ID             uuid.UUID         `json:"id"`
	JournalEntryID uuid.UUID         `json:"journal_entry_id"`
	Title          string            `json:"title"`
	Subtitle       string            `json:"subtitle"`
	Amount         int64             `json:"amount"`
	Currency       string            `json:"currency"`
	IsCredit       bool              `json:"is_credit"`
	Type           TransactionType   `json:"type"`
	Status         TransactionStatus `json:"status"`
	ReferenceID    string            `json:"reference_id"`
	CreatedAt      time.Time         `json:"created_at"`
	Counterparty   string            `json:"counterparty,omitempty"`
}

// TransferRequest is the payload to execute a P2P transfer.
type TransferRequest struct {
	ToUserID       *uuid.UUID `json:"to_user_id,omitempty"`
	ToMiighoID     string     `json:"to_miigho_id,omitempty"`
	ToPhone        string     `json:"to_phone,omitempty"`
	Amount         int64      `json:"amount" validate:"required,gt=0"`
	Currency       string     `json:"currency" validate:"required"`
	Description    string     `json:"description"`
	IdempotencyKey string     `json:"idempotency_key" validate:"required"`
}

// CashInRequest is the payload to simulate a Mobile Money / Card recharge.
type CashInRequest struct {
	Provider       string `json:"provider" validate:"required"` // wave, orange_money, mtn_momo, card
	PhoneNumber    string `json:"phone_number"`
	Amount         int64  `json:"amount" validate:"required,gt=0"`
	Currency       string `json:"currency" validate:"required"`
	IdempotencyKey string `json:"idempotency_key" validate:"required"`
}

// CashOutRequest is the payload to simulate a Mobile Money withdrawal.
type CashOutRequest struct {
	Provider       string `json:"provider" validate:"required"` // wave, orange_money, mtn_momo
	PhoneNumber    string `json:"phone_number" validate:"required"`
	Amount         int64  `json:"amount" validate:"required,gt=0"`
	Currency       string `json:"currency" validate:"required"`
	IdempotencyKey string `json:"idempotency_key" validate:"required"`
}

// QRPayRequest is the payload to pay a merchant or user by scanning their QR code.
type QRPayRequest struct {
	QRData         string `json:"qr_data" validate:"required"` // miigho://pay?to=...&amount=...
	Amount         int64  `json:"amount" validate:"required,gt=0"`
	Currency       string `json:"currency" validate:"required"`
	Description    string `json:"description"`
	IdempotencyKey string `json:"idempotency_key" validate:"required"`
}
