package business

import (
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/ledger"
)

var (
	ErrBusinessNotFound              = errors.New("business not found")
	ErrBusinessClosed                = errors.New("business is closed")
	ErrBusinessSuspended             = errors.New("business is suspended")
	ErrUnauthorizedAccess            = errors.New("unauthorized: user is not a member of this business")
	ErrInsufficientPermission        = errors.New("insufficient permission for this action")
	ErrDuplicateMember               = errors.New("user is already a member of this business")
	ErrMemberNotFound                = errors.New("business member not found")
	ErrCannotRemoveOwner             = errors.New("cannot remove or demote the only business owner")
	ErrInvalidRole                   = errors.New("invalid member role")
	ErrInvalidStatus                 = errors.New("invalid business status")
	ErrBusinessAccountNotFound       = errors.New("business account not found")
	ErrMerchantQRNotFound            = errors.New("merchant qr code not found")
	ErrMerchantQRInvalid             = errors.New("merchant qr code is disabled or invalid")
	ErrMerchantQRRevoked             = errors.New("merchant qr code is revoked")
	ErrPaymentIntentNotFound         = errors.New("payment intent not found")
	ErrPaymentIntentExpired          = errors.New("payment intent has expired")
	ErrPaymentIntentAlreadySucceeded = errors.New("payment intent has already succeeded")
	ErrPaymentIntentInvalidStatus    = errors.New("payment intent is not in a confirmable status")
	ErrSelfPaymentNotAllowed         = errors.New("self-payment is not allowed: you cannot pay your own business")
	ErrCurrencyMismatch              = errors.New("currency mismatch between payment and business")
	ErrPaymentFailed                 = errors.New("payment failed: insufficient funds or transaction error")
	ErrRefundNotFound                = errors.New("refund not found")
	ErrRefundAmountExceedsRemaining  = errors.New("refund amount exceeds remaining refundable amount")
	ErrPaymentNotEligibleForRefund   = errors.New("payment intent is not eligible for refund: status must be SUCCEEDED")
	ErrAlreadyFullyRefunded          = errors.New("payment intent is already fully refunded")
	ErrInvalidRefundAmount           = errors.New("refund amount must be strictly greater than zero")
	ErrSettlementNotFound            = errors.New("settlement not found")
	ErrNoEligiblePayments            = errors.New("no eligible succeeded payments available for settlement")
	ErrOverSettlement                = errors.New("settlement amount exceeds available net settleable amount")
	ErrAlreadyFullySettled           = errors.New("payment intent is already fully settled")
	ErrSettlementCurrencyMismatch    = errors.New("settlement currency mismatch")
	ErrSettlementAlreadyProcessed    = errors.New("settlement has already been processed")
	ErrInvalidSettlementAmount       = errors.New("settlement amount must be strictly greater than zero")
	ErrSettlementNotPending          = errors.New("settlement must be in PENDING status to be processed")
)

type RefundStatus string

const (
	RefundRequested RefundStatus = "REQUESTED"
	RefundSucceeded RefundStatus = "SUCCEEDED"
	RefundFailed    RefundStatus = "FAILED"
	RefundCancelled RefundStatus = "CANCELLED"
)

// Refund represents a merchant-initiated full or partial refund on a Succeeded Payment Intent.
type Refund struct {
	ID              uuid.UUID    `json:"id"`
	PaymentIntentID uuid.UUID    `json:"payment_intent_id"`
	BusinessID      uuid.UUID    `json:"business_id"`
	PayerUserID     uuid.UUID    `json:"payer_user_id"`
	Amount          int64        `json:"amount"` // in minor units / FCFA
	Currency        string       `json:"currency"`
	Status          RefundStatus `json:"status"`
	Reason          string       `json:"reason,omitempty"`
	IdempotencyKey  string       `json:"idempotency_key,omitempty"`
	JournalEntryID  *uuid.UUID   `json:"journal_entry_id,omitempty"`
	CreatedAt       time.Time    `json:"created_at"`
	CompletedAt     *time.Time   `json:"completed_at,omitempty"`
}

