package business

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/ledger"
)

// SettlementProvider defines the interface for executing merchant settlement disbursements.
type SettlementProvider interface {
	ProcessSettlement(ctx context.Context, settlement *Settlement) error
}

// SandboxSettlementProvider simulates immediate 100% sandbox processing with 0 real PSP calls.
type SandboxSettlementProvider struct{}

func NewSandboxSettlementProvider() *SandboxSettlementProvider {
	return &SandboxSettlementProvider{}
}

func (p *SandboxSettlementProvider) ProcessSettlement(ctx context.Context, settlement *Settlement) error {
	// 100% Sandbox simulation - 0 external calls
	return nil
}

// Service coordinates business logic, authorization rules, and double-entry ledger linkage.
type Service struct {
	repo               Repository
	ledgerRepo         ledger.Repository
	settlementProvider SettlementProvider
	settlementMu       sync.Mutex
	paymentMu          sync.Mutex
}

func NewService(repo Repository, ledgerRepo ledger.Repository) *Service {
	return &Service{
		repo:               repo,
		ledgerRepo:         ledgerRepo,
		settlementProvider: NewSandboxSettlementProvider(),
	}
}

func (s *Service) SetSettlementProvider(p SettlementProvider) {
	s.settlementProvider = p
}

// ════════════════════════════════════════════════
// AUTHORIZATION POLICY MATRIX
// ════════════════════════════════════════════════

func CanViewBusiness(role MemberRole, status BusinessStatus) bool {
	return true
}

func CanUpdateBusiness(role MemberRole, status BusinessStatus) bool {
	if status == StatusClosed {
		return false
	}
	return role == RoleOwner || role == RoleAdmin
}

func CanAddMember(role MemberRole, status BusinessStatus) bool {
	if status == StatusClosed || status == StatusSuspended {
		return false
	}
	return role == RoleOwner || role == RoleAdmin
}

func CanViewAccount(role MemberRole, status BusinessStatus) bool {
	return true
}

// ════════════════════════════════════════════════
// SERVICE METHODS
// ════════════════════════════════════════════════

// CreateBusiness creates a new Business, an associated Ledger Account (with 0 balance / 0 postings),
// a Business Account linkage, and automatically assigns the creator as OWNER.
func (s *Service) CreateBusiness(ctx context.Context, ownerUserID uuid.UUID, req *CreateBusinessRequest) (*BusinessDetail, error) {
	if req.Currency == "" {
		req.Currency = "FCFA"
	}
	if req.Country == "" {
		req.Country = "CI"
	}

	bizID := uuid.New()
	ledgerAccID := uuid.New()
	now := time.Now().UTC()

	// 1. Prepare Ledger Account (Asset account for the business entity)
	ledgerAcc := &ledger.LedgerAccount{
		ID:          ledgerAccID,
		UserID:      nil, // Business entity account, distinct from individual user wallet
		Currency:    req.Currency,
		AccountType: ledger.Asset,
		Name:        fmt.Sprintf("Compte Entreprise • %s", req.DisplayName),
		CreatedAt:   now,
	}

	// 2. Prepare Business Entity
	biz := &Business{
		ID:           bizID,
		OwnerUserID:  ownerUserID,
		LegalName:    req.LegalName,
		DisplayName:  req.DisplayName,
		BusinessType: req.BusinessType,
		Status:       StatusActive,
		Phone:        req.Phone,
		Email:        req.Email,
		Country:      req.Country,
		Currency:     req.Currency,
		CreatedAt:    now,
		UpdatedAt:    now,
	}

	// 3. Prepare Business Account
	bizAccount := &BusinessAccount{
		ID:              uuid.New(),
		BusinessID:      bizID,
		LedgerAccountID: ledgerAccID,
		Currency:        req.Currency,
		Status:          AccountStatusActive,
		CreatedAt:       now,
		UpdatedAt:       now,
	}

	// 4. Prepare Owner Member
	ownerMember := &BusinessMember{
		ID:         uuid.New(),
		BusinessID: bizID,
		UserID:     ownerUserID,
		Role:       RoleOwner,
		Status:     MemberStatusActive,
		CreatedAt:  now,
		UpdatedAt:  now,
	}

	// 5. Execute Atomic Creation
	if err := s.repo.CreateBusinessWithAccountAndOwner(ctx, biz, bizAccount, ownerMember, ledgerAcc); err != nil {
		return nil, fmt.Errorf("failed to create business: %w", err)
	}

	// 6. Return full business detail (Initial balance is strictly 0 derived from ledger)
	balance, _ := s.ledgerRepo.GetBalance(ctx, ledgerAccID)

	return &BusinessDetail{
		Business:         biz,
		Account:          bizAccount,
		UserRole:         RoleOwner,
		Members:          []*BusinessMember{ownerMember},
		AvailableBalance: balance,
		Currency:         req.Currency,
	}, nil
}

// GetBusiness retrieves a business detail with member list and derived balance from Ledger.
func (s *Service) GetBusiness(ctx context.Context, businessID, requestUserID uuid.UUID) (*BusinessDetail, error) {
	biz, err := s.repo.GetBusiness(ctx, businessID)
	if err != nil {
		return nil, err
	}

	member, err := s.repo.GetMember(ctx, businessID, requestUserID)
	if err != nil {
		return nil, ErrUnauthorizedAccess
	}

	if !CanViewBusiness(member.Role, biz.Status) {
		return nil, ErrInsufficientPermission
	}

	account, err := s.repo.GetBusinessAccount(ctx, businessID)
	if err != nil {
		return nil, err
	}

	members, err := s.repo.GetMembers(ctx, businessID)
	if err != nil {
		return nil, err
	}

	// Derive balance strictly from double-entry ledger
	balance, _ := s.ledgerRepo.GetBalance(ctx, account.LedgerAccountID)

	return &BusinessDetail{
		Business:         biz,
		Account:          account,
		UserRole:         member.Role,
		Members:          members,
		AvailableBalance: balance,
		Currency:         biz.Currency,
	}, nil
}

// ListUserBusinesses returns all active businesses where the user is a member.
func (s *Service) ListUserBusinesses(ctx context.Context, userID uuid.UUID) ([]*BusinessSummary, error) {
	return s.repo.ListBusinessesForUser(ctx, userID)
}

// UpdateBusiness updates business information if requester has OWNER or ADMIN role.
func (s *Service) UpdateBusiness(ctx context.Context, businessID, requestUserID uuid.UUID, req *UpdateBusinessRequest) (*Business, error) {
	biz, err := s.repo.GetBusiness(ctx, businessID)
	if err != nil {
		return nil, err
	}

	member, err := s.repo.GetMember(ctx, businessID, requestUserID)
	if err != nil {
		return nil, ErrUnauthorizedAccess
	}

	if !CanUpdateBusiness(member.Role, biz.Status) {
		return nil, ErrInsufficientPermission
	}

	if req.DisplayName != nil && *req.DisplayName != "" {
		biz.DisplayName = *req.DisplayName
	}
	if req.BusinessType != nil && *req.BusinessType != "" {
		biz.BusinessType = *req.BusinessType
	}
	if req.Phone != nil {
		biz.Phone = *req.Phone
	}
	if req.Email != nil {
		biz.Email = *req.Email
	}
	if req.Status != nil {
		if *req.Status == StatusClosed && member.Role != RoleOwner {
			return nil, ErrInsufficientPermission // Only owner can close a business
		}
		biz.Status = *req.Status
	}

	if err := s.repo.UpdateBusiness(ctx, biz); err != nil {
		return nil, err
	}

	return biz, nil
}

// AddMember adds a new member to the business with a specified role.
func (s *Service) AddMember(ctx context.Context, businessID, requestUserID uuid.UUID, req *AddMemberRequest) (*BusinessMember, error) {
	biz, err := s.repo.GetBusiness(ctx, businessID)
	if err != nil {
		return nil, err
	}

	requester, err := s.repo.GetMember(ctx, businessID, requestUserID)
	if err != nil {
		return nil, ErrUnauthorizedAccess
	}

	if !CanAddMember(requester.Role, biz.Status) {
		return nil, ErrInsufficientPermission
	}

	// Role escalation prevention: ADMIN cannot assign OWNER
	if requester.Role == RoleAdmin && req.Role == RoleOwner {
		return nil, ErrInsufficientPermission
	}

	newMember := &BusinessMember{
		ID:         uuid.New(),
		BusinessID: businessID,
		UserID:     req.UserID,
		Role:       req.Role,
		Status:     MemberStatusActive,
		CreatedAt:  time.Now().UTC(),
		UpdatedAt:  time.Now().UTC(),
	}

	if err := s.repo.AddMember(ctx, newMember); err != nil {
		return nil, err
	}

	return newMember, nil
}

// ListMembers returns the list of all members of a business.
func (s *Service) ListMembers(ctx context.Context, businessID, requestUserID uuid.UUID) ([]*BusinessMember, error) {
	biz, err := s.repo.GetBusiness(ctx, businessID)
	if err != nil {
		return nil, err
	}

	member, err := s.repo.GetMember(ctx, businessID, requestUserID)
	if err != nil {
		return nil, ErrUnauthorizedAccess
	}

	if !CanViewBusiness(member.Role, biz.Status) {
		return nil, ErrInsufficientPermission
	}

	return s.repo.GetMembers(ctx, businessID)
}

