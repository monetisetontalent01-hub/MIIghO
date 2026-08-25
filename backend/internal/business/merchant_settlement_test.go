package business

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/ledger"
)

// ════════════════════════════════════════════════════════════
// SETTLEMENT TEST HELPERS
// ════════════════════════════════════════════════════════════

type settlementTestEnv struct {
	*merchantTestEnv
	adminID   uuid.UUID
	managerID uuid.UUID
	cashierID uuid.UUID
}

func setupSettlementEnv(t *testing.T) *settlementTestEnv {
	t.Helper()

	base := setupMerchantEnv(t)
	ctx := context.Background()

	adminID := uuid.New()
	managerID := uuid.New()
	cashierID := uuid.New()

	// Add ADMIN
	_, err := base.svc.AddMember(ctx, base.business.Business.ID, base.ownerID, &AddMemberRequest{
		UserID: adminID,
		Role:   RoleAdmin,
	})
	if err != nil {
		t.Fatalf("setupSettlementEnv: failed to add ADMIN: %v", err)
	}

	// Add MANAGER
	_, err = base.svc.AddMember(ctx, base.business.Business.ID, base.ownerID, &AddMemberRequest{
		UserID: managerID,
		Role:   RoleManager,
	})
	if err != nil {
		t.Fatalf("setupSettlementEnv: failed to add MANAGER: %v", err)
	}

	// Add CASHIER
	_, err = base.svc.AddMember(ctx, base.business.Business.ID, base.ownerID, &AddMemberRequest{
		UserID: cashierID,
		Role:   RoleCashier,
	})
	if err != nil {
		t.Fatalf("setupSettlementEnv: failed to add CASHIER: %v", err)
	}

	return &settlementTestEnv{
		merchantTestEnv: base,
		adminID:         adminID,
		managerID:       managerID,
		cashierID:       cashierID,
	}
}

// createSucceededPayment helper creates and confirms a merchant payment intent.
func (e *settlementTestEnv) createSucceededPayment(t *testing.T, amount int64) *PaymentIntent {
	t.Helper()
	ctx := context.Background()

	e.fundClient(t, amount)

	intent, err := e.svc.CreatePaymentIntent(ctx, e.clientID, &CreatePaymentIntentRequest{
		QRCode:   e.qr.Code,
		Amount:   amount,
		Currency: "FCFA",
	})
	if err != nil {
		t.Fatalf("createSucceededPayment: failed to create intent: %v", err)
	}

	_, err = e.svc.ConfirmPaymentIntent(ctx, e.clientID, intent.ID, &ConfirmPaymentIntentRequest{})
	if err != nil {
		t.Fatalf("createSucceededPayment: failed to confirm intent: %v", err)
	}

	fetched, _ := e.bizRepo.GetPaymentIntent(ctx, intent.ID)
	return fetched
}

// ════════════════════════════════════════════════════════════
// MERCHANT SETTLEMENT TESTS (PHASE 3A.4)
// ════════════════════════════════════════════════════════════

func TestSettlement_Create(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	// 3 payments: 4 000 + 3 000 + 3 000 = 10 000 FCFA
	env.createSucceededPayment(t, 4000)
	env.createSucceededPayment(t, 3000)
	env.createSucceededPayment(t, 3000)

	receipt, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{
		IdempotencyKey: "settle-create-001",
	})
	if err != nil {
		t.Fatalf("expected settlement creation to succeed, got %v", err)
	}

	if receipt.Status != SettlementPending {
		t.Errorf("expected status PENDING, got %s", receipt.Status)
	}
	if receipt.TotalAmount != 10000 {
		t.Errorf("expected total amount 10000, got %d", receipt.TotalAmount)
	}
	if receipt.ItemCount != 3 {
		t.Errorf("expected 3 items in batch, got %d", receipt.ItemCount)
	}
	if !receipt.IsSandbox {
		t.Error("expected IsSandbox to be true")
	}
}

