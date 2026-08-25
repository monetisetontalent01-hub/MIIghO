package psp

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
)

// SandboxPSPProvider provides a 100% local, networkless, in-memory PSP simulation rail.
// INVARIANT: Zero HTTP client, zero network call, zero external secret.
type SandboxPSPProvider struct {
	mu       sync.RWMutex
	payments map[string]*PSPPaymentResponse
	refunds  map[string]*PSPRefundResponse
	payouts  map[string]*PSPPayoutResponse
}

func NewSandboxPSPProvider() *SandboxPSPProvider {
	return &SandboxPSPProvider{
		payments: make(map[string]*PSPPaymentResponse),
		refunds:  make(map[string]*PSPRefundResponse),
		payouts:  make(map[string]*PSPPayoutResponse),
	}
}

func (p *SandboxPSPProvider) ProviderName() string {
	return "sandbox"
}

// CreatePayment simulates initiating a payment on the sandbox rail.
func (p *SandboxPSPProvider) CreatePayment(ctx context.Context, req *PSPPaymentRequest) (*PSPPaymentResponse, error) {
	if req.Amount <= 0 {
		return nil, ErrInvalidAmount
	}

	p.mu.Lock()
	defer p.mu.Unlock()

	now := time.Now().UTC()
	pspTxID := fmt.Sprintf("SANDBOX-PAY-%s", uuid.New().String()[:12])

	status := PSPStatusSucceeded
	var completedAt *time.Time = &now
	var failCode, failReason string

	action := strings.ToLower(req.SimulationAction)
	if action == "simulate_fail" || req.Amount == 999999 {
		status = PSPStatusFailed
		failCode = "SANDBOX_INSUFFICIENT_FUNDS"
		failReason = "Simulated card or account decline in sandbox"
	} else if action == "simulate_pending" {
		status = PSPStatusPending
		completedAt = nil
	} else if action == "simulate_expire" {
		status = PSPStatusExpired
		failCode = "SANDBOX_SESSION_TIMEOUT"
		failReason = "Simulated payment intent session expiration"
	}

	resp := &PSPPaymentResponse{
		Provider:          p.ProviderName(),
		PSPTransactionID:  pspTxID,
		InternalReference: req.InternalReference,
		Amount:            req.Amount,
		Currency:          req.Currency,
		Status:            status,
		CheckoutURL:       fmt.Sprintf("https://sandbox.miigho.local/checkout/%s", pspTxID),
		FailureCode:       failCode,
		FailureReason:     failReason,
		RawResponse:       fmt.Sprintf(`{"status":"%s","simulated":true}`, status),
		CreatedAt:         now,
		CompletedAt:       completedAt,
	}

	p.payments[pspTxID] = resp
	return resp, nil
}

// GetPaymentStatus checks the status of a simulated payment.
func (p *SandboxPSPProvider) GetPaymentStatus(ctx context.Context, pspTxID string) (*PSPPaymentResponse, error) {
	p.mu.RLock()
	defer p.mu.RUnlock()

	resp, ok := p.payments[pspTxID]
	if !ok {
		return nil, ErrPSPTransactionNotFound
	}
	return resp, nil
}

// RefundPayment simulates processing a refund on the sandbox rail.
func (p *SandboxPSPProvider) RefundPayment(ctx context.Context, req *PSPRefundRequest) (*PSPRefundResponse, error) {
	if req.Amount <= 0 {
		return nil, ErrInvalidAmount
	}

	p.mu.Lock()
	defer p.mu.Unlock()

	now := time.Now().UTC()
	pspRefundID := fmt.Sprintf("SANDBOX-REF-%s", uuid.New().String()[:12])

	status := PSPStatusSucceeded
	var completedAt *time.Time = &now
	var failCode, failReason string

	action := strings.ToLower(req.SimulationAction)
	if action == "simulate_fail" {
		status = PSPStatusFailed
		failCode = "SANDBOX_REFUND_REJECTED"
		failReason = "Simulated refund rejection by issuer"
	}

	resp := &PSPRefundResponse{
		Provider:          p.ProviderName(),
		PSPRefundID:       pspRefundID,
		OriginalPSPTxID:   req.OriginalPSPTxID,
		InternalReference: req.InternalReference,
		Amount:            req.Amount,
		Currency:          req.Currency,
		Status:            status,
		FailureCode:       failCode,
		FailureReason:     failReason,
		RawResponse:       fmt.Sprintf(`{"status":"%s","simulated":true}`, status),
		CreatedAt:         now,
		CompletedAt:       completedAt,
	}

	p.refunds[pspRefundID] = resp
	return resp, nil
}

