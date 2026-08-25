package business

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/ledger"
)

// ════════════════════════════════════════════════════════════
// HELPERS — Sets up a complete sandbox environment for merchant payment tests
// ════════════════════════════════════════════════════════════

type merchantTestEnv struct {
	ledgerRepo *ledger.MemoryRepository
	bizRepo    *MemoryBusinessRepository
	svc        *Service
	ownerID    uuid.UUID
	clientID   uuid.UUID
	business   *BusinessDetail
	qr         *MerchantQR
}

// setupMerchantEnv creates: ledger repo + business repo + service + owner + business + merchant QR
func setupMerchantEnv(t *testing.T) *merchantTestEnv {
	t.Helper()

	ledgerRepo := ledger.NewMemoryRepository()
	bizRepo := NewMemoryBusinessRepository(ledgerRepo)
	svc := NewService(bizRepo, ledgerRepo)

	ownerID := uuid.New()
	clientID := uuid.New()

	ctx := context.Background()

	// Create business
	biz, err := svc.CreateBusiness(ctx, ownerID, &CreateBusinessRequest{
		LegalName:    "Sahel Agro SARL",
		DisplayName:  "Sahel Agro",
		BusinessType: "retail",
		Phone:        "+243810000001",
		Country:      "CD",
		Currency:     "FCFA",
	})
	if err != nil {
		t.Fatalf("setup: failed to create business: %v", err)
	}

	// Create Merchant QR
	qr, err := svc.CreateMerchantQR(ctx, biz.Business.ID, ownerID, nil)
	if err != nil {
		t.Fatalf("setup: failed to create merchant QR: %v", err)
	}

	return &merchantTestEnv{
		ledgerRepo: ledgerRepo,
		bizRepo:    bizRepo,
		svc:        svc,
		ownerID:    ownerID,
		clientID:   clientID,
		business:   biz,
		qr:         qr,
	}
}

// fundClient creates a wallet for clientID and gives it the specified balance via a sandbox cash-in.
func (env *merchantTestEnv) fundClient(t *testing.T, amount int64) uuid.UUID {
	t.Helper()

	ctx := context.Background()

	acc := &ledger.LedgerAccount{
		ID:          uuid.New(),
		UserID:      &env.clientID,
		Currency:    "FCFA",
		AccountType: ledger.Asset,
		Name:        "Portefeuille Client",
		CreatedAt:   time.Now().UTC(),
	}
	if err := env.ledgerRepo.CreateAccount(ctx, acc); err != nil {
		// Account might already exist, fetch it
		existing, fetchErr := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")
		if fetchErr != nil {
			t.Fatalf("setup: failed to create client account: %v", err)
		}
		acc = existing
	}

	if amount > 0 {
		// Fund via a system credit (sandbox cash-in)
		sysAcc, err := env.ledgerRepo.GetSystemAccount(ctx, "settlement_fcfa", "FCFA", ledger.Liability)
		if err != nil {
			sysAcc = &ledger.LedgerAccount{
				ID:          uuid.New(),
				Currency:    "FCFA",
				AccountType: ledger.Liability,
				Name:        "settlement_fcfa",
				CreatedAt:   time.Now().UTC(),
			}
			if err := env.ledgerRepo.CreateAccount(ctx, sysAcc); err != nil {
				t.Fatalf("setup: failed to create settlement account: %v", err)
			}
		}

		entryID := uuid.New()
		entry := &ledger.JournalEntry{
			ID:              entryID,
			TransactionType: ledger.MoMoCashIn,
			ReferenceID:     fmt.Sprintf("SANDBOX-FUND-%s", uuid.New().String()[:6]),
			Description:     "Test funding",
			CreatedAt:       time.Now().UTC(),
		}
		postings := []*ledger.LedgerPosting{
			{ID: uuid.New(), JournalEntryID: entryID, AccountID: acc.ID, Amount: amount, IsCredit: false, CreatedAt: time.Now().UTC()},
			{ID: uuid.New(), JournalEntryID: entryID, AccountID: sysAcc.ID, Amount: amount, IsCredit: true, CreatedAt: time.Now().UTC()},
		}
		if err := env.ledgerRepo.PostJournalEntry(ctx, entry, postings, fmt.Sprintf("FUND-%s", uuid.New().String()[:8])); err != nil {
			t.Fatalf("setup: failed to fund client: %v", err)
		}
	}

	return acc.ID
}