func TestSettlement_List(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	env.createSucceededPayment(t, 5000)

	_, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{})
	if err != nil {
		t.Fatalf("failed to create settlement: %v", err)
	}

	list, err := env.svc.ListSettlements(ctx, env.ownerID, env.business.Business.ID)
	if err != nil {
		t.Fatalf("failed to list settlements: %v", err)
	}

	if len(list) != 1 {
		t.Fatalf("expected 1 settlement, got %d", len(list))
	}
	if list[0].TotalAmount != 5000 {
		t.Errorf("expected amount 5000, got %d", list[0].TotalAmount)
	}
}

func TestSettlement_Detail(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	p1 := env.createSucceededPayment(t, 6000)
	p2 := env.createSucceededPayment(t, 4000)

	created, err := env.svc.CreateSettlement(ctx, env.adminID, env.business.Business.ID, &CreateSettlementRequest{})
	if err != nil {
		t.Fatalf("failed to create settlement: %v", err)
	}

	detail, err := env.svc.GetSettlement(ctx, env.managerID, env.business.Business.ID, created.SettlementID)
	if err != nil {
		t.Fatalf("failed to get settlement detail: %v", err)
	}

	if detail.TotalAmount != 10000 {
		t.Errorf("expected 10000, got %d", detail.TotalAmount)
	}
	if len(detail.Items) != 2 {
		t.Fatalf("expected 2 items, got %d", len(detail.Items))
	}

	// Verify items map to payment intents
	foundP1, foundP2 := false, false
	for _, it := range detail.Items {
		if it.PaymentIntentID == p1.ID && it.NetAmount == 6000 {
			foundP1 = true
		}
		if it.PaymentIntentID == p2.ID && it.NetAmount == 4000 {
			foundP2 = true
		}
	}
	if !foundP1 || !foundP2 {
		t.Errorf("items did not match payment intents: %+v", detail.Items)
	}
}

func TestSettlement_Authorization(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	env.createSucceededPayment(t, 10000)

	// CASHIER cannot create settlement
	_, err := env.svc.CreateSettlement(ctx, env.cashierID, env.business.Business.ID, &CreateSettlementRequest{})
	if !errors.Is(err, ErrInsufficientPermission) {
		t.Errorf("expected CASHIER creation to be rejected with ErrInsufficientPermission, got %v", err)
	}

	// MANAGER cannot create settlement
	_, err = env.svc.CreateSettlement(ctx, env.managerID, env.business.Business.ID, &CreateSettlementRequest{})
	if !errors.Is(err, ErrInsufficientPermission) {
		t.Errorf("expected MANAGER creation to be rejected with ErrInsufficientPermission, got %v", err)
	}

	// ADMIN can create settlement
	settlement, err := env.svc.CreateSettlement(ctx, env.adminID, env.business.Business.ID, &CreateSettlementRequest{})
	if err != nil {
		t.Fatalf("expected ADMIN creation to succeed, got %v", err)
	}

	// CASHIER cannot process settlement
	_, err = env.svc.ProcessSettlement(ctx, env.cashierID, env.business.Business.ID, settlement.SettlementID)
	if !errors.Is(err, ErrInsufficientPermission) {
		t.Errorf("expected CASHIER process to be rejected, got %v", err)
	}

	// MANAGER cannot process settlement
	_, err = env.svc.ProcessSettlement(ctx, env.managerID, env.business.Business.ID, settlement.SettlementID)
	if !errors.Is(err, ErrInsufficientPermission) {
		t.Errorf("expected MANAGER process to be rejected, got %v", err)
	}

	// OWNER can process settlement
	processed, err := env.svc.ProcessSettlement(ctx, env.ownerID, env.business.Business.ID, settlement.SettlementID)
	if err != nil {
		t.Fatalf("expected OWNER process to succeed, got %v", err)
	}
	if processed.Status != SettlementSucceeded {
		t.Errorf("expected SUCCEEDED status, got %s", processed.Status)
	}
}

