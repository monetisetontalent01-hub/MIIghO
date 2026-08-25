package ledger

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func setupTestService(t *testing.T) (*Service, *MemoryRepository) {
	repo := NewMemoryRepository()
	svc := NewService(repo)
	return svc, repo
}

// Test 1: Invariant Debit == Credit
func TestLedger_Invariant_DebitEqualsCredit(t *testing.T) {
	svc, repo := setupTestService(t)
	ctx := context.Background()

	user1 := uuid.New()
	user2 := uuid.New()

	acc1, err := svc.GetOrCreateUserAccount(ctx, user1, "FCFA")
	require.NoError(t, err)
	acc2, err := svc.GetOrCreateUserAccount(ctx, user2, "FCFA")
	require.NoError(t, err)

	// Attempt imbalanced entry (Debit 10000 != Credit 5000)
	imbalancedEntry := &JournalEntry{
		ID:              uuid.New(),
		TransactionType: P2PTransfer,
		ReferenceID:     "IMBALANCED-01",
		Description:     "Imbalanced transfer attempt",
		CreatedAt:       time.Now().UTC(),
	}
	imbalancedPostings := []*LedgerPosting{
		{ID: uuid.New(), JournalEntryID: imbalancedEntry.ID, AccountID: acc1.ID, Amount: 10000, IsCredit: false}, // Debit 10000
		{ID: uuid.New(), JournalEntryID: imbalancedEntry.ID, AccountID: acc2.ID, Amount: 5000, IsCredit: true},   // Credit 5000
	}

	err = repo.PostJournalEntry(ctx, imbalancedEntry, imbalancedPostings, "imbalanced-key-1")
	assert.Error(t, err)
	assert.True(t, errors.Is(err, ErrImbalancedEntry))

	// Balanced entry (Debit 10000 == Credit 10000)
	balancedEntry := &JournalEntry{
		ID:              uuid.New(),
		TransactionType: P2PTransfer,
		ReferenceID:     "BALANCED-01",
		Description:     "Balanced transfer",
		CreatedAt:       time.Now().UTC(),
	}
	balancedPostings := []*LedgerPosting{
		{ID: uuid.New(), JournalEntryID: balancedEntry.ID, AccountID: acc1.ID, Amount: 10000, IsCredit: false},
		{ID: uuid.New(), JournalEntryID: balancedEntry.ID, AccountID: acc2.ID, Amount: 10000, IsCredit: true},
	}

	err = repo.PostJournalEntry(ctx, balancedEntry, balancedPostings, "balanced-key-1")
	assert.NoError(t, err)
}

// Test 2: Account Creation & Types
func TestLedger_AccountCreation(t *testing.T) {
	svc, _ := setupTestService(t)
	ctx := context.Background()

	uID := uuid.New()
	acc, err := svc.CreateAccount(ctx, &uID, "EUR", Asset)
	require.NoError(t, err)
	assert.Equal(t, "EUR", acc.Currency)
	assert.Equal(t, Asset, acc.AccountType)
	assert.Equal(t, &uID, acc.UserID)

	// System account
	sysAcc, err := svc.CreateAccount(ctx, nil, "USD", Liability)
	require.NoError(t, err)
	assert.Nil(t, sysAcc.UserID)
	assert.Equal(t, Liability, sysAcc.AccountType)
}

// Test 3: Derived Balance Calculation
func TestLedger_DerivedBalance(t *testing.T) {
	svc, repo := setupTestService(t)
	ctx := context.Background()

	userID := uuid.New()
	userAcc, err := svc.GetOrCreateUserAccount(ctx, userID, "FCFA")
	require.NoError(t, err)

	momoPool, err := repo.GetSystemAccount(ctx, "MoMo Settlement Pool", "FCFA", Liability)
	require.NoError(t, err)

	// Initial balance should be 0
	bal, err := repo.GetBalance(ctx, userAcc.ID)
	require.NoError(t, err)
	assert.Equal(t, int64(0), bal)

	// Cash in 50,000 FCFA
	_, err = svc.CashIn(ctx, userID, &CashInRequest{
		Provider:       "wave",
		PhoneNumber:    "+22507000000",
		Amount:         50000,
		Currency:       "FCFA",
		IdempotencyKey: "cashin-derived-test-1",
	})
	require.NoError(t, err)

	// Derived balance must be strictly 50,000
	bal, err = repo.GetBalance(ctx, userAcc.ID)
	require.NoError(t, err)
	assert.Equal(t, int64(50000), bal)

	// Cash out 20,000 FCFA
	_, err = svc.CashOut(ctx, userID, &CashOutRequest{
		Provider:       "orange_money",
		PhoneNumber:    "+22507000000",
		Amount:         20000,
		Currency:       "FCFA",
		IdempotencyKey: "cashout-derived-test-1",
	})
	require.NoError(t, err)

	// Derived balance must be strictly 30,000
	bal, err = repo.GetBalance(ctx, userAcc.ID)
	require.NoError(t, err)
	assert.Equal(t, int64(30000), bal)

	// MoMo pool liability must reflect seeded transactions (55,000) + test transactions (50,000 - 20,000 = 30,000) = 85,000 FCFA
	momoBal, err := repo.GetBalance(ctx, momoPool.ID)
	require.NoError(t, err)
	assert.Equal(t, int64(85000), momoBal)
}