// ════════════════════════════════════════════════════════════
// MERCHANT QR TESTS
// ════════════════════════════════════════════════════════════

func TestMerchantQR_Create(t *testing.T) {
	env := setupMerchantEnv(t)

	if env.qr == nil {
		t.Fatal("QR should have been created during setup")
	}
	if env.qr.Status != MerchantQRActive {
		t.Errorf("QR status = %s, want ACTIVE", env.qr.Status)
	}
	if env.qr.Code == "" {
		t.Error("QR code should not be empty")
	}
	if env.qr.BusinessID != env.business.Business.ID {
		t.Errorf("QR businessID = %s, want %s", env.qr.BusinessID, env.business.Business.ID)
	}
	t.Logf("✅ QR created: code=%s, status=%s", env.qr.Code, env.qr.Status)
}

func TestMerchantQR_Resolve(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	info, err := env.svc.ResolveMerchantQR(ctx, env.qr.Code)
	if err != nil {
		t.Fatalf("ResolveMerchantQR failed: %v", err)
	}

	if info.BusinessID != env.business.Business.ID {
		t.Errorf("BusinessID = %s, want %s", info.BusinessID, env.business.Business.ID)
	}
	if info.DisplayName != "Sahel Agro" {
		t.Errorf("DisplayName = %s, want 'Sahel Agro'", info.DisplayName)
	}
	if info.Currency != "FCFA" {
		t.Errorf("Currency = %s, want FCFA", info.Currency)
	}
	t.Logf("✅ QR resolved: business=%s, currency=%s", info.DisplayName, info.Currency)
}

func TestMerchantQR_Revoke(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	err := env.svc.RevokeMerchantQR(ctx, env.business.Business.ID, env.ownerID, env.qr.ID)
	if err != nil {
		t.Fatalf("RevokeMerchantQR failed: %v", err)
	}

	// Resolving revoked QR should fail
	_, err = env.svc.ResolveMerchantQR(ctx, env.qr.Code)
	if !errors.Is(err, ErrMerchantQRRevoked) {
		t.Errorf("expected ErrMerchantQRRevoked, got: %v", err)
	}
	t.Logf("✅ QR revoked and cannot be resolved")
}

func TestMerchantQR_Invalid(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	_, err := env.svc.ResolveMerchantQR(ctx, "non-existent-qr-code")
	if !errors.Is(err, ErrMerchantQRNotFound) {
		t.Errorf("expected ErrMerchantQRNotFound, got: %v", err)
	}
	t.Logf("✅ Invalid QR correctly rejected")
}

func TestMerchantQR_BusinessSuspended(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	// Suspend the business
	env.business.Business.Status = StatusSuspended
	if err := env.bizRepo.UpdateBusiness(ctx, env.business.Business); err != nil {
		t.Fatalf("failed to suspend business: %v", err)
	}

	_, err := env.svc.ResolveMerchantQR(ctx, env.qr.Code)
	if !errors.Is(err, ErrBusinessSuspended) {
		t.Errorf("expected ErrBusinessSuspended, got: %v", err)
	}
	t.Logf("✅ QR resolution blocked for suspended business")
}

func TestMerchantQR_BusinessClosed(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	// Close the business
	env.business.Business.Status = StatusClosed
	if err := env.bizRepo.UpdateBusiness(ctx, env.business.Business); err != nil {
		t.Fatalf("failed to close business: %v", err)
	}

	_, err := env.svc.ResolveMerchantQR(ctx, env.qr.Code)
	if !errors.Is(err, ErrBusinessClosed) {
		t.Errorf("expected ErrBusinessClosed, got: %v", err)
	}
	t.Logf("✅ QR resolution blocked for closed business")
}

// ════════════════════════════════════════════════════════════
// PAYMENT INTENT TESTS
// ════════════════════════════════════════════════════════════