// UpdateMemberRole modifies a member's role and status.
func (s *Service) UpdateMemberRole(ctx context.Context, businessID, requestUserID, targetMemberID uuid.UUID, req *UpdateMemberRoleRequest) (*BusinessMember, error) {
	biz, err := s.repo.GetBusiness(ctx, businessID)
	if err != nil {
		return nil, err
	}

	if biz.Status == StatusClosed {
		return nil, ErrBusinessClosed
	}

	requester, err := s.repo.GetMember(ctx, businessID, requestUserID)
	if err != nil {
		return nil, ErrUnauthorizedAccess
	}

	if requester.Role != RoleOwner && requester.Role != RoleAdmin {
		return nil, ErrInsufficientPermission
	}

	targetMember, err := s.repo.GetMemberByID(ctx, targetMemberID)
	if err != nil || targetMember.BusinessID != businessID {
		return nil, ErrMemberNotFound
	}

	// Prevent removing/demoting the only owner
	if targetMember.Role == RoleOwner && req.Role != RoleOwner {
		members, err := s.repo.GetMembers(ctx, businessID)
		if err == nil {
			ownerCount := 0
			for _, m := range members {
				if m.Role == RoleOwner && m.Status == MemberStatusActive {
					ownerCount++
				}
			}
			if ownerCount <= 1 {
				return nil, ErrCannotRemoveOwner
			}
		}
	}

	// Admin privilege restriction: Admin cannot demote/promote Owner
	if requester.Role == RoleAdmin && (targetMember.Role == RoleOwner || req.Role == RoleOwner) {
		return nil, ErrInsufficientPermission
	}

	targetMember.Role = req.Role
	if req.Status != nil {
		targetMember.Status = *req.Status
	}

	if err := s.repo.UpdateMember(ctx, targetMember); err != nil {
		return nil, err
	}

	return targetMember, nil
}

// RemoveMember removes a member from the business.
func (s *Service) RemoveMember(ctx context.Context, businessID, requestUserID, targetMemberID uuid.UUID) error {
	biz, err := s.repo.GetBusiness(ctx, businessID)
	if err != nil {
		return err
	}

	if biz.Status == StatusClosed {
		return ErrBusinessClosed
	}

	requester, err := s.repo.GetMember(ctx, businessID, requestUserID)
	if err != nil {
		return ErrUnauthorizedAccess
	}

	if requester.Role != RoleOwner && requester.Role != RoleAdmin {
		return ErrInsufficientPermission
	}

	targetMember, err := s.repo.GetMemberByID(ctx, targetMemberID)
	if err != nil || targetMember.BusinessID != businessID {
		return ErrMemberNotFound
	}

	// Prevent removing the only owner
	if targetMember.Role == RoleOwner {
		members, err := s.repo.GetMembers(ctx, businessID)
		if err == nil {
			ownerCount := 0
			for _, m := range members {
				if m.Role == RoleOwner && m.Status == MemberStatusActive {
					ownerCount++
				}
			}
			if ownerCount <= 1 {
				return ErrCannotRemoveOwner
			}
		}
	}

	// Admin cannot remove Owner
	if requester.Role == RoleAdmin && targetMember.Role == RoleOwner {
		return ErrInsufficientPermission
	}

	return s.repo.RemoveMember(ctx, businessID, targetMemberID)
}

// GetBusinessAccount returns the financial account detail and balance derived from Ledger.
func (s *Service) GetBusinessAccount(ctx context.Context, businessID, requestUserID uuid.UUID) (*BusinessAccountDetail, error) {
	biz, err := s.repo.GetBusiness(ctx, businessID)
	if err != nil {
		return nil, err
	}

	member, err := s.repo.GetMember(ctx, businessID, requestUserID)
	if err != nil {
		return nil, ErrUnauthorizedAccess
	}

	if !CanViewAccount(member.Role, biz.Status) {
		return nil, ErrInsufficientPermission
	}

	bizAcc, err := s.repo.GetBusinessAccount(ctx, businessID)
	if err != nil {
		return nil, err
	}

	ledgerAcc, err := s.ledgerRepo.GetAccount(ctx, bizAcc.LedgerAccountID)
	if err != nil {
		return nil, err
	}

	// Strictly derive balance from double-entry ledger postings
	balance, _ := s.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)

	return &BusinessAccountDetail{
		Account:          bizAcc,
		LedgerAccount:    ledgerAcc,
		AvailableBalance: balance,
		PendingBalance:   0,
		Currency:         bizAcc.Currency,
		IsSandbox:        true,
	}, nil
}

// ════════════════════════════════════════════════
// MERCHANT QR CODE METHODS (PHASE 3A.2)
// ════════════════════════════════════════════════

// CreateMerchantQR generates a new QR code identifying a business. Only OWNER and ADMIN can create a QR.
func (s *Service) CreateMerchantQR(ctx context.Context, businessID, requestUserID uuid.UUID, req *CreateMerchantQRRequest) (*MerchantQR, error) {
	biz, err := s.repo.GetBusiness(ctx, businessID)
	if err != nil {
		return nil, err
	}

	if biz.Status == StatusClosed {
		return nil, ErrBusinessClosed
	}
	if biz.Status == StatusSuspended {
		return nil, ErrBusinessSuspended
	}

	member, err := s.repo.GetMember(ctx, businessID, requestUserID)
	if err != nil {
		return nil, ErrUnauthorizedAccess
	}

	if member.Role != RoleOwner && member.Role != RoleAdmin {
		return nil, ErrInsufficientPermission
	}

	code := ""
	if req != nil && req.CustomCode != "" {
		code = strings.TrimSpace(req.CustomCode)
	} else {
		// Standardized format: miigho://merchant/MG-{BUSINESS_SLUG}-{RANDOM}
		slug := strings.ToUpper(strings.ReplaceAll(biz.DisplayName, " ", "-"))
		if len(slug) > 12 {
			slug = slug[:12]
		}
		code = fmt.Sprintf("miigho://merchant/MG-%s-%s", slug, uuid.New().String()[:6])
	}

	qr := &MerchantQR{
		ID:         uuid.New(),
		BusinessID: businessID,
		Code:       code,
		Status:     MerchantQRActive,
		CreatedAt:  time.Now().UTC(),
		UpdatedAt:  time.Now().UTC(),
	}

	if err := s.repo.CreateMerchantQR(ctx, qr); err != nil {
		return nil, err
	}

	return qr, nil
}

// ResolveMerchantQR resolves a public QR code to sanitized business information.
func (s *Service) ResolveMerchantQR(ctx context.Context, code string) (*PublicMerchantQRInfo, error) {
	code = strings.TrimSpace(code)
	qr, err := s.repo.GetMerchantQRByCode(ctx, code)
	if err != nil {
		return nil, ErrMerchantQRNotFound
	}

	if qr.Status == MerchantQRRevoked {
		return nil, ErrMerchantQRRevoked
	}
	if qr.Status != MerchantQRActive {
		return nil, ErrMerchantQRInvalid
	}

	biz, err := s.repo.GetBusiness(ctx, qr.BusinessID)
	if err != nil {
		return nil, err
	}

	if biz.Status == StatusClosed {
		return nil, ErrBusinessClosed
	}
	if biz.Status == StatusSuspended {
		return nil, ErrBusinessSuspended
	}

	return &PublicMerchantQRInfo{
		BusinessID:   biz.ID,
		DisplayName:  biz.DisplayName,
		BusinessType: biz.BusinessType,
		Country:      biz.Country,
		Currency:     biz.Currency,
		Status:       biz.Status,
		QRCode:       qr.Code,
	}, nil
}

// RevokeMerchantQR revokes a QR code so it can no longer be used for payments.
func (s *Service) RevokeMerchantQR(ctx context.Context, businessID, requestUserID, qrID uuid.UUID) error {
	biz, err := s.repo.GetBusiness(ctx, businessID)
	if err != nil {
		return err
	}

	if biz.Status == StatusClosed {
		return ErrBusinessClosed
	}

	member, err := s.repo.GetMember(ctx, businessID, requestUserID)
	if err != nil {
		return ErrUnauthorizedAccess
	}

	if member.Role != RoleOwner && member.Role != RoleAdmin {
		return ErrInsufficientPermission
	}

	qr, err := s.repo.GetMerchantQRByID(ctx, qrID)
	if err != nil || qr.BusinessID != businessID {
		return ErrMerchantQRNotFound
	}

	return s.repo.UpdateMerchantQRStatus(ctx, qrID, MerchantQRRevoked)
}

// GetMerchantQRs returns all QR codes for a given business.
func (s *Service) GetMerchantQRs(ctx context.Context, businessID, requestUserID uuid.UUID) ([]*MerchantQR, error) {
	biz, err := s.repo.GetBusiness(ctx, businessID)
	if err != nil {
		return nil, err
	}

	member, err := s.repo.GetMember(ctx, businessID, requestUserID)
	if err != nil {
		return nil, ErrUnauthorizedAccess
	}

	if !CanViewBusiness(member.Role, biz.Status) {
		return nil, ErrInsufficientPermission
	}

	return s.repo.GetMerchantQRsByBusiness(ctx, businessID)
}

// ════════════════════════════════════════════════
// PAYMENT INTENT & CONFIRMATION METHODS (PHASE 3A.2)
// ════════════════════════════════════════════════

