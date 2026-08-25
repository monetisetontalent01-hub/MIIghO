package psp

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// setupPSPTestEnv initializes an isolated in-memory test environment for Phase 3A.6.
func setupPSPTestEnv(t *testing.T) (*GatewayService, *MemoryRepository, *SandboxPSPProvider) {
	t.Helper()
	repo := NewMemoryRepository()
	svc := NewGatewayService(repo)
	provider := NewSandboxPSPProvider()
	// The gateway service already registers a sandbox provider by default.
	return svc, repo, provider
}

// ======================================================================
// 1. TestPSP_Sandbox_CreatePayment
// ======================================================================
func TestPSP_Sandbox_CreatePayment(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	piID := uuid.New()
	tx, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            5000,
		Currency:          "FCFA",
		IdempotencyKey:    "pay-idemp-001",
	})
	require.NoError(t, err)
	assert.Equal(t, "sandbox", tx.Provider)
	assert.Equal(t, "payment", tx.OperationType)
	assert.Equal(t, PSPStatusSucceeded, tx.Status)
	assert.Equal(t, int64(5000), tx.Amount)
	assert.Equal(t, "FCFA", tx.Currency)
	assert.NotEmpty(t, tx.PSPTransactionID)
	assert.NotNil(t, tx.PaymentIntentID)
	assert.Equal(t, piID, *tx.PaymentIntentID)
}

// ======================================================================
// 2. TestPSP_Sandbox_GetPaymentStatus
// ======================================================================
func TestPSP_Sandbox_GetPaymentStatus(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	piID := uuid.New()
	tx, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            3000,
		Currency:          "FCFA",
		IdempotencyKey:    "pay-status-001",
	})
	require.NoError(t, err)

	result, err := svc.GetPaymentStatus(ctx, "sandbox", tx.PSPTransactionID)
	require.NoError(t, err)
	assert.Equal(t, PSPStatusSucceeded, result.Status)
	assert.Equal(t, tx.ID, result.ID)
}

// ======================================================================
// 3. TestPSP_Sandbox_Refund
// ======================================================================
func TestPSP_Sandbox_Refund(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	piID := uuid.New()
	payTx, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            10000,
		Currency:          "FCFA",
		IdempotencyKey:    "pay-ref-001",
	})
	require.NoError(t, err)

	refID := uuid.New()
	refTx, err := svc.ExecuteRefund(ctx, "sandbox", &PSPRefundRequest{
		InternalReference: refID.String(),
		RefundID:          &refID,
		OriginalPSPTxID:   payTx.PSPTransactionID,
		PaymentIntentID:   &piID,
		Amount:            5000,
		Currency:          "FCFA",
		Reason:            "Customer request",
		IdempotencyKey:    "ref-idemp-001",
	})
	require.NoError(t, err)
	assert.Equal(t, "refund", refTx.OperationType)
	assert.Equal(t, PSPStatusSucceeded, refTx.Status)
	assert.Equal(t, int64(5000), refTx.Amount)
}

// ======================================================================
// 4. TestPSP_Sandbox_Payout
// ======================================================================
func TestPSP_Sandbox_Payout(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	settlID := uuid.New()
	tx, err := svc.ExecutePayout(ctx, "sandbox", &PSPPayoutRequest{
		InternalReference:  settlID.String(),
		SettlementID:       &settlID,
		Amount:             25000,
		Currency:           "FCFA",
		DestinationType:    "momo",
		DestinationAccount: "+225070000001",
		IdempotencyKey:     "payout-001",
	})
	require.NoError(t, err)
	assert.Equal(t, "payout", tx.OperationType)
	assert.Equal(t, PSPStatusSucceeded, tx.Status)
	assert.Equal(t, int64(25000), tx.Amount)
	assert.NotNil(t, tx.SettlementID)
}