func TestPaymentIntent_Create(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	intent, err := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   10000,
		Currency: "FCFA",
	})
	if err != nil {
		t.Fatalf("CreatePaymentIntent failed: %v", err)
	}

	if intent.Status != IntentCreated {
		t.Errorf("status = %s, want CREATED", intent.Status)
	}
	if intent.Amount != 10000 {
		t.Errorf("amount = %d, want 10000", intent.Amount)
	}
	if intent.BusinessID != env.business.Business.ID {
		t.Errorf("businessID mismatch")
	}
	if intent.PayerUserID != env.clientID {
		t.Errorf("payerUserID = %s, want %s", intent.PayerUserID, env.clientID)
	}
	t.Logf("✅ Payment Intent created: id=%s, amount=%d, status=%s", intent.ID, intent.Amount, intent.Status)
}

func TestPaymentIntent_AmountValidation(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	_, err := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   0,
		Currency: "FCFA",
	})
	if !errors.Is(err, ledger.ErrInvalidAmount) {
		t.Errorf("expected ErrInvalidAmount for amount=0, got: %v", err)
	}

	_, err = env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   -500,
		Currency: "FCFA",
	})
	if !errors.Is(err, ledger.ErrInvalidAmount) {
		t.Errorf("expected ErrInvalidAmount for amount=-500, got: %v", err)
	}
	t.Logf("✅ Invalid amounts correctly rejected (0 and negative)")
}

func TestPaymentIntent_CurrencyValidation(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	_, err := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   5000,
		Currency: "USD",
	})
	if !errors.Is(err, ErrCurrencyMismatch) {
		t.Errorf("expected ErrCurrencyMismatch for USD→FCFA, got: %v", err)
	}
	t.Logf("✅ Currency mismatch correctly rejected (USD vs FCFA)")
}

func TestPaymentIntent_InsufficientFunds(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	// Fund client with 5000
	env.fundClient(t, 5000)

	// Create intent for 10000
	intent, err := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   10000,
		Currency: "FCFA",
	})
	if err != nil {
		t.Fatalf("CreatePaymentIntent failed: %v", err)
	}

	// Confirm should fail with insufficient funds
	_, err = env.svc.ConfirmPaymentIntent(ctx, env.clientID, intent.ID, &ConfirmPaymentIntentRequest{})
	if !errors.Is(err, ErrPaymentFailed) {
		t.Errorf("expected ErrPaymentFailed, got: %v", err)
	}

	// Verify no ledger impact
	clientBalance, _ := env.ledgerRepo.GetBalance(ctx, func() uuid.UUID {
		acc, _ := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")
		return acc.ID
	}())
	if clientBalance != 5000 {
		t.Errorf("client balance = %d, want 5000 (unchanged)", clientBalance)
	}

	bizAcc, _ := env.bizRepo.GetBusinessAccount(ctx, env.business.Business.ID)
	bizBalance, _ := env.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)
	if bizBalance != 0 {
		t.Errorf("business balance = %d, want 0 (unchanged)", bizBalance)
	}

	t.Logf("✅ Insufficient funds: payment FAILED, no ledger writes, client=%d, biz=%d", clientBalance, bizBalance)
}

// ════════════════════════════════════════════════════════════
// MERCHANT PAYMENT TESTS (Full E2E Flow)
// ════════════════════════════════════════════════════════════

func TestMerchantPayment(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	env.fundClient(t, 10000)

	intent, err := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   10000,
		Currency: "FCFA",
	})
	if err != nil {
		t.Fatalf("CreatePaymentIntent failed: %v", err)
	}

	receipt, err := env.svc.ConfirmPaymentIntent(ctx, env.clientID, intent.ID, &ConfirmPaymentIntentRequest{})
	if err != nil {
		t.Fatalf("ConfirmPaymentIntent failed: %v", err)
	}

	if receipt.Status != IntentSucceeded {
		t.Errorf("receipt status = %s, want SUCCEEDED", receipt.Status)
	}
	if receipt.Amount != 10000 {
		t.Errorf("receipt amount = %d, want 10000", receipt.Amount)
	}
	if receipt.IsSandbox != true {
		t.Error("IsSandbox should be true")
	}
	t.Logf("✅ Merchant Payment SUCCEEDED: receipt=%+v", receipt.PaymentIntentID)
}

