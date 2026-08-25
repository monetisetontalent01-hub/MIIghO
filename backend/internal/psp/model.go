package psp

import (
	"time"

	"github.com/google/uuid"
)

// PSPTransaction models the audit and correlation entity for all operations on PSP rails.
// INVARIANT: This table tracks provider state and references without storing mutable financial balances.
type PSPTransaction struct {
	ID                uuid.UUID  `json:"id"`
	Provider          string     `json:"provider"`
	OperationType     string     `json:"operation_type"` // "payment", "refund", "payout"
	InternalReference string     `json:"internal_reference"`
	PSPTransactionID  string     `json:"psp_transaction_id"`
	PaymentIntentID   *uuid.UUID `json:"payment_intent_id,omitempty"`
	RefundID          *uuid.UUID `json:"refund_id,omitempty"`
	SettlementID      *uuid.UUID `json:"settlement_id,omitempty"`
	Amount            int64      `json:"amount"` // in minor units / FCFA
	Currency          string     `json:"currency"`
	Status            PSPStatus  `json:"status"`
	IdempotencyKey    string     `json:"idempotency_key,omitempty"`
	RequestReference  string     `json:"request_reference,omitempty"`
	ResponseReference string     `json:"response_reference,omitempty"`
	FailureCode       string     `json:"failure_code,omitempty"`
	FailureReason     string     `json:"failure_reason,omitempty"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
	CompletedAt       *time.Time `json:"completed_at,omitempty"`
}

// PSPWebhookRecord models persistent storage for incoming webhook events to guarantee idempotency and audit.
type PSPWebhookRecord struct {
	ID           uuid.UUID  `json:"id"`
	Provider     string     `json:"provider"`
	EventID      string     `json:"event_id"`
	EventType    string     `json:"event_type"`
	Payload      string     `json:"payload"`
	Status       string     `json:"status"` // "RECEIVED", "PROCESSED", "FAILED", "IGNORED"
	ReceivedAt   time.Time  `json:"received_at"`
	ProcessedAt  *time.Time `json:"processed_at,omitempty"`
	ErrorMessage string     `json:"error_message,omitempty"`
}