// CreatePaymentIntent validates QR code and business details, creating an unconfirmed Payment Intent.
// Note: 0 Ledger entries are created at this step.
func (s *Service) CreatePaymentIntent(ctx context.Context, payerUserID uuid.UUID, req *CreatePaymentIntentRequest) (*PaymentIntent, error) {
	if req.Amount <= 0 {
		return nil, ledger.ErrInvalidAmount
	}

	// Idempotency check if idempotency key is provided
	if req.IdempotencyKey != "" {
		if existing, err := s.repo.GetPaymentIntentByIdempotencyKey(ctx, req.IdempotencyKey); err == nil {
			if existing.Amount != req.Amount || existing.Currency != req.Currency {
				return nil, fmt.Errorf("%w: existing amount=%d, requested amount=%d", ledger.ErrIdempotencyConflict, existing.Amount, req.Amount)
			}
			return existing, nil
		}
	}

	// 1. Resolve QR Code
	qr, err := s.repo.GetMerchantQRByCode(ctx, strings.TrimSpace(req.QRCode))
	if err != nil {
		return nil, ErrMerchantQRNotFound
	}

	if qr.Status == MerchantQRRevoked {
		return nil, ErrMerchantQRRevoked
	}
	if qr.Status != MerchantQRActive {
		return nil, ErrMerchantQRInvalid
	}

	// 2. Fetch Business & Validate Status
	biz, err := s.repo.GetBusiness(ctx, qr.BusinessID)
	if err != nil {
		return nil, err
	}

	if biz.Status == StatusClosed {
		return nil, ErrBusinessClosed
	}
	if biz.Status == StatusSuspended {
		return nil, ErrBusinessSuspended
	}
	if biz.Status != StatusActive {
		return nil, ErrInvalidStatus
	}

	// 3. Currency Validation
	if req.Currency != "" && req.Currency != biz.Currency {
		return nil, fmt.Errorf("%w: requested %s, business accepts %s", ErrCurrencyMismatch, req.Currency, biz.Currency)
	}
	currency := biz.Currency

	// 4. Self-payment protection: Owner cannot pay their own business
	if payerUserID == biz.OwnerUserID {
		return nil, ErrSelfPaymentNotAllowed
	}

	// 5. Verify Business Account exists
	_, err = s.repo.GetBusinessAccount(ctx, biz.ID)
	if err != nil {
		return nil, ErrBusinessAccountNotFound
	}

	// 6. Create Payment Intent
	now := time.Now().UTC()
	intent := &PaymentIntent{
		ID:             uuid.New(),
		BusinessID:     biz.ID,
		PayerUserID:    payerUserID,
		MerchantQRID:   &qr.ID,
		Amount:         req.Amount,
		Currency:       currency,
		Status:         IntentCreated,
		IdempotencyKey: req.IdempotencyKey,
		CreatedAt:      now,
		ExpiresAt:      now.Add(15 * time.Minute),
	}

	if err := s.repo.CreatePaymentIntent(ctx, intent); err != nil {
		return nil, err
	}

	return intent, nil
}

// GetPaymentIntent retrieves a payment intent by ID, verifying authorization.
func (s *Service) GetPaymentIntent(ctx context.Context, requestUserID, intentID uuid.UUID) (*PaymentIntent, error) {
	intent, err := s.repo.GetPaymentIntent(ctx, intentID)
	if err != nil {
		return nil, err
	}

	// Authorization check: Only the payer or a member of the destination business can view the intent
	if intent.PayerUserID != requestUserID {
		if _, memberErr := s.repo.GetMember(ctx, intent.BusinessID, requestUserID); memberErr != nil {
			return nil, ErrUnauthorizedAccess
		}
	}

	return intent, nil
}

// ConfirmPaymentIntent executes the atomic double-entry ledger movement:
// Client (Asset) CRÉDIT (-) | Business (Asset) DÉBIT (+)
func (s *Service) ConfirmPaymentIntent(ctx context.Context, payerUserID, intentID uuid.UUID, req *ConfirmPaymentIntentRequest) (*MerchantPaymentReceipt, error) {
	s.paymentMu.Lock()
	defer s.paymentMu.Unlock()

	intent, err := s.repo.GetPaymentIntent(ctx, intentID)
	if err != nil {
		return nil, err
	}

	// 1. Authorization: Only the payer can confirm their own payment intent
	if intent.PayerUserID != payerUserID {
		return nil, ErrUnauthorizedAccess
	}

	// 2. Idempotency on already succeeded intent
	if intent.Status == IntentSucceeded {
		biz, _ := s.repo.GetBusiness(ctx, intent.BusinessID)
		bizName := "Marchand"
		if biz != nil {
			bizName = biz.DisplayName
		}
		confirmedAt := time.Now().UTC()
		if intent.ConfirmedAt != nil {
			confirmedAt = *intent.ConfirmedAt
		}
		return &MerchantPaymentReceipt{
			PaymentIntentID: intent.ID,
			BusinessID:      intent.BusinessID,
			BusinessName:    bizName,
			PayerUserID:     intent.PayerUserID,
			Amount:          intent.Amount,
			Currency:        intent.Currency,
			Status:          IntentSucceeded,
			JournalEntryID:  intent.JournalEntryID,
			ConfirmedAt:     confirmedAt,
			IsSandbox:       true,
		}, nil
	}

	// 3. Status validation
	if intent.Status != IntentCreated && intent.Status != IntentConfirmed {
		return nil, fmt.Errorf("%w: status is %s", ErrPaymentIntentInvalidStatus, intent.Status)
	}

	// 4. Expiration validation
	now := time.Now().UTC()
	if now.After(intent.ExpiresAt) {
		_ = s.repo.UpdatePaymentIntentStatus(ctx, intent.ID, IntentExpired, nil, nil)
		return nil, ErrPaymentIntentExpired
	}

	// 5. Business & Account validation
	biz, err := s.repo.GetBusiness(ctx, intent.BusinessID)
	if err != nil {
		return nil, err
	}
	if biz.Status == StatusClosed {
		_ = s.repo.UpdatePaymentIntentStatus(ctx, intent.ID, IntentFailed, nil, nil)
		return nil, ErrBusinessClosed
	}
	if biz.Status == StatusSuspended {
		_ = s.repo.UpdatePaymentIntentStatus(ctx, intent.ID, IntentFailed, nil, nil)
		return nil, ErrBusinessSuspended
	}
	if biz.Status != StatusActive {
		_ = s.repo.UpdatePaymentIntentStatus(ctx, intent.ID, IntentFailed, nil, nil)
		return nil, ErrInvalidStatus
	}

	bizAcc, err := s.repo.GetBusinessAccount(ctx, biz.ID)
	if err != nil {
		_ = s.repo.UpdatePaymentIntentStatus(ctx, intent.ID, IntentFailed, nil, nil)
		return nil, ErrBusinessAccountNotFound
	}

	// 6. Get or create Client Ledger Account
	clientLedgerAcc, err := s.ledgerRepo.GetAccountByUserID(ctx, payerUserID, intent.Currency)
	if err != nil {
		clientLedgerAcc = &ledger.LedgerAccount{
			ID:          uuid.New(),
			UserID:      &payerUserID,
			Currency:    intent.Currency,
			AccountType: ledger.Asset,
			Name:        "Portefeuille Principal",
			CreatedAt:   now,
		}
		if createErr := s.ledgerRepo.CreateAccount(ctx, clientLedgerAcc); createErr != nil {
			_ = s.repo.UpdatePaymentIntentStatus(ctx, intent.ID, IntentFailed, nil, nil)
			return nil, createErr
		}
	}

	// 7. Verify Client Funds via Ledger
	clientBalance, err := s.ledgerRepo.GetBalance(ctx, clientLedgerAcc.ID)
	if err != nil {
		_ = s.repo.UpdatePaymentIntentStatus(ctx, intent.ID, IntentFailed, nil, nil)
		return nil, err
	}

	if clientBalance < intent.Amount {
		_ = s.repo.UpdatePaymentIntentStatus(ctx, intent.ID, IntentFailed, nil, nil)
		return nil, fmt.Errorf("%w: available balance is %d, required %d", ErrPaymentFailed, clientBalance, intent.Amount)
	}

	// 8. Execute Atomic Double-Entry Ledger Movement
	// Invariant: SUM(DR) == SUM(CR)
	// Client: CRÉDIT (decrease Asset)
	// Business: DÉBIT (increase Asset)
	entryID := uuid.New()
	ledgerRef := fmt.Sprintf("MERCHANT-PAY-%s", intent.ID.String())
	ledgerIdempotencyKey := fmt.Sprintf("CONFIRM-INTENT-%s", intent.ID.String())

	entry := &ledger.JournalEntry{
		ID:              entryID,
		TransactionType: ledger.MerchantPayment,
		ReferenceID:     ledgerRef,
		Description:     fmt.Sprintf("Paiement Marchand • %s", biz.DisplayName),
		CreatedAt:       now,
	}

	postings := []*ledger.LedgerPosting{
		{
			ID:             uuid.New(),
			JournalEntryID: entryID,
			AccountID:      clientLedgerAcc.ID,
			Amount:         intent.Amount,
			IsCredit:       true, // Credit client asset (reduces balance)
			CreatedAt:      now,
		},
		{
			ID:             uuid.New(),
			JournalEntryID: entryID,
			AccountID:      bizAcc.LedgerAccountID,
			Amount:         intent.Amount,
			IsCredit:       false, // Debit business asset (increases balance)
			CreatedAt:      now,
		},
	}

	if err := s.ledgerRepo.PostJournalEntry(ctx, entry, postings, ledgerIdempotencyKey); err != nil {
		if errors.Is(err, ledger.ErrDuplicateIdempotency) {
			// Already posted under race condition, recover gracefully
			_ = s.repo.UpdatePaymentIntentStatus(ctx, intent.ID, IntentSucceeded, &now, &entryID)
			return &MerchantPaymentReceipt{
				PaymentIntentID: intent.ID,
				BusinessID:      biz.ID,
				BusinessName:    biz.DisplayName,
				PayerUserID:     payerUserID,
				Amount:          intent.Amount,
				Currency:        intent.Currency,
				Status:          IntentSucceeded,
				JournalEntryID:  &entryID,
				ConfirmedAt:     now,
				IsSandbox:       true,
			}, nil
		}

		_ = s.repo.UpdatePaymentIntentStatus(ctx, intent.ID, IntentFailed, nil, nil)
		return nil, fmt.Errorf("%w: %v", ErrPaymentFailed, err)
	}

	// 9. Update Payment Intent to SUCCEEDED
	if err := s.repo.UpdatePaymentIntentStatus(ctx, intent.ID, IntentSucceeded, &now, &entryID); err != nil {
		return nil, err
	}

	return &MerchantPaymentReceipt{
		PaymentIntentID: intent.ID,
		BusinessID:      biz.ID,
		BusinessName:    biz.DisplayName,
		PayerUserID:     payerUserID,
		Amount:          intent.Amount,
		Currency:        intent.Currency,
		Status:          IntentSucceeded,
		JournalEntryID:  &entryID,
		ConfirmedAt:     now,
		IsSandbox:       true,
	}, nil
}