// Test 4: Transfer P2P Flow & Insufficient Funds
func TestLedger_TransferP2P(t *testing.T) {
	svc, repo := setupTestService(t)
	ctx := context.Background()

	aliceID := uuid.New()
	bobID := uuid.New()

	// Give Alice 10,000 FCFA via CashIn
	_, err := svc.CashIn(ctx, aliceID, &CashInRequest{
		Provider:       "wave",
		Amount:         10000,
		Currency:       "FCFA",
		IdempotencyKey: "alice-fund-01",
	})
	require.NoError(t, err)

	// Alice transfers 4,000 FCFA to Bob
	detail, err := svc.TransferP2P(ctx, aliceID, &TransferRequest{
		ToUserID:       &bobID,
		Amount:         4000,
		Currency:       "FCFA",
		Description:    "Cadeau anniversaire",
		IdempotencyKey: "alice-to-bob-01",
	})
	require.NoError(t, err)
	assert.True(t, detail.IsBalanced)
	assert.Equal(t, int64(4000), detail.TotalDebit)
	assert.Equal(t, int64(4000), detail.TotalCredit)

	// Check Alice balance (10000 - 4000 = 6000)
	aliceSummary, err := svc.GetWalletSummary(ctx, aliceID, "FCFA")
	require.NoError(t, err)
	assert.Equal(t, int64(6000), aliceSummary.AvailableBalance)

	// Check Bob balance (4000)
	bobSummary, err := svc.GetWalletSummary(ctx, bobID, "FCFA")
	require.NoError(t, err)
	assert.Equal(t, int64(4000), bobSummary.AvailableBalance)

	// Attempt transfer exceeding balance (Alice sends 7,000 when she has 6,000)
	_, err = svc.TransferP2P(ctx, aliceID, &TransferRequest{
		ToUserID:       &bobID,
		Amount:         7000,
		Currency:       "FCFA",
		Description:    "Exceeding amount",
		IdempotencyKey: "alice-fail-tx",
	})
	assert.Error(t, err)
	assert.True(t, errors.Is(err, ErrInsufficientFunds))

	// Ensure Alice balance did not change
	aliceAcc, _ := svc.GetOrCreateUserAccount(ctx, aliceID, "FCFA")
	bal, _ := repo.GetBalance(ctx, aliceAcc.ID)
	assert.Equal(t, int64(6000), bal)
}

// Test 5: QR Pay Flow
func TestLedger_QRPay(t *testing.T) {
	svc, _ := setupTestService(t)
	ctx := context.Background()

	customerID := uuid.New()

	// Fund customer
	_, err := svc.CashIn(ctx, customerID, &CashInRequest{
		Provider:       "mtn_momo",
		Amount:         15000,
		Currency:       "FCFA",
		IdempotencyKey: "customer-seed-01",
	})
	require.NoError(t, err)

	// Pay merchant via QR
	qrPayload := "miigho://pay?to=MG-PHARMACIE-01&amount=5000"
	detail, err := svc.QRPay(ctx, customerID, &QRPayRequest{
		QRData:         qrPayload,
		Amount:         5000,
		Currency:       "FCFA",
		Description:    "Achat Médicaments",
		IdempotencyKey: "qr-payment-01",
	})
	require.NoError(t, err)
	assert.True(t, detail.IsBalanced)
	assert.Equal(t, int64(5000), detail.TotalDebit)
	assert.Equal(t, int64(5000), detail.TotalCredit)

	// Verify customer balance
	summary, err := svc.GetWalletSummary(ctx, customerID, "FCFA")
	require.NoError(t, err)
	assert.Equal(t, int64(10000), summary.AvailableBalance)
}