func TestMerchantPayment_LedgerBalance(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	env.fundClient(t, 10000)

	intent, err := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   10000,
		Currency: "FCFA",
	})
	if err != nil {
		t.Fatalf("CreatePaymentIntent failed: %v", err)
	}

	_, err = env.svc.ConfirmPaymentIntent(ctx, env.clientID, intent.ID, &ConfirmPaymentIntentRequest{})
	if err != nil {
		t.Fatalf("ConfirmPaymentIntent failed: %v", err)
	}

	// Verify Ledger Balances
	clientAcc, _ := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")
	clientBalance, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	if clientBalance != 0 {
		t.Errorf("client balance = %d, want 0", clientBalance)
	}

	bizAcc, _ := env.bizRepo.GetBusinessAccount(ctx, env.business.Business.ID)
	bizBalance, _ := env.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)
	if bizBalance != 10000 {
		t.Errorf("business balance = %d, want 10000", bizBalance)
	}

	t.Logf("✅ Ledger Balance: Client=%d, Business=%d", clientBalance, bizBalance)
}

func TestMerchantPayment_Idempotency(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	env.fundClient(t, 10000)

	intent, err := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   10000,
		Currency: "FCFA",
	})
	if err != nil {
		t.Fatalf("CreatePaymentIntent failed: %v", err)
	}

	// First confirmation
	receipt1, err := env.svc.ConfirmPaymentIntent(ctx, env.clientID, intent.ID, &ConfirmPaymentIntentRequest{})
	if err != nil {
		t.Fatalf("First ConfirmPaymentIntent failed: %v", err)
	}

	// Second confirmation (idempotent)
	receipt2, err := env.svc.ConfirmPaymentIntent(ctx, env.clientID, intent.ID, &ConfirmPaymentIntentRequest{})
	if err != nil {
		t.Fatalf("Second ConfirmPaymentIntent failed: %v", err)
	}

	if receipt1.PaymentIntentID != receipt2.PaymentIntentID {
		t.Errorf("idempotent receipts differ")
	}

	// Verify exactly 1 journal entry was created for this payment
	clientAcc, _ := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")
	clientBalance, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	if clientBalance != 0 {
		t.Errorf("client balance after idempotent confirm = %d, want 0", clientBalance)
	}

	bizAcc, _ := env.bizRepo.GetBusinessAccount(ctx, env.business.Business.ID)
	bizBalance, _ := env.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)
	if bizBalance != 10000 {
		t.Errorf("business balance after idempotent confirm = %d, want 10000", bizBalance)
	}

	t.Logf("✅ Idempotency: 2 confirms → 1 transaction, client=%d, biz=%d", clientBalance, bizBalance)
}

func TestMerchantPayment_ConcurrentConfirmation(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	env.fundClient(t, 20000)

	// Create TWO separate payment intents
	intentA, err := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:         env.qr.Code,
		Amount:         15000,
		Currency:       "FCFA",
		IdempotencyKey: "payment-a",
	})
	if err != nil {
		t.Fatalf("CreatePaymentIntent A failed: %v", err)
	}

	intentB, err := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:         env.qr.Code,
		Amount:         15000,
		Currency:       "FCFA",
		IdempotencyKey: "payment-b",
	})
	if err != nil {
		t.Fatalf("CreatePaymentIntent B failed: %v", err)
	}

	var wg sync.WaitGroup
	var errA, errB error
	var receiptA, receiptB *MerchantPaymentReceipt

	wg.Add(2)
	go func() {
		defer wg.Done()
		receiptA, errA = env.svc.ConfirmPaymentIntent(ctx, env.clientID, intentA.ID, &ConfirmPaymentIntentRequest{})
	}()
	go func() {
		defer wg.Done()
		receiptB, errB = env.svc.ConfirmPaymentIntent(ctx, env.clientID, intentB.ID, &ConfirmPaymentIntentRequest{})
	}()
	wg.Wait()

	// Exactly one should succeed
	successCount := 0
	if errA == nil && receiptA != nil && receiptA.Status == IntentSucceeded {
		successCount++
	}
	if errB == nil && receiptB != nil && receiptB.Status == IntentSucceeded {
		successCount++
	}

	if successCount == 0 {
		t.Fatal("At least one payment should have succeeded")
	}
	if successCount == 2 {
		// Both succeeded means balance went negative — check
		clientAcc, _ := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")
		clientBalance, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
		if clientBalance < 0 {
			t.Fatalf("CRITICAL: Balance went negative (%d) — double spend detected!", clientBalance)
		}
		// If balance is still >= 0, it's acceptable (20000 - 15000 - 15000 = -10000 NOT OK)
		// Actually 20000 - 15000 = 5000, and 5000 < 15000, so second should fail
		t.Errorf("Both payments succeeded, possible race condition")
	}

	// Verify client balance is not negative
	clientAcc, _ := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")
	clientBalance, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	if clientBalance < 0 {
		t.Fatalf("CRITICAL: Client balance is negative (%d) — financial invariant violated!", clientBalance)
	}

	t.Logf("✅ Concurrent Confirmation: successCount=%d, clientBalance=%d, errA=%v, errB=%v", successCount, clientBalance, errA, errB)
}