// ════════════════════════════════════════════════
// MERCHANT REFUND METHODS (PHASE 3A.3)
// ════════════════════════════════════════════════

// RefundPayment executes a full or partial refund for a Succeeded Payment Intent.
// Strictly append-only: Reverses postings via a new Journal Entry of type merchant_refund without altering historical data.
func (s *Service) RefundPayment(ctx context.Context, requesterUserID, paymentIntentID uuid.UUID, req *CreateRefundRequest) (*RefundReceipt, error) {
	if req.Amount <= 0 {
		return nil, ErrInvalidRefundAmount
	}

	// 1. Fetch Payment Intent
	intent, err := s.repo.GetPaymentIntent(ctx, paymentIntentID)
	if err != nil {
		return nil, err
	}

	// 2. Validate Payment Intent Status: Only SUCCEEDED payments can be refunded
	if intent.Status != IntentSucceeded {
		return nil, ErrPaymentNotEligibleForRefund
	}

	// 3. Fetch Business & Check Status
	biz, err := s.repo.GetBusiness(ctx, intent.BusinessID)
	if err != nil {
		return nil, err
	}

	if biz.Status == StatusClosed {
		return nil, ErrBusinessClosed
	}
	if biz.Status == StatusSuspended {
		return nil, ErrBusinessSuspended
	}

	// 4. Authorization & IDOR Protection: Only OWNER and ADMIN of the business can initiate refunds
	member, err := s.repo.GetMember(ctx, intent.BusinessID, requesterUserID)
	if err != nil {
		return nil, ErrUnauthorizedAccess
	}

	if member.Role != RoleOwner && member.Role != RoleAdmin {
		return nil, ErrInsufficientPermission
	}

	// 5. Idempotency Check
	if req.IdempotencyKey != "" {
		if existing, err := s.repo.GetRefundByIdempotencyKey(ctx, req.IdempotencyKey); err == nil {
			if existing.Amount != req.Amount {
				return nil, fmt.Errorf("%w: existing amount=%d, requested amount=%d", ledger.ErrIdempotencyConflict, existing.Amount, req.Amount)
			}
			if existing.Status == RefundSucceeded {
				totalRef, _ := s.repo.GetTotalRefundedAmount(ctx, intent.ID)
				rem := intent.Amount - totalRef
				completedAt := time.Now().UTC()
				if existing.CompletedAt != nil {
					completedAt = *existing.CompletedAt
				}
				return &RefundReceipt{
					RefundID:            existing.ID,
					PaymentIntentID:     intent.ID,
					BusinessID:          biz.ID,
					BusinessName:        biz.DisplayName,
					PayerUserID:         intent.PayerUserID,
					OriginalAmount:      intent.Amount,
					RefundAmount:        existing.Amount,
					TotalRefunded:       totalRef,
					RemainingRefundable: rem,
					Currency:            intent.Currency,
					Status:              RefundSucceeded,
					Reason:              existing.Reason,
					JournalEntryID:      existing.JournalEntryID,
					CreatedAt:           existing.CreatedAt,
					CompletedAt:         completedAt,
					IsSandbox:           true,
				}, nil
			}
		}
	}

	// 6. Remaining Refundable Validation (Atomic lock safe)
	totalRefunded, err := s.repo.GetTotalRefundedAmount(ctx, intent.ID)
	if err != nil {
		return nil, err
	}

	remaining := intent.Amount - totalRefunded
	if remaining <= 0 {
		return nil, ErrAlreadyFullyRefunded
	}

	if req.Amount > remaining {
		return nil, fmt.Errorf("%w: requested %d, remaining refundable %d", ErrRefundAmountExceedsRemaining, req.Amount, remaining)
	}

	// 7. Fetch Business Account and Client Account
	bizAcc, err := s.repo.GetBusinessAccount(ctx, biz.ID)
	if err != nil {
		return nil, ErrBusinessAccountNotFound
	}

	clientAcc, err := s.ledgerRepo.GetAccountByUserID(ctx, intent.PayerUserID, intent.Currency)
	if err != nil {
		return nil, err
	}

	// 8. Verify Business has sufficient funds to cover the refund
	bizBalance, err := s.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)
	if err != nil {
		return nil, err
	}
	if bizBalance < req.Amount {
		return nil, fmt.Errorf("%w: business available balance %d is less than refund amount %d", ErrPaymentFailed, bizBalance, req.Amount)
	}

	// 9. Create Refund in REQUESTED status
	now := time.Now().UTC()
	refundID := uuid.New()
	refund := &Refund{
		ID:              refundID,
		PaymentIntentID: intent.ID,
		BusinessID:      biz.ID,
		PayerUserID:     intent.PayerUserID,
		Amount:          req.Amount,
		Currency:        intent.Currency,
		Status:          RefundRequested,
		Reason:          req.Reason,
		IdempotencyKey:  req.IdempotencyKey,
		CreatedAt:       now,
	}

	if err := s.repo.CreateRefund(ctx, refund); err != nil {
		if errors.Is(err, ledger.ErrDuplicateIdempotency) {
			if existing, fetchErr := s.repo.GetRefundByIdempotencyKey(ctx, req.IdempotencyKey); fetchErr == nil {
				totRef, _ := s.repo.GetTotalRefundedAmount(ctx, intent.ID)
				rem := intent.Amount - totRef
				completedAt := time.Now().UTC()
				if existing.CompletedAt != nil {
					completedAt = *existing.CompletedAt
				}
				return &RefundReceipt{
					RefundID:            existing.ID,
					PaymentIntentID:     intent.ID,
					BusinessID:          biz.ID,
					BusinessName:        biz.DisplayName,
					PayerUserID:         intent.PayerUserID,
					OriginalAmount:      intent.Amount,
					RefundAmount:        existing.Amount,
					TotalRefunded:       totRef,
					RemainingRefundable: rem,
					Currency:            intent.Currency,
					Status:              RefundSucceeded,
					Reason:              existing.Reason,
					JournalEntryID:      existing.JournalEntryID,
					CreatedAt:           existing.CreatedAt,
					CompletedAt:         completedAt,
					IsSandbox:           true,
				}, nil
			}
		}
		return nil, err
	}

	// 10. Execute Atomic Double-Entry Ledger Reversal
	// Business: CRÉDIT (Asset decrease)
	// Client: DÉBIT (Asset increase)
	// Invariant: SUM(DR) == SUM(CR) == req.Amount
	entryID := uuid.New()
	ledgerRef := fmt.Sprintf("REFUND-%s", refundID.String())
	ledgerIdempotencyKey := fmt.Sprintf("CONFIRM-REFUND-%s", refundID.String())
	if req.IdempotencyKey != "" {
		ledgerIdempotencyKey = fmt.Sprintf("REFUND-IDEMP-%s", req.IdempotencyKey)
	}

	entry := &ledger.JournalEntry{
		ID:              entryID,
		TransactionType: ledger.MerchantRefund,
		ReferenceID:     ledgerRef,
		Description:     fmt.Sprintf("Remboursement Marchand • %s", biz.DisplayName),
		CreatedAt:       now,
	}

	postings := []*ledger.LedgerPosting{
		{
			ID:             uuid.New(),
			JournalEntryID: entryID,
			AccountID:      bizAcc.LedgerAccountID,
			Amount:         req.Amount,
			IsCredit:       true, // Credit business asset (decreases business balance)
			CreatedAt:      now,
		},
		{
			ID:             uuid.New(),
			JournalEntryID: entryID,
			AccountID:      clientAcc.ID,
			Amount:         req.Amount,
			IsCredit:       false, // Debit client asset (increases client balance)
			CreatedAt:      now,
		},
	}

	if err := s.ledgerRepo.PostJournalEntry(ctx, entry, postings, ledgerIdempotencyKey); err != nil {
		if errors.Is(err, ledger.ErrDuplicateIdempotency) {
			_ = s.repo.UpdateRefundStatus(ctx, refundID, RefundSucceeded, &now, &entryID)
			totRef, _ := s.repo.GetTotalRefundedAmount(ctx, intent.ID)
			rem := intent.Amount - totRef
			return &RefundReceipt{
				RefundID:            refundID,
				PaymentIntentID:     intent.ID,
				BusinessID:          biz.ID,
				BusinessName:        biz.DisplayName,
				PayerUserID:         intent.PayerUserID,
				OriginalAmount:      intent.Amount,
				RefundAmount:        req.Amount,
				TotalRefunded:       totRef,
				RemainingRefundable: rem,
				Currency:            intent.Currency,
				Status:              RefundSucceeded,
				Reason:              req.Reason,
				JournalEntryID:      &entryID,
				CreatedAt:           now,
				CompletedAt:         now,
				IsSandbox:           true,
			}, nil
		}
		_ = s.repo.UpdateRefundStatus(ctx, refundID, RefundFailed, nil, nil)
		return nil, fmt.Errorf("%w: %v", ErrPaymentFailed, err)
	}

	// 11. Update Refund to SUCCEEDED
	completedAt := time.Now().UTC()
	if err := s.repo.UpdateRefundStatus(ctx, refundID, RefundSucceeded, &completedAt, &entryID); err != nil {
		return nil, err
	}

	newTotalRefunded := totalRefunded + req.Amount
	newRemaining := intent.Amount - newTotalRefunded

	return &RefundReceipt{
		RefundID:            refundID,
		PaymentIntentID:     intent.ID,
		BusinessID:          biz.ID,
		BusinessName:        biz.DisplayName,
		PayerUserID:         intent.PayerUserID,
		OriginalAmount:      intent.Amount,
		RefundAmount:        req.Amount,
		TotalRefunded:       newTotalRefunded,
		RemainingRefundable: newRemaining,
		Currency:            intent.Currency,
		Status:              RefundSucceeded,
		Reason:              req.Reason,
		JournalEntryID:      &entryID,
		CreatedAt:           now,
		CompletedAt:         completedAt,
		IsSandbox:           true,
	}, nil
}

