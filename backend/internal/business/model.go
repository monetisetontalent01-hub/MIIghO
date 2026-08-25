package business

import (
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/ledger"
)

var (
	ErrBusinessNotFound       = errors.New("business not found")
	ErrBusinessClosed         = errors.New("business is closed")
	ErrBusinessSuspended      = errors.New("business is suspended")
	ErrUnauthorizedAccess     = errors.New("unauthorized: user is not a member of this business")
	ErrInsufficientPermission = errors.New("insufficient permission for this action")
	ErrDuplicateMember        = errors.New("user is already a member of this business")
	ErrMemberNotFound         = errors.New("business member not found")
	ErrCannotRemoveOwner      = errors.New("cannot remove or demote the only business owner")
	ErrInvalidRole            = errors.New("invalid member role")
	ErrInvalidStatus          = errors.New("invalid business status")
	ErrBusinessAccountNotFound = errors.New("business account not found")
)

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
	ID          uuid.UUID      `json:"id"`
	OwnerUserID uuid.UUID      `json:"owner_user_id"`
	LegalName   string         `json:"legal_name"`
	DisplayName string         `json:"display_name"`
	BusinessType string        `json:"business_type"`
	Status      BusinessStatus `json:"status"`
	Phone       string         `json:"phone,omitempty"`
	Email       string         `json:"email,omitempty"`
	Country     string         `json:"country"`
	Currency    string         `json:"currency"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
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
	Business        *Business  `json:"business"`
	UserRole        MemberRole `json:"user_role"`
	AvailableBalance int64     `json:"available_balance"`
	Currency        string     `json:"currency"`
}

type BusinessDetail struct {
	Business        *Business          `json:"business"`
	Account         *BusinessAccount   `json:"account"`
	UserRole        MemberRole         `json:"user_role"`
	Members         []*BusinessMember  `json:"members"`
	AvailableBalance int64             `json:"available_balance"`
	Currency        string             `json:"currency"`
}

type BusinessAccountDetail struct {
	Account         *BusinessAccount       `json:"account"`
	LedgerAccount   *ledger.LedgerAccount  `json:"ledger_account"`
	AvailableBalance int64                 `json:"available_balance"`
	PendingBalance  int64                  `json:"pending_balance"`
	Currency        string                 `json:"currency"`
	IsSandbox       bool                   `json:"is_sandbox"`
}
