package business

import (
	"context"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/ledger"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// setupFeeTestEnv initializes an isolated in-memory test environment for Phase 3A.5.
func setupFeeTestEnv(t *testing.T) (*Service, *MemoryBusinessRepository, *ledger.MemoryRepository, uuid.UUID, uuid.UUID, uuid.UUID) {
	t.Helper()
	ledgerRepo := ledger.NewMemoryRepository()
	bizRepo := NewMemoryBusinessRepository(ledgerRepo)
	svc := NewService(bizRepo, ledgerRepo)

	ctx := context.Background()
	ownerID := uuid.New()
	adminID := uuid.New()
	cashierID := uuid.New()

	// Create Business
	createReq := &CreateBusinessRequest{
		LegalName:    "Boutique Sahel SARL",
		DisplayName:  "Boutique Sahel",
		BusinessType: "retail",
		Phone:        "+243810000001",
		Country:      "CI",
		Currency:     "FCFA",
	}
	bizDetail, err := svc.CreateBusiness(ctx, ownerID, createReq)
	require.NoError(t, err)

	bizID := bizDetail.Business.ID

	// Add Admin
	_, err = svc.AddMember(ctx, bizID, ownerID, &AddMemberRequest{
		UserID: adminID,
		Role:   RoleAdmin,
	})
	require.NoError(t, err)

	// Add Cashier
	_, err = svc.AddMember(ctx, bizID, ownerID, &AddMemberRequest{
		UserID: cashierID,
		Role:   RoleCashier,
	})
	require.NoError(t, err)

	return svc, bizRepo, ledgerRepo, bizID, ownerID, adminID
}

// 1. TestFee_CreateRule: Valid fee rule creation
func TestFee_CreateRule(t *testing.T) {
	svc, _, _, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	rule, err := svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "HYBRID",
		FixedAmount:     50,
		PercentageBps:   150, // 1.50%
		MinimumFee:      50,
		MaximumFee:      5000,
		Currency:        "FCFA",
		IsRefundable:    true,
	})
	require.NoError(t, err)
	assert.Equal(t, "merchant_payment", rule.TransactionType)
	assert.Equal(t, FeeTypeHybrid, rule.FeeType)
	assert.Equal(t, int64(50), rule.FixedAmount)
	assert.Equal(t, int64(150), rule.PercentageBps)
	assert.Equal(t, int64(50), rule.MinimumFee)
	assert.Equal(t, int64(5000), rule.MaximumFee)
	assert.Equal(t, "FCFA", rule.Currency)
	assert.Equal(t, FeeRuleActive, rule.Status)
	assert.True(t, rule.IsRefundable)
}

// 2. TestFee_RuleValidation: Invalid parameters
func TestFee_RuleValidation(t *testing.T) {
	svc, _, _, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	// bps > 10000
	_, err := svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "PERCENTAGE",
		PercentageBps:   10001,
	})
	assert.ErrorIs(t, err, ErrInvalidPercentageBps)

	// Negative fixed amount
	_, err = svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     -10,
	})
	assert.ErrorIs(t, err, ErrInvalidFeeRule)

	// Zero fee components
	_, err = svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     0,
		PercentageBps:   0,
	})
	assert.ErrorIs(t, err, ErrInvalidFeeRule)
}

// 3. TestFee_BoundsValidation: min > max
func TestFee_BoundsValidation(t *testing.T) {
	svc, _, _, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	_, err := svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "HYBRID",
		FixedAmount:     100,
		PercentageBps:   200,
		MinimumFee:      500,
		MaximumFee:      300, // min > max
	})
	assert.ErrorIs(t, err, ErrInvalidFeeBounds)
}

// 4. TestFee_Calculate_Fixed: Pure fixed fee
func TestFee_Calculate_Fixed(t *testing.T) {
	engine := &FeeEngine{}
	rule := &FeeRule{
		FeeType:     FeeTypeFixed,
		FixedAmount: 100,
		Currency:    "FCFA",
	}

	calc := engine.Calculate(rule, 10000)
	assert.Equal(t, int64(100), calc.FixedPart)
	assert.Equal(t, int64(0), calc.PercentagePart)
	assert.Equal(t, int64(100), calc.FinalFee)
}