// RefundReceipt represents the audit-proof receipt issued after a successful merchant refund.
type RefundReceipt struct {
	RefundID            uuid.UUID    `json:"refund_id"`
	PaymentIntentID     uuid.UUID    `json:"payment_intent_id"`
	BusinessID          uuid.UUID    `json:"business_id"`
	BusinessName        string       `json:"business_name"`
	PayerUserID         uuid.UUID    `json:"payer_user_id"`
	OriginalAmount      int64        `json:"original_amount"`
	RefundAmount        int64        `json:"refund_amount"`
	TotalRefunded       int64        `json:"total_refunded"`
	RemainingRefundable int64        `json:"remaining_refundable"`
	Currency            string       `json:"currency"`
	Status              RefundStatus `json:"status"`
	Reason              string       `json:"reason,omitempty"`
	JournalEntryID      *uuid.UUID   `json:"journal_entry_id,omitempty"`
	CreatedAt           time.Time    `json:"created_at"`
	CompletedAt         time.Time    `json:"completed_at"`
	IsSandbox           bool         `json:"is_sandbox"`
}

type CreateRefundRequest struct {
	Amount         int64  `json:"amount" validate:"required,gt=0"`
	Reason         string `json:"reason,omitempty"`
	IdempotencyKey string `json:"idempotency_key,omitempty"`
}

type MerchantQRStatus string

const (
	MerchantQRActive   MerchantQRStatus = "ACTIVE"
	MerchantQRDisabled MerchantQRStatus = "DISABLED"
	MerchantQRRevoked  MerchantQRStatus = "REVOKED"
)

type PaymentIntentStatus string

const (
	IntentCreated   PaymentIntentStatus = "CREATED"
	IntentConfirmed PaymentIntentStatus = "CONFIRMED"
	IntentSucceeded PaymentIntentStatus = "SUCCEEDED"
	IntentFailed    PaymentIntentStatus = "FAILED"
	IntentCancelled PaymentIntentStatus = "CANCELLED"
	IntentExpired   PaymentIntentStatus = "EXPIRED"
)

// MerchantQR represents a static or merchant identifier QR code.
type MerchantQR struct {
	ID         uuid.UUID        `json:"id"`
	BusinessID uuid.UUID        `json:"business_id"`
	Code       string           `json:"code"`
	Status     MerchantQRStatus `json:"status"`
	CreatedAt  time.Time        `json:"created_at"`
	UpdatedAt  time.Time        `json:"updated_at"`
}

// PublicMerchantQRInfo exposes safe, sanitized public metadata when resolving a QR code.
type PublicMerchantQRInfo struct {
	BusinessID   uuid.UUID      `json:"business_id"`
	DisplayName  string         `json:"display_name"`
	BusinessType string         `json:"business_type"`
	Country      string         `json:"country"`
	Currency     string         `json:"currency"`
	Status       BusinessStatus `json:"status"`
	QRCode       string         `json:"qr_code"`
}

// PaymentIntent represents a customer payment intention before or after ledger execution.
type PaymentIntent struct {
	ID             uuid.UUID           `json:"id"`
	BusinessID     uuid.UUID           `json:"business_id"`
	PayerUserID    uuid.UUID           `json:"payer_user_id"`
	MerchantQRID   *uuid.UUID          `json:"merchant_qr_id,omitempty"`
	Amount         int64               `json:"amount"` // in minor units / FCFA
	Currency       string              `json:"currency"`
	Status         PaymentIntentStatus `json:"status"`
	IdempotencyKey string              `json:"idempotency_key,omitempty"`
	CreatedAt      time.Time           `json:"created_at"`
	ExpiresAt      time.Time           `json:"expires_at"`
	ConfirmedAt    *time.Time          `json:"confirmed_at,omitempty"`
	JournalEntryID *uuid.UUID          `json:"journal_entry_id,omitempty"`
}

// MerchantPaymentReceipt represents the final receipt of an authorized and settled payment.
type MerchantPaymentReceipt struct {
	PaymentIntentID uuid.UUID           `json:"payment_intent_id"`
	BusinessID      uuid.UUID           `json:"business_id"`
	BusinessName    string              `json:"business_name"`
	PayerUserID     uuid.UUID           `json:"payer_user_id"`
	Amount          int64               `json:"amount"`
	Currency        string              `json:"currency"`
	Status          PaymentIntentStatus `json:"status"`
	JournalEntryID  *uuid.UUID          `json:"journal_entry_id,omitempty"`
	ConfirmedAt     time.Time           `json:"confirmed_at"`
	IsSandbox       bool                `json:"is_sandbox"`
}

type CreateMerchantQRRequest struct {
	CustomCode string `json:"custom_code,omitempty"`
}

type CreatePaymentIntentRequest struct {
	QRCode         string `json:"qr_code" validate:"required"`
	Amount         int64  `json:"amount" validate:"required,gt=0"`
	Currency       string `json:"currency" validate:"required"`
	IdempotencyKey string `json:"idempotency_key,omitempty"`
}

