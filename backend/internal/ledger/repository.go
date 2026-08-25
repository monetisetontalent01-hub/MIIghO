package ledger

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrAccountNotFound      = errors.New("ledger account not found")
	ErrInsufficientFunds    = errors.New("insufficient funds for transaction")
	ErrImbalancedEntry      = errors.New("journal entry debits do not match credits (double-entry violation)")
	ErrDuplicateIdempotency = errors.New("idempotency key already used")
	ErrIdempotencyConflict  = errors.New("idempotency key conflict: payload does not match existing transaction")
	ErrInvalidAmount        = errors.New("transaction amount must be strictly greater than zero")
	ErrInvalidCurrency      = errors.New("invalid or mismatched currency")
)

// Repository defines data access methods for double-entry ledger.
type Repository interface {
	CreateAccount(ctx context.Context, account *LedgerAccount) error
	GetAccount(ctx context.Context, accountID uuid.UUID) (*LedgerAccount, error)
	GetAccountByUserID(ctx context.Context, userID uuid.UUID, currency string) (*LedgerAccount, error)
	GetSystemAccount(ctx context.Context, name string, currency string, accType AccountType) (*LedgerAccount, error)

	// Atomic transaction posting
	PostJournalEntry(ctx context.Context, entry *JournalEntry, postings []*LedgerPosting, idempotencyKey string) error

	GetBalance(ctx context.Context, accountID uuid.UUID) (int64, error)
	GetStatement(ctx context.Context, accountID uuid.UUID, from, to time.Time, limit int, offset int) ([]*LedgerPosting, error)
	GetJournalEntry(ctx context.Context, entryID uuid.UUID) (*JournalEntry, []*LedgerPosting, error)
	ListJournalEntries(ctx context.Context, limit int, offset int) ([]*JournalEntry, error)
	GetPostingsForEntry(ctx context.Context, entryID uuid.UUID) ([]*LedgerPosting, error)
	GetPostingsForAccount(ctx context.Context, accountID uuid.UUID, limit int, offset int) ([]*LedgerPosting, error)
	CheckIdempotency(ctx context.Context, key string) (bool, *JournalEntry, error)
}

// MemoryRepository is a high-performance in-memory double-entry ledger repository with ACID-like locking.
// Ideal for sandbox simulation and fast unit testing.
type MemoryRepository struct {
	mu             sync.RWMutex
	accounts       map[uuid.UUID]*LedgerAccount
	userAccounts   map[string]uuid.UUID // "userID:currency" -> accountID
	sysAccounts    map[string]uuid.UUID // "name:currency" -> accountID
	entries        map[uuid.UUID]*JournalEntry
	orderedEntries []*JournalEntry
	postings       map[uuid.UUID][]*LedgerPosting // entryID -> postings
	idempotency    map[string]uuid.UUID           // key -> entryID
}

func NewMemoryRepository() *MemoryRepository {
	repo := &MemoryRepository{
		accounts:       make(map[uuid.UUID]*LedgerAccount),
		userAccounts:   make(map[string]uuid.UUID),
		sysAccounts:    make(map[string]uuid.UUID),
		entries:        make(map[uuid.UUID]*JournalEntry),
		orderedEntries: make([]*JournalEntry, 0),
		postings:       make(map[uuid.UUID][]*LedgerPosting),
		idempotency:    make(map[string]uuid.UUID),
	}

	// Seed system accounts for Sandbox
	repo.seedSystemAccounts()
	return repo
}

func (r *MemoryRepository) seedSystemAccounts() {
	currencies := []string{"FCFA", "XOF", "USD", "EUR", "NGN", "KES"}
	for _, c := range currencies {
		// MoMo Settlement Pool (Liability)
		momoAcc := &LedgerAccount{
			ID:          uuid.New(),
			UserID:      nil,
			Currency:    c,
			AccountType: Liability,
			Name:        "MoMo Settlement Pool",
			CreatedAt:   time.Now().UTC(),
		}
		r.accounts[momoAcc.ID] = momoAcc
		r.sysAccounts[fmt.Sprintf("MoMo Settlement Pool:%s", c)] = momoAcc.ID

		// Platform Fee Account (Revenue)
		feeAcc := &LedgerAccount{
			ID:          uuid.New(),
			UserID:      nil,
			Currency:    c,
			AccountType: Revenue,
			Name:        "Platform Fee Account",
			CreatedAt:   time.Now().UTC(),
		}
		r.accounts[feeAcc.ID] = feeAcc
		r.sysAccounts[fmt.Sprintf("Platform Fee Account:%s", c)] = feeAcc.ID

		// Marketplace Escrow Account (Liability)
		escrowAcc := &LedgerAccount{
			ID:          uuid.New(),
			UserID:      nil,
			Currency:    c,
			AccountType: Liability,
			Name:        "Marketplace Escrow Account",
			CreatedAt:   time.Now().UTC(),
		}
		r.accounts[escrowAcc.ID] = escrowAcc
		r.sysAccounts[fmt.Sprintf("Marketplace Escrow Account:%s", c)] = escrowAcc.ID
	}
}

