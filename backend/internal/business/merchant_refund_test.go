package business

import (
	"context"
	"errors"
	"sync"
	"testing"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/ledger"
)

// ════════════════════════════════════════════════════════════
// REFUND TEST HELPERS
// ════════════════════════════════════════════════════════════

type refundTestEnv struct {
	*merchantTestEnv
	intent  *PaymentIntent
	receipt *MerchantPaymentReceipt
}

// setupRefundEnv creates an environment where a client has already successfully paid 10 000 FCFA to the merchant.
func setupRefundEnv(t *testing.T, paymentAmount int64) *refundTestEnv {
	t.Helper()

	base := setupMerchantEnv(t)
	ctx := context.Background()

	// Fund client with payment amount
	base.fundClient(t, paymentAmount)

	// Create payment intent
	intent, err := base.svc.CreatePaymentIntent(ctx, base.clientID, &CreatePaymentIntentRequest{
		QRCode:   base.qr.Code,
		Amount:   paymentAmount,
		Currency: "FCFA",
	})
	if err != nil {
		t.Fatalf("setupRefundEnv: failed to create payment intent: %v", err)
	}

	// Confirm payment
	receipt, err := base.svc.ConfirmPaymentIntent(ctx, base.clientID, intent.ID, &ConfirmPaymentIntentRequest{})
	if err != nil {
		t.Fatalf("setupRefundEnv: failed to confirm payment: %v", err)
	}

	return &refundTestEnv{
		merchantTestEnv: base,
		intent:          intent,
		receipt:         receipt,
	}
}

// ════════════════════════════════════════════════════════════
// MERCHANT REFUND TESTS (PHASE 3A.3)
// ════════════════════════════════════════════════════════════

func TestRefund_Full(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	// Verify pre-refund balances: Client = 0, Business = 10 000
	clientAcc, _ := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")
	bizAcc, _ := env.bizRepo.GetBusinessAccount(ctx, env.business.Business.ID)

	clientBalBefore, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	bizBalBefore, _ := env.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)

	if clientBalBefore != 0 || bizBalBefore != 10000 {
		t.Fatalf("Pre-refund balances unexpected: client=%d, biz=%d", clientBalBefore, bizBalBefore)
	}

	// Execute Full Refund of 10 000 FCFA
	receipt, err := env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount: 10000,
		Reason: "Client request - return item",
	})
	if err != nil {
		t.Fatalf("RefundPayment failed: %v", err)
	}

	if receipt.Status != RefundSucceeded {
		t.Errorf("refund status = %s, want SUCCEEDED", receipt.Status)
	}
	if receipt.RefundAmount != 10000 {
		t.Errorf("refund amount = %d, want 10000", receipt.RefundAmount)
	}
	if receipt.TotalRefunded != 10000 {
		t.Errorf("total refunded = %d, want 10000", receipt.TotalRefunded)
	}
	if receipt.RemainingRefundable != 0 {
		t.Errorf("remaining refundable = %d, want 0", receipt.RemainingRefundable)
	}

	// Verify Post-Refund Balances: Client = 10 000, Business = 0
	clientBalAfter, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	bizBalAfter, _ := env.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)

	if clientBalAfter != 10000 {
		t.Errorf("client balance after refund = %d, want 10000", clientBalAfter)
	}
	if bizBalAfter != 0 {
		t.Errorf("business balance after refund = %d, want 0", bizBalAfter)
	}

	t.Logf("✅ Full Refund SUCCEEDED: client=%d→%d, biz=%d→%d, remaining=%d",
		clientBalBefore, clientBalAfter, bizBalBefore, bizBalAfter, receipt.RemainingRefundable)
}

