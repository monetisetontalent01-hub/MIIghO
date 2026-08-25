package psp

import (
	"context"
	"errors"
	"sync"
	"time"

	"github.com/google/uuid"
)

// GatewayService coordinates operations across PSP providers, ensures idempotency,
// persists PSPTransaction audit records, and normalizes webhook events.
// INVARIANT: GatewayService does NOT directly mutate financial balances or write directly to Ledger.
// The calling Business/Payment service receives normalized PSP responses and performs Ledger bookings.
type GatewayService struct {
	repo      Repository
	mu        sync.RWMutex
	providers map[string]PSPProvider
}

func NewGatewayService(repo Repository) *GatewayService {
	svc := &GatewayService{
		repo:      repo,
		providers: make(map[string]PSPProvider),
	}
	// Register default sandbox provider
	svc.RegisterProvider(NewSandboxPSPProvider())
	return svc
}

// RegisterProvider registers a payment provider implementation.
func (s *GatewayService) RegisterProvider(provider PSPProvider) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.providers[provider.ProviderName()] = provider
}

// GetProvider retrieves a registered provider by name.
func (s *GatewayService) GetProvider(name string) (PSPProvider, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if name == "" {
		name = "sandbox"
	}

	p, ok := s.providers[name]
	if !ok {
		return nil, ErrPSPProviderUnavailable
	}
	return p, nil
}

// ExecutePayment orchestrates initiating a payment on the specified PSP rail.
// Idempotent: If a transaction with the same idempotency key exists, returns the existing record.
func (s *GatewayService) ExecutePayment(ctx context.Context, providerName string, req *PSPPaymentRequest) (*PSPTransaction, error) {
	if providerName == "" {
		providerName = "sandbox"
	}

	provider, err := s.GetProvider(providerName)
	if err != nil {
		return nil, err
	}

	// 1. Idempotency Check
	if req.IdempotencyKey != "" {
		if existing, err := s.repo.GetPSPTransactionByIdempotencyKey(ctx, providerName, req.IdempotencyKey); err == nil {
			return existing, nil
		}
	}

	// 2. Execute on Provider Rail
	resp, err := provider.CreatePayment(ctx, req)
	if err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	tx := &PSPTransaction{
		ID:                uuid.New(),
		Provider:          providerName,
		OperationType:     "payment",
		InternalReference: req.InternalReference,
		PSPTransactionID:  resp.PSPTransactionID,
		PaymentIntentID:   req.PaymentIntentID,
		Amount:            req.Amount,
		Currency:          req.Currency,
		Status:            resp.Status,
		IdempotencyKey:    req.IdempotencyKey,
		RequestReference:  req.InternalReference,
		ResponseReference: resp.PSPTransactionID,
		FailureCode:       resp.FailureCode,
		FailureReason:     resp.FailureReason,
		CreatedAt:         now,
		UpdatedAt:         now,
		CompletedAt:       resp.CompletedAt,
	}

	if err := s.repo.CreatePSPTransaction(ctx, tx); err != nil {
		if errors.Is(err, ErrDuplicatePSPTransaction) {
			if req.IdempotencyKey != "" {
				if existing, findErr := s.repo.GetPSPTransactionByIdempotencyKey(ctx, providerName, req.IdempotencyKey); findErr == nil {
					return existing, nil
				}
			}
			if existing, findErr := s.repo.GetPSPTransactionByPSPTxID(ctx, providerName, resp.PSPTransactionID); findErr == nil {
				return existing, nil
			}
		}
		return nil, err
	}

	return tx, nil
}

// GetPaymentStatus checks the latest status of a payment from the provider and updates storage.
func (s *GatewayService) GetPaymentStatus(ctx context.Context, providerName string, pspTxID string) (*PSPTransaction, error) {
	if providerName == "" {
		providerName = "sandbox"
	}

	provider, err := s.GetProvider(providerName)
	if err != nil {
		return nil, err
	}

	tx, err := s.repo.GetPSPTransactionByPSPTxID(ctx, providerName, pspTxID)
	if err != nil {
		return nil, err
	}

	// Query provider for fresh status
	resp, err := provider.GetPaymentStatus(ctx, pspTxID)
	if err != nil {
		return nil, err
	}

	if resp.Status != tx.Status {
		if err := s.repo.UpdatePSPTransactionStatus(ctx, tx.ID, resp.Status, resp.PSPTransactionID, resp.FailureCode, resp.FailureReason, resp.CompletedAt); err != nil {
			return nil, err
		}
		tx.Status = resp.Status
		tx.FailureCode = resp.FailureCode
		tx.FailureReason = resp.FailureReason
		tx.CompletedAt = resp.CompletedAt
	}

	return tx, nil
}