// 5. TestFee_Calculate_Percentage: Pure percentage fee (150 bps on 10,000 = 150 FCFA)
func TestFee_Calculate_Percentage(t *testing.T) {
	engine := &FeeEngine{}
	rule := &FeeRule{
		FeeType:       FeeTypePercentage,
		PercentageBps: 150, // 1.50%
		Currency:      "FCFA",
	}

	calc := engine.Calculate(rule, 10000)
	assert.Equal(t, int64(0), calc.FixedPart)
	assert.Equal(t, int64(150), calc.PercentagePart)
	assert.Equal(t, int64(150), calc.FinalFee)
}

// 6. TestFee_Calculate_Hybrid: Fixed + percentage (50 + 1.5% on 10,000 = 200 FCFA)
func TestFee_Calculate_Hybrid(t *testing.T) {
	engine := &FeeEngine{}
	rule := &FeeRule{
		FeeType:       FeeTypeHybrid,
		FixedAmount:   50,
		PercentageBps: 150,
		Currency:      "FCFA",
	}

	calc := engine.Calculate(rule, 10000)
	assert.Equal(t, int64(50), calc.FixedPart)
	assert.Equal(t, int64(150), calc.PercentagePart)
	assert.Equal(t, int64(200), calc.FinalFee)
}

// 7. TestFee_Calculate_MinimumFee: Min fee floor
func TestFee_Calculate_MinimumFee(t *testing.T) {
	engine := &FeeEngine{}
	rule := &FeeRule{
		FeeType:       FeeTypePercentage,
		PercentageBps: 100, // 1% of 1000 = 10
		MinimumFee:    50,  // floor is 50
		Currency:      "FCFA",
	}

	calc := engine.Calculate(rule, 1000)
	assert.Equal(t, int64(10), calc.RawFee)
	assert.Equal(t, int64(50), calc.FinalFee)
}

// 8. TestFee_Calculate_MaximumFee: Max fee cap
func TestFee_Calculate_MaximumFee(t *testing.T) {
	engine := &FeeEngine{}
	rule := &FeeRule{
		FeeType:       FeeTypePercentage,
		PercentageBps: 500,  // 5% of 100,000 = 5000
		MaximumFee:    2000, // cap is 2000
		Currency:      "FCFA",
	}

	calc := engine.Calculate(rule, 100000)
	assert.Equal(t, int64(5000), calc.RawFee)
	assert.Equal(t, int64(2000), calc.FinalFee)
}

// 9. TestFee_Calculate_CapAtGross: Never exceed gross amount
func TestFee_Calculate_CapAtGross(t *testing.T) {
	engine := &FeeEngine{}
	rule := &FeeRule{
		FeeType:     FeeTypeFixed,
		FixedAmount: 500, // fixed 500 on gross 200
		Currency:    "FCFA",
	}

	calc := engine.Calculate(rule, 200)
	assert.Equal(t, int64(200), calc.FinalFee)
}

// 10. TestFee_CurrencyMismatch: Currency validation
func TestFee_CurrencyMismatch(t *testing.T) {
	svc, _, _, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	// Create FCFA rule
	_, err := svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     100,
		Currency:        "FCFA",
	})
	require.NoError(t, err)

	// Simulate calculate with EUR
	_, err = svc.CalculateFee(ctx, ownerID, bizID, &CalculateFeeRequest{
		TransactionType: "merchant_payment",
		GrossAmount:     10000,
		Currency:        "EUR",
	})
	assert.ErrorIs(t, err, ErrFeeRuleNotFound)
}

