package business

import (
	"context"
	"database/sql"
	"errors"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/miigho/miigho/internal/ledger"
)

// Repository defines data access operations for MÏÏghO Business Core & Merchant Payments.
type Repository interface {
	CreateBusinessWithAccountAndOwner(ctx context.Context, business *Business, account *BusinessAccount, member *BusinessMember, ledgerAcc *ledger.LedgerAccount) error
	GetBusiness(ctx context.Context, id uuid.UUID) (*Business, error)
	ListBusinessesForUser(ctx context.Context, userID uuid.UUID) ([]*BusinessSummary, error)
	UpdateBusiness(ctx context.Context, business *Business) error
	AddMember(ctx context.Context, member *BusinessMember) error
	GetMember(ctx context.Context, businessID, userID uuid.UUID) (*BusinessMember, error)
	GetMemberByID(ctx context.Context, memberID uuid.UUID) (*BusinessMember, error)
	GetMembers(ctx context.Context, businessID uuid.UUID) ([]*BusinessMember, error)
	UpdateMember(ctx context.Context, member *BusinessMember) error
	RemoveMember(ctx context.Context, businessID, memberID uuid.UUID) error
	GetBusinessAccount(ctx context.Context, businessID uuid.UUID) (*BusinessAccount, error)
	GetBusinessAccountByLedgerID(ctx context.Context, ledgerAccountID uuid.UUID) (*BusinessAccount, error)

	// Merchant QR Codes
	CreateMerchantQR(ctx context.Context, qr *MerchantQR) error
	GetMerchantQRByCode(ctx context.Context, code string) (*MerchantQR, error)
	GetMerchantQRByID(ctx context.Context, id uuid.UUID) (*MerchantQR, error)
	GetMerchantQRsByBusiness(ctx context.Context, businessID uuid.UUID) ([]*MerchantQR, error)
	UpdateMerchantQRStatus(ctx context.Context, qrID uuid.UUID, status MerchantQRStatus) error

	// Payment Intents
	CreatePaymentIntent(ctx context.Context, intent *PaymentIntent) error
	GetPaymentIntent(ctx context.Context, id uuid.UUID) (*PaymentIntent, error)
	GetPaymentIntentByIdempotencyKey(ctx context.Context, key string) (*PaymentIntent, error)
	UpdatePaymentIntentStatus(ctx context.Context, id uuid.UUID, status PaymentIntentStatus, confirmedAt *time.Time, journalEntryID *uuid.UUID) error

	// Refunds (Phase 3A.3)
	CreateRefund(ctx context.Context, refund *Refund) error
	GetRefund(ctx context.Context, id uuid.UUID) (*Refund, error)
	GetRefundByIdempotencyKey(ctx context.Context, key string) (*Refund, error)
	GetRefundsByPaymentIntent(ctx context.Context, paymentIntentID uuid.UUID) ([]*Refund, error)
	GetRefundsByBusiness(ctx context.Context, businessID uuid.UUID) ([]*Refund, error)
	UpdateRefundStatus(ctx context.Context, id uuid.UUID, status RefundStatus, completedAt *time.Time, journalEntryID *uuid.UUID) error
	GetTotalRefundedAmount(ctx context.Context, paymentIntentID uuid.UUID) (int64, error)

	// Settlements (Phase 3A.4)
	ListSucceededPaymentIntents(ctx context.Context, businessID uuid.UUID) ([]*PaymentIntent, error)
	CreateSettlement(ctx context.Context, settlement *Settlement, items []*SettlementItem) error
	GetSettlement(ctx context.Context, id uuid.UUID) (*Settlement, error)
	GetSettlementByIdempotencyKey(ctx context.Context, key string) (*Settlement, error)
	ListSettlements(ctx context.Context, businessID uuid.UUID) ([]*Settlement, error)
	GetSettlementItems(ctx context.Context, settlementID uuid.UUID) ([]*SettlementItem, error)
	UpdateSettlementStatus(ctx context.Context, id uuid.UUID, status SettlementStatus, processedAt *time.Time, journalEntryID *uuid.UUID, failureReason string) error
	GetTotalSettledAmount(ctx context.Context, paymentIntentID uuid.UUID) (int64, error)

	// Fees (Phase 3A.5)
	CreateFeeRule(ctx context.Context, rule *FeeRule) error
	GetFeeRule(ctx context.Context, id uuid.UUID) (*FeeRule, error)
	ListFeeRules(ctx context.Context, businessID uuid.UUID) ([]*FeeRule, error)
	GetActiveFeeRule(ctx context.Context, businessID uuid.UUID, txType string, currency string) (*FeeRule, error)
	UpdateFeeRuleStatus(ctx context.Context, id uuid.UUID, status FeeRuleStatus) error
	CreateFeeTransaction(ctx context.Context, feeTx *FeeTransaction) error
	GetFeeTransaction(ctx context.Context, id uuid.UUID) (*FeeTransaction, error)
	GetFeeTransactionBySource(ctx context.Context, sourceID uuid.UUID, sourceType string) (*FeeTransaction, error)
	GetFeeTransactionByIdempotencyKey(ctx context.Context, key string) (*FeeTransaction, error)
	ListFeeTransactions(ctx context.Context, businessID uuid.UUID) ([]*FeeTransaction, error)
	UpdateFeeTransactionStatus(ctx context.Context, id uuid.UUID, status FeeTransactionStatus, refundedAmount int64, journalEntryID *uuid.UUID) error
	GetFeeSummary(ctx context.Context, businessID uuid.UUID, currency string) (*FeeSummary, error)
	GetTotalFeesCollected(ctx context.Context, paymentIntentID uuid.UUID) (int64, error)
}

// MemoryBusinessRepository is an in-memory repository for sandbox and unit testing with full ACID-like locking.
type MemoryBusinessRepository struct {
	mu                 sync.RWMutex
	ledgerRepo         ledger.Repository
	businesses         map[uuid.UUID]*Business
	members            map[uuid.UUID]*BusinessMember               // memberID -> member
	bizMembers         map[uuid.UUID]map[uuid.UUID]*BusinessMember // bizID -> userID -> member
	accounts           map[uuid.UUID]*BusinessAccount              // bizID -> account
	ledgerMap          map[uuid.UUID]*BusinessAccount              // ledgerAccID -> account
	qrCodesByID        map[uuid.UUID]*MerchantQR
	qrCodesByCode      map[string]*MerchantQR
	paymentIntents     map[uuid.UUID]*PaymentIntent
	intentsByIdemp     map[string]*PaymentIntent
	refunds            map[uuid.UUID]*Refund
	refundsByIdemp     map[string]*Refund
	settlements        map[uuid.UUID]*Settlement
	settlementsByIdemp map[string]*Settlement
	settlementItems    map[uuid.UUID][]*SettlementItem // settlementID -> items
	feeRules           map[uuid.UUID]*FeeRule
	feeTransactions    map[uuid.UUID]*FeeTransaction
	feeTxBySource      map[string]*FeeTransaction // "sourceID:sourceType" -> feeTx
	feeTxByIdemp       map[string]*FeeTransaction
}

func NewMemoryBusinessRepository(ledgerRepo ledger.Repository) *MemoryBusinessRepository {
	return &MemoryBusinessRepository{
		ledgerRepo:         ledgerRepo,
		businesses:         make(map[uuid.UUID]*Business),
		members:            make(map[uuid.UUID]*BusinessMember),
		bizMembers:         make(map[uuid.UUID]map[uuid.UUID]*BusinessMember),
		accounts:           make(map[uuid.UUID]*BusinessAccount),
		ledgerMap:          make(map[uuid.UUID]*BusinessAccount),
		qrCodesByID:        make(map[uuid.UUID]*MerchantQR),
		qrCodesByCode:      make(map[string]*MerchantQR),
		paymentIntents:     make(map[uuid.UUID]*PaymentIntent),
		intentsByIdemp:     make(map[string]*PaymentIntent),
		refunds:            make(map[uuid.UUID]*Refund),
		refundsByIdemp:     make(map[string]*Refund),
		settlements:        make(map[uuid.UUID]*Settlement),
		settlementsByIdemp: make(map[string]*Settlement),
		settlementItems:    make(map[uuid.UUID][]*SettlementItem),
		feeRules:           make(map[uuid.UUID]*FeeRule),
		feeTransactions:    make(map[uuid.UUID]*FeeTransaction),
		feeTxBySource:      make(map[string]*FeeTransaction),
		feeTxByIdemp:       make(map[string]*FeeTransaction),
	}
}

func (r *MemoryBusinessRepository) CreateBusinessWithAccountAndOwner(
	ctx context.Context,
	business *Business,
	account *BusinessAccount,
	member *BusinessMember,
	ledgerAcc *ledger.LedgerAccount,
) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	// 1. Create Ledger Account first
	if err := r.ledgerRepo.CreateAccount(ctx, ledgerAcc); err != nil {
		return err
	}

	// 2. Persist Business
	if business.ID == uuid.Nil {
		business.ID = uuid.New()
	}
	now := time.Now().UTC()
	if business.CreatedAt.IsZero() {
		business.CreatedAt = now
	}
	business.UpdatedAt = now
	r.businesses[business.ID] = business

	// 3. Persist Business Account
	if account.ID == uuid.Nil {
		account.ID = uuid.New()
	}
	account.BusinessID = business.ID
	account.LedgerAccountID = ledgerAcc.ID
	account.CreatedAt = now
	account.UpdatedAt = now
	r.accounts[business.ID] = account
	r.ledgerMap[ledgerAcc.ID] = account

	// 4. Persist Owner Member
	if member.ID == uuid.Nil {
		member.ID = uuid.New()
	}
	member.BusinessID = business.ID
	member.CreatedAt = now
	member.UpdatedAt = now
	r.members[member.ID] = member

	if _, ok := r.bizMembers[business.ID]; !ok {
		r.bizMembers[business.ID] = make(map[uuid.UUID]*BusinessMember)
	}
	r.bizMembers[business.ID][member.UserID] = member

	return nil
}