// InitiatePayout simulates processing a disbursement / settlement to a merchant.
func (p *SandboxPSPProvider) InitiatePayout(ctx context.Context, req *PSPPayoutRequest) (*PSPPayoutResponse, error) {
	if req.Amount <= 0 {
		return nil, ErrInvalidAmount
	}

	p.mu.Lock()
	defer p.mu.Unlock()

	now := time.Now().UTC()
	pspPayoutID := fmt.Sprintf("SANDBOX-PAYOUT-%s", uuid.New().String()[:12])

	status := PSPStatusSucceeded
	var completedAt *time.Time = &now
	var failCode, failReason string

	action := strings.ToLower(req.SimulationAction)
	if action == "simulate_fail" {
		status = PSPStatusFailed
		failCode = "SANDBOX_DESTINATION_ACCOUNT_INVALID"
		failReason = "Simulated destination bank account or MoMo wallet error"
	}

	resp := &PSPPayoutResponse{
		Provider:          p.ProviderName(),
		PSPPayoutID:       pspPayoutID,
		InternalReference: req.InternalReference,
		Amount:            req.Amount,
		Currency:          req.Currency,
		Status:            status,
		FailureCode:       failCode,
		FailureReason:     failReason,
		RawResponse:       fmt.Sprintf(`{"status":"%s","simulated":true}`, status),
		CreatedAt:         now,
		CompletedAt:       completedAt,
	}

	p.payouts[pspPayoutID] = resp
	return resp, nil
}

// GetPayoutStatus checks the status of a simulated payout.
func (p *SandboxPSPProvider) GetPayoutStatus(ctx context.Context, pspPayoutID string) (*PSPPayoutResponse, error) {
	p.mu.RLock()
	defer p.mu.RUnlock()

	resp, ok := p.payouts[pspPayoutID]
	if !ok {
		return nil, ErrPSPTransactionNotFound
	}
	return resp, nil
}

// ProcessWebhook parses and normalizes a sandbox webhook event.
func (p *SandboxPSPProvider) ProcessWebhook(ctx context.Context, payload []byte, headers map[string]string) (*PSPWebhookEvent, error) {
	var raw struct {
		EventID           string `json:"event_id"`
		EventType         string `json:"event_type"`
		PSPTransactionID  string `json:"psp_transaction_id"`
		InternalReference string `json:"internal_reference"`
		Status            string `json:"status"`
		Amount            int64  `json:"amount"`
		Currency          string `json:"currency"`
		FailureCode       string `json:"failure_code,omitempty"`
		FailureReason     string `json:"failure_reason,omitempty"`
	}

	if err := json.Unmarshal(payload, &raw); err != nil {
		return nil, fmt.Errorf("invalid sandbox webhook payload: %w", err)
	}

	if raw.EventID == "" {
		raw.EventID = fmt.Sprintf("SANDBOX-EVT-%s", uuid.New().String()[:12])
	}

	normalizedStatus := PSPStatus(strings.ToUpper(raw.Status))
	switch normalizedStatus {
	case "ACCEPTED", "SUCCESS", "COMPLETED", "SUCCEEDED":
		normalizedStatus = PSPStatusSucceeded
	case "FAILED", "DECLINED", "REJECTED":
		normalizedStatus = PSPStatusFailed
	case "PENDING", "IN_PROGRESS", "PROCESSING":
		normalizedStatus = PSPStatusProcessing
	case "EXPIRED", "TIMEOUT":
		normalizedStatus = PSPStatusExpired
	case "CANCELLED":
		normalizedStatus = PSPStatusCancelled
	default:
		if normalizedStatus == "" {
			normalizedStatus = PSPStatusUnknown
		}
	}

	return &PSPWebhookEvent{
		EventID:           raw.EventID,
		Provider:          p.ProviderName(),
		EventType:         raw.EventType,
		PSPTransactionID:  raw.PSPTransactionID,
		InternalReference: raw.InternalReference,
		Status:            normalizedStatus,
		Amount:            raw.Amount,
		Currency:          raw.Currency,
		FailureCode:       raw.FailureCode,
		FailureReason:     raw.FailureReason,
		RawPayload:        string(payload),
		Timestamp:         time.Now().UTC(),
	}, nil
}