// GetRefunds returns all refunds for a specific payment intent with IDOR verification.
func (s *Service) GetRefunds(ctx context.Context, requestUserID, paymentIntentID uuid.UUID) ([]*Refund, error) {
	intent, err := s.repo.GetPaymentIntent(ctx, paymentIntentID)
	if err != nil {
		return nil, err
	}

	// Authorization: Payer or Business Member can view refunds
	if intent.PayerUserID != requestUserID {
		if _, memberErr := s.repo.GetMember(ctx, intent.BusinessID, requestUserID); memberErr != nil {
			return nil, ErrUnauthorizedAccess
		}
	}

	return s.repo.GetRefundsByPaymentIntent(ctx, paymentIntentID)
}

// ════════════════════════════════════════════════
// MERCHANT SETTLEMENT METHODS (PHASE 3A.4)
// ════════════════════════════════════════════════

// CalculateEligibleSettlement derives the total settleable balance across all succeeded payment intents.
// Formula: net_settleable = SUM(gross_payment - successful_refunds - already_settled).
func (s *Service) CalculateEligibleSettlement(ctx context.Context, requesterUserID, businessID uuid.UUID) (*EligibleSettlementCalculation, error) {
	biz, err := s.repo.GetBusiness(ctx, businessID)
	if err != nil {
		return nil, err
	}

	member, err := s.repo.GetMember(ctx, businessID, requesterUserID)
	if err != nil {
		return nil, ErrUnauthorizedAccess
	}

	if !CanViewAccount(member.Role, biz.Status) {
		return nil, ErrInsufficientPermission
	}

	intents, err := s.repo.ListSucceededPaymentIntents(ctx, businessID)
	if err != nil {
		return nil, err
	}

	var grossTotal int64
	var refundedTotal int64
	var settledTotal int64
	var netSettleableTotal int64
	var eligibleCount int

	for _, intent := range intents {
		if intent.Currency != biz.Currency {
			continue
		}

		refAmt, _ := s.repo.GetTotalRefundedAmount(ctx, intent.ID)
		setAmt, _ := s.repo.GetTotalSettledAmount(ctx, intent.ID)

		net := intent.Amount - refAmt - setAmt
		if net > 0 {
			grossTotal += intent.Amount
			refundedTotal += refAmt
			settledTotal += setAmt
			netSettleableTotal += net
			eligibleCount++
		}
	}

	return &EligibleSettlementCalculation{
		BusinessID:     businessID,
		Currency:       biz.Currency,
		GrossAmount:    grossTotal,
		TotalRefunded:  refundedTotal,
		AlreadySettled: settledTotal,
		NetSettleable:  netSettleableTotal,
		EligibleCount:  eligibleCount,
	}, nil
}

// CreateSettlement builds a batch settlement for eligible payments and puts it in PENDING status.
func (s *Service) CreateSettlement(ctx context.Context, requesterUserID, businessID uuid.UUID, req *CreateSettlementRequest) (*SettlementReceipt, error) {
	s.settlementMu.Lock()
	defer s.settlementMu.Unlock()

	// 1. Fetch Business & verify status
	biz, err := s.repo.GetBusiness(ctx, businessID)
	if err != nil {
		return nil, err
	}

	if biz.Status == StatusClosed {
		return nil, ErrBusinessClosed
	}
	if biz.Status == StatusSuspended {
		return nil, ErrBusinessSuspended
	}

	// 2. Authorization & IDOR: OWNER and ADMIN only
	member, err := s.repo.GetMember(ctx, businessID, requesterUserID)
	if err != nil {
		return nil, ErrUnauthorizedAccess
	}

	if member.Role != RoleOwner && member.Role != RoleAdmin {
		return nil, ErrInsufficientPermission
	}

	// 3. Currency Validation
	if req.Currency != "" && req.Currency != biz.Currency {
		return nil, ErrSettlementCurrencyMismatch
	}

	// 4. Idempotency Check
	if req.IdempotencyKey != "" {
		if existing, err := s.repo.GetSettlementByIdempotencyKey(ctx, req.IdempotencyKey); err == nil {
			if req.Amount > 0 && existing.TotalAmount != req.Amount {
				return nil, fmt.Errorf("%w: existing amount=%d, requested amount=%d", ledger.ErrIdempotencyConflict, existing.TotalAmount, req.Amount)
			}
			items, _ := s.repo.GetSettlementItems(ctx, existing.ID)
			return &SettlementReceipt{
				SettlementID:   existing.ID,
				BusinessID:     biz.ID,
				BusinessName:   biz.DisplayName,
				TotalAmount:    existing.TotalAmount,
				Currency:       existing.Currency,
				Status:         existing.Status,
				IdempotencyKey: existing.IdempotencyKey,
				JournalEntryID: existing.JournalEntryID,
				FailureReason:  existing.FailureReason,
				Items:          items,
				ItemCount:      len(items),
				CreatedAt:      existing.CreatedAt,
				ProcessedAt:    existing.ProcessedAt,
				IsSandbox:      true,
			}, nil
		}
	}

	if req.Amount < 0 {
		return nil, ErrInvalidSettlementAmount
	}

	// 5. Fetch Succeeded Payments & Calculate Eligible Net Settleable
	intents, err := s.repo.ListSucceededPaymentIntents(ctx, businessID)
	if err != nil {
		return nil, err
	}

	type eligibleIntent struct {
		intent   *PaymentIntent
		gross    int64
		refunded int64
		settled  int64
		net      int64
	}

	var eligibleList []eligibleIntent
	var totalAvailableNet int64

	for _, intent := range intents {
		if intent.Currency != biz.Currency {
			continue
		}
		refAmt, _ := s.repo.GetTotalRefundedAmount(ctx, intent.ID)
		setAmt, _ := s.repo.GetTotalSettledAmount(ctx, intent.ID)
		net := intent.Amount - refAmt - setAmt
		if net > 0 {
			eligibleList = append(eligibleList, eligibleIntent{
				intent:   intent,
				gross:    intent.Amount,
				refunded: refAmt,
				settled:  setAmt,
				net:      net,
			})
			totalAvailableNet += net
		}
	}

	if len(eligibleList) == 0 || totalAvailableNet <= 0 {
		return nil, ErrNoEligiblePayments
	}

	// 6. Determine target settlement amount
	targetAmount := totalAvailableNet
	if req.Amount > 0 {
		if req.Amount > totalAvailableNet {
			return nil, fmt.Errorf("%w: requested %d, available %d", ErrOverSettlement, req.Amount, totalAvailableNet)
		}
		targetAmount = req.Amount
	}

	if targetAmount <= 0 {
		return nil, ErrInvalidSettlementAmount
	}

	// 7. Construct Settlement Batch Items
	now := time.Now().UTC()
	settlementID := uuid.New()
	remainingToAllocate := targetAmount
	var settlementItems []*SettlementItem

	for _, el := range eligibleList {
		if remainingToAllocate <= 0 {
			break
		}

		take := el.net
		if take > remainingToAllocate {
			take = remainingToAllocate
		}

		item := &SettlementItem{
			ID:              uuid.New(),
			SettlementID:    settlementID,
			PaymentIntentID: el.intent.ID,
			GrossAmount:     el.gross,
			RefundAmount:    el.refunded,
			NetAmount:       take,
			Currency:        biz.Currency,
			CreatedAt:       now,
		}

		settlementItems = append(settlementItems, item)
		remainingToAllocate -= take
	}

	// 8. Create Settlement entity (PENDING)
	settlement := &Settlement{
		ID:             settlementID,
		BusinessID:     biz.ID,
		TotalAmount:    targetAmount,
		Currency:       biz.Currency,
		Status:         SettlementPending,
		IdempotencyKey: req.IdempotencyKey,
		CreatedAt:      now,
	}

	if err := s.repo.CreateSettlement(ctx, settlement, settlementItems); err != nil {
		if errors.Is(err, ledger.ErrDuplicateIdempotency) {
			if existing, fetchErr := s.repo.GetSettlementByIdempotencyKey(ctx, req.IdempotencyKey); fetchErr == nil {
				items, _ := s.repo.GetSettlementItems(ctx, existing.ID)
				return &SettlementReceipt{
					SettlementID:   existing.ID,
					BusinessID:     biz.ID,
					BusinessName:   biz.DisplayName,
					TotalAmount:    existing.TotalAmount,
					Currency:       existing.Currency,
					Status:         existing.Status,
					IdempotencyKey: existing.IdempotencyKey,
					JournalEntryID: existing.JournalEntryID,
					FailureReason:  existing.FailureReason,
					Items:          items,
					ItemCount:      len(items),
					CreatedAt:      existing.CreatedAt,
					ProcessedAt:    existing.ProcessedAt,
					IsSandbox:      true,
				}, nil
			}
		}
		return nil, err
	}

	return &SettlementReceipt{
		SettlementID:   settlement.ID,
		BusinessID:     biz.ID,
		BusinessName:   biz.DisplayName,
		TotalAmount:    settlement.TotalAmount,
		Currency:       settlement.Currency,
		Status:         SettlementPending,
		IdempotencyKey: settlement.IdempotencyKey,
		Items:          settlementItems,
		ItemCount:      len(settlementItems),
		CreatedAt:      now,
		IsSandbox:      true,
	}, nil
}