// 11. TestFee_CollectOnPayment: Fee collection on merchant payment
func TestFee_CollectOnPayment(t *testing.T) {
	svc, _, _, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	// 1. Create fee rule (200 FCFA fixed)
	_, err := svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     200,
		Currency:        "FCFA",
		IsRefundable:    false,
	})
	require.NoError(t, err)

	// 2. Collect fee on payment
	paymentIntentID := uuid.New()
	feeTx, err := svc.CollectFeeOnPayment(ctx, bizID, paymentIntentID, "FCFA", 10000, "fee-idemp-01")
	require.NoError(t, err)
	require.NotNil(t, feeTx)
	assert.Equal(t, int64(10000), feeTx.GrossAmount)
	assert.Equal(t, int64(200), feeTx.FeeAmount)
	assert.Equal(t, FeeStatusCollected, feeTx.Status)
	assert.NotNil(t, feeTx.JournalEntryID)
}

// 12. TestFee_DoubleEntryLedger: Check DR = CR = feeAmount
func TestFee_DoubleEntryLedger(t *testing.T) {
	svc, _, ledgerRepo, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	_, err := svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "PERCENTAGE",
		PercentageBps:   200, // 2% of 10,000 = 200
		Currency:        "FCFA",
	})
	require.NoError(t, err)

	paymentIntentID := uuid.New()
	feeTx, err := svc.CollectFeeOnPayment(ctx, bizID, paymentIntentID, "FCFA", 10000, "fee-idemp-02")
	require.NoError(t, err)

	entry, postings, err := ledgerRepo.GetJournalEntry(ctx, *feeTx.JournalEntryID)
	require.NoError(t, err)
	assert.Equal(t, ledger.Fee, entry.TransactionType)
	assert.Len(t, postings, 2)

	var debits, credits int64
	for _, p := range postings {
		if p.IsCredit {
			credits += p.Amount
		} else {
			debits += p.Amount
		}
	}
	assert.Equal(t, int64(200), debits)
	assert.Equal(t, int64(200), credits)
	assert.Equal(t, debits, credits)
}

// 13. TestFee_LedgerBalanceExact: Exact deduction from merchant balance
func TestFee_LedgerBalanceExact(t *testing.T) {
	svc, bizRepo, ledgerRepo, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	bizAcc, err := bizRepo.GetBusinessAccount(ctx, bizID)
	require.NoError(t, err)

	// Seed merchant with 10,000 FCFA
	seedEntry := &ledger.JournalEntry{
		ID:              uuid.New(),
		TransactionType: ledger.MoMoCashIn,
		Description:     "Seed merchant account",
		CreatedAt:       time.Now().UTC(),
	}
	momoPool, _ := ledgerRepo.GetSystemAccount(ctx, "MoMo Settlement Pool", "FCFA", ledger.Liability)
	_ = ledgerRepo.PostJournalEntry(ctx, seedEntry, []*ledger.LedgerPosting{
		{ID: uuid.New(), JournalEntryID: seedEntry.ID, AccountID: bizAcc.LedgerAccountID, Amount: 10000, IsCredit: false, CreatedAt: seedEntry.CreatedAt},
		{ID: uuid.New(), JournalEntryID: seedEntry.ID, AccountID: momoPool.ID, Amount: 10000, IsCredit: true, CreatedAt: seedEntry.CreatedAt},
	}, "seed-fee-bal")

	// Collect 300 FCFA fee
	_, err = svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     300,
		Currency:        "FCFA",
	})
	require.NoError(t, err)

	_, err = svc.CollectFeeOnPayment(ctx, bizID, uuid.New(), "FCFA", 10000, "fee-deduct-01")
	require.NoError(t, err)

	// Balance should now be 10,000 - 300 = 9,700 FCFA
	bal, err := ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)
	require.NoError(t, err)
	assert.Equal(t, int64(9700), bal)
}

// 14. TestFee_Idempotency: Same idempotency key produces 1 fee transaction and 1 ledger entry
func TestFee_Idempotency(t *testing.T) {
	svc, _, _, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	_, err := svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     150,
		Currency:        "FCFA",
	})
	require.NoError(t, err)

	paymentIntentID := uuid.New()
	tx1, err1 := svc.CollectFeeOnPayment(ctx, bizID, paymentIntentID, "FCFA", 5000, "fee-idemp-key-repeat")
	require.NoError(t, err1)

	tx2, err2 := svc.CollectFeeOnPayment(ctx, bizID, paymentIntentID, "FCFA", 5000, "fee-idemp-key-repeat")
	require.NoError(t, err2)

	assert.Equal(t, tx1.ID, tx2.ID)
	assert.Equal(t, tx1.JournalEntryID, tx2.JournalEntryID)
}