func TestMerchantPayment_AlreadySucceeded(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	env.fundClient(t, 10000)

	intent, _ := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   10000,
		Currency: "FCFA",
	})

	// First confirm
	_, err := env.svc.ConfirmPaymentIntent(ctx, env.clientID, intent.ID, &ConfirmPaymentIntentRequest{})
	if err != nil {
		t.Fatalf("ConfirmPaymentIntent failed: %v", err)
	}

	// Second confirm (already succeeded) should return idempotent result, not create new entries
	receipt2, err := env.svc.ConfirmPaymentIntent(ctx, env.clientID, intent.ID, &ConfirmPaymentIntentRequest{})
	if err != nil {
		t.Fatalf("Second confirm failed unexpectedly: %v", err)
	}
	if receipt2.Status != IntentSucceeded {
		t.Errorf("status = %s, want SUCCEEDED", receipt2.Status)
	}

	// Verify no duplicate ledger entries
	clientAcc, _ := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")
	balance, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	if balance != 0 {
		t.Errorf("client balance = %d, want 0 (single debit)", balance)
	}

	t.Logf("✅ Already Succeeded: idempotent response, no duplicate ledger write, balance=%d", balance)
}

func TestMerchantPayment_Expired(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	env.fundClient(t, 10000)

	intent, _ := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   10000,
		Currency: "FCFA",
	})

	// Force expiration by backdating ExpiresAt
	intent.ExpiresAt = time.Now().UTC().Add(-1 * time.Minute)
	_ = env.bizRepo.UpdatePaymentIntentStatus(ctx, intent.ID, IntentCreated, nil, nil)
	// Directly manipulate for test
	env.bizRepo.mu.Lock()
	env.bizRepo.paymentIntents[intent.ID].ExpiresAt = time.Now().UTC().Add(-1 * time.Minute)
	env.bizRepo.mu.Unlock()

	_, err := env.svc.ConfirmPaymentIntent(ctx, env.clientID, intent.ID, &ConfirmPaymentIntentRequest{})
	if !errors.Is(err, ErrPaymentIntentExpired) {
		t.Errorf("expected ErrPaymentIntentExpired, got: %v", err)
	}

	// No ledger impact
	clientAcc, _ := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")
	balance, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	if balance != 10000 {
		t.Errorf("client balance = %d, want 10000 (unchanged)", balance)
	}

	t.Logf("✅ Expired: payment rejected, client balance unchanged=%d", balance)
}

func TestMerchantPayment_Unauthorized(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	env.fundClient(t, 10000)

	intent, _ := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   5000,
		Currency: "FCFA",
	})

	// Another user tries to view
	otherUser := uuid.New()
	_, err := env.svc.GetPaymentIntent(ctx, otherUser, intent.ID)
	if !errors.Is(err, ErrUnauthorizedAccess) {
		t.Errorf("expected ErrUnauthorizedAccess for GET, got: %v", err)
	}

	t.Logf("✅ Unauthorized GET correctly blocked")
}

func TestMerchantPayment_IDOR(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	env.fundClient(t, 10000)

	intent, _ := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   5000,
		Currency: "FCFA",
	})

	// Attacker (a different user) tries to confirm the client's payment
	attacker := uuid.New()
	_, err := env.svc.ConfirmPaymentIntent(ctx, attacker, intent.ID, &ConfirmPaymentIntentRequest{})
	if !errors.Is(err, ErrUnauthorizedAccess) {
		t.Errorf("expected ErrUnauthorizedAccess for IDOR confirm, got: %v", err)
	}

	t.Logf("✅ IDOR: attacker cannot confirm another user's payment intent")
}