func (r *MemoryBusinessRepository) GetBusiness(ctx context.Context, id uuid.UUID) (*Business, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	b, ok := r.businesses[id]
	if !ok {
		return nil, ErrBusinessNotFound
	}
	return b, nil
}

func (r *MemoryBusinessRepository) ListBusinessesForUser(ctx context.Context, userID uuid.UUID) ([]*BusinessSummary, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var summaries []*BusinessSummary
	for bizID, userMap := range r.bizMembers {
		if member, ok := userMap[userID]; ok && member.Status == MemberStatusActive {
			biz, ok := r.businesses[bizID]
			if !ok || biz.Status == StatusClosed {
				continue
			}

			var balance int64
			if acc, ok := r.accounts[bizID]; ok {
				bal, err := r.ledgerRepo.GetBalance(ctx, acc.LedgerAccountID)
				if err == nil {
					balance = bal
				}
			}

			summaries = append(summaries, &BusinessSummary{
				Business:         biz,
				UserRole:         member.Role,
				AvailableBalance: balance,
				Currency:         biz.Currency,
			})
		}
	}
	return summaries, nil
}

func (r *MemoryBusinessRepository) UpdateBusiness(ctx context.Context, business *Business) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, ok := r.businesses[business.ID]; !ok {
		return ErrBusinessNotFound
	}
	business.UpdatedAt = time.Now().UTC()
	r.businesses[business.ID] = business
	return nil
}

func (r *MemoryBusinessRepository) AddMember(ctx context.Context, member *BusinessMember) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, ok := r.businesses[member.BusinessID]; !ok {
		return ErrBusinessNotFound
	}

	if userMap, ok := r.bizMembers[member.BusinessID]; ok {
		if _, exists := userMap[member.UserID]; exists {
			return ErrDuplicateMember
		}
	} else {
		r.bizMembers[member.BusinessID] = make(map[uuid.UUID]*BusinessMember)
	}

	if member.ID == uuid.Nil {
		member.ID = uuid.New()
	}
	now := time.Now().UTC()
	member.CreatedAt = now
	member.UpdatedAt = now

	r.members[member.ID] = member
	r.bizMembers[member.BusinessID][member.UserID] = member
	return nil
}

func (r *MemoryBusinessRepository) GetMember(ctx context.Context, businessID, userID uuid.UUID) (*BusinessMember, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	if userMap, ok := r.bizMembers[businessID]; ok {
		if member, exists := userMap[userID]; exists {
			return member, nil
		}
	}
	return nil, ErrMemberNotFound
}

func (r *MemoryBusinessRepository) GetMemberByID(ctx context.Context, memberID uuid.UUID) (*BusinessMember, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	m, ok := r.members[memberID]
	if !ok {
		return nil, ErrMemberNotFound
	}
	return m, nil
}

func (r *MemoryBusinessRepository) GetMembers(ctx context.Context, businessID uuid.UUID) ([]*BusinessMember, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var result []*BusinessMember
	if userMap, ok := r.bizMembers[businessID]; ok {
		for _, m := range userMap {
			result = append(result, m)
		}
	}
	return result, nil
}

func (r *MemoryBusinessRepository) UpdateMember(ctx context.Context, member *BusinessMember) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, ok := r.members[member.ID]; !ok {
		return ErrMemberNotFound
	}
	member.UpdatedAt = time.Now().UTC()
	r.members[member.ID] = member
	if userMap, ok := r.bizMembers[member.BusinessID]; ok {
		userMap[member.UserID] = member
	}
	return nil
}

func (r *MemoryBusinessRepository) RemoveMember(ctx context.Context, businessID, memberID uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	m, ok := r.members[memberID]
	if !ok || m.BusinessID != businessID {
		return ErrMemberNotFound
	}

	delete(r.members, memberID)
	if userMap, ok := r.bizMembers[businessID]; ok {
		delete(userMap, m.UserID)
	}
	return nil
}

func (r *MemoryBusinessRepository) GetBusinessAccount(ctx context.Context, businessID uuid.UUID) (*BusinessAccount, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	acc, ok := r.accounts[businessID]
	if !ok {
		return nil, ErrBusinessAccountNotFound
	}
	return acc, nil
}

func (r *MemoryBusinessRepository) GetBusinessAccountByLedgerID(ctx context.Context, ledgerAccountID uuid.UUID) (*BusinessAccount, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	acc, ok := r.ledgerMap[ledgerAccountID]
	if !ok {
		return nil, ErrBusinessAccountNotFound
	}
	return acc, nil
}

// Merchant QR Codes (Memory)

func (r *MemoryBusinessRepository) CreateMerchantQR(ctx context.Context, qr *MerchantQR) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if qr.ID == uuid.Nil {
		qr.ID = uuid.New()
	}
	now := time.Now().UTC()
	if qr.CreatedAt.IsZero() {
		qr.CreatedAt = now
	}
	qr.UpdatedAt = now

	r.qrCodesByID[qr.ID] = qr
	r.qrCodesByCode[qr.Code] = qr
	return nil
}

func (r *MemoryBusinessRepository) GetMerchantQRByCode(ctx context.Context, code string) (*MerchantQR, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	qr, ok := r.qrCodesByCode[code]
	if !ok {
		return nil, ErrMerchantQRNotFound
	}
	return qr, nil
}

func (r *MemoryBusinessRepository) GetMerchantQRByID(ctx context.Context, id uuid.UUID) (*MerchantQR, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	qr, ok := r.qrCodesByID[id]
	if !ok {
		return nil, ErrMerchantQRNotFound
	}
	return qr, nil
}

func (r *MemoryBusinessRepository) GetMerchantQRsByBusiness(ctx context.Context, businessID uuid.UUID) ([]*MerchantQR, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var result []*MerchantQR
	for _, qr := range r.qrCodesByID {
		if qr.BusinessID == businessID {
			result = append(result, qr)
		}
	}
	return result, nil
}

func (r *MemoryBusinessRepository) UpdateMerchantQRStatus(ctx context.Context, qrID uuid.UUID, status MerchantQRStatus) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	qr, ok := r.qrCodesByID[qrID]
	if !ok {
		return ErrMerchantQRNotFound
	}
	qr.Status = status
	qr.UpdatedAt = time.Now().UTC()
	return nil
}

// Payment Intents (Memory)

func (r *MemoryBusinessRepository) CreatePaymentIntent(ctx context.Context, intent *PaymentIntent) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if intent.ID == uuid.Nil {
		intent.ID = uuid.New()
	}
	now := time.Now().UTC()
	if intent.CreatedAt.IsZero() {
		intent.CreatedAt = now
	}
	if intent.ExpiresAt.IsZero() {
		intent.ExpiresAt = now.Add(15 * time.Minute)
	}

	r.paymentIntents[intent.ID] = intent
	if intent.IdempotencyKey != "" {
		r.intentsByIdemp[intent.IdempotencyKey] = intent
	}
	return nil
}

func (r *MemoryBusinessRepository) GetPaymentIntent(ctx context.Context, id uuid.UUID) (*PaymentIntent, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	intent, ok := r.paymentIntents[id]
	if !ok {
		return nil, ErrPaymentIntentNotFound
	}
	return intent, nil
}

func (r *MemoryBusinessRepository) GetPaymentIntentByIdempotencyKey(ctx context.Context, key string) (*PaymentIntent, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	intent, ok := r.intentsByIdemp[key]
	if !ok {
		return nil, ErrPaymentIntentNotFound
	}
	return intent, nil
}

func (r *MemoryBusinessRepository) UpdatePaymentIntentStatus(ctx context.Context, id uuid.UUID, status PaymentIntentStatus, confirmedAt *time.Time, journalEntryID *uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	intent, ok := r.paymentIntents[id]
	if !ok {
		return ErrPaymentIntentNotFound
	}
	intent.Status = status
	if confirmedAt != nil {
		intent.ConfirmedAt = confirmedAt
	}
	if journalEntryID != nil {
		intent.JournalEntryID = journalEntryID
	}
	return nil
}

// Refunds (Memory - Phase 3A.3)

func (r *MemoryBusinessRepository) CreateRefund(ctx context.Context, refund *Refund) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if refund.IdempotencyKey != "" {
		if existing, ok := r.refundsByIdemp[refund.IdempotencyKey]; ok {
			if existing.Amount != refund.Amount {
				return ledger.ErrIdempotencyConflict
			}
			return ledger.ErrDuplicateIdempotency
		}
	}

	if refund.ID == uuid.Nil {
		refund.ID = uuid.New()
	}
	now := time.Now().UTC()
	if refund.CreatedAt.IsZero() {
		refund.CreatedAt = now
	}

	r.refunds[refund.ID] = refund
	if refund.IdempotencyKey != "" {
		r.refundsByIdemp[refund.IdempotencyKey] = refund
	}
	return nil
}

