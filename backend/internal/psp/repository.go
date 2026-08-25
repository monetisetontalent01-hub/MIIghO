package psp

import (
	"context"
	"database/sql"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repository defines storage operations for PSP transactions and webhook records.
type Repository interface {
	CreatePSPTransaction(ctx context.Context, tx *PSPTransaction) error
	GetPSPTransaction(ctx context.Context, id uuid.UUID) (*PSPTransaction, error)
	GetPSPTransactionByPSPTxID(ctx context.Context, provider string, pspTxID string) (*PSPTransaction, error)
	GetPSPTransactionByIdempotencyKey(ctx context.Context, provider string, key string) (*PSPTransaction, error)
	GetPSPTransactionsByInternalRef(ctx context.Context, internalRef string) ([]*PSPTransaction, error)
	UpdatePSPTransactionStatus(ctx context.Context, id uuid.UUID, status PSPStatus, pspTxID string, failureCode string, failureReason string, completedAt *time.Time) error

	RecordWebhookEvent(ctx context.Context, event *PSPWebhookRecord) error
	GetWebhookEvent(ctx context.Context, provider string, eventID string) (*PSPWebhookRecord, error)
	UpdateWebhookEventStatus(ctx context.Context, id uuid.UUID, status string, errorMessage string, processedAt *time.Time) error
}

// MemoryRepository provides thread-safe in-memory storage for PSP transactions and webhook events.
type MemoryRepository struct {
	mu           sync.RWMutex
	transactions map[uuid.UUID]*PSPTransaction
	txByPSPID    map[string]*PSPTransaction   // "provider:pspTxID" -> tx
	txByIdemp    map[string]*PSPTransaction   // "provider:idempKey" -> tx
	txByRef      map[string][]*PSPTransaction // internalRef -> txs
	webhooks     map[uuid.UUID]*PSPWebhookRecord
	whByEventID  map[string]*PSPWebhookRecord // "provider:eventID" -> wh
}

func NewMemoryRepository() *MemoryRepository {
	return &MemoryRepository{
		transactions: make(map[uuid.UUID]*PSPTransaction),
		txByPSPID:    make(map[string]*PSPTransaction),
		txByIdemp:    make(map[string]*PSPTransaction),
		txByRef:      make(map[string][]*PSPTransaction),
		webhooks:     make(map[uuid.UUID]*PSPWebhookRecord),
		whByEventID:  make(map[string]*PSPWebhookRecord),
	}
}

func (r *MemoryRepository) CreatePSPTransaction(ctx context.Context, tx *PSPTransaction) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	pspKey := tx.Provider + ":" + tx.PSPTransactionID
	if _, exists := r.txByPSPID[pspKey]; exists {
		return ErrDuplicatePSPTransaction
	}

	if tx.IdempotencyKey != "" {
		idempKey := tx.Provider + ":" + tx.IdempotencyKey
		if _, exists := r.txByIdemp[idempKey]; exists {
			return ErrDuplicatePSPTransaction
		}
		r.txByIdemp[idempKey] = tx
	}

	r.transactions[tx.ID] = tx
	r.txByPSPID[pspKey] = tx
	r.txByRef[tx.InternalReference] = append(r.txByRef[tx.InternalReference], tx)
	return nil
}

func (r *MemoryRepository) GetPSPTransaction(ctx context.Context, id uuid.UUID) (*PSPTransaction, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	tx, ok := r.transactions[id]
	if !ok {
		return nil, ErrPSPTransactionNotFound
	}
	return tx, nil
}

func (r *MemoryRepository) GetPSPTransactionByPSPTxID(ctx context.Context, provider string, pspTxID string) (*PSPTransaction, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	key := provider + ":" + pspTxID
	tx, ok := r.txByPSPID[key]
	if !ok {
		return nil, ErrPSPTransactionNotFound
	}
	return tx, nil
}

func (r *MemoryRepository) GetPSPTransactionByIdempotencyKey(ctx context.Context, provider string, key string) (*PSPTransaction, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	idempKey := provider + ":" + key
	tx, ok := r.txByIdemp[idempKey]
	if !ok {
		return nil, ErrPSPTransactionNotFound
	}
	return tx, nil
}

func (r *MemoryRepository) GetPSPTransactionsByInternalRef(ctx context.Context, internalRef string) ([]*PSPTransaction, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	txs, ok := r.txByRef[internalRef]
	if !ok {
		return []*PSPTransaction{}, nil
	}
	return txs, nil
}

func (r *MemoryRepository) UpdatePSPTransactionStatus(ctx context.Context, id uuid.UUID, status PSPStatus, pspTxID string, failureCode string, failureReason string, completedAt *time.Time) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	tx, ok := r.transactions[id]
	if !ok {
		return ErrPSPTransactionNotFound
	}

	tx.Status = status
	if pspTxID != "" {
		tx.PSPTransactionID = pspTxID
		r.txByPSPID[tx.Provider+":"+pspTxID] = tx
	}
	if failureCode != "" {
		tx.FailureCode = failureCode
	}
	if failureReason != "" {
		tx.FailureReason = failureReason
	}
	if completedAt != nil {
		tx.CompletedAt = completedAt
	}
	tx.UpdatedAt = time.Now().UTC()
	return nil
}