// Test 6: Zero / Negative Amount Validation
func TestLedger_NegativeZeroAmount(t *testing.T) {
	svc, _ := setupTestService(t)
	ctx := context.Background()

	uID := uuid.New()

	// Zero amount CashIn
	_, err := svc.CashIn(ctx, uID, &CashInRequest{
		Amount:         0,
		Currency:       "FCFA",
		IdempotencyKey: "zero-amount-1",
	})
	assert.Error(t, err)
	assert.True(t, errors.Is(err, ErrInvalidAmount))

	// Negative amount CashIn
	_, err = svc.CashIn(ctx, uID, &CashInRequest{
		Amount:         -500,
		Currency:       "FCFA",
		IdempotencyKey: "neg-amount-1",
	})
	assert.Error(t, err)
	assert.True(t, errors.Is(err, ErrInvalidAmount))
}

// Test 7: Idempotency Protection
func TestLedger_Idempotency(t *testing.T) {
	svc, _ := setupTestService(t)
	ctx := context.Background()

	uID := uuid.New()
	idempotencyKey := "unique-idempotency-key-123"

	// First execution
	tx1, err := svc.CashIn(ctx, uID, &CashInRequest{
		Provider:       "wave",
		Amount:         10000,
		Currency:       "FCFA",
		IdempotencyKey: idempotencyKey,
	})
	require.NoError(t, err)

	// Second execution with SAME idempotency key
	tx2, err := svc.CashIn(ctx, uID, &CashInRequest{
		Provider:       "wave",
		Amount:         10000,
		Currency:       "FCFA",
		IdempotencyKey: idempotencyKey,
	})
	require.NoError(t, err)

	// Must return the exact same JournalEntry ID
	assert.Equal(t, tx1.Entry.ID, tx2.Entry.ID)

	// Balance must only have been credited ONCE (10,000, NOT 20,000)
	summary, err := svc.GetWalletSummary(ctx, uID, "FCFA")
	require.NoError(t, err)
	assert.Equal(t, int64(10000), summary.AvailableBalance)
}

// Test 8: Concurrency Safety
func TestLedger_ConcurrencySafety(t *testing.T) {
	svc, _ := setupTestService(t)
	ctx := context.Background()

	uID := uuid.New()

	// Initial CashIn of 100,000
	_, err := svc.CashIn(ctx, uID, &CashInRequest{
		Amount:         100000,
		Currency:       "FCFA",
		IdempotencyKey: "seed-concurrent",
	})
	require.NoError(t, err)

	// Launch 20 concurrent transfers of 1,000 FCFA each
	var wg sync.WaitGroup
	workers := 20
	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func(index int) {
			defer wg.Done()
			destID := uuid.New()
			_, _ = svc.TransferP2P(ctx, uID, &TransferRequest{
				ToUserID:       &destID,
				Amount:         1000,
				Currency:       "FCFA",
				IdempotencyKey: fmt.Sprintf("concurrent-tx-%d", index),
			})
		}(i)
	}
	wg.Wait()

	// Final balance must be exactly 100,000 - (20 * 1,000) = 80,000 FCFA
	summary, err := svc.GetWalletSummary(ctx, uID, "FCFA")
	require.NoError(t, err)
	assert.Equal(t, int64(80000), summary.AvailableBalance)
}

// Test 9: Auditable Journal Entries
func TestLedger_JournalAudit(t *testing.T) {
	svc, _ := setupTestService(t)
	ctx := context.Background()

	// Retrieve all journal entries
	journal, err := svc.GetDetailedJournalEntries(ctx, 50, 0)
	require.NoError(t, err)
	assert.NotEmpty(t, journal)

	// Every single entry in the system must be strictly balanced
	for _, entry := range journal {
		assert.True(t, entry.IsBalanced, "Journal entry %s must be balanced", entry.Entry.ID)
		assert.Equal(t, entry.TotalDebit, entry.TotalCredit, "Debits must equal Credits for entry %s", entry.Entry.ID)
		assert.NotEmpty(t, entry.Postings)
	}
}

// ════════════════════════════════════════════════
// PHASE 3A.0 — HARDENING TESTS
// ════════════════════════════════════════════════