func (r *MemoryBusinessRepository) GetRefund(ctx context.Context, id uuid.UUID) (*Refund, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	refund, ok := r.refunds[id]
	if !ok {
		return nil, ErrRefundNotFound
	}
	return refund, nil
}

func (r *MemoryBusinessRepository) GetRefundByIdempotencyKey(ctx context.Context, key string) (*Refund, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	refund, ok := r.refundsByIdemp[key]
	if !ok {
		return nil, ErrRefundNotFound
	}
	return refund, nil
}

func (r *MemoryBusinessRepository) GetRefundsByPaymentIntent(ctx context.Context, paymentIntentID uuid.UUID) ([]*Refund, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var result []*Refund
	for _, ref := range r.refunds {
		if ref.PaymentIntentID == paymentIntentID {
			result = append(result, ref)
		}
	}
	return result, nil
}

func (r *MemoryBusinessRepository) GetRefundsByBusiness(ctx context.Context, businessID uuid.UUID) ([]*Refund, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var result []*Refund
	for _, ref := range r.refunds {
		if ref.BusinessID == businessID {
			result = append(result, ref)
		}
	}
	return result, nil
}

func (r *MemoryBusinessRepository) UpdateRefundStatus(ctx context.Context, id uuid.UUID, status RefundStatus, completedAt *time.Time, journalEntryID *uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	refund, ok := r.refunds[id]
	if !ok {
		return ErrRefundNotFound
	}
	refund.Status = status
	if completedAt != nil {
		refund.CompletedAt = completedAt
	}
	if journalEntryID != nil {
		refund.JournalEntryID = journalEntryID
	}
	return nil
}

func (r *MemoryBusinessRepository) GetTotalRefundedAmount(ctx context.Context, paymentIntentID uuid.UUID) (int64, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var total int64
	for _, ref := range r.refunds {
		if ref.PaymentIntentID == paymentIntentID && (ref.Status == RefundSucceeded || ref.Status == RefundRequested) {
			total += ref.Amount
		}
	}
	return total, nil
}

// Settlements (Memory - Phase 3A.4)

func (r *MemoryBusinessRepository) ListSucceededPaymentIntents(ctx context.Context, businessID uuid.UUID) ([]*PaymentIntent, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var intents []*PaymentIntent
	for _, intent := range r.paymentIntents {
		if intent.BusinessID == businessID && intent.Status == IntentSucceeded {
			intents = append(intents, intent)
		}
	}
	return intents, nil
}

func (r *MemoryBusinessRepository) CreateSettlement(ctx context.Context, settlement *Settlement, items []*SettlementItem) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if settlement.IdempotencyKey != "" {
		if existing, ok := r.settlementsByIdemp[settlement.IdempotencyKey]; ok {
			if existing.TotalAmount != settlement.TotalAmount {
				return ledger.ErrIdempotencyConflict
			}
			return ledger.ErrDuplicateIdempotency
		}
	}

	if settlement.ID == uuid.Nil {
		settlement.ID = uuid.New()
	}
	now := time.Now().UTC()
	if settlement.CreatedAt.IsZero() {
		settlement.CreatedAt = now
	}

	r.settlements[settlement.ID] = settlement
	if settlement.IdempotencyKey != "" {
		r.settlementsByIdemp[settlement.IdempotencyKey] = settlement
	}

	persistedItems := make([]*SettlementItem, 0, len(items))
	for _, it := range items {
		if it.ID == uuid.Nil {
			it.ID = uuid.New()
		}
		it.SettlementID = settlement.ID
		if it.CreatedAt.IsZero() {
			it.CreatedAt = now
		}
		persistedItems = append(persistedItems, it)
	}
	r.settlementItems[settlement.ID] = persistedItems

	return nil
}

func (r *MemoryBusinessRepository) GetSettlement(ctx context.Context, id uuid.UUID) (*Settlement, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	settlement, ok := r.settlements[id]
	if !ok {
		return nil, ErrSettlementNotFound
	}
	return settlement, nil
}

func (r *MemoryBusinessRepository) GetSettlementByIdempotencyKey(ctx context.Context, key string) (*Settlement, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	settlement, ok := r.settlementsByIdemp[key]
	if !ok {
		return nil, ErrSettlementNotFound
	}
	return settlement, nil
}

func (r *MemoryBusinessRepository) ListSettlements(ctx context.Context, businessID uuid.UUID) ([]*Settlement, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var result []*Settlement
	for _, s := range r.settlements {
		if s.BusinessID == businessID {
			result = append(result, s)
		}
	}
	return result, nil
}

func (r *MemoryBusinessRepository) GetSettlementItems(ctx context.Context, settlementID uuid.UUID) ([]*SettlementItem, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	items, ok := r.settlementItems[settlementID]
	if !ok {
		return []*SettlementItem{}, nil
	}
	return items, nil
}

func (r *MemoryBusinessRepository) UpdateSettlementStatus(ctx context.Context, id uuid.UUID, status SettlementStatus, processedAt *time.Time, journalEntryID *uuid.UUID, failureReason string) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	settlement, ok := r.settlements[id]
	if !ok {
		return ErrSettlementNotFound
	}
	settlement.Status = status
	if processedAt != nil {
		settlement.ProcessedAt = processedAt
	}
	if journalEntryID != nil {
		settlement.JournalEntryID = journalEntryID
	}
	if failureReason != "" {
		settlement.FailureReason = failureReason
	}
	return nil
}

func (r *MemoryBusinessRepository) GetTotalSettledAmount(ctx context.Context, paymentIntentID uuid.UUID) (int64, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var total int64
	for settlementID, items := range r.settlementItems {
		settlement, ok := r.settlements[settlementID]
		if !ok || (settlement.Status != SettlementSucceeded && settlement.Status != SettlementProcessing && settlement.Status != SettlementPending) {
			// Note: If a settlement is active (PENDING, PROCESSING, SUCCEEDED), we count its net amount
			// to protect against double settlement during in-flight batches.
			continue
		}
		for _, it := range items {
			if it.PaymentIntentID == paymentIntentID {
				total += it.NetAmount
			}
		}
	}
	return total, nil
}

// ========================
// Phase 3A.5 — Fee Repository (Memory)
// ========================

func (r *MemoryBusinessRepository) CreateFeeRule(ctx context.Context, rule *FeeRule) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.feeRules[rule.ID] = rule
	return nil
}

func (r *MemoryBusinessRepository) GetFeeRule(ctx context.Context, id uuid.UUID) (*FeeRule, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	rule, ok := r.feeRules[id]
	if !ok {
		return nil, ErrFeeRuleNotFound
	}
	return rule, nil
}

func (r *MemoryBusinessRepository) ListFeeRules(ctx context.Context, businessID uuid.UUID) ([]*FeeRule, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var result []*FeeRule
	for _, rule := range r.feeRules {
		if rule.BusinessID != nil && *rule.BusinessID == businessID {
			result = append(result, rule)
		}
	}
	return result, nil
}

func (r *MemoryBusinessRepository) GetActiveFeeRule(ctx context.Context, businessID uuid.UUID, txType string, currency string) (*FeeRule, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	now := time.Now().UTC()

	// Priority 1: Business-specific active rule
	for _, rule := range r.feeRules {
		if rule.BusinessID != nil && *rule.BusinessID == businessID &&
			rule.TransactionType == txType &&
			rule.Currency == currency &&
			rule.Status == FeeRuleActive &&
			!now.Before(rule.EffectiveFrom) &&
			(rule.EffectiveUntil == nil || !now.After(*rule.EffectiveUntil)) {
			return rule, nil
		}
	}

	// Priority 2: Global platform default (BusinessID == nil)
	for _, rule := range r.feeRules {
		if rule.BusinessID == nil &&
			rule.TransactionType == txType &&
			rule.Currency == currency &&
			rule.Status == FeeRuleActive &&
			!now.Before(rule.EffectiveFrom) &&
			(rule.EffectiveUntil == nil || !now.After(*rule.EffectiveUntil)) {
			return rule, nil
		}
	}

	return nil, ErrFeeRuleNotFound
}

func (r *MemoryBusinessRepository) UpdateFeeRuleStatus(ctx context.Context, id uuid.UUID, status FeeRuleStatus) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	rule, ok := r.feeRules[id]
	if !ok {
		return ErrFeeRuleNotFound
	}
	rule.Status = status
	rule.UpdatedAt = time.Now().UTC()
	return nil
}

func (r *MemoryBusinessRepository) CreateFeeTransaction(ctx context.Context, feeTx *FeeTransaction) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	// Enforce unique source constraint (equivalent to UNIQUE(source_transaction_id, source_transaction_type) in PostgreSQL)
	sourceKey := feeTx.SourceTransactionID.String() + ":" + feeTx.SourceTransactionType
	if _, exists := r.feeTxBySource[sourceKey]; exists {
		return ErrDuplicateFeeTransaction
	}

	// Check idempotency
	if feeTx.IdempotencyKey != "" {
		if existing, ok := r.feeTxByIdemp[feeTx.IdempotencyKey]; ok {
			// Already exists with same key — idempotent return handled by caller
			_ = existing
			return ErrFeeAlreadyCollected
		}
	}

	r.feeTransactions[feeTx.ID] = feeTx
	r.feeTxBySource[sourceKey] = feeTx
	if feeTx.IdempotencyKey != "" {
		r.feeTxByIdemp[feeTx.IdempotencyKey] = feeTx
	}
	return nil
}