func (r *MemoryRepository) RecordWebhookEvent(ctx context.Context, event *PSPWebhookRecord) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	key := event.Provider + ":" + event.EventID
	if _, exists := r.whByEventID[key]; exists {
		return ErrWebhookAlreadyProcessed
	}

	r.webhooks[event.ID] = event
	r.whByEventID[key] = event
	return nil
}

func (r *MemoryRepository) GetWebhookEvent(ctx context.Context, provider string, eventID string) (*PSPWebhookRecord, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	key := provider + ":" + eventID
	event, ok := r.whByEventID[key]
	if !ok {
		return nil, ErrPSPTransactionNotFound
	}
	return event, nil
}

func (r *MemoryRepository) UpdateWebhookEventStatus(ctx context.Context, id uuid.UUID, status string, errorMessage string, processedAt *time.Time) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	wh, ok := r.webhooks[id]
	if !ok {
		return ErrPSPTransactionNotFound
	}
	wh.Status = status
	if errorMessage != "" {
		wh.ErrorMessage = errorMessage
	}
	if processedAt != nil {
		wh.ProcessedAt = processedAt
	}
	return nil
}

// PostgresRepository provides PostgreSQL persistence for PSP transactions and webhook events.
type PostgresRepository struct {
	pool *pgxpool.Pool
}

func NewPostgresRepository(pool *pgxpool.Pool) *PostgresRepository {
	return &PostgresRepository{pool: pool}
}

func (r *PostgresRepository) CreatePSPTransaction(ctx context.Context, tx *PSPTransaction) error {
	query := `
		INSERT INTO psp_transactions (
			id, provider, operation_type, internal_reference, psp_transaction_id,
			payment_intent_id, refund_id, settlement_id, amount, currency,
			status, idempotency_key, request_reference, response_reference,
			failure_code, failure_reason, created_at, updated_at, completed_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)
	`
	_, err := r.pool.Exec(ctx, query,
		tx.ID, tx.Provider, tx.OperationType, tx.InternalReference, tx.PSPTransactionID,
		tx.PaymentIntentID, tx.RefundID, tx.SettlementID, tx.Amount, tx.Currency,
		string(tx.Status), tx.IdempotencyKey, tx.RequestReference, tx.ResponseReference,
		tx.FailureCode, tx.FailureReason, tx.CreatedAt, tx.UpdatedAt, tx.CompletedAt,
	)
	return err
}

func (r *PostgresRepository) scanPSPTransaction(row interface {
	Scan(dest ...interface{}) error
}) (*PSPTransaction, error) {
	var tx PSPTransaction
	var payIntentID, refundID, settlementID, idempKey, reqRef, respRef, failCode, failReason sql.NullString
	var completedAt sql.NullTime
	var status string

	err := row.Scan(
		&tx.ID, &tx.Provider, &tx.OperationType, &tx.InternalReference, &tx.PSPTransactionID,
		&payIntentID, &refundID, &settlementID, &tx.Amount, &tx.Currency,
		&status, &idempKey, &reqRef, &respRef,
		&failCode, &failReason, &tx.CreatedAt, &tx.UpdatedAt, &completedAt,
	)
	if err != nil {
		return nil, ErrPSPTransactionNotFound
	}
	tx.Status = PSPStatus(status)
	if payIntentID.Valid {
		p, _ := uuid.Parse(payIntentID.String)
		tx.PaymentIntentID = &p
	}
	if refundID.Valid {
		p, _ := uuid.Parse(refundID.String)
		tx.RefundID = &p
	}
	if settlementID.Valid {
		p, _ := uuid.Parse(settlementID.String)
		tx.SettlementID = &p
	}
	if idempKey.Valid {
		tx.IdempotencyKey = idempKey.String
	}
	if reqRef.Valid {
		tx.RequestReference = reqRef.String
	}
	if respRef.Valid {
		tx.ResponseReference = respRef.String
	}
	if failCode.Valid {
		tx.FailureCode = failCode.String
	}
	if failReason.Valid {
		tx.FailureReason = failReason.String
	}
	if completedAt.Valid {
		tx.CompletedAt = &completedAt.Time
	}
	return &tx, nil
}

func (r *PostgresRepository) GetPSPTransaction(ctx context.Context, id uuid.UUID) (*PSPTransaction, error) {
	query := `
		SELECT id, provider, operation_type, internal_reference, psp_transaction_id,
		       payment_intent_id, refund_id, settlement_id, amount, currency,
		       status, idempotency_key, request_reference, response_reference,
		       failure_code, failure_reason, created_at, updated_at, completed_at
		FROM psp_transactions WHERE id = $1
	`
	return r.scanPSPTransaction(r.pool.QueryRow(ctx, query, id))
}