func (r *MemoryRepository) CreateAccount(ctx context.Context, account *LedgerAccount) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if account.UserID != nil {
		key := fmt.Sprintf("%s:%s", account.UserID.String(), account.Currency)
		if existingID, exists := r.userAccounts[key]; exists {
			account.ID = existingID
			return nil
		}
	} else {
		key := fmt.Sprintf("%s:%s", account.Name, account.Currency)
		if existingID, exists := r.sysAccounts[key]; exists {
			account.ID = existingID
			return nil
		}
	}

	if account.ID == uuid.Nil {
		account.ID = uuid.New()
	}
	if account.CreatedAt.IsZero() {
		account.CreatedAt = time.Now().UTC()
	}

	r.accounts[account.ID] = account

	if account.UserID != nil {
		key := fmt.Sprintf("%s:%s", account.UserID.String(), account.Currency)
		r.userAccounts[key] = account.ID
	} else {
		key := fmt.Sprintf("%s:%s", account.Name, account.Currency)
		r.sysAccounts[key] = account.ID
	}

	return nil
}

func (r *MemoryRepository) GetAccount(ctx context.Context, accountID uuid.UUID) (*LedgerAccount, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	acc, ok := r.accounts[accountID]
	if !ok {
		return nil, ErrAccountNotFound
	}
	return acc, nil
}

func (r *MemoryRepository) GetAccountByUserID(ctx context.Context, userID uuid.UUID, currency string) (*LedgerAccount, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	key := fmt.Sprintf("%s:%s", userID.String(), currency)
	accID, ok := r.userAccounts[key]
	if !ok {
		return nil, ErrAccountNotFound
	}
	return r.accounts[accID], nil
}

func (r *MemoryRepository) GetSystemAccount(ctx context.Context, name string, currency string, accType AccountType) (*LedgerAccount, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	key := fmt.Sprintf("%s:%s", name, currency)
	if accID, ok := r.sysAccounts[key]; ok {
		return r.accounts[accID], nil
	}

	// Create if not exists
	acc := &LedgerAccount{
		ID:          uuid.New(),
		UserID:      nil,
		Currency:    currency,
		AccountType: accType,
		Name:        name,
		CreatedAt:   time.Now().UTC(),
	}
	r.accounts[acc.ID] = acc
	r.sysAccounts[key] = acc.ID
	return acc, nil
}

func (r *MemoryRepository) CheckIdempotency(ctx context.Context, key string) (bool, *JournalEntry, error) {
	if key == "" {
		return false, nil, nil
	}
	r.mu.RLock()
	defer r.mu.RUnlock()

	if entryID, exists := r.idempotency[key]; exists {
		if entry, ok := r.entries[entryID]; ok {
			return true, entry, nil
		}
	}
	return false, nil, nil
}

func (r *MemoryRepository) PostJournalEntry(ctx context.Context, entry *JournalEntry, postings []*LedgerPosting, idempotencyKey string) error {
	if len(postings) < 2 {
		return errors.New("a journal entry must contain at least 2 postings")
	}

	// Invariant check: SUM(Debit) == SUM(Credit)
	var sumDebits int64
	var sumCredits int64

	for _, p := range postings {
		if p.Amount <= 0 {
			return ErrInvalidAmount
		}
		if p.IsCredit {
			sumCredits += p.Amount
		} else {
			sumDebits += p.Amount
		}
	}

	if sumDebits != sumCredits {
		return fmt.Errorf("%w: debits=%d, credits=%d", ErrImbalancedEntry, sumDebits, sumCredits)
	}

	r.mu.Lock()
	defer r.mu.Unlock()

	// Check Idempotency Key
	if idempotencyKey != "" {
		if _, exists := r.idempotency[idempotencyKey]; exists {
			return ErrDuplicateIdempotency
		}
	}

	// Verify all accounts exist
	for _, p := range postings {
		if _, ok := r.accounts[p.AccountID]; !ok {
			return fmt.Errorf("%w: account_id=%s", ErrAccountNotFound, p.AccountID)
		}
	}

	// Persist entry
	if entry.ID == uuid.Nil {
		entry.ID = uuid.New()
	}
	if entry.CreatedAt.IsZero() {
		entry.CreatedAt = time.Now().UTC()
	}

	r.entries[entry.ID] = entry
	r.orderedEntries = append([]*JournalEntry{entry}, r.orderedEntries...) // Prepend for reverse chronological order

	entryPostings := make([]*LedgerPosting, 0, len(postings))
	for _, p := range postings {
		if p.ID == uuid.Nil {
			p.ID = uuid.New()
		}
		p.JournalEntryID = entry.ID
		if p.CreatedAt.IsZero() {
			p.CreatedAt = entry.CreatedAt
		}
		entryPostings = append(entryPostings, p)
	}
	r.postings[entry.ID] = entryPostings

	if idempotencyKey != "" {
		r.idempotency[idempotencyKey] = entry.ID
	}

	return nil
}