func (r *MemoryBusinessRepository) GetFeeTransaction(ctx context.Context, id uuid.UUID) (*FeeTransaction, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	feeTx, ok := r.feeTransactions[id]
	if !ok {
		return nil, ErrFeeTransactionNotFound
	}
	return feeTx, nil
}

func (r *MemoryBusinessRepository) GetFeeTransactionBySource(ctx context.Context, sourceID uuid.UUID, sourceType string) (*FeeTransaction, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	key := sourceID.String() + ":" + sourceType
	feeTx, ok := r.feeTxBySource[key]
	if !ok {
		return nil, ErrFeeTransactionNotFound
	}
	return feeTx, nil
}

func (r *MemoryBusinessRepository) GetFeeTransactionByIdempotencyKey(ctx context.Context, key string) (*FeeTransaction, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	feeTx, ok := r.feeTxByIdemp[key]
	if !ok {
		return nil, ErrFeeTransactionNotFound
	}
	return feeTx, nil
}

func (r *MemoryBusinessRepository) ListFeeTransactions(ctx context.Context, businessID uuid.UUID) ([]*FeeTransaction, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var result []*FeeTransaction
	for _, ft := range r.feeTransactions {
		if ft.BusinessID == businessID {
			result = append(result, ft)
		}
	}
	return result, nil
}

func (r *MemoryBusinessRepository) UpdateFeeTransactionStatus(ctx context.Context, id uuid.UUID, status FeeTransactionStatus, refundedAmount int64, journalEntryID *uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	feeTx, ok := r.feeTransactions[id]
	if !ok {
		return ErrFeeTransactionNotFound
	}
	feeTx.Status = status
	if refundedAmount > 0 {
		feeTx.RefundedFeeAmount = refundedAmount
	}
	if journalEntryID != nil {
		feeTx.JournalEntryID = journalEntryID
	}
	return nil
}

func (r *MemoryBusinessRepository) GetFeeSummary(ctx context.Context, businessID uuid.UUID, currency string) (*FeeSummary, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	summary := &FeeSummary{
		BusinessID: businessID,
		Currency:   currency,
		IsSandbox:  true,
	}
	for _, ft := range r.feeTransactions {
		if ft.BusinessID == businessID && ft.Currency == currency {
			summary.TransactionCount++
			if ft.Status == FeeStatusCollected || ft.Status == FeeStatusRefunded {
				summary.TotalFeesCollected += ft.FeeAmount
				summary.TotalFeesRefunded += ft.RefundedFeeAmount
			}
		}
	}
	summary.NetFeeRevenue = summary.TotalFeesCollected - summary.TotalFeesRefunded
	return summary, nil
}

func (r *MemoryBusinessRepository) GetTotalFeesCollected(ctx context.Context, paymentIntentID uuid.UUID) (int64, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var total int64
	for _, ft := range r.feeTransactions {
		if ft.SourceTransactionID == paymentIntentID &&
			ft.SourceTransactionType == "merchant_payment" &&
			(ft.Status == FeeStatusCollected || ft.Status == FeeStatusRefunded) {
			total += ft.FeeAmount - ft.RefundedFeeAmount
		}
	}
	return total, nil
}

// PostgresBusinessRepository provides PostgreSQL persistence for MÏÏghO Business Core.
type PostgresBusinessRepository struct {
	pool       *pgxpool.Pool
	ledgerRepo ledger.Repository
}

func NewPostgresBusinessRepository(pool *pgxpool.Pool, ledgerRepo ledger.Repository) *PostgresBusinessRepository {
	return &PostgresBusinessRepository{
		pool:       pool,
		ledgerRepo: ledgerRepo,
	}
}

func (r *PostgresBusinessRepository) CreateBusinessWithAccountAndOwner(
	ctx context.Context,
	business *Business,
	account *BusinessAccount,
	member *BusinessMember,
	ledgerAcc *ledger.LedgerAccount,
) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// 1. Create Ledger Account
	if ledgerAcc.ID == uuid.Nil {
		ledgerAcc.ID = uuid.New()
	}
	if ledgerAcc.CreatedAt.IsZero() {
		ledgerAcc.CreatedAt = time.Now().UTC()
	}
	ledgerQuery := `
		INSERT INTO ledger_accounts (id, user_id, type, currency, name, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err = tx.Exec(ctx, ledgerQuery, ledgerAcc.ID, ledgerAcc.UserID, string(ledgerAcc.AccountType), ledgerAcc.Currency, ledgerAcc.Name, ledgerAcc.CreatedAt)
	if err != nil {
		return err
	}

	// 2. Insert Business
	if business.ID == uuid.Nil {
		business.ID = uuid.New()
	}
	now := time.Now().UTC()
	if business.CreatedAt.IsZero() {
		business.CreatedAt = now
	}
	business.UpdatedAt = now

	bizQuery := `
		INSERT INTO businesses (id, owner_user_id, legal_name, display_name, business_type, status, phone, email, country, currency, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`
	_, err = tx.Exec(ctx, bizQuery, business.ID, business.OwnerUserID, business.LegalName, business.DisplayName, business.BusinessType, string(business.Status), business.Phone, business.Email, business.Country, business.Currency, business.CreatedAt, business.UpdatedAt)
	if err != nil {
		return err
	}

	// 3. Insert Business Account
	if account.ID == uuid.Nil {
		account.ID = uuid.New()
	}
	account.BusinessID = business.ID
	account.LedgerAccountID = ledgerAcc.ID
	account.CreatedAt = now
	account.UpdatedAt = now

	accQuery := `
		INSERT INTO business_accounts (id, business_id, ledger_account_id, currency, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err = tx.Exec(ctx, accQuery, account.ID, account.BusinessID, account.LedgerAccountID, account.Currency, string(account.Status), account.CreatedAt, account.UpdatedAt)
	if err != nil {
		return err
	}

	// 4. Insert Owner Member
	if member.ID == uuid.Nil {
		member.ID = uuid.New()
	}
	member.BusinessID = business.ID
	member.CreatedAt = now
	member.UpdatedAt = now

	memberQuery := `
		INSERT INTO business_members (id, business_id, user_id, role, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err = tx.Exec(ctx, memberQuery, member.ID, member.BusinessID, member.UserID, string(member.Role), string(member.Status), member.CreatedAt, member.UpdatedAt)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}

func (r *PostgresBusinessRepository) GetBusiness(ctx context.Context, id uuid.UUID) (*Business, error) {
	query := `
		SELECT id, owner_user_id, legal_name, display_name, business_type, status, phone, email, country, currency, created_at, updated_at
		FROM businesses
		WHERE id = $1
	`
	var b Business
	var status string
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&b.ID, &b.OwnerUserID, &b.LegalName, &b.DisplayName, &b.BusinessType, &status, &b.Phone, &b.Email, &b.Country, &b.Currency, &b.CreatedAt, &b.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrBusinessNotFound
		}
		return nil, err
	}
	b.Status = BusinessStatus(status)
	return &b, nil
}

func (r *PostgresBusinessRepository) ListBusinessesForUser(ctx context.Context, userID uuid.UUID) ([]*BusinessSummary, error) {
	query := `
		SELECT b.id, b.owner_user_id, b.legal_name, b.display_name, b.business_type, b.status, b.phone, b.email, b.country, b.currency, b.created_at, b.updated_at,
		       bm.role, ba.ledger_account_id
		FROM businesses b
		INNER JOIN business_members bm ON b.id = bm.business_id
		LEFT JOIN business_accounts ba ON b.id = ba.business_id
		WHERE bm.user_id = $1 AND bm.status = 'ACTIVE' AND b.status != 'CLOSED'
		ORDER BY b.created_at DESC
	`
	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var summaries []*BusinessSummary
	for rows.Next() {
		var b Business
		var status, role string
		var ledgerAccID *uuid.UUID
		err := rows.Scan(
			&b.ID, &b.OwnerUserID, &b.LegalName, &b.DisplayName, &b.BusinessType, &status, &b.Phone, &b.Email, &b.Country, &b.Currency, &b.CreatedAt, &b.UpdatedAt,
			&role, &ledgerAccID,
		)
		if err != nil {
			return nil, err
		}
		b.Status = BusinessStatus(status)

		var balance int64
		if ledgerAccID != nil {
			bal, err := r.ledgerRepo.GetBalance(ctx, *ledgerAccID)
			if err == nil {
				balance = bal
			}
		}

		summaries = append(summaries, &BusinessSummary{
			Business:         &b,
			UserRole:         MemberRole(role),
			AvailableBalance: balance,
			Currency:         b.Currency,
		})
	}

	return summaries, nil
}

func (r *PostgresBusinessRepository) UpdateBusiness(ctx context.Context, business *Business) error {
	business.UpdatedAt = time.Now().UTC()
	query := `
		UPDATE businesses
		SET display_name = $1, business_type = $2, status = $3, phone = $4, email = $5, updated_at = $6
		WHERE id = $7
	`
	tag, err := r.pool.Exec(ctx, query, business.DisplayName, business.BusinessType, string(business.Status), business.Phone, business.Email, business.UpdatedAt, business.ID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrBusinessNotFound
	}
	return nil
}

func (r *PostgresBusinessRepository) AddMember(ctx context.Context, member *BusinessMember) error {
	if member.ID == uuid.Nil {
		member.ID = uuid.New()
	}
	now := time.Now().UTC()
	member.CreatedAt = now
	member.UpdatedAt = now

	query := `
		INSERT INTO business_members (id, business_id, user_id, role, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err := r.pool.Exec(ctx, query, member.ID, member.BusinessID, member.UserID, string(member.Role), string(member.Status), member.CreatedAt, member.UpdatedAt)
	if err != nil {
		return err
	}
	return nil
}

func (r *PostgresBusinessRepository) GetMember(ctx context.Context, businessID, userID uuid.UUID) (*BusinessMember, error) {
	query := `
		SELECT id, business_id, user_id, role, status, created_at, updated_at
		FROM business_members
		WHERE business_id = $1 AND user_id = $2
	`
	var m BusinessMember
	var role, status string
	err := r.pool.QueryRow(ctx, query, businessID, userID).Scan(&m.ID, &m.BusinessID, &m.UserID, &role, &status, &m.CreatedAt, &m.UpdatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrMemberNotFound
		}
		return nil, err
	}
	m.Role = MemberRole(role)
	m.Status = MemberStatus(status)
	return &m, nil
}

func (r *PostgresBusinessRepository) GetMemberByID(ctx context.Context, memberID uuid.UUID) (*BusinessMember, error) {
	query := `
		SELECT id, business_id, user_id, role, status, created_at, updated_at
		FROM business_members
		WHERE id = $1
	`
	var m BusinessMember
	var role, status string
	err := r.pool.QueryRow(ctx, query, memberID).Scan(&m.ID, &m.BusinessID, &m.UserID, &role, &status, &m.CreatedAt, &m.UpdatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrMemberNotFound
		}
		return nil, err
	}
	m.Role = MemberRole(role)
	m.Status = MemberStatus(status)
	return &m, nil
}

