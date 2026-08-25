package psp

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
)

// Domain Errors for PSP Gateway Abstraction
var (
	ErrPSPTransactionNotFound    = errors.New("psp transaction not found")
	ErrDuplicatePSPTransaction   = errors.New("duplicate psp transaction")
	ErrInvalidPSPOperation       = errors.New("invalid psp operation")
	ErrPSPProviderUnavailable    = errors.New("psp provider is unavailable or unsupported")
	ErrWebhookVerificationFailed = errors.New("psp webhook signature verification failed")
	ErrWebhookAlreadyProcessed   = errors.New("psp webhook event has already been processed")
	ErrCurrencyMismatch          = errors.New("currency mismatch on psp operation")
	ErrInvalidAmount             = errors.New("psp amount must be strictly greater than zero")
	ErrUnauthorizedPSPOperation  = errors.New("unauthorized psp operation")
)

// PSPStatus represents the normalized, unified payment status across all PSP providers.
// INVARIANT: Provider-specific statuses (e.g., CinetPay ACCEPTED, Wave SUCCESS, MTN COMPLETED)
// MUST ALWAYS be normalized to one of these unified statuses.
type PSPStatus string

const (
	PSPStatusPending    PSPStatus = "PENDING"
	PSPStatusProcessing PSPStatus = "PROCESSING"
	PSPStatusSucceeded  PSPStatus = "SUCCEEDED"
	PSPStatusFailed     PSPStatus = "FAILED"
	PSPStatusCancelled  PSPStatus = "CANCELLED"
	PSPStatusExpired    PSPStatus = "EXPIRED"
	PSPStatusUnknown    PSPStatus = "UNKNOWN"
)

// PSPPaymentRequest represents a request to initiate a payment on a PSP rail.
type PSPPaymentRequest struct {
	InternalReference string            `json:"internal_reference"` // e.g. PaymentIntent ID
	PaymentIntentID   *uuid.UUID        `json:"payment_intent_id,omitempty"`
	BusinessID        *uuid.UUID        `json:"business_id,omitempty"`
	PayerUserID       *uuid.UUID        `json:"payer_user_id,omitempty"`
	Amount            int64             `json:"amount"` // in minor units (FCFA)
	Currency          string            `json:"currency"`
	Description       string            `json:"description,omitempty"`
	IdempotencyKey    string            `json:"idempotency_key"`
	CustomerPhone     string            `json:"customer_phone,omitempty"`
	CustomerEmail     string            `json:"customer_email,omitempty"`
	Metadata          map[string]string `json:"metadata,omitempty"`
	// Simulation flag for deterministic Sandbox testing
	SimulationAction string `json:"simulation_action,omitempty"` // e.g. "simulate_fail", "simulate_pending", "simulate_expire"
}

// PSPPaymentResponse represents the normalized response after initiating or querying a payment.
type PSPPaymentResponse struct {
	Provider          string     `json:"provider"`
	PSPTransactionID  string     `json:"psp_transaction_id"`
	InternalReference string     `json:"internal_reference"`
	Amount            int64      `json:"amount"`
	Currency          string     `json:"currency"`
	Status            PSPStatus  `json:"status"`
	CheckoutURL       string     `json:"checkout_url,omitempty"`
	FailureCode       string     `json:"failure_code,omitempty"`
	FailureReason     string     `json:"failure_reason,omitempty"`
	RawResponse       string     `json:"raw_response,omitempty"`
	CreatedAt         time.Time  `json:"created_at"`
	CompletedAt       *time.Time `json:"completed_at,omitempty"`
}

// PSPRefundRequest represents a request to refund an existing payment on a PSP rail.
type PSPRefundRequest struct {
	InternalReference string            `json:"internal_reference"` // e.g. Refund ID
	RefundID          *uuid.UUID        `json:"refund_id,omitempty"`
	OriginalPSPTxID   string            `json:"original_psp_tx_id"`
	PaymentIntentID   *uuid.UUID        `json:"payment_intent_id,omitempty"`
	BusinessID        *uuid.UUID        `json:"business_id,omitempty"`
	Amount            int64             `json:"amount"`
	Currency          string            `json:"currency"`
	Reason            string            `json:"reason,omitempty"`
	IdempotencyKey    string            `json:"idempotency_key"`
	Metadata          map[string]string `json:"metadata,omitempty"`
	SimulationAction  string            `json:"simulation_action,omitempty"` // e.g. "simulate_fail"
}