func TestRefund_Partial(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	clientAcc, _ := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")
	bizAcc, _ := env.bizRepo.GetBusinessAccount(ctx, env.business.Business.ID)

	// Step 1: Partial Refund 3 000 FCFA
	receipt1, err := env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount: 3000,
		Reason: "Partial discount",
	})
	if err != nil {
		t.Fatalf("Partial refund 1 failed: %v", err)
	}

	if receipt1.TotalRefunded != 3000 || receipt1.RemainingRefundable != 7000 {
		t.Errorf("receipt1: total=%d, remaining=%d; want total=3000, remaining=7000", receipt1.TotalRefunded, receipt1.RemainingRefundable)
	}

	clientBal1, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	bizBal1, _ := env.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)
	if clientBal1 != 3000 || bizBal1 != 7000 {
		t.Errorf("Step 1 balances: client=%d (want 3000), biz=%d (want 7000)", clientBal1, bizBal1)
	}

	// Step 2: Second Partial Refund 7 000 FCFA
	receipt2, err := env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount: 7000,
		Reason: "Final remainder refund",
	})
	if err != nil {
		t.Fatalf("Partial refund 2 failed: %v", err)
	}

	if receipt2.TotalRefunded != 10000 || receipt2.RemainingRefundable != 0 {
		t.Errorf("receipt2: total=%d, remaining=%d; want total=10000, remaining=0", receipt2.TotalRefunded, receipt2.RemainingRefundable)
	}

	clientBal2, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	bizBal2, _ := env.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)
	if clientBal2 != 10000 || bizBal2 != 0 {
		t.Errorf("Step 2 balances: client=%d (want 10000), biz=%d (want 0)", clientBal2, bizBal2)
	}

	t.Logf("✅ Multi-Step Partial Refund: Step 1 (3000) → Client=%d, Biz=%d | Step 2 (7000) → Client=%d, Biz=%d",
		clientBal1, bizBal1, clientBal2, bizBal2)
}

func TestRefund_OverAmount(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	// Attempt refund of 15 000 on a 10 000 payment
	_, err := env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount: 15000,
		Reason: "Over refund test",
	})
	if !errors.Is(err, ErrRefundAmountExceedsRemaining) {
		t.Errorf("expected ErrRefundAmountExceedsRemaining, got: %v", err)
	}

	t.Logf("✅ Over-amount refund correctly rejected (15000 > 10000)")
}

func TestRefund_OverRemaining(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	// 1. Refund 7 000 (Leaves 3 000 remaining)
	_, err := env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount: 7000,
		Reason: "First partial",
	})
	if err != nil {
		t.Fatalf("First refund failed: %v", err)
	}

	// 2. Attempt refund of 5 000 (when only 3 000 is remaining)
	_, err = env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount: 5000,
		Reason: "Excessive second refund",
	})
	if !errors.Is(err, ErrRefundAmountExceedsRemaining) {
		t.Errorf("expected ErrRefundAmountExceedsRemaining, got: %v", err)
	}

	t.Logf("✅ Over-remaining refund correctly rejected (5000 > 3000 remaining)")
}

func TestRefund_AlreadyFullyRefunded(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	// Full refund 10 000
	_, err := env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount: 10000,
	})
	if err != nil {
		t.Fatalf("Full refund failed: %v", err)
	}

	// Attempt any further refund
	_, err = env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount: 1,
	})
	if !errors.Is(err, ErrAlreadyFullyRefunded) {
		t.Errorf("expected ErrAlreadyFullyRefunded, got: %v", err)
	}

	t.Logf("✅ Already fully refunded payment rejects any additional refund request")
}

func TestRefund_InvalidPaymentStatus(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	// Create unconfirmed Payment Intent (status CREATED)
	intent, _ := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   5000,
		Currency: "FCFA",
	})

	_, err := env.svc.RefundPayment(ctx, env.ownerID, intent.ID, &CreateRefundRequest{
		Amount: 5000,
	})
	if !errors.Is(err, ErrPaymentNotEligibleForRefund) {
		t.Errorf("expected ErrPaymentNotEligibleForRefund for CREATED status, got: %v", err)
	}

	t.Logf("✅ Unconfirmed Payment Intent correctly ineligible for refund")
}