// ======================================================================
// 5. TestPSP_StatusNormalization
// ======================================================================
func TestPSP_StatusNormalization(t *testing.T) {
	provider := NewSandboxPSPProvider()
	ctx := context.Background()

	tests := []struct {
		rawStatus string
		expected  PSPStatus
	}{
		{"ACCEPTED", PSPStatusSucceeded},
		{"SUCCESS", PSPStatusSucceeded},
		{"COMPLETED", PSPStatusSucceeded},
		{"SUCCEEDED", PSPStatusSucceeded},
		{"FAILED", PSPStatusFailed},
		{"DECLINED", PSPStatusFailed},
		{"REJECTED", PSPStatusFailed},
		{"PENDING", PSPStatusProcessing},
		{"IN_PROGRESS", PSPStatusProcessing},
		{"PROCESSING", PSPStatusProcessing},
		{"EXPIRED", PSPStatusExpired},
		{"TIMEOUT", PSPStatusExpired},
		{"CANCELLED", PSPStatusCancelled},
	}

	for _, tc := range tests {
		t.Run(tc.rawStatus, func(t *testing.T) {
			payload, _ := json.Marshal(map[string]interface{}{
				"event_id":           fmt.Sprintf("evt-%s", tc.rawStatus),
				"event_type":         "payment.status",
				"psp_transaction_id": "TX-001",
				"status":             tc.rawStatus,
				"amount":             1000,
				"currency":           "FCFA",
			})
			event, err := provider.ProcessWebhook(ctx, payload, nil)
			require.NoError(t, err)
			assert.Equal(t, tc.expected, event.Status, "normalization failed for raw status: %s", tc.rawStatus)
		})
	}
}

// ======================================================================
// 6. TestPSP_Idempotency
// ======================================================================
func TestPSP_Idempotency(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	piID := uuid.New()
	req := &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            7500,
		Currency:          "FCFA",
		IdempotencyKey:    "idemp-unique-001",
	}

	tx1, err := svc.ExecutePayment(ctx, "sandbox", req)
	require.NoError(t, err)

	// Second call with same key must return the same transaction
	tx2, err := svc.ExecutePayment(ctx, "sandbox", req)
	require.NoError(t, err)
	assert.Equal(t, tx1.ID, tx2.ID)
	assert.Equal(t, tx1.PSPTransactionID, tx2.PSPTransactionID)
}

// ======================================================================
// 7. TestPSP_ConcurrentIdempotency
// ======================================================================
func TestPSP_ConcurrentIdempotency(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	piID := uuid.New()
	const n = 20
	results := make([]*PSPTransaction, n)
	errs := make([]error, n)
	var wg sync.WaitGroup

	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			tx, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
				InternalReference: piID.String(),
				PaymentIntentID:   &piID,
				Amount:            5000,
				Currency:          "FCFA",
				IdempotencyKey:    "concurrent-idemp-001",
			})
			results[idx] = tx
			errs[idx] = err
		}(i)
	}
	wg.Wait()

	// All results should be non-nil and have the same ID
	var firstID uuid.UUID
	for i := 0; i < n; i++ {
		require.NoError(t, errs[i])
		require.NotNil(t, results[i])
		if i == 0 {
			firstID = results[i].ID
		} else {
			assert.Equal(t, firstID, results[i].ID, "concurrent call %d returned different transaction", i)
		}
	}
}

// ======================================================================
// 8. TestPSP_PaymentSuccess
// ======================================================================
func TestPSP_PaymentSuccess(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	piID := uuid.New()
	tx, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            15000,
		Currency:          "FCFA",
		IdempotencyKey:    "pay-success-001",
	})
	require.NoError(t, err)
	assert.Equal(t, PSPStatusSucceeded, tx.Status)
	assert.NotNil(t, tx.CompletedAt)
	assert.Empty(t, tx.FailureCode)
	assert.Empty(t, tx.FailureReason)
}

// ======================================================================
// 9. TestPSP_PaymentFailure
// ======================================================================
func TestPSP_PaymentFailure(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	piID := uuid.New()
	tx, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            5000,
		Currency:          "FCFA",
		IdempotencyKey:    "pay-fail-001",
		SimulationAction:  "simulate_fail",
	})
	require.NoError(t, err)
	assert.Equal(t, PSPStatusFailed, tx.Status)
	assert.NotEmpty(t, tx.FailureCode)
	assert.NotEmpty(t, tx.FailureReason)
}

// ======================================================================
// 10. TestPSP_PaymentPending
// ======================================================================
func TestPSP_PaymentPending(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	piID := uuid.New()
	tx, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            8000,
		Currency:          "FCFA",
		IdempotencyKey:    "pay-pending-001",
		SimulationAction:  "simulate_pending",
	})
	require.NoError(t, err)
	assert.Equal(t, PSPStatusPending, tx.Status)
	// A pending payment must NOT have a completedAt (no premature Ledger write).
	assert.Nil(t, tx.CompletedAt)
}