func TestSettlement_IDOR(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	env.createSucceededPayment(t, 5000)

	// Create second business owned by outsider
	outsiderID := uuid.New()
	biz2, err := env.svc.CreateBusiness(ctx, outsiderID, &CreateBusinessRequest{
		LegalName:    "Other Biz SARL",
		DisplayName:  "Other Biz",
		BusinessType: "tech",
		Country:      "CD",
		Currency:     "FCFA",
	})
	if err != nil {
		t.Fatalf("failed to create other biz: %v", err)
	}

	// Outsider tries to create settlement for Business 1 -> 403 Forbidden
	_, err = env.svc.CreateSettlement(ctx, outsiderID, env.business.Business.ID, &CreateSettlementRequest{})
	if !errors.Is(err, ErrUnauthorizedAccess) {
		t.Errorf("expected outsider create to fail with ErrUnauthorizedAccess, got %v", err)
	}

	// Create valid settlement on Business 1
	s1, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{})
	if err != nil {
		t.Fatalf("failed to create settlement on biz 1: %v", err)
	}

	// Outsider tries to view settlement on Business 1 -> 403 Forbidden
	_, err = env.svc.GetSettlement(ctx, outsiderID, env.business.Business.ID, s1.SettlementID)
	if !errors.Is(err, ErrUnauthorizedAccess) {
		t.Errorf("expected outsider view to fail with ErrUnauthorizedAccess, got %v", err)
	}

	// Outsider tries to process settlement on Business 1 -> 403 Forbidden
	_, err = env.svc.ProcessSettlement(ctx, outsiderID, env.business.Business.ID, s1.SettlementID)
	if !errors.Is(err, ErrUnauthorizedAccess) {
		t.Errorf("expected outsider process to fail with ErrUnauthorizedAccess, got %v", err)
	}

	// Cross-tenant mismatch (valid user on Biz 1, but passing Biz 2's ID) -> 403 Forbidden
	_, err = env.svc.GetSettlement(ctx, env.ownerID, biz2.Business.ID, s1.SettlementID)
	if !errors.Is(err, ErrUnauthorizedAccess) {
		t.Errorf("expected cross-tenant access to fail with ErrUnauthorizedAccess, got %v", err)
	}
}

func TestSettlement_OnlySucceededPayments(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	// Only 1 succeeded payment of 7 000 FCFA
	env.createSucceededPayment(t, 7000)

	calc, err := env.svc.CalculateEligibleSettlement(ctx, env.ownerID, env.business.Business.ID)
	if err != nil {
		t.Fatalf("failed to calculate settlement: %v", err)
	}

	if calc.NetSettleable != 7000 {
		t.Errorf("expected 7000 net settleable, got %d", calc.NetSettleable)
	}
	if calc.EligibleCount != 1 {
		t.Errorf("expected 1 eligible payment, got %d", calc.EligibleCount)
	}
}

func TestSettlement_ExcludesFailedPayments(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	// Create payment intent but fail it (no confirmation)
	env.fundClient(t, 1000) // insufficient funds for 10 000
	intent, _ := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   10000,
		Currency: "FCFA",
	})
	_, _ = env.svc.ConfirmPaymentIntent(ctx, env.clientID, intent.ID, &ConfirmPaymentIntentRequest{})

	// Eligible calculation should return 0 eligible payments
	calc, err := env.svc.CalculateEligibleSettlement(ctx, env.ownerID, env.business.Business.ID)
	if err != nil {
		t.Fatalf("calculation error: %v", err)
	}
	if calc.NetSettleable != 0 || calc.EligibleCount != 0 {
		t.Errorf("expected 0 net settleable, got %d", calc.NetSettleable)
	}

	// Create settlement should return ErrNoEligiblePayments
	_, err = env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{})
	if !errors.Is(err, ErrNoEligiblePayments) {
		t.Errorf("expected ErrNoEligiblePayments, got %v", err)
	}
}

func TestSettlement_ExcludesExpiredPayments(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	// Create expired intent manually
	expiredIntent := &PaymentIntent{
		ID:          uuid.New(),
		BusinessID:  env.business.Business.ID,
		PayerUserID: env.clientID,
		Amount:      5000,
		Currency:    "FCFA",
		Status:      IntentExpired,
		CreatedAt:   time.Now().UTC().Add(-2 * time.Hour),
		ExpiresAt:   time.Now().UTC().Add(-1 * time.Hour),
	}
	_ = env.bizRepo.CreatePaymentIntent(ctx, expiredIntent)

	_, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{})
	if !errors.Is(err, ErrNoEligiblePayments) {
		t.Errorf("expected ErrNoEligiblePayments, got %v", err)
	}
}