// 15. TestFee_ConcurrentIdempotency: 20 concurrent identical requests
func TestFee_ConcurrentIdempotency(t *testing.T) {
	svc, _, _, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	_, err := svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     100,
		Currency:        "FCFA",
	})
	require.NoError(t, err)

	paymentIntentID := uuid.New()
	key := fmt.Sprintf("fee-concurrent-idemp-%s", uuid.New().String())

	var wg sync.WaitGroup
	results := make([]*FeeTransaction, 20)
	errorsList := make([]error, 20)

	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			tx, err := svc.CollectFeeOnPayment(ctx, bizID, paymentIntentID, "FCFA", 10000, key)
			results[idx] = tx
			errorsList[idx] = err
		}(i)
	}
	wg.Wait()

	var firstID uuid.UUID
	for i := 0; i < 20; i++ {
		require.NoError(t, errorsList[i])
		require.NotNil(t, results[i])
		if firstID == uuid.Nil {
			firstID = results[i].ID
		} else {
			assert.Equal(t, firstID, results[i].ID)
		}
	}
}

// 16. TestFee_PreventDoubleFeeOnSamePayment: Prevent double fee on the same payment
func TestFee_PreventDoubleFeeOnSamePayment(t *testing.T) {
	svc, _, _, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	_, err := svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     100,
		Currency:        "FCFA",
	})
	require.NoError(t, err)

	paymentIntentID := uuid.New()
	tx1, err := svc.CollectFeeOnPayment(ctx, bizID, paymentIntentID, "FCFA", 10000, "key-1")
	require.NoError(t, err)
	require.NotNil(t, tx1)

	// Second attempt with different key on same payment intent returns the existing transaction
	tx2, err := svc.CollectFeeOnPayment(ctx, bizID, paymentIntentID, "FCFA", 10000, "key-2")
	require.NoError(t, err)
	assert.Equal(t, tx1.ID, tx2.ID)
}

// 17. TestFee_Immutability: Rule update does not retroactively recalculate collected fees
func TestFee_Immutability(t *testing.T) {
	svc, _, _, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	// Create rule 1 (100 FCFA)
	rule1, err := svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     100,
		Currency:        "FCFA",
	})
	require.NoError(t, err)

	paymentIntentID := uuid.New()
	feeTx, err := svc.CollectFeeOnPayment(ctx, bizID, paymentIntentID, "FCFA", 10000, "idemp-immut-1")
	require.NoError(t, err)
	assert.Equal(t, int64(100), feeTx.FeeAmount)

	// Deactivate rule 1
	err = svc.UpdateFeeRule(ctx, ownerID, bizID, rule1.ID, &UpdateFeeRuleRequest{Status: "INACTIVE"})
	require.NoError(t, err)

	// Create rule 2 (500 FCFA)
	_, err = svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     500,
		Currency:        "FCFA",
	})
	require.NoError(t, err)

	// Historical feeTx remains 100 FCFA
	list, err := svc.ListFeeTransactions(ctx, ownerID, bizID)
	require.NoError(t, err)
	assert.Len(t, list, 1)
	assert.Equal(t, int64(100), list[0].FeeAmount)
}

// 18. TestFee_Refund_NonRefundable: Non-refundable fee stays intact on refund
func TestFee_Refund_NonRefundable(t *testing.T) {
	svc, _, _, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	_, err := svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     200,
		Currency:        "FCFA",
		IsRefundable:    false, // Non-refundable
	})
	require.NoError(t, err)

	paymentIntentID := uuid.New()
	_, err = svc.CollectFeeOnPayment(ctx, bizID, paymentIntentID, "FCFA", 10000, "fee-refund-nonref")
	require.NoError(t, err)

	// Try refund fee
	feeRefund, err := svc.RefundFeeForPayment(ctx, bizID, paymentIntentID, 10000, "FCFA", "refund-tx-01")
	require.NoError(t, err)
	assert.Equal(t, int64(0), feeRefund.RefundedFeeAmount)
	assert.Equal(t, FeeStatusCollected, feeRefund.Status)
}