func TestMerchantPayment_SelfPayment(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	// Owner tries to pay their own business
	_, err := env.svc.CreatePaymentIntent(ctx, env.ownerID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   5000,
		Currency: "FCFA",
	})
	if !errors.Is(err, ErrSelfPaymentNotAllowed) {
		t.Errorf("expected ErrSelfPaymentNotAllowed, got: %v", err)
	}

	t.Logf("✅ Self-payment correctly blocked")
}

func TestMerchantPayment_NoMoneyCreationOnFailure(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	// Client funded with 5000, attempts 10000
	env.fundClient(t, 5000)

	clientAcc, _ := env.ledgerRepo.GetAccountByUserID(ctx, env.clientID, "FCFA")
	bizAcc, _ := env.bizRepo.GetBusinessAccount(ctx, env.business.Business.ID)

	balanceBefore, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	bizBalanceBefore, _ := env.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)

	intent, _ := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   10000,
		Currency: "FCFA",
	})

	_, err := env.svc.ConfirmPaymentIntent(ctx, env.clientID, intent.ID, &ConfirmPaymentIntentRequest{})
	if err == nil {
		t.Fatal("expected failure for insufficient funds")
	}

	balanceAfter, _ := env.ledgerRepo.GetBalance(ctx, clientAcc.ID)
	bizBalanceAfter, _ := env.ledgerRepo.GetBalance(ctx, bizAcc.LedgerAccountID)

	if balanceBefore != balanceAfter {
		t.Errorf("client balance changed: before=%d, after=%d", balanceBefore, balanceAfter)
	}
	if bizBalanceBefore != bizBalanceAfter {
		t.Errorf("business balance changed: before=%d, after=%d", bizBalanceBefore, bizBalanceAfter)
	}

	t.Logf("✅ No money creation on failure: client=%d→%d, biz=%d→%d", balanceBefore, balanceAfter, bizBalanceBefore, bizBalanceAfter)
}

func TestMerchantPayment_Atomicity(t *testing.T) {
	env := setupMerchantEnv(t)
	ctx := context.Background()

	// Fund client with exactly 10000
	env.fundClient(t, 10000)

	intent, _ := env.svc.CreatePaymentIntent(ctx, env.clientID, &CreatePaymentIntentRequest{
		QRCode:   env.qr.Code,
		Amount:   10000,
		Currency: "FCFA",
	})

	receipt, err := env.svc.ConfirmPaymentIntent(ctx, env.clientID, intent.ID, &ConfirmPaymentIntentRequest{})
	if err != nil {
		t.Fatalf("ConfirmPaymentIntent failed: %v", err)
	}

	// Verify the journal entry exists and is balanced
	if receipt.JournalEntryID == nil {
		t.Fatal("JournalEntryID should not be nil after successful payment")
	}

	entry, postings, err := env.ledgerRepo.GetJournalEntry(ctx, *receipt.JournalEntryID)
	if err != nil {
		t.Fatalf("GetJournalEntry failed: %v", err)
	}

	if entry.TransactionType != ledger.MerchantPayment {
		t.Errorf("TransactionType = %s, want merchant_payment", entry.TransactionType)
	}

	if len(postings) != 2 {
		t.Fatalf("expected 2 postings, got %d", len(postings))
	}

	var totalDR, totalCR int64
	for _, p := range postings {
		if p.IsCredit {
			totalCR += p.Amount
		} else {
			totalDR += p.Amount
		}
	}

	if totalDR != totalCR {
		t.Fatalf("CRITICAL: DR=%d != CR=%d — double-entry violation!", totalDR, totalCR)
	}

	if totalDR != 10000 {
		t.Errorf("totalDR = %d, want 10000", totalDR)
	}

	t.Logf("✅ Atomicity: 1 JournalEntry, 2 Postings, DR=%d, CR=%d, balanced=%v", totalDR, totalCR, totalDR == totalCR)
}