func TestSettlement_RefundDeduction(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	// Payment: 10 000 FCFA
	payment := env.createSucceededPayment(t, 10000)

	// Refund: 3 000 FCFA
	_, err := env.svc.RefundPayment(ctx, env.ownerID, payment.ID, &CreateRefundRequest{
		Amount: 3000,
		Reason: "Article retourné",
	})
	if err != nil {
		t.Fatalf("refund failed: %v", err)
	}

	// Net Settlement expected = 10 000 - 3 000 = 7 000 FCFA
	calc, err := env.svc.CalculateEligibleSettlement(ctx, env.ownerID, env.business.Business.ID)
	if err != nil {
		t.Fatalf("calculation failed: %v", err)
	}

	if calc.GrossAmount != 10000 {
		t.Errorf("expected Gross 10000, got %d", calc.GrossAmount)
	}
	if calc.TotalRefunded != 3000 {
		t.Errorf("expected Refunded 3000, got %d", calc.TotalRefunded)
	}
	if calc.NetSettleable != 7000 {
		t.Errorf("expected Net 7000, got %d", calc.NetSettleable)
	}

	// Create settlement
	receipt, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{})
	if err != nil {
		t.Fatalf("settlement creation failed: %v", err)
	}

	if receipt.TotalAmount != 7000 {
		t.Errorf("expected batch total 7000, got %d", receipt.TotalAmount)
	}
	if receipt.Items[0].GrossAmount != 10000 || receipt.Items[0].RefundAmount != 3000 || receipt.Items[0].NetAmount != 7000 {
		t.Errorf("unexpected item amounts: %+v", receipt.Items[0])
	}
}

func TestSettlement_FullSettlement(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	env.createSucceededPayment(t, 10000)

	// Create and process full settlement of 10 000 FCFA
	created, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{})
	if err != nil {
		t.Fatalf("failed to create settlement: %v", err)
	}

	processed, err := env.svc.ProcessSettlement(ctx, env.ownerID, env.business.Business.ID, created.SettlementID)
	if err != nil {
		t.Fatalf("failed to process settlement: %v", err)
	}
	if processed.Status != SettlementSucceeded {
		t.Errorf("expected SUCCEEDED, got %s", processed.Status)
	}

	// Remaining available for settlement should now be 0
	calc, err := env.svc.CalculateEligibleSettlement(ctx, env.ownerID, env.business.Business.ID)
	if err != nil {
		t.Fatalf("failed to calculate remaining: %v", err)
	}
	if calc.NetSettleable != 0 {
		t.Errorf("expected remaining 0, got %d", calc.NetSettleable)
	}
}

func TestSettlement_PartialSettlement(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	// Payment: 10 000 FCFA
	env.createSucceededPayment(t, 10000)

	// Settlement 1: 6 000 FCFA
	s1, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{
		Amount: 6000,
	})
	if err != nil {
		t.Fatalf("failed to create s1: %v", err)
	}
	_, err = env.svc.ProcessSettlement(ctx, env.ownerID, env.business.Business.ID, s1.SettlementID)
	if err != nil {
		t.Fatalf("failed to process s1: %v", err)
	}

	// Remaining should be 4 000 FCFA
	calc, err := env.svc.CalculateEligibleSettlement(ctx, env.ownerID, env.business.Business.ID)
	if err != nil {
		t.Fatalf("failed to calculate remaining: %v", err)
	}
	if calc.NetSettleable != 4000 {
		t.Errorf("expected remaining 4000, got %d", calc.NetSettleable)
	}

	// Settlement 2: 4 000 FCFA
	s2, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{
		Amount: 4000,
	})
	if err != nil {
		t.Fatalf("failed to create s2: %v", err)
	}
	_, err = env.svc.ProcessSettlement(ctx, env.ownerID, env.business.Business.ID, s2.SettlementID)
	if err != nil {
		t.Fatalf("failed to process s2: %v", err)
	}

	// Settlement 3: Any further attempt (even 1 FCFA) must be rejected
	_, err = env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{
		Amount: 1,
	})
	if !errors.Is(err, ErrNoEligiblePayments) {
		t.Errorf("expected ErrNoEligiblePayments on third attempt, got %v", err)
	}
}