// Test 10: Append-Only — JournalEntries cannot be mutated or deleted through repo
func TestLedger_AppendOnly(t *testing.T) {
	svc, repo := setupTestService(t)
	ctx := context.Background()

	uID := uuid.New()

	// Create a CashIn transaction
	tx1, err := svc.CashIn(ctx, uID, &CashInRequest{
		Provider:       "wave",
		Amount:         25000,
		Currency:       "FCFA",
		IdempotencyKey: "append-only-test-1",
	})
	require.NoError(t, err)

	// Verify the entry exists and is retrievable
	entry, postings, err := repo.GetJournalEntry(ctx, tx1.Entry.ID)
	require.NoError(t, err)
	assert.Equal(t, tx1.Entry.ID, entry.ID)
	assert.Len(t, postings, 2)

	// Verify the entry remains unchanged after subsequent operations
	_, err = svc.CashIn(ctx, uID, &CashInRequest{
		Provider:       "wave",
		Amount:         5000,
		Currency:       "FCFA",
		IdempotencyKey: "append-only-test-2",
	})
	require.NoError(t, err)

	// Original entry must still exist unchanged
	entryAfter, postingsAfter, err := repo.GetJournalEntry(ctx, tx1.Entry.ID)
	require.NoError(t, err)
	assert.Equal(t, entry.ID, entryAfter.ID)
	assert.Equal(t, entry.Description, entryAfter.Description)
	assert.Equal(t, entry.ReferenceID, entryAfter.ReferenceID)
	assert.Len(t, postingsAfter, 2)
	assert.Equal(t, postings[0].Amount, postingsAfter[0].Amount)
	assert.Equal(t, postings[1].Amount, postingsAfter[1].Amount)
}

// Test 11: Idempotency Key Conflict — same key, different amount must be detected
func TestLedger_IdempotencyConflict(t *testing.T) {
	svc, _ := setupTestService(t)
	ctx := context.Background()

	uID := uuid.New()
	key := "conflict-key-ABC123"

	// First CashIn: 10,000 FCFA
	tx1, err := svc.CashIn(ctx, uID, &CashInRequest{
		Provider:       "wave",
		Amount:         10000,
		Currency:       "FCFA",
		IdempotencyKey: key,
	})
	require.NoError(t, err)
	assert.Equal(t, int64(10000), tx1.TotalDebit)

	// Second CashIn: same key but DIFFERENT amount (50,000 FCFA)
	_, err = svc.CashIn(ctx, uID, &CashInRequest{
		Provider:       "wave",
		Amount:         50000,
		Currency:       "FCFA",
		IdempotencyKey: key,
	})
	assert.Error(t, err, "Must reject idempotency key reuse with different amount")
	assert.True(t, errors.Is(err, ErrIdempotencyConflict), "Expected ErrIdempotencyConflict, got: %v", err)

	// Balance must remain at 10,000 (only the first transaction)
	summary, err := svc.GetWalletSummary(ctx, uID, "FCFA")
	require.NoError(t, err)
	assert.Equal(t, int64(10000), summary.AvailableBalance)
}

// Test 12: Concurrent Idempotency — 3 concurrent requests with same key
func TestLedger_ConcurrentIdempotency(t *testing.T) {
	svc, _ := setupTestService(t)
	ctx := context.Background()

	uID := uuid.New()
	key := "concurrent-idempotency-XYZ"

	var wg sync.WaitGroup
	results := make([]*DetailedJournalEntry, 3)
	errs := make([]error, 3)

	for i := 0; i < 3; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			results[idx], errs[idx] = svc.CashIn(ctx, uID, &CashInRequest{
				Provider:       "wave",
				Amount:         10000,
				Currency:       "FCFA",
				IdempotencyKey: key,
			})
		}(i)
	}
	wg.Wait()

	// Exactly one transaction should be created; all must return same entry ID
	var firstEntryID uuid.UUID
	successCount := 0
	for i := 0; i < 3; i++ {
		if errs[i] == nil {
			successCount++
			if firstEntryID == uuid.Nil {
				firstEntryID = results[i].Entry.ID
			}
			assert.Equal(t, firstEntryID, results[i].Entry.ID, "All successful results must reference the same entry")
		}
	}
	assert.GreaterOrEqual(t, successCount, 1, "At least one request must succeed")

	// Balance must be exactly 10,000 (not 20,000 or 30,000)
	summary, err := svc.GetWalletSummary(ctx, uID, "FCFA")
	require.NoError(t, err)
	assert.Equal(t, int64(10000), summary.AvailableBalance)
}