// ProcessSettlement executes the disbursement workflow for a PENDING settlement in Sandbox mode.
// Double-entry accounting: Business Asset Account CRÉDIT, System Settlement Pool DÉBIT.
func (s *Service) ProcessSettlement(ctx context.Context, requesterUserID, businessID, settlementID uuid.UUID) (*SettlementReceipt, error) {
	// 1. Fetch Business & check status
	biz, err := s.repo.GetBusiness(ctx, businessID)
	if err != nil {
		return nil, err
	}

	if biz.Status == StatusClosed {
		return nil, ErrBusinessClosed
	}
	if biz.Status == StatusSuspended {
		return nil, ErrBusinessSuspended
	}

	// 2. Authorization & IDOR: OWNER and ADMIN only
	member, err := s.repo.GetMember(ctx, businessID, requesterUserID)
	if err != nil {
		return nil, ErrUnauthorizedAccess
	}

	if member.Role != RoleOwner && member.Role != RoleAdmin {
		return nil, ErrInsufficientPermission
	}

	// 3. Fetch Settlement
	settlement, err := s.repo.GetSettlement(ctx, settlementID)
	if err != nil {
		return nil, err
	}

	if settlement.BusinessID != businessID {
		return nil, ErrUnauthorizedAccess
	}

	if settlement.Status == SettlementSucceeded {
		// Idempotent success response
		items, _ := s.repo.GetSettlementItems(ctx, settlement.ID)
		return &SettlementReceipt{
			SettlementID:   settlement.ID,
			BusinessID:     biz.ID,
			BusinessName:   biz.DisplayName,
			TotalAmount:    settlement.TotalAmount,
			Currency:       settlement.Currency,
			Status:         SettlementSucceeded,
			IdempotencyKey: settlement.IdempotencyKey,
			JournalEntryID: settlement.JournalEntryID,
			FailureReason:  settlement.FailureReason,
			Items:          items,
			ItemCount:      len(items),
			CreatedAt:      settlement.CreatedAt,
			ProcessedAt:    settlement.ProcessedAt,
			IsSandbox:      true,
		}, nil
	}

	if settlement.Status != SettlementPending {
		return nil, ErrSettlementNotPending
	}

	// 4. Fetch Business Financial Account & Verify Funds on Ledger
	bizAcc, err := s.repo.GetBusinessAccount(ctx, biz.ID)
	if err != nil {
		return nil, ErrBusinessAccountNotFound
	}

	bizBalance, err := s.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)
	if err != nil {
		return nil, err
	}

	if bizBalance < settlement.TotalAmount {
		failureReason := fmt.Sprintf("insufficient funds on business account: available %d, required %d", bizBalance, settlement.TotalAmount)
		_ = s.repo.UpdateSettlementStatus(ctx, settlement.ID, SettlementFailed, nil, nil, failureReason)
		return nil, fmt.Errorf("%w: %s", ErrPaymentFailed, failureReason)
	}

	// 5. Transition to PROCESSING
	_ = s.repo.UpdateSettlementStatus(ctx, settlement.ID, SettlementProcessing, nil, nil, "")

	// 6. Execute Provider Disbursement (100% Sandbox Provider - 0 external calls)
	if err := s.settlementProvider.ProcessSettlement(ctx, settlement); err != nil {
		_ = s.repo.UpdateSettlementStatus(ctx, settlement.ID, SettlementFailed, nil, nil, err.Error())
		return nil, fmt.Errorf("settlement provider error: %w", err)
	}

	// 7. Execute Double-Entry Ledger Posting
	// Business Asset Account: CRÉDIT (balance decreases)
	// MoMo Settlement Pool (Liability): DÉBIT (settlement liability cleared)
	// Invariant: SUM(DR) == SUM(CR) == settlement.TotalAmount
	settlementPool, err := s.ledgerRepo.GetSystemAccount(ctx, "MoMo Settlement Pool", settlement.Currency, ledger.Liability)
	if err != nil {
		_ = s.repo.UpdateSettlementStatus(ctx, settlement.ID, SettlementFailed, nil, nil, err.Error())
		return nil, err
	}

	now := time.Now().UTC()
	entryID := uuid.New()
	ledgerRef := fmt.Sprintf("SETTLEMENT-%s", settlement.ID.String())
	ledgerIdempotencyKey := fmt.Sprintf("CONFIRM-SETTLEMENT-%s", settlement.ID.String())

	entry := &ledger.JournalEntry{
		ID:              entryID,
		TransactionType: ledger.MerchantSettlement,
		ReferenceID:     ledgerRef,
		Description:     fmt.Sprintf("Règlement Marchand (Settlement) • %s", biz.DisplayName),
		CreatedAt:       now,
	}

	postings := []*ledger.LedgerPosting{
		{
			ID:             uuid.New(),
			JournalEntryID: entryID,
			AccountID:      bizAcc.LedgerAccountID,
			Amount:         settlement.TotalAmount,
			IsCredit:       true, // Credit business asset (decreases balance)
			CreatedAt:      now,
		},
		{
			ID:             uuid.New(),
			JournalEntryID: entryID,
			AccountID:      settlementPool.ID,
			Amount:         settlement.TotalAmount,
			IsCredit:       false, // Debit system settlement pool liability
			CreatedAt:      now,
		},
	}

	if err := s.ledgerRepo.PostJournalEntry(ctx, entry, postings, ledgerIdempotencyKey); err != nil {
		if !errors.Is(err, ledger.ErrDuplicateIdempotency) {
			_ = s.repo.UpdateSettlementStatus(ctx, settlement.ID, SettlementFailed, nil, nil, err.Error())
			return nil, fmt.Errorf("%w: failed to post ledger entry: %v", ErrPaymentFailed, err)
		}
	}

	// 8. Update Settlement to SUCCEEDED
	if err := s.repo.UpdateSettlementStatus(ctx, settlement.ID, SettlementSucceeded, &now, &entryID, ""); err != nil {
		return nil, err
	}

	items, _ := s.repo.GetSettlementItems(ctx, settlement.ID)

	return &SettlementReceipt{
		SettlementID:   settlement.ID,
		BusinessID:     biz.ID,
		BusinessName:   biz.DisplayName,
		TotalAmount:    settlement.TotalAmount,
		Currency:       settlement.Currency,
		Status:         SettlementSucceeded,
		IdempotencyKey: settlement.IdempotencyKey,
		JournalEntryID: &entryID,
		Items:          items,
		ItemCount:      len(items),
		CreatedAt:      settlement.CreatedAt,
		ProcessedAt:    &now,
		IsSandbox:      true,
	}, nil
}

// GetSettlement retrieves a single settlement detail and its constituent items with IDOR protection.
func (s *Service) GetSettlement(ctx context.Context, requesterUserID, businessID, settlementID uuid.UUID) (*SettlementReceipt, error) {
	biz, err := s.repo.GetBusiness(ctx, businessID)
	if err != nil {
		return nil, err
	}

	member, err := s.repo.GetMember(ctx, businessID, requesterUserID)
	if err != nil {
		return nil, ErrUnauthorizedAccess
	}

	if !CanViewAccount(member.Role, biz.Status) {
		return nil, ErrInsufficientPermission
	}

	settlement, err := s.repo.GetSettlement(ctx, settlementID)
	if err != nil {
		return nil, err
	}

	if settlement.BusinessID != businessID {
		return nil, ErrUnauthorizedAccess
	}

	items, err := s.repo.GetSettlementItems(ctx, settlement.ID)
	if err != nil {
		return nil, err
	}

	return &SettlementReceipt{
		SettlementID:   settlement.ID,
		BusinessID:     biz.ID,
		BusinessName:   biz.DisplayName,
		TotalAmount:    settlement.TotalAmount,
		Currency:       settlement.Currency,
		Status:         settlement.Status,
		IdempotencyKey: settlement.IdempotencyKey,
		JournalEntryID: settlement.JournalEntryID,
		FailureReason:  settlement.FailureReason,
		Items:          items,
		ItemCount:      len(items),
		CreatedAt:      settlement.CreatedAt,
		ProcessedAt:    settlement.ProcessedAt,
		IsSandbox:      true,
	}, nil
}