func TestSettlement_OverSettlement(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	env.createSucceededPayment(t, 10000)

	// Attempt to settle 12 000 FCFA on a 10 000 FCFA pool -> Rejected with ErrOverSettlement
	_, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{
		Amount: 12000,
	})
	if !errors.Is(err, ErrOverSettlement) {
		t.Errorf("expected ErrOverSettlement, got %v", err)
	}
}

func TestSettlement_DoubleSettlement(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	env.createSucceededPayment(t, 10000)

	// First settlement for full 10 000
	s1, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{
		Amount: 10000,
	})
	if err != nil {
		t.Fatalf("s1 failed: %v", err)
	}

	// While s1 is in-flight (PENDING), attempt another settlement for 10 000
	_, err = env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{
		Amount: 10000,
	})
	if !errors.Is(err, ErrNoEligiblePayments) && !errors.Is(err, ErrOverSettlement) {
		t.Errorf("expected double settlement to be blocked, got %v", err)
	}

	// Process s1
	_, err = env.svc.ProcessSettlement(ctx, env.ownerID, env.business.Business.ID, s1.SettlementID)
	if err != nil {
		t.Fatalf("process s1 failed: %v", err)
	}

	// After s1 succeeded, attempt again
	_, err = env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{})
	if !errors.Is(err, ErrNoEligiblePayments) {
		t.Errorf("expected ErrNoEligiblePayments, got %v", err)
	}
}

func TestSettlement_Idempotency(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	env.createSucceededPayment(t, 10000)

	// Call CreateSettlement twice with identical idempotency key
	idempKey := "idemp-settle-12345"
	s1, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{
		Amount:         10000,
		IdempotencyKey: idempKey,
	})
	if err != nil {
		t.Fatalf("s1 failed: %v", err)
	}

	s2, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{
		Amount:         10000,
		IdempotencyKey: idempKey,
	})
	if err != nil {
		t.Fatalf("s2 failed: %v", err)
	}

	if s1.SettlementID != s2.SettlementID {
		t.Errorf("expected same SettlementID, got %s vs %s", s1.SettlementID, s2.SettlementID)
	}

	// Conflicting payload on same key -> Error
	_, err = env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{
		Amount:         5000,
		IdempotencyKey: idempKey,
	})
	if !errors.Is(err, ledger.ErrIdempotencyConflict) {
		t.Errorf("expected ErrIdempotencyConflict, got %v", err)
	}
}

func TestSettlement_ConcurrentIdempotency(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	env.createSucceededPayment(t, 10000)

	const goroutines = 20
	var wg sync.WaitGroup
	results := make([]*SettlementReceipt, goroutines)
	errorsList := make([]error, goroutines)
	idempKey := "concurrent-settle-idemp"

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			r, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{
				Amount:         10000,
				IdempotencyKey: idempKey,
			})
			results[idx] = r
			errorsList[idx] = err
		}(i)
	}
	wg.Wait()

	var firstID uuid.UUID
	successCount := 0
	for i := 0; i < goroutines; i++ {
		if errorsList[i] == nil && results[i] != nil {
			successCount++
			if firstID == uuid.Nil {
				firstID = results[i].SettlementID
			} else if results[i].SettlementID != firstID {
				t.Errorf("goroutine %d got different ID %s vs %s", i, results[i].SettlementID, firstID)
			}
		}
	}

	if successCount != goroutines {
		t.Errorf("expected all 20 calls to succeed idempotently, got %d", successCount)
	}

	// Verify exactly 1 settlement created
	allSettlements, _ := env.bizRepo.ListSettlements(ctx, env.business.Business.ID)
	if len(allSettlements) != 1 {
		t.Errorf("expected exactly 1 settlement in repository, got %d", len(allSettlements))
	}
}