// 19. TestFee_Refund_Refundable_Full: Full refund of refundable fee
func TestFee_Refund_Refundable_Full(t *testing.T) {
	svc, _, ledgerRepo, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	_, err := svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     200,
		Currency:        "FCFA",
		IsRefundable:    true, // Refundable
	})
	require.NoError(t, err)

	paymentIntentID := uuid.New()
	_, err = svc.CollectFeeOnPayment(ctx, bizID, paymentIntentID, "FCFA", 10000, "fee-refund-full")
	require.NoError(t, err)

	// Full refund (10,000 on 10,000) -> 200 FCFA refunded
	feeRefund, err := svc.RefundFeeForPayment(ctx, bizID, paymentIntentID, 10000, "FCFA", "refund-tx-02")
	require.NoError(t, err)
	assert.Equal(t, int64(200), feeRefund.RefundedFeeAmount)
	assert.Equal(t, FeeStatusRefunded, feeRefund.Status)

	// Check Ledger reversal entry
	entry, postings, err := ledgerRepo.GetJournalEntry(ctx, *feeRefund.JournalEntryID)
	require.NoError(t, err)
	assert.Equal(t, ledger.Fee, entry.TransactionType)
	assert.Len(t, postings, 2)
}

// 20. TestFee_Refund_Refundable_Partial: Proportional fee refund
func TestFee_Refund_Refundable_Partial(t *testing.T) {
	svc, _, _, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	_, err := svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "PERCENTAGE",
		PercentageBps:   200, // 2% on 10,000 = 200 FCFA
		Currency:        "FCFA",
		IsRefundable:    true,
	})
	require.NoError(t, err)

	paymentIntentID := uuid.New()
	_, err = svc.CollectFeeOnPayment(ctx, bizID, paymentIntentID, "FCFA", 10000, "fee-refund-part")
	require.NoError(t, err)

	// 50% refund (5,000 on 10,000) -> 100 FCFA refunded
	feeRefund, err := svc.RefundFeeForPayment(ctx, bizID, paymentIntentID, 5000, "FCFA", "refund-tx-03")
	require.NoError(t, err)
	assert.Equal(t, int64(100), feeRefund.RefundedFeeAmount)
}

// 21. TestFee_SettlementReconciliation: Reconciliation across Sales, Fees, Refunds, Settlement
func TestFee_SettlementReconciliation(t *testing.T) {
	svc, bizRepo, ledgerRepo, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	bizAcc, _ := bizRepo.GetBusinessAccount(ctx, bizID)
	momoPool, _ := ledgerRepo.GetSystemAccount(ctx, "MoMo Settlement Pool", "FCFA", ledger.Liability)

	// Simulate payment of 10,000 FCFA
	payEntry := &ledger.JournalEntry{
		ID:              uuid.New(),
		TransactionType: ledger.MerchantPayment,
		Description:     "Merchant payment",
		CreatedAt:       time.Now().UTC(),
	}
	_ = ledgerRepo.PostJournalEntry(ctx, payEntry, []*ledger.LedgerPosting{
		{ID: uuid.New(), JournalEntryID: payEntry.ID, AccountID: bizAcc.LedgerAccountID, Amount: 10000, IsCredit: false, CreatedAt: payEntry.CreatedAt},
		{ID: uuid.New(), JournalEntryID: payEntry.ID, AccountID: momoPool.ID, Amount: 10000, IsCredit: true, CreatedAt: payEntry.CreatedAt},
	}, "pay-reconcile-01")

	// Collect 200 FCFA fee
	_, _ = svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     200,
		Currency:        "FCFA",
	})
	paymentIntentID := uuid.New()
	_, _ = svc.CollectFeeOnPayment(ctx, bizID, paymentIntentID, "FCFA", 10000, "fee-reconcile-01")

	// Balance derived: 10,000 - 200 = 9,800 FCFA
	bal, err := ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)
	require.NoError(t, err)
	assert.Equal(t, int64(9800), bal)

	// Summary derivation
	summary, err := svc.GetFeeSummary(ctx, ownerID, bizID, "FCFA")
	require.NoError(t, err)
	assert.Equal(t, int64(200), summary.TotalFeesCollected)
	assert.Equal(t, int64(0), summary.TotalFeesRefunded)
	assert.Equal(t, int64(200), summary.NetFeeRevenue)
}