// GetBalance derives the balance strictly by summing postings:
// For Asset accounts: Balance = SUM(Debits) - SUM(Credits)
// For Liability/Equity/Revenue accounts: Balance = SUM(Credits) - SUM(Debits)
func (r *MemoryRepository) GetBalance(ctx context.Context, accountID uuid.UUID) (int64, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	account, ok := r.accounts[accountID]
	if !ok {
		return 0, ErrAccountNotFound
	}

	var sumDebits int64
	var sumCredits int64

	for _, pList := range r.postings {
		for _, p := range pList {
			if p.AccountID == accountID {
				if p.IsCredit {
					sumCredits += p.Amount
				} else {
					sumDebits += p.Amount
				}
			}
		}
	}

	if account.AccountType == Asset || account.AccountType == Expense {
		return sumDebits - sumCredits, nil
	}
	return sumCredits - sumDebits, nil
}

func (r *MemoryRepository) GetStatement(ctx context.Context, accountID uuid.UUID, from, to time.Time, limit int, offset int) ([]*LedgerPosting, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var result []*LedgerPosting
	for _, pList := range r.postings {
		for _, p := range pList {
			if p.AccountID == accountID {
				if (!from.IsZero() && p.CreatedAt.Before(from)) || (!to.IsZero() && p.CreatedAt.After(to)) {
					continue
				}
				result = append(result, p)
			}
		}
	}

	if offset >= len(result) {
		return []*LedgerPosting{}, nil
	}
	end := offset + limit
	if end > len(result) {
		end = len(result)
	}
	return result[offset:end], nil
}

func (r *MemoryRepository) GetJournalEntry(ctx context.Context, entryID uuid.UUID) (*JournalEntry, []*LedgerPosting, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	entry, ok := r.entries[entryID]
	if !ok {
		return nil, nil, errors.New("journal entry not found")
	}
	postings := r.postings[entryID]
	return entry, postings, nil
}

func (r *MemoryRepository) ListJournalEntries(ctx context.Context, limit int, offset int) ([]*JournalEntry, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	if offset >= len(r.orderedEntries) {
		return []*JournalEntry{}, nil
	}
	end := offset + limit
	if end > len(r.orderedEntries) {
		end = len(r.orderedEntries)
	}
	return r.orderedEntries[offset:end], nil
}

func (r *MemoryRepository) GetPostingsForEntry(ctx context.Context, entryID uuid.UUID) ([]*LedgerPosting, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	postings, ok := r.postings[entryID]
	if !ok {
		return []*LedgerPosting{}, nil
	}
	return postings, nil
}

func (r *MemoryRepository) GetPostingsForAccount(ctx context.Context, accountID uuid.UUID, limit int, offset int) ([]*LedgerPosting, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var result []*LedgerPosting
	for _, entry := range r.orderedEntries {
		if pList, ok := r.postings[entry.ID]; ok {
			for _, p := range pList {
				if p.AccountID == accountID {
					result = append(result, p)
				}
			}
		}
	}

	if offset >= len(result) {
		return []*LedgerPosting{}, nil
	}
	end := offset + limit
	if end > len(result) {
		end = len(result)
	}
	return result[offset:end], nil
}

// PostgresRepository provides PostgreSQL persistence for production
type PostgresRepository struct {
	pool *pgxpool.Pool
}

func NewPostgresRepository(pool *pgxpool.Pool) *PostgresRepository {
	return &PostgresRepository{pool: pool}
}