func TestSettlement_ConcurrentSettlement(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	env.createSucceededPayment(t, 10000)

	var wg sync.WaitGroup
	var s1, s2 *SettlementReceipt
	var err1, err2 error

	wg.Add(2)
	go func() {
		defer wg.Done()
		s1, err1 = env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{
			Amount:         10000,
			IdempotencyKey: "race-key-A",
		})
	}()
	go func() {
		defer wg.Done()
		s2, err2 = env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{
			Amount:         10000,
			IdempotencyKey: "race-key-B",
		})
	}()
	wg.Wait()

	// Exactly 1 must succeed, 1 must be rejected
	successCount := 0
	if err1 == nil && s1 != nil {
		successCount++
	}
	if err2 == nil && s2 != nil {
		successCount++
	}

	if successCount != 1 {
		t.Fatalf("expected exactly 1 success in non-idempotent race on 10000 pool, got %d (err1=%v, err2=%v)", successCount, err1, err2)
	}
}

func TestSettlement_Atomicity(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	env.createSucceededPayment(t, 10000)

	// Create settlement
	created, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{
		Amount: 10000,
	})
	if err != nil {
		t.Fatalf("failed to create settlement: %v", err)
	}

	// Drain business account by reversing/withdrawing before process
	bizAcc, _ := env.bizRepo.GetBusinessAccount(ctx, env.business.Business.ID)
	momoPool, _ := env.ledgerRepo.GetSystemAccount(ctx, "MoMo Settlement Pool", "FCFA", ledger.Liability)
	drainEntry := &ledger.JournalEntry{
		ID:              uuid.New(),
		TransactionType: ledger.Fee,
		ReferenceID:     "DRAIN-ACC",
		Description:     "Drain account for test",
		CreatedAt:       time.Now().UTC(),
	}
	_ = env.ledgerRepo.PostJournalEntry(ctx, drainEntry, []*ledger.LedgerPosting{
		{ID: uuid.New(), JournalEntryID: drainEntry.ID, AccountID: bizAcc.LedgerAccountID, Amount: 10000, IsCredit: true, CreatedAt: drainEntry.CreatedAt},
		{ID: uuid.New(), JournalEntryID: drainEntry.ID, AccountID: momoPool.ID, Amount: 10000, IsCredit: false, CreatedAt: drainEntry.CreatedAt},
	}, "drain-idemp")

	// Attempt process with insufficient funds -> FAILED
	_, err = env.svc.ProcessSettlement(ctx, env.ownerID, env.business.Business.ID, created.SettlementID)
	if !errors.Is(err, ErrPaymentFailed) {
		t.Errorf("expected ErrPaymentFailed, got %v", err)
	}

	// Verify settlement status is FAILED in repo
	st, _ := env.bizRepo.GetSettlement(ctx, created.SettlementID)
	if st.Status != SettlementFailed {
		t.Errorf("expected status FAILED, got %s", st.Status)
	}
}

func TestSettlement_LedgerIntegrity(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	env.createSucceededPayment(t, 10000)

	created, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{
		Amount: 10000,
	})
	if err != nil {
		t.Fatalf("create failed: %v", err)
	}

	processed, err := env.svc.ProcessSettlement(ctx, env.ownerID, env.business.Business.ID, created.SettlementID)
	if err != nil {
		t.Fatalf("process failed: %v", err)
	}

	if processed.JournalEntryID == nil {
		t.Fatal("expected non-nil JournalEntryID")
	}

	// Verify double-entry balance in ledger: DR == CR == 10 000
	detailed, _, err := env.svc.ledgerRepo.GetJournalEntry(ctx, *processed.JournalEntryID)
	if err != nil {
		t.Fatalf("failed to fetch journal entry: %v", err)
	}

	if detailed.TransactionType != ledger.MerchantSettlement {
		t.Errorf("expected TransactionType %s, got %s", ledger.MerchantSettlement, detailed.TransactionType)
	}

	postings, _ := env.ledgerRepo.GetPostingsForEntry(ctx, detailed.ID)
	var drTotal, crTotal int64
	for _, p := range postings {
		if p.IsCredit {
			crTotal += p.Amount
		} else {
			drTotal += p.Amount
		}
	}

	if drTotal != 10000 || crTotal != 10000 {
		t.Errorf("double-entry violation: DR=%d, CR=%d, expected 10000", drTotal, crTotal)
	}
}