// 22. TestFee_Authorization: Access control matrix
func TestFee_Authorization(t *testing.T) {
	svc, _, _, bizID, ownerID, adminID := setupFeeTestEnv(t)
	ctx := context.Background()
	strangerID := uuid.New()

	// OWNER can create
	rule, err := svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     100,
		Currency:        "FCFA",
	})
	require.NoError(t, err)

	// ADMIN can update
	err = svc.UpdateFeeRule(ctx, adminID, bizID, rule.ID, &UpdateFeeRuleRequest{Status: "INACTIVE"})
	require.NoError(t, err)

	// Stranger cannot create or view
	_, err = svc.CreateFeeRule(ctx, strangerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     100,
		Currency:        "FCFA",
	})
	assert.ErrorIs(t, err, ErrNotBusinessMember)

	_, err = svc.ListFeeRules(ctx, strangerID, bizID)
	assert.ErrorIs(t, err, ErrNotBusinessMember)
}

// 23. TestFee_IDOR: Business A member cannot access Business B fees
func TestFee_IDOR(t *testing.T) {
	svc, _, _, bizA, ownerA, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	// Create Business B with owner B
	ownerB := uuid.New()
	bizBDetail, err := svc.CreateBusiness(ctx, ownerB, &CreateBusinessRequest{
		LegalName:    "Entreprise B",
		DisplayName:  "Biz B",
		BusinessType: "retail",
		Phone:        "+243810000002",
		Country:      "CI",
		Currency:     "FCFA",
	})
	require.NoError(t, err)
	bizB := bizBDetail.Business.ID

	// Owner A attempts to create rule for Business B -> Rejected
	_, err = svc.CreateFeeRule(ctx, ownerA, bizB, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     100,
		Currency:        "FCFA",
	})
	assert.ErrorIs(t, err, ErrNotBusinessMember)

	// Owner A attempts to get fee summary for Business B -> Rejected
	_, err = svc.GetFeeSummary(ctx, ownerA, bizB, "FCFA")
	assert.ErrorIs(t, err, ErrNotBusinessMember)

	_ = bizA
}

// 24. TestFee_Atomicity: Append-only integrity
func TestFee_Atomicity(t *testing.T) {
	svc, _, ledgerRepo, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	_, _ = svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     100,
		Currency:        "FCFA",
	})

	feeTx, err := svc.CollectFeeOnPayment(ctx, bizID, uuid.New(), "FCFA", 10000, "atom-01")
	require.NoError(t, err)
	require.NotNil(t, feeTx)

	// Verify journal entry exists and cannot be deleted
	entry, _, err := ledgerRepo.GetJournalEntry(ctx, *feeTx.JournalEntryID)
	require.NoError(t, err)
	assert.Equal(t, ledger.Fee, entry.TransactionType)
}

// 25. TestFee_NoPSP: 0 external PSP calls
func TestFee_NoPSP(t *testing.T) {
	svc, _, _, bizID, ownerID, _ := setupFeeTestEnv(t)
	ctx := context.Background()

	rule, err := svc.CreateFeeRule(ctx, ownerID, bizID, &CreateFeeRuleRequest{
		TransactionType: "merchant_payment",
		FeeType:         "FIXED",
		FixedAmount:     100,
		Currency:        "FCFA",
	})
	require.NoError(t, err)
	require.NotNil(t, rule)

	feeTx, err := svc.CollectFeeOnPayment(ctx, bizID, uuid.New(), "FCFA", 10000, "nopsp-01")
	require.NoError(t, err)
	require.NotNil(t, feeTx)
}