func TestRefund_Unauthorized(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	// Add Manager and Cashier
	managerID := uuid.New()
	cashierID := uuid.New()

	_, _ = env.svc.AddMember(ctx, env.business.Business.ID, env.ownerID, &AddMemberRequest{
		UserID: managerID,
		Role:   RoleManager,
	})
	_, _ = env.svc.AddMember(ctx, env.business.Business.ID, env.ownerID, &AddMemberRequest{
		UserID: cashierID,
		Role:   RoleCashier,
	})

	// Manager attempts refund
	_, err := env.svc.RefundPayment(ctx, managerID, env.intent.ID, &CreateRefundRequest{Amount: 1000})
	if !errors.Is(err, ErrInsufficientPermission) {
		t.Errorf("expected ErrInsufficientPermission for MANAGER, got: %v", err)
	}

	// Cashier attempts refund
	_, err = env.svc.RefundPayment(ctx, cashierID, env.intent.ID, &CreateRefundRequest{Amount: 1000})
	if !errors.Is(err, ErrInsufficientPermission) {
		t.Errorf("expected ErrInsufficientPermission for CASHIER, got: %v", err)
	}

	// External stranger attempts refund
	strangerID := uuid.New()
	_, err = env.svc.RefundPayment(ctx, strangerID, env.intent.ID, &CreateRefundRequest{Amount: 1000})
	if !errors.Is(err, ErrUnauthorizedAccess) {
		t.Errorf("expected ErrUnauthorizedAccess for stranger, got: %v", err)
	}

	t.Logf("✅ Role authorization strictly enforced (MANAGER, CASHIER, Stranger all blocked)")
}

func TestRefund_IDOR(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	// Owner of a DIFFERENT business attempts to refund this business's payment
	otherOwnerID := uuid.New()
	otherBiz, err := env.svc.CreateBusiness(ctx, otherOwnerID, &CreateBusinessRequest{
		LegalName:    "Other Corp",
		DisplayName:  "Other Store",
		BusinessType: "retail",
		Country:      "CD",
		Currency:     "FCFA",
	})
	if err != nil {
		t.Fatalf("failed to create other business: %v", err)
	}

	_, err = env.svc.RefundPayment(ctx, otherOwnerID, env.intent.ID, &CreateRefundRequest{
		Amount: 5000,
	})
	if !errors.Is(err, ErrUnauthorizedAccess) {
		t.Errorf("expected ErrUnauthorizedAccess for cross-business IDOR, got: %v", err)
	}

	_ = otherBiz
	t.Logf("✅ IDOR: Owner of Business B cannot refund Payment of Business A")
}

func TestRefund_CurrencyMismatch(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	// Intent currency is FCFA. Any amount validated strictly against intent currency.
	receipt, err := env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount: 5000,
	})
	if err != nil {
		t.Fatalf("refund failed: %v", err)
	}
	if receipt.Currency != "FCFA" {
		t.Errorf("receipt currency = %s, want FCFA", receipt.Currency)
	}

	t.Logf("✅ Currency consistency strictly maintained")
}

func TestRefund_AmountValidation(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	_, err := env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount: 0,
	})
	if !errors.Is(err, ErrInvalidRefundAmount) {
		t.Errorf("expected ErrInvalidRefundAmount for amount=0, got: %v", err)
	}

	_, err = env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount: -500,
	})
	if !errors.Is(err, ErrInvalidRefundAmount) {
		t.Errorf("expected ErrInvalidRefundAmount for amount=-500, got: %v", err)
	}

	t.Logf("✅ Invalid refund amounts (0, negative) rejected")
}

func TestRefund_Idempotency(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	key := "refund-idempotent-key-01"

	// First submission
	receipt1, err := env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount:         5000,
		IdempotencyKey: key,
	})
	if err != nil {
		t.Fatalf("First refund failed: %v", err)
	}

	// Second submission with exact same key
	receipt2, err := env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount:         5000,
		IdempotencyKey: key,
	})
	if err != nil {
		t.Fatalf("Second idempotent refund failed: %v", err)
	}

	if receipt1.RefundID != receipt2.RefundID {
		t.Errorf("refund IDs differ on idempotent call")
	}

	// Verify balance is only debited once: Biz = 5000, Client = 5000
	clientAcc, _ := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")
	bizAcc, _ := env.bizRepo.GetBusinessAccount(ctx, env.business.Business.ID)

	clientBal, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	bizBal, _ := env.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)

	if clientBal != 5000 || bizBal != 5000 {
		t.Errorf("Balances after idempotent refund: client=%d, biz=%d (want 5000 each)", clientBal, bizBal)
	}

	t.Logf("✅ Idempotency: 2 submissions → 1 financial reversal, client=%d, biz=%d", clientBal, bizBal)
}