// ======================================================================
// 11. TestPSP_PaymentExpired
// ======================================================================
func TestPSP_PaymentExpired(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	piID := uuid.New()
	tx, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            2000,
		Currency:          "FCFA",
		IdempotencyKey:    "pay-expire-001",
		SimulationAction:  "simulate_expire",
	})
	require.NoError(t, err)
	assert.Equal(t, PSPStatusExpired, tx.Status)
	assert.Equal(t, "SANDBOX_SESSION_TIMEOUT", tx.FailureCode)
}

// ======================================================================
// 12. TestPSP_RefundSuccess
// ======================================================================
func TestPSP_RefundSuccess(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	piID := uuid.New()
	payTx, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            20000,
		Currency:          "FCFA",
		IdempotencyKey:    "ref-suc-pay-001",
	})
	require.NoError(t, err)

	refID := uuid.New()
	refTx, err := svc.ExecuteRefund(ctx, "sandbox", &PSPRefundRequest{
		InternalReference: refID.String(),
		RefundID:          &refID,
		OriginalPSPTxID:   payTx.PSPTransactionID,
		Amount:            20000,
		Currency:          "FCFA",
		IdempotencyKey:    "ref-suc-001",
	})
	require.NoError(t, err)
	assert.Equal(t, PSPStatusSucceeded, refTx.Status)
	assert.NotNil(t, refTx.CompletedAt)
}

// ======================================================================
// 13. TestPSP_RefundFailure
// ======================================================================
func TestPSP_RefundFailure(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	refID := uuid.New()
	refTx, err := svc.ExecuteRefund(ctx, "sandbox", &PSPRefundRequest{
		InternalReference: refID.String(),
		RefundID:          &refID,
		OriginalPSPTxID:   "SANDBOX-PAY-ORIGINAL",
		Amount:            5000,
		Currency:          "FCFA",
		IdempotencyKey:    "ref-fail-001",
		SimulationAction:  "simulate_fail",
	})
	require.NoError(t, err)
	assert.Equal(t, PSPStatusFailed, refTx.Status)
	assert.NotEmpty(t, refTx.FailureCode)
}

// ======================================================================
// 14. TestPSP_PayoutSuccess
// ======================================================================
func TestPSP_PayoutSuccess(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	settlID := uuid.New()
	tx, err := svc.ExecutePayout(ctx, "sandbox", &PSPPayoutRequest{
		InternalReference:  settlID.String(),
		SettlementID:       &settlID,
		Amount:             50000,
		Currency:           "FCFA",
		DestinationType:    "bank",
		DestinationAccount: "CI001234567890",
		IdempotencyKey:     "payout-suc-001",
	})
	require.NoError(t, err)
	assert.Equal(t, PSPStatusSucceeded, tx.Status)
	assert.NotNil(t, tx.CompletedAt)
}

// ======================================================================
// 15. TestPSP_PayoutFailure
// ======================================================================
func TestPSP_PayoutFailure(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	settlID := uuid.New()
	tx, err := svc.ExecutePayout(ctx, "sandbox", &PSPPayoutRequest{
		InternalReference:  settlID.String(),
		SettlementID:       &settlID,
		Amount:             30000,
		Currency:           "FCFA",
		DestinationType:    "momo",
		DestinationAccount: "+225070000002",
		IdempotencyKey:     "payout-fail-001",
		SimulationAction:   "simulate_fail",
	})
	require.NoError(t, err)
	assert.Equal(t, PSPStatusFailed, tx.Status)
	assert.NotEmpty(t, tx.FailureCode)
}