func (r *PostgresBusinessRepository) GetMembers(ctx context.Context, businessID uuid.UUID) ([]*BusinessMember, error) {
	query := `
		SELECT id, business_id, user_id, role, status, created_at, updated_at
		FROM business_members
		WHERE business_id = $1
		ORDER BY created_at ASC
	`
	rows, err := r.pool.Query(ctx, query, businessID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []*BusinessMember
	for rows.Next() {
		var m BusinessMember
		var role, status string
		if err := rows.Scan(&m.ID, &m.BusinessID, &m.UserID, &role, &status, &m.CreatedAt, &m.UpdatedAt); err != nil {
			return nil, err
		}
		m.Role = MemberRole(role)
		m.Status = MemberStatus(status)
		members = append(members, &m)
	}
	return members, nil
}

func (r *PostgresBusinessRepository) UpdateMember(ctx context.Context, member *BusinessMember) error {
	member.UpdatedAt = time.Now().UTC()
	query := `
		UPDATE business_members
		SET role = $1, status = $2, updated_at = $3
		WHERE id = $4
	`
	tag, err := r.pool.Exec(ctx, query, string(member.Role), string(member.Status), member.UpdatedAt, member.ID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrMemberNotFound
	}
	return nil
}

func (r *PostgresBusinessRepository) RemoveMember(ctx context.Context, businessID, memberID uuid.UUID) error {
	query := `
		DELETE FROM business_members
		WHERE id = $1 AND business_id = $2
	`
	tag, err := r.pool.Exec(ctx, query, memberID, businessID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrMemberNotFound
	}
	return nil
}

func (r *PostgresBusinessRepository) GetBusinessAccount(ctx context.Context, businessID uuid.UUID) (*BusinessAccount, error) {
	query := `
		SELECT id, business_id, ledger_account_id, currency, status, created_at, updated_at
		FROM business_accounts
		WHERE business_id = $1
	`
	var acc BusinessAccount
	var status string
	err := r.pool.QueryRow(ctx, query, businessID).Scan(&acc.ID, &acc.BusinessID, &acc.LedgerAccountID, &acc.Currency, &status, &acc.CreatedAt, &acc.UpdatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrBusinessAccountNotFound
		}
		return nil, err
	}
	acc.Status = BusinessAccountStatus(status)
	return &acc, nil
}

func (r *PostgresBusinessRepository) GetBusinessAccountByLedgerID(ctx context.Context, ledgerAccountID uuid.UUID) (*BusinessAccount, error) {
	query := `
		SELECT id, business_id, ledger_account_id, currency, status, created_at, updated_at
		FROM business_accounts
		WHERE ledger_account_id = $1
	`
	var acc BusinessAccount
	var status string
	err := r.pool.QueryRow(ctx, query, ledgerAccountID).Scan(&acc.ID, &acc.BusinessID, &acc.LedgerAccountID, &acc.Currency, &status, &acc.CreatedAt, &acc.UpdatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrBusinessAccountNotFound
		}
		return nil, err
	}
	acc.Status = BusinessAccountStatus(status)
	return &acc, nil
}

// Merchant QR Codes (Postgres)