// PSPRefundResponse represents the normalized response after processing a refund on a PSP rail.
type PSPRefundResponse struct {
	Provider          string     `json:"provider"`
	PSPRefundID       string     `json:"psp_refund_id"`
	OriginalPSPTxID   string     `json:"original_psp_tx_id"`
	InternalReference string     `json:"internal_reference"`
	Amount            int64      `json:"amount"`
	Currency          string     `json:"currency"`
	Status            PSPStatus  `json:"status"`
	FailureCode       string     `json:"failure_code,omitempty"`
	FailureReason     string     `json:"failure_reason,omitempty"`
	RawResponse       string     `json:"raw_response,omitempty"`
	CreatedAt         time.Time  `json:"created_at"`
	CompletedAt       *time.Time `json:"completed_at,omitempty"`
}

// PSPPayoutRequest represents a request to initiate a payout / settlement to a merchant on a PSP rail.
type PSPPayoutRequest struct {
	InternalReference  string            `json:"internal_reference"` // e.g. Settlement ID
	SettlementID       *uuid.UUID        `json:"settlement_id,omitempty"`
	BusinessID         *uuid.UUID        `json:"business_id,omitempty"`
	Amount             int64             `json:"amount"`
	Currency           string            `json:"currency"`
	DestinationType    string            `json:"destination_type"` // e.g. "momo", "bank"
	DestinationAccount string            `json:"destination_account"`
	IdempotencyKey     string            `json:"idempotency_key"`
	Description        string            `json:"description,omitempty"`
	Metadata           map[string]string `json:"metadata,omitempty"`
	SimulationAction   string            `json:"simulation_action,omitempty"` // e.g. "simulate_fail"
}

// PSPPayoutResponse represents the normalized response after initiating or querying a payout on a PSP rail.
type PSPPayoutResponse struct {
	Provider          string     `json:"provider"`
	PSPPayoutID       string     `json:"psp_payout_id"`
	InternalReference string     `json:"internal_reference"`
	Amount            int64      `json:"amount"`
	Currency          string     `json:"currency"`
	Status            PSPStatus  `json:"status"`
	FailureCode       string     `json:"failure_code,omitempty"`
	FailureReason     string     `json:"failure_reason,omitempty"`
	RawResponse       string     `json:"raw_response,omitempty"`
	CreatedAt         time.Time  `json:"created_at"`
	CompletedAt       *time.Time `json:"completed_at,omitempty"`
}

// PSPWebhookEvent represents a normalized webhook event received from a PSP rail.
type PSPWebhookEvent struct {
	EventID           string            `json:"event_id"`
	Provider          string            `json:"provider"`
	EventType         string            `json:"event_type"` // e.g. "payment.succeeded", "refund.succeeded", "payout.failed"
	PSPTransactionID  string            `json:"psp_transaction_id"`
	InternalReference string            `json:"internal_reference"`
	Status            PSPStatus         `json:"status"`
	Amount            int64             `json:"amount"`
	Currency          string            `json:"currency"`
	FailureCode       string            `json:"failure_code,omitempty"`
	FailureReason     string            `json:"failure_reason,omitempty"`
	RawPayload        string            `json:"raw_payload"`
	Metadata          map[string]string `json:"metadata,omitempty"`
	Timestamp         time.Time         `json:"timestamp"`
}

// PSPProvider defines the standard, decoupled interface for any payment provider rail.
// INVARIANT: All providers (Sandbox or future real PSPs) MUST implement this exact contract.
type PSPProvider interface {
	// ProviderName returns the identifier of the provider (e.g. "sandbox", "cinetpay", "wave").
	ProviderName() string

	// CreatePayment initiates a payment on the rail.
	CreatePayment(ctx context.Context, req *PSPPaymentRequest) (*PSPPaymentResponse, error)

	// GetPaymentStatus checks the status of a payment by its provider-specific ID.
	GetPaymentStatus(ctx context.Context, pspTxID string) (*PSPPaymentResponse, error)

	// RefundPayment initiates a full or partial refund on the rail.
	RefundPayment(ctx context.Context, req *PSPRefundRequest) (*PSPRefundResponse, error)

	// InitiatePayout initiates a disbursement to a merchant destination.
	InitiatePayout(ctx context.Context, req *PSPPayoutRequest) (*PSPPayoutResponse, error)

	// GetPayoutStatus checks the status of a payout by its provider-specific ID.
	GetPayoutStatus(ctx context.Context, pspPayoutID string) (*PSPPayoutResponse, error)

	// ProcessWebhook parses and verifies an incoming webhook payload and normalizes it.
	ProcessWebhook(ctx context.Context, payload []byte, headers map[string]string) (*PSPWebhookEvent, error)
}