// Test 13: Reversal — Append-only correction via counter-entry
func TestLedger_Reversal(t *testing.T) {
	svc, _ := setupTestService(t)
	ctx := context.Background()

	userID := uuid.New()

	// Fund user with 20,000 FCFA
	_, err := svc.CashIn(ctx, userID, &CashInRequest{
		Provider:       "wave",
		Amount:         20000,
		Currency:       "FCFA",
		IdempotencyKey: "reversal-fund-1",
	})
	require.NoError(t, err)

	// Create a P2P transfer of 5,000 FCFA
	recipientID := uuid.New()
	originalTx, err := svc.TransferP2P(ctx, userID, &TransferRequest{
		ToUserID:       &recipientID,
		Amount:         5000,
		Currency:       "FCFA",
		IdempotencyKey: "reversal-p2p-1",
	})
	require.NoError(t, err)

	// User balance: 20,000 - 5,000 = 15,000
	summary, err := svc.GetWalletSummary(ctx, userID, "FCFA")
	require.NoError(t, err)
	assert.Equal(t, int64(15000), summary.AvailableBalance)

	// Reverse the P2P transfer
	reversalTx, err := svc.ReverseTransaction(ctx, originalTx.Entry.ID, "Erreur de saisie")
	require.NoError(t, err)
	assert.True(t, reversalTx.IsBalanced)
	assert.Contains(t, reversalTx.Entry.Description, "[REVERSAL]")

	// Reversal must be a NEW entry, not the original
	assert.NotEqual(t, originalTx.Entry.ID, reversalTx.Entry.ID)

	// User balance must be restored: 15,000 + 5,000 = 20,000
	summary, err = svc.GetWalletSummary(ctx, userID, "FCFA")
	require.NoError(t, err)
	assert.Equal(t, int64(20000), summary.AvailableBalance)

	// Original entry must still exist (append-only)
	origEntry, origPostings, err := svc.repo.GetJournalEntry(ctx, originalTx.Entry.ID)
	require.NoError(t, err)
	assert.Equal(t, originalTx.Entry.ID, origEntry.ID)
	assert.Len(t, origPostings, 2)

	// Double reversal must be idempotent (return same reversal, not create third entry)
	reversalTx2, err := svc.ReverseTransaction(ctx, originalTx.Entry.ID, "Double reversal attempt")
	require.NoError(t, err)
	assert.Equal(t, reversalTx.Entry.ID, reversalTx2.Entry.ID)
}

// Test 14: Zero, Negative, and MaxInt64 at Repository Level
func TestLedger_AmountEdgeCases(t *testing.T) {
	_, repo := setupTestService(t)
	ctx := context.Background()

	acc1ID := uuid.New()
	acc2ID := uuid.New()
	_ = repo.CreateAccount(ctx, &LedgerAccount{ID: acc1ID, AccountType: Asset, Currency: "FCFA", Name: "Test A", CreatedAt: time.Now().UTC()})
	_ = repo.CreateAccount(ctx, &LedgerAccount{ID: acc2ID, AccountType: Asset, Currency: "FCFA", Name: "Test B", CreatedAt: time.Now().UTC()})

	t.Run("zero_amount", func(t *testing.T) {
		entry := &JournalEntry{ID: uuid.New(), TransactionType: P2PTransfer, ReferenceID: "zero-test", CreatedAt: time.Now().UTC()}
		postings := []*LedgerPosting{
			{ID: uuid.New(), JournalEntryID: entry.ID, AccountID: acc1ID, Amount: 0, IsCredit: false},
			{ID: uuid.New(), JournalEntryID: entry.ID, AccountID: acc2ID, Amount: 0, IsCredit: true},
		}
		err := repo.PostJournalEntry(ctx, entry, postings, "zero-key")
		assert.Error(t, err)
		assert.True(t, errors.Is(err, ErrInvalidAmount))
	})

	t.Run("negative_amount", func(t *testing.T) {
		entry := &JournalEntry{ID: uuid.New(), TransactionType: P2PTransfer, ReferenceID: "neg-test", CreatedAt: time.Now().UTC()}
		postings := []*LedgerPosting{
			{ID: uuid.New(), JournalEntryID: entry.ID, AccountID: acc1ID, Amount: -1000, IsCredit: false},
			{ID: uuid.New(), JournalEntryID: entry.ID, AccountID: acc2ID, Amount: -1000, IsCredit: true},
		}
		err := repo.PostJournalEntry(ctx, entry, postings, "neg-key")
		assert.Error(t, err)
		assert.True(t, errors.Is(err, ErrInvalidAmount))
	})

	t.Run("max_int64_overflow_check", func(t *testing.T) {
		// MaxInt64 is valid as a single amount but should produce a balanced entry
		maxAmount := int64(9223372036854775807) // math.MaxInt64
		entry := &JournalEntry{ID: uuid.New(), TransactionType: P2PTransfer, ReferenceID: "max-test", CreatedAt: time.Now().UTC()}
		postings := []*LedgerPosting{
			{ID: uuid.New(), JournalEntryID: entry.ID, AccountID: acc1ID, Amount: maxAmount, IsCredit: false},
			{ID: uuid.New(), JournalEntryID: entry.ID, AccountID: acc2ID, Amount: maxAmount, IsCredit: true},
		}
		// This should succeed (amounts are balanced, both positive)
		err := repo.PostJournalEntry(ctx, entry, postings, "max-key")
		assert.NoError(t, err)
	})
}