func (r *PostgresRepository) CreateAccount(ctx context.Context, account *LedgerAccount) error {
	if account.ID == uuid.Nil {
		account.ID = uuid.New()
	}
	if account.CreatedAt.IsZero() {
		account.CreatedAt = time.Now().UTC()
	}

	query := `
		INSERT INTO ledger_accounts (id, user_id, type, currency, created_at)
		VALUES ($1, $2, $3, $4, $5)
	`
	_, err := r.pool.Exec(ctx, query, account.ID, account.UserID, string(account.AccountType), account.Currency, account.CreatedAt)
	return err
}

func (r *PostgresRepository) GetAccount(ctx context.Context, accountID uuid.UUID) (*LedgerAccount, error) {
	query := `
		SELECT id, user_id, type, currency, created_at
		FROM ledger_accounts
		WHERE id = $1
	`
	var acc LedgerAccount
	var accType string
	err := r.pool.QueryRow(ctx, query, accountID).Scan(&acc.ID, &acc.UserID, &accType, &acc.Currency, &acc.CreatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrAccountNotFound
		}
		return nil, err
	}
	acc.AccountType = AccountType(accType)
	return &acc, nil
}

func (r *PostgresRepository) GetAccountByUserID(ctx context.Context, userID uuid.UUID, currency string) (*LedgerAccount, error) {
	query := `
		SELECT id, user_id, type, currency, created_at
		FROM ledger_accounts
		WHERE user_id = $1 AND currency = $2
		LIMIT 1
	`
	var acc LedgerAccount
	var accType string
	err := r.pool.QueryRow(ctx, query, userID, currency).Scan(&acc.ID, &acc.UserID, &accType, &acc.Currency, &acc.CreatedAt)
	if err != nil {
		return nil, ErrAccountNotFound
	}
	acc.AccountType = AccountType(accType)
	return &acc, nil
}

func (r *PostgresRepository) GetSystemAccount(ctx context.Context, name string, currency string, accType AccountType) (*LedgerAccount, error) {
	query := `
		SELECT id, user_id, type, currency, created_at
		FROM ledger_accounts
		WHERE user_id IS NULL AND type = $1 AND currency = $2
		LIMIT 1
	`
	var acc LedgerAccount
	var typeStr string
	err := r.pool.QueryRow(ctx, query, string(accType), currency).Scan(&acc.ID, &acc.UserID, &typeStr, &acc.Currency, &acc.CreatedAt)
	if err == nil {
		acc.AccountType = AccountType(typeStr)
		acc.Name = name
		return &acc, nil
	}

	// Create system account if missing
	newAcc := &LedgerAccount{
		ID:          uuid.New(),
		UserID:      nil,
		Currency:    currency,
		AccountType: accType,
		Name:        name,
		CreatedAt:   time.Now().UTC(),
	}
	if err := r.CreateAccount(ctx, newAcc); err != nil {
		return nil, err
	}
	return newAcc, nil
}

func (r *PostgresRepository) CheckIdempotency(ctx context.Context, key string) (bool, *JournalEntry, error) {
	if key == "" {
		return false, nil, nil
	}
	query := `
		SELECT id, description, reference_id, created_at
		FROM journal_entries
		WHERE reference_id = $1
		LIMIT 1
	`
	var entry JournalEntry
	err := r.pool.QueryRow(ctx, query, key).Scan(&entry.ID, &entry.Description, &entry.ReferenceID, &entry.CreatedAt)
	if err != nil {
		return false, nil, nil
	}
	return true, &entry, nil
}