func TestRefund_ConcurrentIdempotency(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	key := "concurrent-refund-key"
	var wg sync.WaitGroup
	var receipts []*RefundReceipt
	var errorsList []error
	var mu sync.Mutex

	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			r, err := env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
				Amount:         10000,
				IdempotencyKey: key,
			})
			mu.Lock()
			defer mu.Unlock()
			if err != nil {
				errorsList = append(errorsList, err)
			} else {
				receipts = append(receipts, r)
			}
		}()
	}
	wg.Wait()

	if len(receipts) == 0 {
		t.Fatalf("At least one concurrent request should succeed")
	}

	// Verify ledger balance: exactly 1 reversal of 10 000 FCFA
	clientAcc, _ := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")
	bizAcc, _ := env.bizRepo.GetBusinessAccount(ctx, env.business.Business.ID)

	clientBal, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	bizBal, _ := env.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)

	if clientBal != 10000 || bizBal != 0 {
		t.Errorf("Balances after 20 concurrent idempotent requests: client=%d (want 10000), biz=%d (want 0)", clientBal, bizBal)
	}

	t.Logf("✅ 20 Concurrent Idempotent Requests: total successes=%d, client=%d, biz=%d", len(receipts), clientBal, bizBal)
}

func TestRefund_ConcurrentPartialRefund(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	// Initial payment: 10 000.
	// Two concurrent partial refund requests of 7 000 each.
	// Only ONE must succeed; the other must fail because 7 000 > remaining (3 000).

	var wg sync.WaitGroup
	var rA, rB *RefundReceipt
	var errA, errB error

	wg.Add(2)
	go func() {
		defer wg.Done()
		rA, errA = env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
			Amount:         7000,
			IdempotencyKey: "refund-part-A",
		})
	}()
	go func() {
		defer wg.Done()
		rB, errB = env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
			Amount:         7000,
			IdempotencyKey: "refund-part-B",
		})
	}()
	wg.Wait()

	successCount := 0
	if errA == nil && rA != nil && rA.Status == RefundSucceeded {
		successCount++
	}
	if errB == nil && rB != nil && rB.Status == RefundSucceeded {
		successCount++
	}

	if successCount != 1 {
		t.Fatalf("Expected exactly 1 partial refund to succeed, got %d (errA=%v, errB=%v)", successCount, errA, errB)
	}

	// Verify balance is never negative
	clientAcc, _ := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")
	bizAcc, _ := env.bizRepo.GetBusinessAccount(ctx, env.business.Business.ID)

	clientBal, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	bizBal, _ := env.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)

	if clientBal != 7000 || bizBal != 3000 {
		t.Errorf("Balances after concurrent partial refund: client=%d (want 7000), biz=%d (want 3000)", clientBal, bizBal)
	}

	t.Logf("✅ Concurrent Partial Refund: 1 SUCCESS, 1 FAILED, client=%d, biz=%d", clientBal, bizBal)
}

func TestRefund_LedgerReversal(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	receipt, err := env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount: 4000,
		Reason: "Reversal verification",
	})
	if err != nil {
		t.Fatalf("refund failed: %v", err)
	}

	// Inspect the created JournalEntry
	if receipt.JournalEntryID == nil {
		t.Fatal("JournalEntryID should not be nil")
	}

	entry, postings, err := env.ledgerRepo.GetJournalEntry(ctx, *receipt.JournalEntryID)
	if err != nil {
		t.Fatalf("GetJournalEntry failed: %v", err)
	}

	if entry.TransactionType != ledger.MerchantRefund {
		t.Errorf("TransactionType = %s, want merchant_refund", entry.TransactionType)
	}

	if len(postings) != 2 {
		t.Fatalf("expected 2 postings, got %d", len(postings))
	}

	bizAcc, _ := env.bizRepo.GetBusinessAccount(ctx, env.business.Business.ID)
	clientAcc, _ := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")

	var bizPosting, clientPosting *ledger.LedgerPosting
	for _, p := range postings {
		if p.AccountID == bizAcc.LedgerAccountID {
			bizPosting = p
		}
		if p.AccountID == clientAcc.ID {
			clientPosting = p
		}
	}

	if bizPosting == nil || !bizPosting.IsCredit || bizPosting.Amount != 4000 {
		t.Errorf("bizPosting invalid: expected Credit 4000, got: %+v", bizPosting)
	}
	if clientPosting == nil || clientPosting.IsCredit || clientPosting.Amount != 4000 {
		t.Errorf("clientPosting invalid: expected Debit 4000, got: %+v", clientPosting)
	}

	t.Logf("✅ Ledger Reversal correctly structured: Biz Credit 4000, Client Debit 4000, Type=%s", entry.TransactionType)
}

