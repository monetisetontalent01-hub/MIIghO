package business

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/ledger"
)

// Service coordinates business logic, authorization rules, and double-entry ledger linkage.
type Service struct {
	repo       Repository
	ledgerRepo ledger.Repository
}

func NewService(repo Repository, ledgerRepo ledger.Repository) *Service {
	return &Service{
		repo:       repo,
		ledgerRepo: ledgerRepo,
	}
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
		LedgerAccount:   ledgerAcc,
		AvailableBalance: balance,
		PendingBalance:  0,
		Currency:        bizAcc.Currency,
		IsSandbox:       true,
	}, nil
}