// Test 15: Invalid Account Rejection
func TestLedger_InvalidAccount(t *testing.T) {
	_, repo := setupTestService(t)
	ctx := context.Background()

	validAccID := uuid.New()
	_ = repo.CreateAccount(ctx, &LedgerAccount{ID: validAccID, AccountType: Asset, Currency: "FCFA", Name: "Valid", CreatedAt: time.Now().UTC()})

	nonExistentID := uuid.New()

	entry := &JournalEntry{ID: uuid.New(), TransactionType: P2PTransfer, ReferenceID: "invalid-acc-test", CreatedAt: time.Now().UTC()}
	postings := []*LedgerPosting{
		{ID: uuid.New(), JournalEntryID: entry.ID, AccountID: validAccID, Amount: 1000, IsCredit: false},
		{ID: uuid.New(), JournalEntryID: entry.ID, AccountID: nonExistentID, Amount: 1000, IsCredit: true},
	}
	err := repo.PostJournalEntry(ctx, entry, postings, "invalid-acc-key")
	assert.Error(t, err)
	assert.True(t, errors.Is(err, ErrAccountNotFound))
}

// Test 16: Single Posting Rejection (must have >= 2)
func TestLedger_SinglePostingRejection(t *testing.T) {
	_, repo := setupTestService(t)
	ctx := context.Background()

	accID := uuid.New()
	_ = repo.CreateAccount(ctx, &LedgerAccount{ID: accID, AccountType: Asset, Currency: "FCFA", Name: "Lonely", CreatedAt: time.Now().UTC()})

	entry := &JournalEntry{ID: uuid.New(), TransactionType: P2PTransfer, ReferenceID: "single-posting-test", CreatedAt: time.Now().UTC()}
	postings := []*LedgerPosting{
		{ID: uuid.New(), JournalEntryID: entry.ID, AccountID: accID, Amount: 1000, IsCredit: false},
	}
	err := repo.PostJournalEntry(ctx, entry, postings, "single-posting-key")
	assert.Error(t, err)
}

// Test 17: CashIn & CashOut Ledger Symmetry
func TestLedger_CashInOutSymmetry(t *testing.T) {
	svc, repo := setupTestService(t)
	ctx := context.Background()

	uID := uuid.New()

	// CashIn 10,000 then CashOut 10,000 — net balance must be 0
	_, err := svc.CashIn(ctx, uID, &CashInRequest{
		Provider:       "wave",
		Amount:         10000,
		Currency:       "FCFA",
		IdempotencyKey: "symmetry-in-1",
	})
	require.NoError(t, err)

	_, err = svc.CashOut(ctx, uID, &CashOutRequest{
		Provider:       "wave",
		Amount:         10000,
		Currency:       "FCFA",
		IdempotencyKey: "symmetry-out-1",
	})
	require.NoError(t, err)

	userAcc, err := svc.GetOrCreateUserAccount(ctx, uID, "FCFA")
	require.NoError(t, err)

	bal, err := repo.GetBalance(ctx, userAcc.ID)
	require.NoError(t, err)
	assert.Equal(t, int64(0), bal, "CashIn + CashOut of equal amounts must net to zero")
}