func TestSettlement_CurrencyValidation(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	env.createSucceededPayment(t, 10000)

	// Business currency is FCFA. Attempt settlement with EUR -> Rejected
	_, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{
		Amount:   10000,
		Currency: "EUR",
	})
	if !errors.Is(err, ErrSettlementCurrencyMismatch) {
		t.Errorf("expected ErrSettlementCurrencyMismatch, got %v", err)
	}
}

func TestSettlement_BusinessIsolation(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	// Business 1 receives 10 000 FCFA
	env.createSucceededPayment(t, 10000)

	// Create Business 2
	owner2 := uuid.New()
	biz2, err := env.svc.CreateBusiness(ctx, owner2, &CreateBusinessRequest{
		LegalName:    "Isolated Biz SARL",
		DisplayName:  "Isolated Biz",
		BusinessType: "retail",
		Country:      "CD",
		Currency:     "FCFA",
	})
	if err != nil {
		t.Fatalf("failed to create biz2: %v", err)
	}

	// Business 2 has 0 eligible payments
	calc2, err := env.svc.CalculateEligibleSettlement(ctx, owner2, biz2.Business.ID)
	if err != nil {
		t.Fatalf("failed to calculate biz2: %v", err)
	}
	if calc2.NetSettleable != 0 || calc2.EligibleCount != 0 {
		t.Errorf("expected 0 eligible for biz2, got %d", calc2.NetSettleable)
	}

	// Business 2 cannot settle funds from Business 1
	_, err = env.svc.CreateSettlement(ctx, owner2, biz2.Business.ID, &CreateSettlementRequest{})
	if !errors.Is(err, ErrNoEligiblePayments) {
		t.Errorf("expected ErrNoEligiblePayments for biz2, got %v", err)
	}
}

func TestSettlement_AppendOnly(t *testing.T) {
	env := setupSettlementEnv(t)
	ctx := context.Background()

	// 1. Payment
	payment := env.createSucceededPayment(t, 10000)
	paymentJournalID := payment.JournalEntryID

	// 2. Refund 3 000
	ref, err := env.svc.RefundPayment(ctx, env.ownerID, payment.ID, &CreateRefundRequest{
		Amount: 3000,
	})
	if err != nil {
		t.Fatalf("refund failed: %v", err)
	}
	refundJournalID := ref.JournalEntryID

	// 3. Settle 7 000
	settle, err := env.svc.CreateSettlement(ctx, env.ownerID, env.business.Business.ID, &CreateSettlementRequest{})
	if err != nil {
		t.Fatalf("settlement create failed: %v", err)
	}
	processed, err := env.svc.ProcessSettlement(ctx, env.ownerID, env.business.Business.ID, settle.SettlementID)
	if err != nil {
		t.Fatalf("settlement process failed: %v", err)
	}
	settleJournalID := processed.JournalEntryID

	// Verify all 3 journal entries are completely intact and distinct (Append-Only)
	if *paymentJournalID == *refundJournalID || *paymentJournalID == *settleJournalID || *refundJournalID == *settleJournalID {
		t.Fatalf("journal entry IDs must all be distinct: payment=%v, refund=%v, settle=%v", paymentJournalID, refundJournalID, settleJournalID)
	}

	// Check that payment journal entry still exists with original debits and credits
	entry, postings, err := env.ledgerRepo.GetJournalEntry(ctx, *paymentJournalID)
	if err != nil || entry == nil || len(postings) != 2 {
		t.Errorf("payment journal entry was mutated or deleted! err=%v", err)
	}
}

func TestSettlement_NoPSP(t *testing.T) {
	// Verify that SandboxSettlementProvider is used and performs 0 network/PSP calls
	provider := NewSandboxSettlementProvider()
	ctx := context.Background()

	dummySettlement := &Settlement{
		ID:          uuid.New(),
		BusinessID:  uuid.New(),
		TotalAmount: 50000,
		Currency:    "FCFA",
		Status:      SettlementProcessing,
	}

	err := provider.ProcessSettlement(ctx, dummySettlement)
	if err != nil {
		t.Errorf("expected SandboxSettlementProvider to return nil, got %v", err)
	}
}