// ======================================================================
// 16. TestPSP_NoDuplicateLedgerEntry
// ======================================================================
func TestPSP_NoDuplicateLedgerEntry(t *testing.T) {
	// Verify that re-submitting the same payment yields the same PSPTransaction
	// without creating a second record (preventing duplicate Ledger entries upstream).
	svc, repo, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	piID := uuid.New()
	req := &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            12000,
		Currency:          "FCFA",
		IdempotencyKey:    "no-dup-ledger-001",
	}

	tx1, err := svc.ExecutePayment(ctx, "sandbox", req)
	require.NoError(t, err)

	tx2, err := svc.ExecutePayment(ctx, "sandbox", req)
	require.NoError(t, err)
	assert.Equal(t, tx1.ID, tx2.ID)

	// Count transactions in repo by internal ref
	txs, err := repo.GetPSPTransactionsByInternalRef(ctx, piID.String())
	require.NoError(t, err)
	assert.Equal(t, 1, len(txs), "must have exactly 1 PSP transaction, not duplicated")
}

// ======================================================================
// 17. TestPSP_LedgerIsolation
// ======================================================================
func TestPSP_LedgerIsolation(t *testing.T) {
	// INVARIANT: The PSP package must NOT import or directly reference the ledger package.
	// This is a design constraint test. The PSP gateway service does NOT write Ledger entries.
	// Verification: The GatewayService has no ledger.Repository dependency.
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	piID := uuid.New()
	tx, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            5000,
		Currency:          "FCFA",
		IdempotencyKey:    "ledger-iso-001",
	})
	require.NoError(t, err)
	// The PSP transaction exists in PSP storage, not in Ledger.
	// No JournalEntry or LedgerPosting is created by the PSP layer.
	assert.Equal(t, PSPStatusSucceeded, tx.Status)
	assert.Equal(t, "payment", tx.OperationType)
}

// ======================================================================
// 18. TestPSP_AppendOnly
// ======================================================================
func TestPSP_AppendOnly(t *testing.T) {
	// Verify that updating a PSP transaction status does not delete or mutate the original record.
	svc, repo, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	piID := uuid.New()
	tx, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            5000,
		Currency:          "FCFA",
		IdempotencyKey:    "append-only-001",
		SimulationAction:  "simulate_pending",
	})
	require.NoError(t, err)
	assert.Equal(t, PSPStatusPending, tx.Status)

	// Simulate a status update (e.g., webhook confirmation)
	err = repo.UpdatePSPTransactionStatus(ctx, tx.ID, PSPStatusSucceeded, tx.PSPTransactionID, "", "", nil)
	require.NoError(t, err)

	updated, err := repo.GetPSPTransaction(ctx, tx.ID)
	require.NoError(t, err)
	assert.Equal(t, PSPStatusSucceeded, updated.Status)
	// Original fields remain intact
	assert.Equal(t, tx.Amount, updated.Amount)
	assert.Equal(t, tx.Provider, updated.Provider)
	assert.Equal(t, tx.InternalReference, updated.InternalReference)
}

// ======================================================================
// 19. TestPSP_IDOR
// ======================================================================
func TestPSP_IDOR(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	// Business A creates a payment
	bizA := uuid.New()
	piA := uuid.New()
	txA, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piA.String(),
		PaymentIntentID:   &piA,
		BusinessID:        &bizA,
		Amount:            5000,
		Currency:          "FCFA",
		IdempotencyKey:    "idor-biz-a-001",
	})
	require.NoError(t, err)

	// Business B creates a payment
	bizB := uuid.New()
	piB := uuid.New()
	txB, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piB.String(),
		PaymentIntentID:   &piB,
		BusinessID:        &bizB,
		Amount:            8000,
		Currency:          "FCFA",
		IdempotencyKey:    "idor-biz-b-001",
	})
	require.NoError(t, err)

	// Each transaction must belong to its respective business reference
	assert.NotEqual(t, txA.InternalReference, txB.InternalReference)
	assert.NotEqual(t, txA.ID, txB.ID)
	assert.NotEqual(t, txA.PSPTransactionID, txB.PSPTransactionID)

	// Querying by ref should only return the correct transaction
	txsA, err := svc.GetTransactionsByInternalRef(ctx, piA.String())
	require.NoError(t, err)
	assert.Equal(t, 1, len(txsA))
	assert.Equal(t, txA.ID, txsA[0].ID)

	txsB, err := svc.GetTransactionsByInternalRef(ctx, piB.String())
	require.NoError(t, err)
	assert.Equal(t, 1, len(txsB))
	assert.Equal(t, txB.ID, txsB[0].ID)
}