type ConfirmPaymentIntentRequest struct {
	IdempotencyKey string `json:"idempotency_key,omitempty"`
}

type BusinessStatus string

const (
	StatusPending   BusinessStatus = "PENDING"
	StatusActive    BusinessStatus = "ACTIVE"
	StatusSuspended BusinessStatus = "SUSPENDED"
	StatusClosed    BusinessStatus = "CLOSED"
)

type MemberRole string

const (
	RoleOwner   MemberRole = "OWNER"
	RoleAdmin   MemberRole = "ADMIN"
	RoleManager MemberRole = "MANAGER"
	RoleCashier MemberRole = "CASHIER"
)

type MemberStatus string

const (
	MemberStatusActive    MemberStatus = "ACTIVE"
	MemberStatusInactive  MemberStatus = "INACTIVE"
	MemberStatusSuspended MemberStatus = "SUSPENDED"
)

type BusinessAccountStatus string

const (
	AccountStatusActive    BusinessAccountStatus = "ACTIVE"
	AccountStatusSuspended BusinessAccountStatus = "SUSPENDED"
	AccountStatusClosed    BusinessAccountStatus = "CLOSED"
)

// Business represents a commercial or enterprise entity in MÏÏghO.
type Business struct {
	ID           uuid.UUID      `json:"id"`
	OwnerUserID  uuid.UUID      `json:"owner_user_id"`
	LegalName    string         `json:"legal_name"`
	DisplayName  string         `json:"display_name"`
	BusinessType string         `json:"business_type"`
	Status       BusinessStatus `json:"status"`
	Phone        string         `json:"phone,omitempty"`
	Email        string         `json:"email,omitempty"`
	Country      string         `json:"country"`
	Currency     string         `json:"currency"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
}

// BusinessMember represents an association between a MÏÏghO User and a Business with a specific Role.
type BusinessMember struct {
	ID         uuid.UUID    `json:"id"`
	BusinessID uuid.UUID    `json:"business_id"`
	UserID     uuid.UUID    `json:"user_id"`
	Role       MemberRole   `json:"role"`
	Status     MemberStatus `json:"status"`
	CreatedAt  time.Time    `json:"created_at"`
	UpdatedAt  time.Time    `json:"updated_at"`

	// Optional enriched display info
	UserDisplayName string `json:"user_display_name,omitempty"`
	UserMiighoID    string `json:"user_miigho_id,omitempty"`
	UserPhone       string `json:"user_phone,omitempty"`
}

// BusinessAccount represents the financial account of a Business, linked 1:1 to a LedgerAccount.
// Note: Balance is NEVER stored here. It is strictly derived from the Double-Entry Ledger.
type BusinessAccount struct {
	ID              uuid.UUID             `json:"id"`
	BusinessID      uuid.UUID             `json:"business_id"`
	LedgerAccountID uuid.UUID             `json:"ledger_account_id"`
	Currency        string                `json:"currency"`
	Status          BusinessAccountStatus `json:"status"`
	CreatedAt       time.Time             `json:"created_at"`
	UpdatedAt       time.Time             `json:"updated_at"`
}

// DTOs

type CreateBusinessRequest struct {
	LegalName    string `json:"legal_name" validate:"required,min=2,max=255"`
	DisplayName  string `json:"display_name" validate:"required,min=2,max=255"`
	BusinessType string `json:"business_type" validate:"required"`
	Phone        string `json:"phone,omitempty"`
	Email        string `json:"email,omitempty" validate:"omitempty,email"`
	Country      string `json:"country" validate:"required,len=2"`
	Currency     string `json:"currency" validate:"required,oneof=FCFA XOF USD EUR NGN KES CDF"`
}

type UpdateBusinessRequest struct {
	DisplayName  *string         `json:"display_name,omitempty"`
	BusinessType *string         `json:"business_type,omitempty"`
	Phone        *string         `json:"phone,omitempty"`
	Email        *string         `json:"email,omitempty"`
	Status       *BusinessStatus `json:"status,omitempty"`
}

type AddMemberRequest struct {
	UserID uuid.UUID  `json:"user_id" validate:"required"`
	Role   MemberRole `json:"role" validate:"required,oneof=OWNER ADMIN MANAGER CASHIER"`
}

type UpdateMemberRoleRequest struct {
	Role   MemberRole    `json:"role" validate:"required,oneof=OWNER ADMIN MANAGER CASHIER"`
	Status *MemberStatus `json:"status,omitempty"`
}

type BusinessSummary struct {
	Business         *Business  `json:"business"`
	UserRole         MemberRole `json:"user_role"`
	AvailableBalance int64      `json:"available_balance"`
	Currency         string     `json:"currency"`
}

type BusinessDetail struct {
	Business         *Business         `json:"business"`
	Account          *BusinessAccount  `json:"account"`
	UserRole         MemberRole        `json:"user_role"`
	Members          []*BusinessMember `json:"members"`
	AvailableBalance int64             `json:"available_balance"`
	Currency         string            `json:"currency"`
}

type BusinessAccountDetail struct {
	Account          *BusinessAccount      `json:"account"`
	LedgerAccount    *ledger.LedgerAccount `json:"ledger_account"`
	AvailableBalance int64                 `json:"available_balance"`
	PendingBalance   int64                 `json:"pending_balance"`
	Currency         string                `json:"currency"`
	IsSandbox        bool                  `json:"is_sandbox"`
}

// ════════════════════════════════════════════════
// MERCHANT SETTLEMENT DOMAIN (PHASE 3A.4)
// ════════════════════════════════════════════════

type SettlementStatus string

const (
	SettlementPending    SettlementStatus = "PENDING"
	SettlementProcessing SettlementStatus = "PROCESSING"
	SettlementSucceeded  SettlementStatus = "SUCCEEDED"
	SettlementFailed     SettlementStatus = "FAILED"
	SettlementCancelled  SettlementStatus = "CANCELLED"
)

// Settlement represents an internal batch settlement for a merchant.
// Note: Balance/amounts are derived and verified against the Ledger.
type Settlement struct {
	ID             uuid.UUID        `json:"id"`
	BusinessID     uuid.UUID        `json:"business_id"`
	TotalAmount    int64            `json:"total_amount"` // in minor units / FCFA
	Currency       string           `json:"currency"`
	Status         SettlementStatus `json:"status"`
	IdempotencyKey string           `json:"idempotency_key,omitempty"`
	JournalEntryID *uuid.UUID       `json:"journal_entry_id,omitempty"`
	FailureReason  string           `json:"failure_reason,omitempty"`
	CreatedAt      time.Time        `json:"created_at"`
	ProcessedAt    *time.Time       `json:"processed_at,omitempty"`
}

// SettlementItem represents a single payment transaction included in a settlement batch.
type SettlementItem struct {
	ID              uuid.UUID `json:"id"`
	SettlementID    uuid.UUID `json:"settlement_id"`
	PaymentIntentID uuid.UUID `json:"payment_intent_id"`
	GrossAmount     int64     `json:"gross_amount"`
	RefundAmount    int64     `json:"refund_amount"`
	NetAmount       int64     `json:"net_amount"`
	Currency        string    `json:"currency"`
	CreatedAt       time.Time `json:"created_at"`
}

// SettlementReceipt represents the audit-proof receipt issued after settlement creation or processing.
type SettlementReceipt struct {
	SettlementID   uuid.UUID         `json:"settlement_id"`
	BusinessID     uuid.UUID         `json:"business_id"`
	BusinessName   string            `json:"business_name"`
	TotalAmount    int64             `json:"total_amount"`
	Currency       string            `json:"currency"`
	Status         SettlementStatus  `json:"status"`
	IdempotencyKey string            `json:"idempotency_key,omitempty"`
	JournalEntryID *uuid.UUID        `json:"journal_entry_id,omitempty"`
	FailureReason  string            `json:"failure_reason,omitempty"`
	Items          []*SettlementItem `json:"items"`
	ItemCount      int               `json:"item_count"`
	CreatedAt      time.Time         `json:"created_at"`
	ProcessedAt    *time.Time        `json:"processed_at,omitempty"`
	IsSandbox      bool              `json:"is_sandbox"`
}

type CreateSettlementRequest struct {
	Amount         int64  `json:"amount,omitempty"` // Optional: If 0/omitted, settles all eligible funds
	Currency       string `json:"currency,omitempty"`
	IdempotencyKey string `json:"idempotency_key,omitempty"`
}

type EligibleSettlementCalculation struct {
	BusinessID     uuid.UUID `json:"business_id"`
	Currency       string    `json:"currency"`
	GrossAmount    int64     `json:"gross_amount"`
	TotalRefunded  int64     `json:"total_refunded"`
	AlreadySettled int64     `json:"already_settled"`
	NetSettleable  int64     `json:"net_settleable"`
	EligibleCount  int       `json:"eligible_count"`
}