func (r *PostgresRepository) GetPSPTransactionByPSPTxID(ctx context.Context, provider string, pspTxID string) (*PSPTransaction, error) {
	query := `
		SELECT id, provider, operation_type, internal_reference, psp_transaction_id,
		       payment_intent_id, refund_id, settlement_id, amount, currency,
		       status, idempotency_key, request_reference, response_reference,
		       failure_code, failure_reason, created_at, updated_at, completed_at
		FROM psp_transactions WHERE provider = $1 AND psp_transaction_id = $2
	`
	return r.scanPSPTransaction(r.pool.QueryRow(ctx, query, provider, pspTxID))
}

func (r *PostgresRepository) GetPSPTransactionByIdempotencyKey(ctx context.Context, provider string, key string) (*PSPTransaction, error) {
	query := `
		SELECT id, provider, operation_type, internal_reference, psp_transaction_id,
		       payment_intent_id, refund_id, settlement_id, amount, currency,
		       status, idempotency_key, request_reference, response_reference,
		       failure_code, failure_reason, created_at, updated_at, completed_at
		FROM psp_transactions WHERE provider = $1 AND idempotency_key = $2
	`
	return r.scanPSPTransaction(r.pool.QueryRow(ctx, query, provider, key))
}

func (r *PostgresRepository) GetPSPTransactionsByInternalRef(ctx context.Context, internalRef string) ([]*PSPTransaction, error) {
	query := `
		SELECT id, provider, operation_type, internal_reference, psp_transaction_id,
		       payment_intent_id, refund_id, settlement_id, amount, currency,
		       status, idempotency_key, request_reference, response_reference,
		       failure_code, failure_reason, created_at, updated_at, completed_at
		FROM psp_transactions WHERE internal_reference = $1 ORDER BY created_at DESC
	`
	rows, err := r.pool.Query(ctx, query, internalRef)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*PSPTransaction
	for rows.Next() {
		tx, err := r.scanPSPTransaction(rows)
		if err != nil {
			return nil, err
		}
		result = append(result, tx)
	}
	return result, nil
}

func (r *PostgresRepository) UpdatePSPTransactionStatus(ctx context.Context, id uuid.UUID, status PSPStatus, pspTxID string, failureCode string, failureReason string, completedAt *time.Time) error {
	query := `
		UPDATE psp_transactions
		SET status = $1,
		    psp_transaction_id = CASE WHEN $2 != '' THEN $2 ELSE psp_transaction_id END,
		    failure_code = CASE WHEN $3 != '' THEN $3 ELSE failure_code END,
		    failure_reason = CASE WHEN $4 != '' THEN $4 ELSE failure_reason END,
		    completed_at = COALESCE($5, completed_at),
		    updated_at = NOW()
		WHERE id = $6
	`
	tag, err := r.pool.Exec(ctx, query, string(status), pspTxID, failureCode, failureReason, completedAt, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrPSPTransactionNotFound
	}
	return nil
}

func (r *PostgresRepository) RecordWebhookEvent(ctx context.Context, event *PSPWebhookRecord) error {
	query := `
		INSERT INTO psp_webhook_events (id, provider, event_id, event_type, payload, status, received_at, processed_at, error_message)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`
	_, err := r.pool.Exec(ctx, query,
		event.ID, event.Provider, event.EventID, event.EventType, event.Payload,
		event.Status, event.ReceivedAt, event.ProcessedAt, event.ErrorMessage,
	)
	return err
}

func (r *PostgresRepository) GetWebhookEvent(ctx context.Context, provider string, eventID string) (*PSPWebhookRecord, error) {
	query := `
		SELECT id, provider, event_id, event_type, payload, status, received_at, processed_at, error_message
		FROM psp_webhook_events WHERE provider = $1 AND event_id = $2
	`
	var wh PSPWebhookRecord
	var processedAt sql.NullTime
	var errMsg sql.NullString
	err := r.pool.QueryRow(ctx, query, provider, eventID).Scan(
		&wh.ID, &wh.Provider, &wh.EventID, &wh.EventType, &wh.Payload, &wh.Status,
		&wh.ReceivedAt, &processedAt, &errMsg,
	)
	if err != nil {
		return nil, ErrPSPTransactionNotFound
	}
	if processedAt.Valid {
		wh.ProcessedAt = &processedAt.Time
	}
	if errMsg.Valid {
		wh.ErrorMessage = errMsg.String
	}
	return &wh, nil
}

func (r *PostgresRepository) UpdateWebhookEventStatus(ctx context.Context, id uuid.UUID, status string, errorMessage string, processedAt *time.Time) error {
	query := `
		UPDATE psp_webhook_events
		SET status = $1, error_message = $2, processed_at = $3
		WHERE id = $4
	`
	_, err := r.pool.Exec(ctx, query, status, errorMessage, processedAt, id)
	return err
}