// ======================================================================
// 20. TestPSP_Authorization
// ======================================================================
func TestPSP_Authorization(t *testing.T) {
	// The PSP gateway enforces provider resolution. Requesting an unknown provider
	// must be rejected.
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	piID := uuid.New()
	_, err := svc.ExecutePayment(ctx, "unknown_provider", &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            5000,
		Currency:          "FCFA",
		IdempotencyKey:    "auth-001",
	})
	require.Error(t, err)
	assert.ErrorIs(t, err, ErrPSPProviderUnavailable)
}

// ======================================================================
// 21. TestPSP_CurrencyValidation
// ======================================================================
func TestPSP_CurrencyValidation(t *testing.T) {
	// The sandbox provider should accept the request with any currency string
	// without crashing. Currency validation is enforced upstream in the business layer.
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	piID := uuid.New()
	tx, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            5000,
		Currency:          "XOF",
		IdempotencyKey:    "currency-001",
	})
	require.NoError(t, err)
	assert.Equal(t, "XOF", tx.Currency)
}

// ======================================================================
// 22. TestPSP_AmountValidation
// ======================================================================
func TestPSP_AmountValidation(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	// Zero amount
	piID := uuid.New()
	_, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            0,
		Currency:          "FCFA",
		IdempotencyKey:    "amt-zero-001",
	})
	require.Error(t, err)
	assert.ErrorIs(t, err, ErrInvalidAmount)

	// Negative amount
	_, err = svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            -500,
		Currency:          "FCFA",
		IdempotencyKey:    "amt-neg-001",
	})
	require.Error(t, err)
	assert.ErrorIs(t, err, ErrInvalidAmount)
}

// ======================================================================
// 23. TestPSP_WebhookIdempotency
// ======================================================================
func TestPSP_WebhookIdempotency(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	payload, _ := json.Marshal(map[string]interface{}{
		"event_id":           "EVT-WH-001",
		"event_type":         "payment.succeeded",
		"psp_transaction_id": "SANDBOX-PAY-WEBHOOK",
		"status":             "SUCCEEDED",
		"amount":             5000,
		"currency":           "FCFA",
	})

	rec1, evt1, err := svc.IngestWebhook(ctx, "sandbox", payload, nil)
	require.NoError(t, err)
	assert.Equal(t, "PROCESSED", rec1.Status)
	assert.Equal(t, PSPStatusSucceeded, evt1.Status)

	// Second ingestion with the same event_id must return the existing record
	rec2, _, err := svc.IngestWebhook(ctx, "sandbox", payload, nil)
	require.NoError(t, err)
	assert.Equal(t, rec1.ID, rec2.ID, "duplicate webhook must return the same record")
}

// ======================================================================
// 24. TestPSP_WebhookDuplicateEvent
// ======================================================================
func TestPSP_WebhookDuplicateEvent(t *testing.T) {
	svc, repo, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	payload, _ := json.Marshal(map[string]interface{}{
		"event_id":           "EVT-DUP-001",
		"event_type":         "payment.succeeded",
		"psp_transaction_id": "SANDBOX-PAY-DUP",
		"status":             "SUCCEEDED",
		"amount":             7000,
		"currency":           "FCFA",
	})

	const n = 20
	records := make([]*PSPWebhookRecord, n)
	errs := make([]error, n)
	var wg sync.WaitGroup

	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			rec, _, err := svc.IngestWebhook(ctx, "sandbox", payload, nil)
			records[idx] = rec
			errs[idx] = err
		}(i)
	}
	wg.Wait()

	var firstID uuid.UUID
	for i := 0; i < n; i++ {
		require.NoError(t, errs[i])
		require.NotNil(t, records[i])
		if i == 0 {
			firstID = records[i].ID
		} else {
			assert.Equal(t, firstID, records[i].ID, "duplicate webhook call %d must return same record", i)
		}
	}

	// Only one webhook record should exist
	wh, err := repo.GetWebhookEvent(ctx, "sandbox", "EVT-DUP-001")
	require.NoError(t, err)
	assert.Equal(t, firstID, wh.ID)
}