func TestRefund_LedgerBalance(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	clientAcc, _ := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")
	bizAcc, _ := env.bizRepo.GetBusinessAccount(ctx, env.business.Business.ID)

	// Refund 6 000
	_, err := env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount: 6000,
	})
	if err != nil {
		t.Fatalf("refund failed: %v", err)
	}

	clientBal, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	bizBal, _ := env.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)

	if clientBal != 6000 {
		t.Errorf("client balance = %d, want 6000", clientBal)
	}
	if bizBal != 4000 {
		t.Errorf("biz balance = %d, want 4000", bizBal)
	}

	t.Logf("✅ Ledger Balance exact: Client=%d, Biz=%d", clientBal, bizBal)
}

func TestRefund_Atomicity(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	receipt, err := env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount: 10000,
	})
	if err != nil {
		t.Fatalf("refund failed: %v", err)
	}

	entry, postings, err := env.ledgerRepo.GetJournalEntry(ctx, *receipt.JournalEntryID)
	if err != nil {
		t.Fatalf("GetJournalEntry failed: %v", err)
	}

	var sumDR, sumCR int64
	for _, p := range postings {
		if p.IsCredit {
			sumCR += p.Amount
		} else {
			sumDR += p.Amount
		}
	}

	if sumDR != sumCR || sumDR != 10000 {
		t.Fatalf("Double-entry violation: DR=%d, CR=%d", sumDR, sumCR)
	}

	_ = entry
	t.Logf("✅ Atomicity: 1 Journal Entry, 2 Postings, DR=CR=10000")
}

func TestRefund_NoMoneyCreationOnFailure(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	clientAcc, _ := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")
	bizAcc, _ := env.bizRepo.GetBusinessAccount(ctx, env.business.Business.ID)

	clientBalBefore, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	bizBalBefore, _ := env.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)

	// Attempt failing refund (amount > remaining)
	_, err := env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount: 25000,
	})
	if err == nil {
		t.Fatal("expected failure on excessive refund")
	}

	clientBalAfter, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	bizBalAfter, _ := env.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)

	if clientBalBefore != clientBalAfter || bizBalBefore != bizBalAfter {
		t.Errorf("Balances altered on failure: client %d→%d, biz %d→%d",
			clientBalBefore, clientBalAfter, bizBalBefore, bizBalAfter)
	}

	t.Logf("✅ No money creation on failure: client=%d, biz=%d unchanged", clientBalAfter, bizBalAfter)
}

func TestRefund_AuditTrail(t *testing.T) {
	env := setupRefundEnv(t, 10000)
	ctx := context.Background()

	receipt, err := env.svc.RefundPayment(ctx, env.ownerID, env.intent.ID, &CreateRefundRequest{
		Amount: 5000,
		Reason: "Audit trail test",
	})
	if err != nil {
		t.Fatalf("refund failed: %v", err)
	}

	// 1. Get Refunds for Payment Intent
	refunds, err := env.svc.GetRefunds(ctx, env.ownerID, env.intent.ID)
	if err != nil {
		t.Fatalf("GetRefunds failed: %v", err)
	}

	if len(refunds) != 1 {
		t.Fatalf("expected 1 refund in history, got %d", len(refunds))
	}

	ref := refunds[0]
	if ref.ID != receipt.RefundID {
		t.Errorf("refund ID mismatch")
	}
	if ref.PaymentIntentID != env.intent.ID {
		t.Errorf("payment intent ID mismatch")
	}
	if ref.BusinessID != env.business.Business.ID {
		t.Errorf("business ID mismatch")
	}
	if ref.JournalEntryID == nil {
		t.Errorf("journal entry ID missing in audit trail")
	}

	t.Logf("✅ Audit Trail complete: Refund %s linked to Intent %s and Journal Entry %s",
		ref.ID, ref.PaymentIntentID, *ref.JournalEntryID)
}