// ListSettlements returns all settlements of a business with IDOR protection.
func (s *Service) ListSettlements(ctx context.Context, requesterUserID, businessID uuid.UUID) ([]*SettlementReceipt, error) {
	biz, err := s.repo.GetBusiness(ctx, businessID)
	if err != nil {
		return nil, err
	}

	member, err := s.repo.GetMember(ctx, businessID, requesterUserID)
	if err != nil {
		return nil, ErrUnauthorizedAccess
	}

	if !CanViewAccount(member.Role, biz.Status) {
		return nil, ErrInsufficientPermission
	}

	settlements, err := s.repo.ListSettlements(ctx, businessID)
	if err != nil {
		return nil, err
	}

	var receipts []*SettlementReceipt
	for _, st := range settlements {
		items, _ := s.repo.GetSettlementItems(ctx, st.ID)
		receipts = append(receipts, &SettlementReceipt{
			SettlementID:   st.ID,
			BusinessID:     biz.ID,
			BusinessName:   biz.DisplayName,
			TotalAmount:    st.TotalAmount,
			Currency:       st.Currency,
			Status:         st.Status,
			IdempotencyKey: st.IdempotencyKey,
			JournalEntryID: st.JournalEntryID,
			FailureReason:  st.FailureReason,
			Items:          items,
			ItemCount:      len(items),
			CreatedAt:      st.CreatedAt,
			ProcessedAt:    st.ProcessedAt,
			IsSandbox:      true,
		})
	}

	return receipts, nil
}

// ========================
// Phase 3A.5 — FeeEngine & Fee Service
// ========================

// FeeEngine performs deterministic, integer-only fee calculations.
// All monetary amounts are in minor units (FCFA). Percentages use basis points (100 bps = 1.00%).
// INVARIANT: No float, no double, no approximate arithmetic. Purely deterministic.
type FeeEngine struct{}

// Calculate computes the fee for the given gross amount using the specified FeeRule.
// Returns a FeeCalculationResult with the full breakdown.
// Formula: percentage_amount = (gross_amount * percentage_bps) / 10000
//
//	raw_fee = fixed_amount + percentage_amount
//	Apply min/max bounds and cap at gross_amount.
func (e *FeeEngine) Calculate(rule *FeeRule, grossAmount int64) *FeeCalculationResult {
	result := &FeeCalculationResult{
		FeeRuleID:    rule.ID,
		GrossAmount:  grossAmount,
		Currency:     rule.Currency,
		IsRefundable: rule.IsRefundable,
	}

	// Fixed part
	var fixedPart int64
	if rule.FeeType == FeeTypeFixed || rule.FeeType == FeeTypeHybrid {
		fixedPart = rule.FixedAmount
	}

	// Percentage part: integer arithmetic with basis points
	var percentagePart int64
	if rule.FeeType == FeeTypePercentage || rule.FeeType == FeeTypeHybrid {
		percentagePart = (grossAmount * rule.PercentageBps) / 10000
	}

	result.FixedPart = fixedPart
	result.PercentagePart = percentagePart
	rawFee := fixedPart + percentagePart
	result.RawFee = rawFee

	finalFee := rawFee

	// Apply minimum bound
	if rule.MinimumFee > 0 && finalFee < rule.MinimumFee {
		finalFee = rule.MinimumFee
	}

	// Apply maximum cap
	if rule.MaximumFee > 0 && finalFee > rule.MaximumFee {
		finalFee = rule.MaximumFee
	}

	// Never exceed gross amount
	if finalFee > grossAmount {
		finalFee = grossAmount
	}

	// Never negative
	if finalFee < 0 {
		finalFee = 0
	}

	result.FinalFee = finalFee
	return result
}

var feeEngine = &FeeEngine{}

// CreateFeeRule creates a new fee rule for a business after validation.
func (s *Service) CreateFeeRule(ctx context.Context, callerID uuid.UUID, businessID uuid.UUID, req *CreateFeeRuleRequest) (*FeeRule, error) {
	// Authorization: OWNER or ADMIN only
	member, err := s.repo.GetMember(ctx, businessID, callerID)
	if err != nil {
		return nil, ErrNotBusinessMember
	}
	if member.Role != "OWNER" && member.Role != "ADMIN" {
		return nil, ErrNotBusinessMember
	}

	// Validate fee type
	feeType := FeeType(req.FeeType)
	if feeType != FeeTypeFixed && feeType != FeeTypePercentage && feeType != FeeTypeHybrid {
		return nil, ErrInvalidFeeRule
	}

	// Validate transaction type
	if req.TransactionType != "merchant_payment" && req.TransactionType != "merchant_settlement" {
		return nil, ErrInvalidFeeRule
	}

	// Validate amounts
	if req.FixedAmount < 0 || req.PercentageBps < 0 {
		return nil, ErrInvalidFeeRule
	}
	if req.PercentageBps > 10000 {
		return nil, ErrInvalidPercentageBps
	}
	if req.MinimumFee < 0 || req.MaximumFee < 0 {
		return nil, ErrInvalidFeeRule
	}
	if req.MaximumFee > 0 && req.MinimumFee > req.MaximumFee {
		return nil, ErrInvalidFeeBounds
	}

	// Must have at least one non-zero fee component
	if req.FixedAmount == 0 && req.PercentageBps == 0 {
		return nil, ErrInvalidFeeRule
	}

	currency := req.Currency
	if currency == "" {
		currency = "FCFA"
	}

	now := time.Now().UTC()
	rule := &FeeRule{
		ID:              uuid.New(),
		BusinessID:      &businessID,
		TransactionType: req.TransactionType,
		FeeType:         feeType,
		FixedAmount:     req.FixedAmount,
		PercentageBps:   req.PercentageBps,
		MinimumFee:      req.MinimumFee,
		MaximumFee:      req.MaximumFee,
		Currency:        currency,
		Status:          FeeRuleActive,
		IsRefundable:    req.IsRefundable,
		EffectiveFrom:   now,
		EffectiveUntil:  nil,
		CreatedAt:       now,
		UpdatedAt:       now,
	}

	if err := s.repo.CreateFeeRule(ctx, rule); err != nil {
		return nil, err
	}
	return rule, nil
}

// UpdateFeeRule deactivates or archives an existing fee rule.
func (s *Service) UpdateFeeRule(ctx context.Context, callerID uuid.UUID, businessID uuid.UUID, ruleID uuid.UUID, req *UpdateFeeRuleRequest) error {
	// Authorization: OWNER or ADMIN only
	member, err := s.repo.GetMember(ctx, businessID, callerID)
	if err != nil {
		return ErrNotBusinessMember
	}
	if member.Role != "OWNER" && member.Role != "ADMIN" {
		return ErrNotBusinessMember
	}

	// Verify the rule exists and belongs to this business
	rule, err := s.repo.GetFeeRule(ctx, ruleID)
	if err != nil {
		return err
	}
	if rule.BusinessID == nil || *rule.BusinessID != businessID {
		return ErrFeeRuleNotFound
	}

	newStatus := FeeRuleStatus(req.Status)
	if newStatus != FeeRuleActive && newStatus != FeeRuleInactive && newStatus != FeeRuleArchived {
		return ErrInvalidFeeRule
	}

	return s.repo.UpdateFeeRuleStatus(ctx, ruleID, newStatus)
}

// ListFeeRules lists all fee rules for a business.
func (s *Service) ListFeeRules(ctx context.Context, callerID uuid.UUID, businessID uuid.UUID) ([]*FeeRule, error) {
	// Authorization: OWNER, ADMIN, or MANAGER
	member, err := s.repo.GetMember(ctx, businessID, callerID)
	if err != nil {
		return nil, ErrNotBusinessMember
	}
	if member.Role != "OWNER" && member.Role != "ADMIN" && member.Role != "MANAGER" {
		return nil, ErrNotBusinessMember
	}
	return s.repo.ListFeeRules(ctx, businessID)
}

// CalculateFee simulates fee calculation without persisting anything.
func (s *Service) CalculateFee(ctx context.Context, callerID uuid.UUID, businessID uuid.UUID, req *CalculateFeeRequest) (*FeeCalculationResult, error) {
	// Authorization: OWNER, ADMIN, or MANAGER
	member, err := s.repo.GetMember(ctx, businessID, callerID)
	if err != nil {
		return nil, ErrNotBusinessMember
	}
	if member.Role != "OWNER" && member.Role != "ADMIN" && member.Role != "MANAGER" {
		return nil, ErrNotBusinessMember
	}

	if req.GrossAmount <= 0 {
		return nil, ledger.ErrInvalidAmount
	}

	currency := req.Currency
	if currency == "" {
		currency = "FCFA"
	}

	rule, err := s.repo.GetActiveFeeRule(ctx, businessID, req.TransactionType, currency)
	if err != nil {
		return nil, err
	}

	return feeEngine.Calculate(rule, req.GrossAmount), nil
}