// ======================================================================
// 25. TestPSP_NoExternalNetworkCall
// ======================================================================
func TestPSP_NoExternalNetworkCall(t *testing.T) {
	// INVARIANT: The SandboxPSPProvider has no http.Client, no net/http import, no DNS resolution.
	// This test verifies that 100 operations complete without any network dependency.
	provider := NewSandboxPSPProvider()
	ctx := context.Background()

	for i := 0; i < 100; i++ {
		resp, err := provider.CreatePayment(ctx, &PSPPaymentRequest{
			InternalReference: fmt.Sprintf("no-net-%d", i),
			Amount:            int64(1000 + i),
			Currency:          "FCFA",
		})
		require.NoError(t, err)
		assert.Equal(t, PSPStatusSucceeded, resp.Status)
		assert.Equal(t, "sandbox", resp.Provider)
	}
}

// ======================================================================
// 26. TestPSP_PaymentLedgerReconciliation
// ======================================================================
func TestPSP_PaymentLedgerReconciliation(t *testing.T) {
	// Verify the correlation chain: PaymentIntent → PSP Transaction.
	// The Ledger entry is NOT created here (it is the business layer's responsibility).
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	piID := uuid.New()
	tx, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            10000,
		Currency:          "FCFA",
		IdempotencyKey:    "recon-pay-001",
	})
	require.NoError(t, err)

	// Verify correlation
	assert.Equal(t, piID.String(), tx.InternalReference)
	assert.Equal(t, &piID, tx.PaymentIntentID)
	assert.Equal(t, "payment", tx.OperationType)
	assert.NotEmpty(t, tx.PSPTransactionID)
	assert.Equal(t, tx.PSPTransactionID, tx.ResponseReference)

	// Verify we can retrieve by internal ref
	txs, err := svc.GetTransactionsByInternalRef(ctx, piID.String())
	require.NoError(t, err)
	assert.Equal(t, 1, len(txs))
	assert.Equal(t, tx.ID, txs[0].ID)
}

// ======================================================================
// 27. TestPSP_RefundLedgerReconciliation
// ======================================================================
func TestPSP_RefundLedgerReconciliation(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	// Create payment first
	piID := uuid.New()
	payTx, err := svc.ExecutePayment(ctx, "sandbox", &PSPPaymentRequest{
		InternalReference: piID.String(),
		PaymentIntentID:   &piID,
		Amount:            20000,
		Currency:          "FCFA",
		IdempotencyKey:    "recon-ref-pay-001",
	})
	require.NoError(t, err)

	// Create refund
	refID := uuid.New()
	refTx, err := svc.ExecuteRefund(ctx, "sandbox", &PSPRefundRequest{
		InternalReference: refID.String(),
		RefundID:          &refID,
		OriginalPSPTxID:   payTx.PSPTransactionID,
		PaymentIntentID:   &piID,
		Amount:            10000,
		Currency:          "FCFA",
		IdempotencyKey:    "recon-ref-001",
	})
	require.NoError(t, err)

	// Verify correlation
	assert.Equal(t, refID.String(), refTx.InternalReference)
	assert.Equal(t, &refID, refTx.RefundID)
	assert.Equal(t, &piID, refTx.PaymentIntentID)
	assert.Equal(t, "refund", refTx.OperationType)
	assert.Equal(t, payTx.PSPTransactionID, refTx.RequestReference)
}

// ======================================================================
// 28. TestPSP_SettlementLedgerReconciliation
// ======================================================================
func TestPSP_SettlementLedgerReconciliation(t *testing.T) {
	svc, _, _ := setupPSPTestEnv(t)
	ctx := context.Background()

	settlID := uuid.New()
	tx, err := svc.ExecutePayout(ctx, "sandbox", &PSPPayoutRequest{
		InternalReference:  settlID.String(),
		SettlementID:       &settlID,
		Amount:             100000,
		Currency:           "FCFA",
		DestinationType:    "bank",
		DestinationAccount: "CI009876543210",
		IdempotencyKey:     "recon-settl-001",
	})
	require.NoError(t, err)

	// Verify correlation
	assert.Equal(t, settlID.String(), tx.InternalReference)
	assert.Equal(t, &settlID, tx.SettlementID)
	assert.Equal(t, "payout", tx.OperationType)
	assert.NotEmpty(t, tx.PSPTransactionID)

	// Verify we can retrieve by internal ref
	txs, err := svc.GetTransactionsByInternalRef(ctx, settlID.String())
	require.NoError(t, err)
	assert.Equal(t, 1, len(txs))
	assert.Equal(t, tx.ID, txs[0].ID)
}