// ExecuteRefund orchestrates initiating a refund on the specified PSP rail.
// Idempotent: If a refund with the same idempotency key exists, returns the existing record.
func (s *GatewayService) ExecuteRefund(ctx context.Context, providerName string, req *PSPRefundRequest) (*PSPTransaction, error) {
	if providerName == "" {
		providerName = "sandbox"
	}

	provider, err := s.GetProvider(providerName)
	if err != nil {
		return nil, err
	}

	// 1. Idempotency Check
	if req.IdempotencyKey != "" {
		if existing, err := s.repo.GetPSPTransactionByIdempotencyKey(ctx, providerName, req.IdempotencyKey); err == nil {
			return existing, nil
		}
	}

	// 2. Execute on Provider Rail
	resp, err := provider.RefundPayment(ctx, req)
	if err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	tx := &PSPTransaction{
		ID:                uuid.New(),
		Provider:          providerName,
		OperationType:     "refund",
		InternalReference: req.InternalReference,
		PSPTransactionID:  resp.PSPRefundID,
		PaymentIntentID:   req.PaymentIntentID,
		RefundID:          req.RefundID,
		Amount:            req.Amount,
		Currency:          req.Currency,
		Status:            resp.Status,
		IdempotencyKey:    req.IdempotencyKey,
		RequestReference:  req.OriginalPSPTxID,
		ResponseReference: resp.PSPRefundID,
		FailureCode:       resp.FailureCode,
		FailureReason:     resp.FailureReason,
		CreatedAt:         now,
		UpdatedAt:         now,
		CompletedAt:       resp.CompletedAt,
	}

	if err := s.repo.CreatePSPTransaction(ctx, tx); err != nil {
		if errors.Is(err, ErrDuplicatePSPTransaction) {
			if req.IdempotencyKey != "" {
				if existing, findErr := s.repo.GetPSPTransactionByIdempotencyKey(ctx, providerName, req.IdempotencyKey); findErr == nil {
					return existing, nil
				}
			}
			if existing, findErr := s.repo.GetPSPTransactionByPSPTxID(ctx, providerName, resp.PSPRefundID); findErr == nil {
				return existing, nil
			}
		}
		return nil, err
	}

	return tx, nil
}

// ExecutePayout orchestrates initiating a payout / settlement on the specified PSP rail.
// Idempotent: If a payout with the same idempotency key exists, returns the existing record.
func (s *GatewayService) ExecutePayout(ctx context.Context, providerName string, req *PSPPayoutRequest) (*PSPTransaction, error) {
	if providerName == "" {
		providerName = "sandbox"
	}

	provider, err := s.GetProvider(providerName)
	if err != nil {
		return nil, err
	}

	// 1. Idempotency Check
	if req.IdempotencyKey != "" {
		if existing, err := s.repo.GetPSPTransactionByIdempotencyKey(ctx, providerName, req.IdempotencyKey); err == nil {
			return existing, nil
		}
	}

	// 2. Execute on Provider Rail
	resp, err := provider.InitiatePayout(ctx, req)
	if err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	tx := &PSPTransaction{
		ID:                uuid.New(),
		Provider:          providerName,
		OperationType:     "payout",
		InternalReference: req.InternalReference,
		PSPTransactionID:  resp.PSPPayoutID,
		SettlementID:      req.SettlementID,
		Amount:            req.Amount,
		Currency:          req.Currency,
		Status:            resp.Status,
		IdempotencyKey:    req.IdempotencyKey,
		RequestReference:  req.InternalReference,
		ResponseReference: resp.PSPPayoutID,
		FailureCode:       resp.FailureCode,
		FailureReason:     resp.FailureReason,
		CreatedAt:         now,
		UpdatedAt:         now,
		CompletedAt:       resp.CompletedAt,
	}

	if err := s.repo.CreatePSPTransaction(ctx, tx); err != nil {
		if errors.Is(err, ErrDuplicatePSPTransaction) {
			if req.IdempotencyKey != "" {
				if existing, findErr := s.repo.GetPSPTransactionByIdempotencyKey(ctx, providerName, req.IdempotencyKey); findErr == nil {
					return existing, nil
				}
			}
			if existing, findErr := s.repo.GetPSPTransactionByPSPTxID(ctx, providerName, resp.PSPPayoutID); findErr == nil {
				return existing, nil
			}
		}
		return nil, err
	}

	return tx, nil
}

// IngestWebhook processes incoming webhook payloads with full de-duplication.
// If an event has already been received and processed, it returns the existing record without re-processing.
func (s *GatewayService) IngestWebhook(ctx context.Context, providerName string, payload []byte, headers map[string]string) (*PSPWebhookRecord, *PSPWebhookEvent, error) {
	if providerName == "" {
		providerName = "sandbox"
	}

	provider, err := s.GetProvider(providerName)
	if err != nil {
		return nil, nil, err
	}

	event, err := provider.ProcessWebhook(ctx, payload, headers)
	if err != nil {
		return nil, nil, err
	}

	// Check if this event was already ingested
	existing, err := s.repo.GetWebhookEvent(ctx, providerName, event.EventID)
	if err == nil {
		// Event was already ingested and processed — idempotent return
		return existing, event, nil
	}

	now := time.Now().UTC()
	record := &PSPWebhookRecord{
		ID:          uuid.New(),
		Provider:    providerName,
		EventID:     event.EventID,
		EventType:   event.EventType,
		Payload:     string(payload),
		Status:      "PROCESSED",
		ReceivedAt:  now,
		ProcessedAt: &now,
	}

	if err := s.repo.RecordWebhookEvent(ctx, record); err != nil {
		if errors.Is(err, ErrWebhookAlreadyProcessed) {
			if ex, findErr := s.repo.GetWebhookEvent(ctx, providerName, event.EventID); findErr == nil {
				return ex, event, nil
			}
		}
		return nil, nil, err
	}

	// Update correlated PSPTransaction if found
	if event.PSPTransactionID != "" {
		if tx, findErr := s.repo.GetPSPTransactionByPSPTxID(ctx, providerName, event.PSPTransactionID); findErr == nil {
			_ = s.repo.UpdatePSPTransactionStatus(ctx, tx.ID, event.Status, event.PSPTransactionID, event.FailureCode, event.FailureReason, &now)
		}
	}

	return record, event, nil
}

// GetTransactionsByInternalRef retrieves all PSP transaction logs for a given MÏÏghO domain entity ID.
func (s *GatewayService) GetTransactionsByInternalRef(ctx context.Context, internalRef string) ([]*PSPTransaction, error) {
	return s.repo.GetPSPTransactionsByInternalRef(ctx, internalRef)
}