// CollectFeeOnPayment collects a commission on a succeeded merchant payment.
// Creates a FeeTransaction and posts a balanced double-entry journal entry.
// Idempotent: a second call with the same idempotency_key returns the existing FeeTransaction.
func (s *Service) CollectFeeOnPayment(ctx context.Context, businessID uuid.UUID, paymentIntentID uuid.UUID, currency string, grossAmount int64, idempotencyKey string) (*FeeTransaction, error) {
	// Check idempotency first
	if idempotencyKey != "" {
		existing, err := s.repo.GetFeeTransactionByIdempotencyKey(ctx, idempotencyKey)
		if err == nil {
			// Already collected — idempotent return
			return existing, nil
		}
	}

	// Check if a fee was already collected for this source transaction (unique constraint)
	if existing, err := s.repo.GetFeeTransactionBySource(ctx, paymentIntentID, "merchant_payment"); err == nil {
		return existing, nil
	}

	// Find the active fee rule
	rule, err := s.repo.GetActiveFeeRule(ctx, businessID, "merchant_payment", currency)
	if err != nil {
		// No active fee rule — no fee to collect (this is not an error; the system operates with 0 fees when no rule exists)
		return nil, ErrFeeRuleNotFound
	}

	// Calculate fee deterministically
	calc := feeEngine.Calculate(rule, grossAmount)
	if calc.FinalFee <= 0 {
		// Zero fee — nothing to collect
		return nil, nil
	}

	// Get the business account's Ledger Account
	bizAccount, err := s.repo.GetBusinessAccount(ctx, businessID)
	if err != nil {
		return nil, err
	}

	// Get the Platform Fee Revenue Account
	feeRevenueAcc, err := s.ledgerRepo.GetSystemAccount(ctx, "Platform Fee Account", currency, ledger.Revenue)
	if err != nil {
		return nil, err
	}

	// Post double-entry journal entry: Business Asset CR, Platform Fee Revenue DR
	ledgerIdempKey := fmt.Sprintf("FEE-COLLECT-%s", idempotencyKey)
	entry := &ledger.JournalEntry{
		ID:              uuid.New(),
		TransactionType: ledger.Fee,
		ReferenceID:     fmt.Sprintf("FEE-PAYMENT-%s", paymentIntentID.String()),
		Description:     fmt.Sprintf("Commission MÏÏghO sur paiement marchand %s (%d %s)", paymentIntentID.String()[:8], calc.FinalFee, currency),
		CreatedAt:       time.Now().UTC(),
	}

	postings := []*ledger.LedgerPosting{
		{
			ID:             uuid.New(),
			JournalEntryID: entry.ID,
			AccountID:      bizAccount.LedgerAccountID,
			Amount:         calc.FinalFee,
			IsCredit:       true, // Credit Business Asset (decreases merchant balance)
			CreatedAt:      entry.CreatedAt,
		},
		{
			ID:             uuid.New(),
			JournalEntryID: entry.ID,
			AccountID:      feeRevenueAcc.ID,
			Amount:         calc.FinalFee,
			IsCredit:       false, // Debit Platform Fee Revenue (increases platform revenue — revenue is normally credit-balance, so debit increases it in the natural direction for this convention)
			CreatedAt:      entry.CreatedAt,
		},
	}

	if err := s.ledgerRepo.PostJournalEntry(ctx, entry, postings, ledgerIdempKey); err != nil {
		// If idempotency conflict on ledger side, wait for the winning goroutine to persist fee tx
		if errors.Is(err, ledger.ErrDuplicateIdempotency) {
			for retries := 0; retries < 10; retries++ {
				if idempotencyKey != "" {
					if existing, findErr := s.repo.GetFeeTransactionByIdempotencyKey(ctx, idempotencyKey); findErr == nil {
						return existing, nil
					}
				}
				if existing, findErr := s.repo.GetFeeTransactionBySource(ctx, paymentIntentID, "merchant_payment"); findErr == nil {
					return existing, nil
				}
				time.Sleep(2 * time.Millisecond)
			}
		}
		return nil, err
	}

	now := time.Now().UTC()
	feeTx := &FeeTransaction{
		ID:                    uuid.New(),
		BusinessID:            businessID,
		FeeRuleID:             &rule.ID,
		SourceTransactionType: "merchant_payment",
		SourceTransactionID:   paymentIntentID,
		GrossAmount:           grossAmount,
		FeeAmount:             calc.FinalFee,
		Currency:              currency,
		Status:                FeeStatusCollected,
		IsRefundable:          rule.IsRefundable,
		RefundedFeeAmount:     0,
		IdempotencyKey:        idempotencyKey,
		JournalEntryID:        &entry.ID,
		CreatedAt:             now,
		CollectedAt:           &now,
	}

	if err := s.repo.CreateFeeTransaction(ctx, feeTx); err != nil {
		// If duplicate source transaction, return existing
		if errors.Is(err, ErrDuplicateFeeTransaction) || errors.Is(err, ErrFeeAlreadyCollected) {
			if idempotencyKey != "" {
				if existing, findErr := s.repo.GetFeeTransactionByIdempotencyKey(ctx, idempotencyKey); findErr == nil {
					return existing, nil
				}
			}
			if existing, findErr := s.repo.GetFeeTransactionBySource(ctx, paymentIntentID, "merchant_payment"); findErr == nil {
				return existing, nil
			}
		}
		return nil, err
	}

	return feeTx, nil
}

// RefundFeeForPayment refunds a proportional amount of the collected fee when a merchant payment is refunded.
// Only applies if the original fee rule had is_refundable = true.
// Formula: refund_fee_amount = (refund_amount * original_fee_amount) / original_gross_amount
// Posts a reversal double-entry journal entry.
func (s *Service) RefundFeeForPayment(ctx context.Context, businessID uuid.UUID, paymentIntentID uuid.UUID, refundAmount int64, currency string, refundIdempotencyKey string) (*FeeTransaction, error) {
	// Look up the original fee transaction for this payment
	feeTx, err := s.repo.GetFeeTransactionBySource(ctx, paymentIntentID, "merchant_payment")
	if err != nil {
		// No fee was collected — nothing to refund
		return nil, nil
	}

	if !feeTx.IsRefundable {
		// Non-refundable fee — no reversal
		return feeTx, nil
	}

	if feeTx.FeeAmount <= 0 || feeTx.GrossAmount <= 0 {
		return feeTx, nil
	}

	// Calculate proportional fee refund: (refundAmount * feeAmount) / grossAmount
	feeRefundAmount := (refundAmount * feeTx.FeeAmount) / feeTx.GrossAmount
	if feeRefundAmount <= 0 {
		return feeTx, nil
	}

	// Don't exceed the remaining refundable amount
	maxRefundable := feeTx.FeeAmount - feeTx.RefundedFeeAmount
	if feeRefundAmount > maxRefundable {
		feeRefundAmount = maxRefundable
	}
	if feeRefundAmount <= 0 {
		return feeTx, nil
	}

	// Get the business account's Ledger Account
	bizAccount, err := s.repo.GetBusinessAccount(ctx, businessID)
	if err != nil {
		return nil, err
	}

	// Get the Platform Fee Revenue Account
	feeRevenueAcc, err := s.ledgerRepo.GetSystemAccount(ctx, "Platform Fee Account", currency, ledger.Revenue)
	if err != nil {
		return nil, err
	}

	// Post double-entry reversal: Business Asset DR, Platform Fee Revenue CR
	ledgerIdempKey := fmt.Sprintf("FEE-REFUND-%s", refundIdempotencyKey)
	entry := &ledger.JournalEntry{
		ID:              uuid.New(),
		TransactionType: ledger.Fee,
		ReferenceID:     fmt.Sprintf("FEE-REFUND-%s", paymentIntentID.String()),
		Description:     fmt.Sprintf("Remboursement commission MÏÏghO sur paiement %s (%d %s)", paymentIntentID.String()[:8], feeRefundAmount, currency),
		CreatedAt:       time.Now().UTC(),
	}

	postings := []*ledger.LedgerPosting{
		{
			ID:             uuid.New(),
			JournalEntryID: entry.ID,
			AccountID:      bizAccount.LedgerAccountID,
			Amount:         feeRefundAmount,
			IsCredit:       false, // Debit Business Asset (restores merchant balance)
			CreatedAt:      entry.CreatedAt,
		},
		{
			ID:             uuid.New(),
			JournalEntryID: entry.ID,
			AccountID:      feeRevenueAcc.ID,
			Amount:         feeRefundAmount,
			IsCredit:       true, // Credit Platform Fee Revenue (decreases platform revenue)
			CreatedAt:      entry.CreatedAt,
		},
	}

	if err := s.ledgerRepo.PostJournalEntry(ctx, entry, postings, ledgerIdempKey); err != nil {
		return nil, err
	}

	// Update the fee transaction status
	newRefundedTotal := feeTx.RefundedFeeAmount + feeRefundAmount
	newStatus := FeeStatusRefunded
	if newRefundedTotal < feeTx.FeeAmount {
		newStatus = FeeStatusCollected // partially refunded, still collected
	}
	if err := s.repo.UpdateFeeTransactionStatus(ctx, feeTx.ID, newStatus, newRefundedTotal, &entry.ID); err != nil {
		return nil, err
	}

	// Return updated fee transaction
	return s.repo.GetFeeTransaction(ctx, feeTx.ID)
}

// GetFeeSummary returns the derived fee summary for a business.
func (s *Service) GetFeeSummary(ctx context.Context, callerID uuid.UUID, businessID uuid.UUID, currency string) (*FeeSummary, error) {
	// Authorization: OWNER, ADMIN, or MANAGER
	member, err := s.repo.GetMember(ctx, businessID, callerID)
	if err != nil {
		return nil, ErrNotBusinessMember
	}
	if member.Role != "OWNER" && member.Role != "ADMIN" && member.Role != "MANAGER" {
		return nil, ErrNotBusinessMember
	}

	if currency == "" {
		currency = "FCFA"
	}
	return s.repo.GetFeeSummary(ctx, businessID, currency)
}

// ListFeeTransactions lists all fee transactions for a business.
func (s *Service) ListFeeTransactions(ctx context.Context, callerID uuid.UUID, businessID uuid.UUID) ([]*FeeTransaction, error) {
	// Authorization: OWNER, ADMIN, or MANAGER
	member, err := s.repo.GetMember(ctx, businessID, callerID)
	if err != nil {
		return nil, ErrNotBusinessMember
	}
	if member.Role != "OWNER" && member.Role != "ADMIN" && member.Role != "MANAGER" {
		return nil, ErrNotBusinessMember
	}
	return s.repo.ListFeeTransactions(ctx, businessID)
}