func (r *PostgresBusinessRepository) CreateMerchantQR(ctx context.Context, qr *MerchantQR) error {
	if qr.ID == uuid.Nil {
		qr.ID = uuid.New()
	}
	now := time.Now().UTC()
	if qr.CreatedAt.IsZero() {
		qr.CreatedAt = now
	}
	qr.UpdatedAt = now

	query := `
		INSERT INTO merchant_qr_codes (id, business_id, code, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err := r.pool.Exec(ctx, query, qr.ID, qr.BusinessID, qr.Code, string(qr.Status), qr.CreatedAt, qr.UpdatedAt)
	return err
}

func (r *PostgresBusinessRepository) GetMerchantQRByCode(ctx context.Context, code string) (*MerchantQR, error) {
	query := `
		SELECT id, business_id, code, status, created_at, updated_at
		FROM merchant_qr_codes
		WHERE code = $1
	`
	var qr MerchantQR
	var status string
	err := r.pool.QueryRow(ctx, query, code).Scan(&qr.ID, &qr.BusinessID, &qr.Code, &status, &qr.CreatedAt, &qr.UpdatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrMerchantQRNotFound
		}
		return nil, err
	}
	qr.Status = MerchantQRStatus(status)
	return &qr, nil
}

func (r *PostgresBusinessRepository) GetMerchantQRByID(ctx context.Context, id uuid.UUID) (*MerchantQR, error) {
	query := `
		SELECT id, business_id, code, status, created_at, updated_at
		FROM merchant_qr_codes
		WHERE id = $1
	`
	var qr MerchantQR
	var status string
	err := r.pool.QueryRow(ctx, query, id).Scan(&qr.ID, &qr.BusinessID, &qr.Code, &status, &qr.CreatedAt, &qr.UpdatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrMerchantQRNotFound
		}
		return nil, err
	}
	qr.Status = MerchantQRStatus(status)
	return &qr, nil
}

func (r *PostgresBusinessRepository) GetMerchantQRsByBusiness(ctx context.Context, businessID uuid.UUID) ([]*MerchantQR, error) {
	query := `
		SELECT id, business_id, code, status, created_at, updated_at
		FROM merchant_qr_codes
		WHERE business_id = $1
		ORDER BY created_at DESC
	`
	rows, err := r.pool.Query(ctx, query, businessID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var qrs []*MerchantQR
	for rows.Next() {
		var qr MerchantQR
		var status string
		if err := rows.Scan(&qr.ID, &qr.BusinessID, &qr.Code, &status, &qr.CreatedAt, &qr.UpdatedAt); err != nil {
			return nil, err
		}
		qr.Status = MerchantQRStatus(status)
		qrs = append(qrs, &qr)
	}
	return qrs, nil
}

func (r *PostgresBusinessRepository) UpdateMerchantQRStatus(ctx context.Context, qrID uuid.UUID, status MerchantQRStatus) error {
	query := `
		UPDATE merchant_qr_codes
		SET status = $1, updated_at = $2
		WHERE id = $3
	`
	tag, err := r.pool.Exec(ctx, query, string(status), time.Now().UTC(), qrID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrMerchantQRNotFound
	}
	return nil
}

// Payment Intents (Postgres)

func (r *PostgresBusinessRepository) CreatePaymentIntent(ctx context.Context, intent *PaymentIntent) error {
	if intent.ID == uuid.Nil {
		intent.ID = uuid.New()
	}
	now := time.Now().UTC()
	if intent.CreatedAt.IsZero() {
		intent.CreatedAt = now
	}
	if intent.ExpiresAt.IsZero() {
		intent.ExpiresAt = now.Add(15 * time.Minute)
	}

	query := `
		INSERT INTO payment_intents (id, business_id, payer_user_id, merchant_qr_id, amount, currency, status, idempotency_key, created_at, expires_at, confirmed_at, journal_entry_id)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`
	_, err := r.pool.Exec(ctx, query, intent.ID, intent.BusinessID, intent.PayerUserID, intent.MerchantQRID, intent.Amount, intent.Currency, string(intent.Status), intent.IdempotencyKey, intent.CreatedAt, intent.ExpiresAt, intent.ConfirmedAt, intent.JournalEntryID)
	return err
}

func (r *PostgresBusinessRepository) GetPaymentIntent(ctx context.Context, id uuid.UUID) (*PaymentIntent, error) {
	query := `
		SELECT id, business_id, payer_user_id, merchant_qr_id, amount, currency, status, idempotency_key, created_at, expires_at, confirmed_at, journal_entry_id
		FROM payment_intents
		WHERE id = $1
	`
	var intent PaymentIntent
	var status string
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&intent.ID, &intent.BusinessID, &intent.PayerUserID, &intent.MerchantQRID,
		&intent.Amount, &intent.Currency, &status, &intent.IdempotencyKey,
		&intent.CreatedAt, &intent.ExpiresAt, &intent.ConfirmedAt, &intent.JournalEntryID,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrPaymentIntentNotFound
		}
		return nil, err
	}
	intent.Status = PaymentIntentStatus(status)
	return &intent, nil
}

func (r *PostgresBusinessRepository) GetPaymentIntentByIdempotencyKey(ctx context.Context, key string) (*PaymentIntent, error) {
	query := `
		SELECT id, business_id, payer_user_id, merchant_qr_id, amount, currency, status, idempotency_key, created_at, expires_at, confirmed_at, journal_entry_id
		FROM payment_intents
		WHERE idempotency_key = $1
	`
	var intent PaymentIntent
	var status string
	err := r.pool.QueryRow(ctx, query, key).Scan(
		&intent.ID, &intent.BusinessID, &intent.PayerUserID, &intent.MerchantQRID,
		&intent.Amount, &intent.Currency, &status, &intent.IdempotencyKey,
		&intent.CreatedAt, &intent.ExpiresAt, &intent.ConfirmedAt, &intent.JournalEntryID,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrPaymentIntentNotFound
		}
		return nil, err
	}
	intent.Status = PaymentIntentStatus(status)
	return &intent, nil
}

func (r *PostgresBusinessRepository) UpdatePaymentIntentStatus(ctx context.Context, id uuid.UUID, status PaymentIntentStatus, confirmedAt *time.Time, journalEntryID *uuid.UUID) error {
	query := `
		UPDATE payment_intents
		SET status = $1, confirmed_at = $2, journal_entry_id = $3
		WHERE id = $4
	`
	tag, err := r.pool.Exec(ctx, query, string(status), confirmedAt, journalEntryID, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrPaymentIntentNotFound
	}
	return nil
}

// Refunds (Postgres - Phase 3A.3)

func (r *PostgresBusinessRepository) CreateRefund(ctx context.Context, refund *Refund) error {
	if refund.ID == uuid.Nil {
		refund.ID = uuid.New()
	}
	now := time.Now().UTC()
	if refund.CreatedAt.IsZero() {
		refund.CreatedAt = now
	}

	query := `
		INSERT INTO refunds (id, payment_intent_id, business_id, payer_user_id, amount, currency, status, reason, idempotency_key, journal_entry_id, created_at, completed_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`
	_, err := r.pool.Exec(ctx, query, refund.ID, refund.PaymentIntentID, refund.BusinessID, refund.PayerUserID, refund.Amount, refund.Currency, string(refund.Status), refund.Reason, refund.IdempotencyKey, refund.JournalEntryID, refund.CreatedAt, refund.CompletedAt)
	return err
}

func (r *PostgresBusinessRepository) GetRefund(ctx context.Context, id uuid.UUID) (*Refund, error) {
	query := `
		SELECT id, payment_intent_id, business_id, payer_user_id, amount, currency, status, reason, idempotency_key, journal_entry_id, created_at, completed_at
		FROM refunds
		WHERE id = $1
	`
	var ref Refund
	var status string
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&ref.ID, &ref.PaymentIntentID, &ref.BusinessID, &ref.PayerUserID,
		&ref.Amount, &ref.Currency, &status, &ref.Reason, &ref.IdempotencyKey,
		&ref.JournalEntryID, &ref.CreatedAt, &ref.CompletedAt,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrRefundNotFound
		}
		return nil, err
	}
	ref.Status = RefundStatus(status)
	return &ref, nil
}

func (r *PostgresBusinessRepository) GetRefundByIdempotencyKey(ctx context.Context, key string) (*Refund, error) {
	query := `
		SELECT id, payment_intent_id, business_id, payer_user_id, amount, currency, status, reason, idempotency_key, journal_entry_id, created_at, completed_at
		FROM refunds
		WHERE idempotency_key = $1
	`
	var ref Refund
	var status string
	err := r.pool.QueryRow(ctx, query, key).Scan(
		&ref.ID, &ref.PaymentIntentID, &ref.BusinessID, &ref.PayerUserID,
		&ref.Amount, &ref.Currency, &status, &ref.Reason, &ref.IdempotencyKey,
		&ref.JournalEntryID, &ref.CreatedAt, &ref.CompletedAt,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrRefundNotFound
		}
		return nil, err
	}
	ref.Status = RefundStatus(status)
	return &ref, nil
}

func (r *PostgresBusinessRepository) GetRefundsByPaymentIntent(ctx context.Context, paymentIntentID uuid.UUID) ([]*Refund, error) {
	query := `
		SELECT id, payment_intent_id, business_id, payer_user_id, amount, currency, status, reason, idempotency_key, journal_entry_id, created_at, completed_at
		FROM refunds
		WHERE payment_intent_id = $1
		ORDER BY created_at DESC
	`
	rows, err := r.pool.Query(ctx, query, paymentIntentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var refs []*Refund
	for rows.Next() {
		var ref Refund
		var status string
		if err := rows.Scan(
			&ref.ID, &ref.PaymentIntentID, &ref.BusinessID, &ref.PayerUserID,
			&ref.Amount, &ref.Currency, &status, &ref.Reason, &ref.IdempotencyKey,
			&ref.JournalEntryID, &ref.CreatedAt, &ref.CompletedAt,
		); err != nil {
			return nil, err
		}
		ref.Status = RefundStatus(status)
		refs = append(refs, &ref)
	}
	return refs, nil
}

func (r *PostgresBusinessRepository) GetRefundsByBusiness(ctx context.Context, businessID uuid.UUID) ([]*Refund, error) {
	query := `
		SELECT id, payment_intent_id, business_id, payer_user_id, amount, currency, status, reason, idempotency_key, journal_entry_id, created_at, completed_at
		FROM refunds
		WHERE business_id = $1
		ORDER BY created_at DESC
	`
	rows, err := r.pool.Query(ctx, query, businessID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var refs []*Refund
	for rows.Next() {
		var ref Refund
		var status string
		if err := rows.Scan(
			&ref.ID, &ref.PaymentIntentID, &ref.BusinessID, &ref.PayerUserID,
			&ref.Amount, &ref.Currency, &status, &ref.Reason, &ref.IdempotencyKey,
			&ref.JournalEntryID, &ref.CreatedAt, &ref.CompletedAt,
		); err != nil {
			return nil, err
		}
		ref.Status = RefundStatus(status)
		refs = append(refs, &ref)
	}
	return refs, nil
}

func (r *PostgresBusinessRepository) UpdateRefundStatus(ctx context.Context, id uuid.UUID, status RefundStatus, completedAt *time.Time, journalEntryID *uuid.UUID) error {
	query := `
		UPDATE refunds
		SET status = $1, completed_at = $2, journal_entry_id = $3
		WHERE id = $4
	`
	tag, err := r.pool.Exec(ctx, query, string(status), completedAt, journalEntryID, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrRefundNotFound
	}
	return nil
}

func (r *PostgresBusinessRepository) GetTotalRefundedAmount(ctx context.Context, paymentIntentID uuid.UUID) (int64, error) {
	query := `
		SELECT COALESCE(SUM(amount), 0)
		FROM refunds
		WHERE payment_intent_id = $1 AND status IN ('REQUESTED', 'SUCCEEDED')
	`
	var total int64
	err := r.pool.QueryRow(ctx, query, paymentIntentID).Scan(&total)
	return total, err
}

// Settlements (Postgres - Phase 3A.4)

func (r *PostgresBusinessRepository) ListSucceededPaymentIntents(ctx context.Context, businessID uuid.UUID) ([]*PaymentIntent, error) {
	query := `
		SELECT id, business_id, payer_user_id, merchant_qr_id, amount, currency, status,
		       idempotency_key, created_at, expires_at, confirmed_at, journal_entry_id
		FROM payment_intents
		WHERE business_id = $1 AND status = 'SUCCEEDED'
		ORDER BY created_at ASC
	`
	rows, err := r.pool.Query(ctx, query, businessID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var intents []*PaymentIntent
	for rows.Next() {
		var intent PaymentIntent
		var status string
		if err := rows.Scan(
			&intent.ID, &intent.BusinessID, &intent.PayerUserID, &intent.MerchantQRID,
			&intent.Amount, &intent.Currency, &status, &intent.IdempotencyKey,
			&intent.CreatedAt, &intent.ExpiresAt, &intent.ConfirmedAt, &intent.JournalEntryID,
		); err != nil {
			return nil, err
		}
		intent.Status = PaymentIntentStatus(status)
		intents = append(intents, &intent)
	}
	return intents, nil
}

func (r *PostgresBusinessRepository) CreateSettlement(ctx context.Context, settlement *Settlement, items []*SettlementItem) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	if settlement.ID == uuid.Nil {
		settlement.ID = uuid.New()
	}
	now := time.Now().UTC()
	if settlement.CreatedAt.IsZero() {
		settlement.CreatedAt = now
	}

	settlementQuery := `
		INSERT INTO settlements (id, business_id, total_amount, currency, status, idempotency_key, journal_entry_id, failure_reason, created_at, processed_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`
	_, err = tx.Exec(ctx, settlementQuery,
		settlement.ID, settlement.BusinessID, settlement.TotalAmount, settlement.Currency,
		string(settlement.Status), settlement.IdempotencyKey, settlement.JournalEntryID,
		settlement.FailureReason, settlement.CreatedAt, settlement.ProcessedAt,
	)
	if err != nil {
		return err
	}

	itemQuery := `
		INSERT INTO settlement_items (id, settlement_id, payment_intent_id, gross_amount, refund_amount, net_amount, currency, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`
	for _, it := range items {
		if it.ID == uuid.Nil {
			it.ID = uuid.New()
		}
		it.SettlementID = settlement.ID
		if it.CreatedAt.IsZero() {
			it.CreatedAt = now
		}
		_, err = tx.Exec(ctx, itemQuery,
			it.ID, it.SettlementID, it.PaymentIntentID,
			it.GrossAmount, it.RefundAmount, it.NetAmount,
			it.Currency, it.CreatedAt,
		)
		if err != nil {
			return err
		}
	}

	return tx.Commit(ctx)
}

func (r *PostgresBusinessRepository) GetSettlement(ctx context.Context, id uuid.UUID) (*Settlement, error) {
	query := `
		SELECT id, business_id, total_amount, currency, status, idempotency_key, journal_entry_id, failure_reason, created_at, processed_at
		FROM settlements
		WHERE id = $1
	`
	var s Settlement
	var status string
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&s.ID, &s.BusinessID, &s.TotalAmount, &s.Currency, &status,
		&s.IdempotencyKey, &s.JournalEntryID, &s.FailureReason,
		&s.CreatedAt, &s.ProcessedAt,
	)
	if err != nil {
		return nil, ErrSettlementNotFound
	}
	s.Status = SettlementStatus(status)
	return &s, nil
}

func (r *PostgresBusinessRepository) GetSettlementByIdempotencyKey(ctx context.Context, key string) (*Settlement, error) {
	if key == "" {
		return nil, ErrSettlementNotFound
	}
	query := `
		SELECT id, business_id, total_amount, currency, status, idempotency_key, journal_entry_id, failure_reason, created_at, processed_at
		FROM settlements
		WHERE idempotency_key = $1
		LIMIT 1
	`
	var s Settlement
	var status string
	err := r.pool.QueryRow(ctx, query, key).Scan(
		&s.ID, &s.BusinessID, &s.TotalAmount, &s.Currency, &status,
		&s.IdempotencyKey, &s.JournalEntryID, &s.FailureReason,
		&s.CreatedAt, &s.ProcessedAt,
	)
	if err != nil {
		return nil, ErrSettlementNotFound
	}
	s.Status = SettlementStatus(status)
	return &s, nil
}

func (r *PostgresBusinessRepository) ListSettlements(ctx context.Context, businessID uuid.UUID) ([]*Settlement, error) {
	query := `
		SELECT id, business_id, total_amount, currency, status, idempotency_key, journal_entry_id, failure_reason, created_at, processed_at
		FROM settlements
		WHERE business_id = $1
		ORDER BY created_at DESC
	`
	rows, err := r.pool.Query(ctx, query, businessID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*Settlement
	for rows.Next() {
		var s Settlement
		var status string
		if err := rows.Scan(
			&s.ID, &s.BusinessID, &s.TotalAmount, &s.Currency, &status,
			&s.IdempotencyKey, &s.JournalEntryID, &s.FailureReason,
			&s.CreatedAt, &s.ProcessedAt,
		); err != nil {
			return nil, err
		}
		s.Status = SettlementStatus(status)
		result = append(result, &s)
	}
	return result, nil
}

func (r *PostgresBusinessRepository) GetSettlementItems(ctx context.Context, settlementID uuid.UUID) ([]*SettlementItem, error) {
	query := `
		SELECT id, settlement_id, payment_intent_id, gross_amount, refund_amount, net_amount, currency, created_at
		FROM settlement_items
		WHERE settlement_id = $1
		ORDER BY created_at ASC
	`
	rows, err := r.pool.Query(ctx, query, settlementID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []*SettlementItem
	for rows.Next() {
		var it SettlementItem
		if err := rows.Scan(
			&it.ID, &it.SettlementID, &it.PaymentIntentID,
			&it.GrossAmount, &it.RefundAmount, &it.NetAmount,
			&it.Currency, &it.CreatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, &it)
	}
	return items, nil
}

func (r *PostgresBusinessRepository) UpdateSettlementStatus(ctx context.Context, id uuid.UUID, status SettlementStatus, processedAt *time.Time, journalEntryID *uuid.UUID, failureReason string) error {
	query := `
		UPDATE settlements
		SET status = $1, processed_at = $2, journal_entry_id = $3, failure_reason = $4
		WHERE id = $5
	`
	tag, err := r.pool.Exec(ctx, query, string(status), processedAt, journalEntryID, failureReason, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrSettlementNotFound
	}
	return nil
}

func (r *PostgresBusinessRepository) GetTotalSettledAmount(ctx context.Context, paymentIntentID uuid.UUID) (int64, error) {
	query := `
		SELECT COALESCE(SUM(si.net_amount), 0)
		FROM settlement_items si
		JOIN settlements s ON s.id = si.settlement_id
		WHERE si.payment_intent_id = $1 AND s.status IN ('PENDING', 'PROCESSING', 'SUCCEEDED')
	`
	var total int64
	err := r.pool.QueryRow(ctx, query, paymentIntentID).Scan(&total)
	return total, err
}

// ========================
// Phase 3A.5 — Fee Repository (Postgres)
// ========================

func (r *PostgresBusinessRepository) CreateFeeRule(ctx context.Context, rule *FeeRule) error {
	query := `
		INSERT INTO fee_rules (id, business_id, transaction_type, fee_type, fixed_amount, percentage_bps, minimum_fee, maximum_fee, currency, status, is_refundable, effective_from, effective_until, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
	`
	_, err := r.pool.Exec(ctx, query,
		rule.ID, rule.BusinessID, rule.TransactionType, string(rule.FeeType),
		rule.FixedAmount, rule.PercentageBps, rule.MinimumFee, rule.MaximumFee,
		rule.Currency, string(rule.Status), rule.IsRefundable,
		rule.EffectiveFrom, rule.EffectiveUntil, rule.CreatedAt, rule.UpdatedAt,
	)
	return err
}

func (r *PostgresBusinessRepository) GetFeeRule(ctx context.Context, id uuid.UUID) (*FeeRule, error) {
	query := `
		SELECT id, business_id, transaction_type, fee_type, fixed_amount, percentage_bps, minimum_fee, maximum_fee, currency, status, is_refundable, effective_from, effective_until, created_at, updated_at
		FROM fee_rules WHERE id = $1
	`
	var rule FeeRule
	var businessID sql.NullString
	var effectiveUntil sql.NullTime
	var feeType, status string
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&rule.ID, &businessID, &rule.TransactionType, &feeType,
		&rule.FixedAmount, &rule.PercentageBps, &rule.MinimumFee, &rule.MaximumFee,
		&rule.Currency, &status, &rule.IsRefundable,
		&rule.EffectiveFrom, &effectiveUntil, &rule.CreatedAt, &rule.UpdatedAt,
	)
	if err != nil {
		return nil, ErrFeeRuleNotFound
	}
	rule.FeeType = FeeType(feeType)
	rule.Status = FeeRuleStatus(status)
	if businessID.Valid {
		parsed, _ := uuid.Parse(businessID.String)
		rule.BusinessID = &parsed
	}
	if effectiveUntil.Valid {
		rule.EffectiveUntil = &effectiveUntil.Time
	}
	return &rule, nil
}

func (r *PostgresBusinessRepository) ListFeeRules(ctx context.Context, businessID uuid.UUID) ([]*FeeRule, error) {
	query := `
		SELECT id, business_id, transaction_type, fee_type, fixed_amount, percentage_bps, minimum_fee, maximum_fee, currency, status, is_refundable, effective_from, effective_until, created_at, updated_at
		FROM fee_rules WHERE business_id = $1 ORDER BY created_at DESC
	`
	rows, err := r.pool.Query(ctx, query, businessID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var result []*FeeRule
	for rows.Next() {
		var rule FeeRule
		var businessIDN sql.NullString
		var effectiveUntil sql.NullTime
		var feeType, status string
		if err := rows.Scan(
			&rule.ID, &businessIDN, &rule.TransactionType, &feeType,
			&rule.FixedAmount, &rule.PercentageBps, &rule.MinimumFee, &rule.MaximumFee,
			&rule.Currency, &status, &rule.IsRefundable,
			&rule.EffectiveFrom, &effectiveUntil, &rule.CreatedAt, &rule.UpdatedAt,
		); err != nil {
			return nil, err
		}
		rule.FeeType = FeeType(feeType)
		rule.Status = FeeRuleStatus(status)
		if businessIDN.Valid {
			parsed, _ := uuid.Parse(businessIDN.String)
			rule.BusinessID = &parsed
		}
		if effectiveUntil.Valid {
			rule.EffectiveUntil = &effectiveUntil.Time
		}
		result = append(result, &rule)
	}
	return result, nil
}

func (r *PostgresBusinessRepository) GetActiveFeeRule(ctx context.Context, businessID uuid.UUID, txType string, currency string) (*FeeRule, error) {
	query := `
		SELECT id, business_id, transaction_type, fee_type, fixed_amount, percentage_bps, minimum_fee, maximum_fee, currency, status, is_refundable, effective_from, effective_until, created_at, updated_at
		FROM fee_rules
		WHERE (business_id = $1 OR business_id IS NULL)
		  AND transaction_type = $2 AND currency = $3 AND status = 'ACTIVE'
		  AND effective_from <= NOW()
		  AND (effective_until IS NULL OR effective_until >= NOW())
		ORDER BY business_id IS NULL ASC, created_at DESC
		LIMIT 1
	`
	var rule FeeRule
	var businessIDN sql.NullString
	var effectiveUntil sql.NullTime
	var feeType, status string
	err := r.pool.QueryRow(ctx, query, businessID, txType, currency).Scan(
		&rule.ID, &businessIDN, &rule.TransactionType, &feeType,
		&rule.FixedAmount, &rule.PercentageBps, &rule.MinimumFee, &rule.MaximumFee,
		&rule.Currency, &status, &rule.IsRefundable,
		&rule.EffectiveFrom, &effectiveUntil, &rule.CreatedAt, &rule.UpdatedAt,
	)
	if err != nil {
		return nil, ErrFeeRuleNotFound
	}
	rule.FeeType = FeeType(feeType)
	rule.Status = FeeRuleStatus(status)
	if businessIDN.Valid {
		parsed, _ := uuid.Parse(businessIDN.String)
		rule.BusinessID = &parsed
	}
	if effectiveUntil.Valid {
		rule.EffectiveUntil = &effectiveUntil.Time
	}
	return &rule, nil
}

func (r *PostgresBusinessRepository) UpdateFeeRuleStatus(ctx context.Context, id uuid.UUID, status FeeRuleStatus) error {
	query := `UPDATE fee_rules SET status = $1, updated_at = NOW() WHERE id = $2`
	tag, err := r.pool.Exec(ctx, query, string(status), id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrFeeRuleNotFound
	}
	return nil
}

func (r *PostgresBusinessRepository) CreateFeeTransaction(ctx context.Context, feeTx *FeeTransaction) error {
	query := `
		INSERT INTO fee_transactions (id, business_id, fee_rule_id, source_transaction_type, source_transaction_id, gross_amount, fee_amount, currency, status, is_refundable, refunded_fee_amount, idempotency_key, journal_entry_id, created_at, collected_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
	`
	_, err := r.pool.Exec(ctx, query,
		feeTx.ID, feeTx.BusinessID, feeTx.FeeRuleID,
		feeTx.SourceTransactionType, feeTx.SourceTransactionID,
		feeTx.GrossAmount, feeTx.FeeAmount, feeTx.Currency,
		string(feeTx.Status), feeTx.IsRefundable, feeTx.RefundedFeeAmount,
		feeTx.IdempotencyKey, feeTx.JournalEntryID, feeTx.CreatedAt, feeTx.CollectedAt,
	)
	return err
}

func (r *PostgresBusinessRepository) GetFeeTransaction(ctx context.Context, id uuid.UUID) (*FeeTransaction, error) {
	query := `
		SELECT id, business_id, fee_rule_id, source_transaction_type, source_transaction_id, gross_amount, fee_amount, currency, status, is_refundable, refunded_fee_amount, idempotency_key, journal_entry_id, created_at, collected_at
		FROM fee_transactions WHERE id = $1
	`
	return r.scanFeeTransaction(r.pool.QueryRow(ctx, query, id))
}

func (r *PostgresBusinessRepository) GetFeeTransactionBySource(ctx context.Context, sourceID uuid.UUID, sourceType string) (*FeeTransaction, error) {
	query := `
		SELECT id, business_id, fee_rule_id, source_transaction_type, source_transaction_id, gross_amount, fee_amount, currency, status, is_refundable, refunded_fee_amount, idempotency_key, journal_entry_id, created_at, collected_at
		FROM fee_transactions WHERE source_transaction_id = $1 AND source_transaction_type = $2
	`
	return r.scanFeeTransaction(r.pool.QueryRow(ctx, query, sourceID, sourceType))
}

func (r *PostgresBusinessRepository) GetFeeTransactionByIdempotencyKey(ctx context.Context, key string) (*FeeTransaction, error) {
	query := `
		SELECT id, business_id, fee_rule_id, source_transaction_type, source_transaction_id, gross_amount, fee_amount, currency, status, is_refundable, refunded_fee_amount, idempotency_key, journal_entry_id, created_at, collected_at
		FROM fee_transactions WHERE idempotency_key = $1
	`
	return r.scanFeeTransaction(r.pool.QueryRow(ctx, query, key))
}

func (r *PostgresBusinessRepository) scanFeeTransaction(row interface {
	Scan(dest ...interface{}) error
}) (*FeeTransaction, error) {
	var ft FeeTransaction
	var feeRuleID sql.NullString
	var journalEntryID sql.NullString
	var idempKey sql.NullString
	var collectedAt sql.NullTime
	var status string
	err := row.Scan(
		&ft.ID, &ft.BusinessID, &feeRuleID,
		&ft.SourceTransactionType, &ft.SourceTransactionID,
		&ft.GrossAmount, &ft.FeeAmount, &ft.Currency,
		&status, &ft.IsRefundable, &ft.RefundedFeeAmount,
		&idempKey, &journalEntryID, &ft.CreatedAt, &collectedAt,
	)
	if err != nil {
		return nil, ErrFeeTransactionNotFound
	}
	ft.Status = FeeTransactionStatus(status)
	if feeRuleID.Valid {
		parsed, _ := uuid.Parse(feeRuleID.String)
		ft.FeeRuleID = &parsed
	}
	if journalEntryID.Valid {
		parsed, _ := uuid.Parse(journalEntryID.String)
		ft.JournalEntryID = &parsed
	}
	if idempKey.Valid {
		ft.IdempotencyKey = idempKey.String
	}
	if collectedAt.Valid {
		ft.CollectedAt = &collectedAt.Time
	}
	return &ft, nil
}

func (r *PostgresBusinessRepository) ListFeeTransactions(ctx context.Context, businessID uuid.UUID) ([]*FeeTransaction, error) {
	query := `
		SELECT id, business_id, fee_rule_id, source_transaction_type, source_transaction_id, gross_amount, fee_amount, currency, status, is_refundable, refunded_fee_amount, idempotency_key, journal_entry_id, created_at, collected_at
		FROM fee_transactions WHERE business_id = $1 ORDER BY created_at DESC
	`
	rows, err := r.pool.Query(ctx, query, businessID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var result []*FeeTransaction
	for rows.Next() {
		ft, err := r.scanFeeTransaction(rows)
		if err != nil {
			return nil, err
		}
		result = append(result, ft)
	}
	return result, nil
}

func (r *PostgresBusinessRepository) UpdateFeeTransactionStatus(ctx context.Context, id uuid.UUID, status FeeTransactionStatus, refundedAmount int64, journalEntryID *uuid.UUID) error {
	query := `UPDATE fee_transactions SET status = $1, refunded_fee_amount = $2, journal_entry_id = COALESCE($3, journal_entry_id) WHERE id = $4`
	tag, err := r.pool.Exec(ctx, query, string(status), refundedAmount, journalEntryID, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrFeeTransactionNotFound
	}
	return nil
}

func (r *PostgresBusinessRepository) GetFeeSummary(ctx context.Context, businessID uuid.UUID, currency string) (*FeeSummary, error) {
	query := `
		SELECT
			COALESCE(SUM(CASE WHEN status IN ('COLLECTED', 'REFUNDED') THEN fee_amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN status IN ('COLLECTED', 'REFUNDED') THEN refunded_fee_amount ELSE 0 END), 0),
			COUNT(*)
		FROM fee_transactions WHERE business_id = $1 AND currency = $2
	`
	summary := &FeeSummary{
		BusinessID: businessID,
		Currency:   currency,
		IsSandbox:  true,
	}
	err := r.pool.QueryRow(ctx, query, businessID, currency).Scan(
		&summary.TotalFeesCollected, &summary.TotalFeesRefunded, &summary.TransactionCount,
	)
	if err != nil {
		return nil, err
	}
	summary.NetFeeRevenue = summary.TotalFeesCollected - summary.TotalFeesRefunded
	return summary, nil
}

func (r *PostgresBusinessRepository) GetTotalFeesCollected(ctx context.Context, paymentIntentID uuid.UUID) (int64, error) {
	query := `
		SELECT COALESCE(SUM(fee_amount - refunded_fee_amount), 0)
		FROM fee_transactions
		WHERE source_transaction_id = $1 AND source_transaction_type = 'merchant_payment' AND status IN ('COLLECTED', 'REFUNDED')
	`
	var total int64
	err := r.pool.QueryRow(ctx, query, paymentIntentID).Scan(&total)
	return total, err
}