func (r *PostgresRepository) PostJournalEntry(ctx context.Context, entry *JournalEntry, postings []*LedgerPosting, idempotencyKey string) error {
	if len(postings) < 2 {
		return errors.New("a journal entry must contain at least 2 postings")
	}

	var sumDebits int64
	var sumCredits int64
	for _, p := range postings {
		if p.Amount <= 0 {
			return ErrInvalidAmount
		}
		if p.IsCredit {
			sumCredits += p.Amount
		} else {
			sumDebits += p.Amount
		}
	}
	if sumDebits != sumCredits {
		return fmt.Errorf("%w: debits=%d, credits=%d", ErrImbalancedEntry, sumDebits, sumCredits)
	}

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	if entry.ID == uuid.Nil {
		entry.ID = uuid.New()
	}
	if entry.CreatedAt.IsZero() {
		entry.CreatedAt = time.Now().UTC()
	}

	entryQuery := `
		INSERT INTO journal_entries (id, description, reference_id, created_at)
		VALUES ($1, $2, $3, $4)
	`
	ref := entry.ReferenceID
	if idempotencyKey != "" {
		ref = idempotencyKey
	}
	_, err = tx.Exec(ctx, entryQuery, entry.ID, entry.Description, ref, entry.CreatedAt)
	if err != nil {
		return err
	}

	postingQuery := `
		INSERT INTO ledger_postings (id, journal_id, account_id, amount, direction, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	for _, p := range postings {
		if p.ID == uuid.Nil {
			p.ID = uuid.New()
		}
		direction := "DR"
		if p.IsCredit {
			direction = "CR"
		}
		_, err = tx.Exec(ctx, postingQuery, p.ID, entry.ID, p.AccountID, p.Amount, direction, entry.CreatedAt)
		if err != nil {
			return err
		}
	}

	return tx.Commit(ctx)
}

func (r *PostgresRepository) GetBalance(ctx context.Context, accountID uuid.UUID) (int64, error) {
	acc, err := r.GetAccount(ctx, accountID)
	if err != nil {
		return 0, err
	}

	query := `
		SELECT 
			COALESCE(SUM(CASE WHEN direction = 'DR' THEN amount ELSE 0 END), 0) as debits,
			COALESCE(SUM(CASE WHEN direction = 'CR' THEN amount ELSE 0 END), 0) as credits
		FROM ledger_postings
		WHERE account_id = $1
	`
	var debits, credits int64
	err = r.pool.QueryRow(ctx, query, accountID).Scan(&debits, &credits)
	if err != nil {
		return 0, err
	}

	if acc.AccountType == Asset || acc.AccountType == Expense {
		return debits - credits, nil
	}
	return credits - debits, nil
}

func (r *PostgresRepository) GetStatement(ctx context.Context, accountID uuid.UUID, from, to time.Time, limit int, offset int) ([]*LedgerPosting, error) {
	query := `
		SELECT id, journal_id, account_id, amount, direction, created_at
		FROM ledger_postings
		WHERE account_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.pool.Query(ctx, query, accountID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var postings []*LedgerPosting
	for rows.Next() {
		var p LedgerPosting
		var dir string
		if err := rows.Scan(&p.ID, &p.JournalEntryID, &p.AccountID, &p.Amount, &dir, &p.CreatedAt); err != nil {
			return nil, err
		}
		p.IsCredit = (dir == "CR")
		postings = append(postings, &p)
	}
	return postings, nil
}

func (r *PostgresRepository) GetJournalEntry(ctx context.Context, entryID uuid.UUID) (*JournalEntry, []*LedgerPosting, error) {
	query := `
		SELECT id, description, reference_id, created_at
		FROM journal_entries
		WHERE id = $1
	`
	var entry JournalEntry
	err := r.pool.QueryRow(ctx, query, entryID).Scan(&entry.ID, &entry.Description, &entry.ReferenceID, &entry.CreatedAt)
	if err != nil {
		return nil, nil, err
	}

	postings, err := r.GetPostingsForEntry(ctx, entryID)
	if err != nil {
		return nil, nil, err
	}
	return &entry, postings, nil
}

func (r *PostgresRepository) ListJournalEntries(ctx context.Context, limit int, offset int) ([]*JournalEntry, error) {
	query := `
		SELECT id, description, reference_id, created_at
		FROM journal_entries
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.pool.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var entries []*JournalEntry
	for rows.Next() {
		var e JournalEntry
		if err := rows.Scan(&e.ID, &e.Description, &e.ReferenceID, &e.CreatedAt); err != nil {
			return nil, err
		}
		entries = append(entries, &e)
	}
	return entries, nil
}

func (r *PostgresRepository) GetPostingsForEntry(ctx context.Context, entryID uuid.UUID) ([]*LedgerPosting, error) {
	query := `
		SELECT id, journal_id, account_id, amount, direction, created_at
		FROM ledger_postings
		WHERE journal_id = $1
		ORDER BY created_at ASC
	`
	rows, err := r.pool.Query(ctx, query, entryID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var postings []*LedgerPosting
	for rows.Next() {
		var p LedgerPosting
		var dir string
		if err := rows.Scan(&p.ID, &p.JournalEntryID, &p.AccountID, &p.Amount, &dir, &p.CreatedAt); err != nil {
			return nil, err
		}
		p.IsCredit = (dir == "CR")
		postings = append(postings, &p)
	}
	return postings, nil
}

func (r *PostgresRepository) GetPostingsForAccount(ctx context.Context, accountID uuid.UUID, limit int, offset int) ([]*LedgerPosting, error) {
	return r.GetStatement(ctx, accountID, time.Time{}, time.Time{}, limit, offset)
}
