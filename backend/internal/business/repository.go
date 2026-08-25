package business

import (
	"context"
	"database/sql"
	"errors"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/miigho/miigho/internal/ledger"
)

// Repository defines data access operations for MÏÏghO Business Core.
type Repository interface {
	CreateBusinessWithAccountAndOwner(ctx context.Context, business *Business, account *BusinessAccount, member *BusinessMember, ledgerAcc *ledger.LedgerAccount) error
	GetBusiness(ctx context.Context, id uuid.UUID) (*Business, error)
	ListBusinessesForUser(ctx context.Context, userID uuid.UUID) ([]*BusinessSummary, error)
	UpdateBusiness(ctx context.Context, business *Business) error
	AddMember(ctx context.Context, member *BusinessMember) error
	GetMember(ctx context.Context, businessID, userID uuid.UUID) (*BusinessMember, error)
	GetMemberByID(ctx context.Context, memberID uuid.UUID) (*BusinessMember, error)
	GetMembers(ctx context.Context, businessID uuid.UUID) ([]*BusinessMember, error)
	UpdateMember(ctx context.Context, member *BusinessMember) error
	RemoveMember(ctx context.Context, businessID, memberID uuid.UUID) error
	GetBusinessAccount(ctx context.Context, businessID uuid.UUID) (*BusinessAccount, error)
	GetBusinessAccountByLedgerID(ctx context.Context, ledgerAccountID uuid.UUID) (*BusinessAccount, error)
}

// MemoryBusinessRepository is an in-memory repository for sandbox and unit testing with full ACID-like locking.
type MemoryBusinessRepository struct {
	mu         sync.RWMutex
	ledgerRepo ledger.Repository
	businesses map[uuid.UUID]*Business
	members    map[uuid.UUID]*BusinessMember                  // memberID -> member
	bizMembers map[uuid.UUID]map[uuid.UUID]*BusinessMember    // bizID -> userID -> member
	accounts   map[uuid.UUID]*BusinessAccount                 // bizID -> account
	ledgerMap  map[uuid.UUID]*BusinessAccount                 // ledgerAccID -> account
}

func NewMemoryBusinessRepository(ledgerRepo ledger.Repository) *MemoryBusinessRepository {
	return &MemoryBusinessRepository{
		ledgerRepo: ledgerRepo,
		businesses: make(map[uuid.UUID]*Business),
		members:    make(map[uuid.UUID]*BusinessMember),
		bizMembers: make(map[uuid.UUID]map[uuid.UUID]*BusinessMember),
		accounts:   make(map[uuid.UUID]*BusinessAccount),
		ledgerMap:  make(map[uuid.UUID]*BusinessAccount),
	}
}

func (r *MemoryBusinessRepository) CreateBusinessWithAccountAndOwner(
	ctx context.Context,
	business *Business,
	account *BusinessAccount,
	member *BusinessMember,
	ledgerAcc *ledger.LedgerAccount,
) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	// 1. Create Ledger Account first
	if err := r.ledgerRepo.CreateAccount(ctx, ledgerAcc); err != nil {
		return err
	}

	// 2. Persist Business
	if business.ID == uuid.Nil {
		business.ID = uuid.New()
	}
	now := time.Now().UTC()
	if business.CreatedAt.IsZero() {
		business.CreatedAt = now
	}
	business.UpdatedAt = now
	r.businesses[business.ID] = business

	// 3. Persist Business Account
	if account.ID == uuid.Nil {
		account.ID = uuid.New()
	}
	account.BusinessID = business.ID
	account.LedgerAccountID = ledgerAcc.ID
	account.CreatedAt = now
	account.UpdatedAt = now
	r.accounts[business.ID] = account
	r.ledgerMap[ledgerAcc.ID] = account

	// 4. Persist Owner Member
	if member.ID == uuid.Nil {
		member.ID = uuid.New()
	}
	member.BusinessID = business.ID
	member.CreatedAt = now
	member.UpdatedAt = now
	r.members[member.ID] = member

	if _, ok := r.bizMembers[business.ID]; !ok {
		r.bizMembers[business.ID] = make(map[uuid.UUID]*BusinessMember)
	}
	r.bizMembers[business.ID][member.UserID] = member

	return nil
}

func (r *MemoryBusinessRepository) GetBusiness(ctx context.Context, id uuid.UUID) (*Business, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	b, ok := r.businesses[id]
	if !ok {
		return nil, ErrBusinessNotFound
	}
	return b, nil
}

func (r *MemoryBusinessRepository) ListBusinessesForUser(ctx context.Context, userID uuid.UUID) ([]*BusinessSummary, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var summaries []*BusinessSummary
	for bizID, userMap := range r.bizMembers {
		if member, ok := userMap[userID]; ok && member.Status == MemberStatusActive {
			biz, ok := r.businesses[bizID]
			if !ok || biz.Status == StatusClosed {
				continue
			}

			var balance int64
			if acc, ok := r.accounts[bizID]; ok {
				bal, err := r.ledgerRepo.GetBalance(ctx, acc.LedgerAccountID)
				if err == nil {
					balance = bal
				}
			}

			summaries = append(summaries, &BusinessSummary{
				Business:         biz,
				UserRole:         member.Role,
				AvailableBalance: balance,
				Currency:         biz.Currency,
			})
		}
	}
	return summaries, nil
}

func (r *MemoryBusinessRepository) UpdateBusiness(ctx context.Context, business *Business) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, ok := r.businesses[business.ID]; !ok {
		return ErrBusinessNotFound
	}
	business.UpdatedAt = time.Now().UTC()
	r.businesses[business.ID] = business
	return nil
}

func (r *MemoryBusinessRepository) AddMember(ctx context.Context, member *BusinessMember) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, ok := r.businesses[member.BusinessID]; !ok {
		return ErrBusinessNotFound
	}

	if userMap, ok := r.bizMembers[member.BusinessID]; ok {
		if _, exists := userMap[member.UserID]; exists {
			return ErrDuplicateMember
		}
	} else {
		r.bizMembers[member.BusinessID] = make(map[uuid.UUID]*BusinessMember)
	}

	if member.ID == uuid.Nil {
		member.ID = uuid.New()
	}
	now := time.Now().UTC()
	member.CreatedAt = now
	member.UpdatedAt = now

	r.members[member.ID] = member
	r.bizMembers[member.BusinessID][member.UserID] = member
	return nil
}

func (r *MemoryBusinessRepository) GetMember(ctx context.Context, businessID, userID uuid.UUID) (*BusinessMember, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	if userMap, ok := r.bizMembers[businessID]; ok {
		if member, exists := userMap[userID]; exists {
			return member, nil
		}
	}
	return nil, ErrMemberNotFound
}

func (r *MemoryBusinessRepository) GetMemberByID(ctx context.Context, memberID uuid.UUID) (*BusinessMember, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	m, ok := r.members[memberID]
	if !ok {
		return nil, ErrMemberNotFound
	}
	return m, nil
}

func (r *MemoryBusinessRepository) GetMembers(ctx context.Context, businessID uuid.UUID) ([]*BusinessMember, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var result []*BusinessMember
	if userMap, ok := r.bizMembers[businessID]; ok {
		for _, m := range userMap {
			result = append(result, m)
		}
	}
	return result, nil
}

func (r *MemoryBusinessRepository) UpdateMember(ctx context.Context, member *BusinessMember) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, ok := r.members[member.ID]; !ok {
		return ErrMemberNotFound
	}
	member.UpdatedAt = time.Now().UTC()
	r.members[member.ID] = member
	if userMap, ok := r.bizMembers[member.BusinessID]; ok {
		userMap[member.UserID] = member
	}
	return nil
}

func (r *MemoryBusinessRepository) RemoveMember(ctx context.Context, businessID, memberID uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	m, ok := r.members[memberID]
	if !ok || m.BusinessID != businessID {
		return ErrMemberNotFound
	}

	delete(r.members, memberID)
	if userMap, ok := r.bizMembers[businessID]; ok {
		delete(userMap, m.UserID)
	}
	return nil
}

func (r *MemoryBusinessRepository) GetBusinessAccount(ctx context.Context, businessID uuid.UUID) (*BusinessAccount, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	acc, ok := r.accounts[businessID]
	if !ok {
		return nil, ErrBusinessAccountNotFound
	}
	return acc, nil
}

func (r *MemoryBusinessRepository) GetBusinessAccountByLedgerID(ctx context.Context, ledgerAccountID uuid.UUID) (*BusinessAccount, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	acc, ok := r.ledgerMap[ledgerAccountID]
	if !ok {
		return nil, ErrBusinessAccountNotFound
	}
	return acc, nil
}

// PostgresBusinessRepository provides PostgreSQL persistence for MÏÏghO Business Core.
type PostgresBusinessRepository struct {
	pool       *pgxpool.Pool
	ledgerRepo ledger.Repository
}

func NewPostgresBusinessRepository(pool *pgxpool.Pool, ledgerRepo ledger.Repository) *PostgresBusinessRepository {
	return &PostgresBusinessRepository{
		pool:       pool,
		ledgerRepo: ledgerRepo,
	}
}

func (r *PostgresBusinessRepository) CreateBusinessWithAccountAndOwner(
	ctx context.Context,
	business *Business,
	account *BusinessAccount,
	member *BusinessMember,
	ledgerAcc *ledger.LedgerAccount,
) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// 1. Create Ledger Account
	if ledgerAcc.ID == uuid.Nil {
		ledgerAcc.ID = uuid.New()
	}
	if ledgerAcc.CreatedAt.IsZero() {
		ledgerAcc.CreatedAt = time.Now().UTC()
	}
	ledgerQuery := `
		INSERT INTO ledger_accounts (id, user_id, type, currency, name, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err = tx.Exec(ctx, ledgerQuery, ledgerAcc.ID, ledgerAcc.UserID, string(ledgerAcc.AccountType), ledgerAcc.Currency, ledgerAcc.Name, ledgerAcc.CreatedAt)
	if err != nil {
		return err
	}

	// 2. Insert Business
	if business.ID == uuid.Nil {
		business.ID = uuid.New()
	}
	now := time.Now().UTC()
	if business.CreatedAt.IsZero() {
		business.CreatedAt = now
	}
	business.UpdatedAt = now

	bizQuery := `
		INSERT INTO businesses (id, owner_user_id, legal_name, display_name, business_type, status, phone, email, country, currency, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`
	_, err = tx.Exec(ctx, bizQuery, business.ID, business.OwnerUserID, business.LegalName, business.DisplayName, business.BusinessType, string(business.Status), business.Phone, business.Email, business.Country, business.Currency, business.CreatedAt, business.UpdatedAt)
	if err != nil {
		return err
	}

	// 3. Insert Business Account
	if account.ID == uuid.Nil {
		account.ID = uuid.New()
	}
	account.BusinessID = business.ID
	account.LedgerAccountID = ledgerAcc.ID
	account.CreatedAt = now
	account.UpdatedAt = now

	accQuery := `
		INSERT INTO business_accounts (id, business_id, ledger_account_id, currency, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err = tx.Exec(ctx, accQuery, account.ID, account.BusinessID, account.LedgerAccountID, account.Currency, string(account.Status), account.CreatedAt, account.UpdatedAt)
	if err != nil {
		return err
	}

	// 4. Insert Owner Member
	if member.ID == uuid.Nil {
		member.ID = uuid.New()
	}
	member.BusinessID = business.ID
	member.CreatedAt = now
	member.UpdatedAt = now

	memberQuery := `
		INSERT INTO business_members (id, business_id, user_id, role, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err = tx.Exec(ctx, memberQuery, member.ID, member.BusinessID, member.UserID, string(member.Role), string(member.Status), member.CreatedAt, member.UpdatedAt)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}

func (r *PostgresBusinessRepository) GetBusiness(ctx context.Context, id uuid.UUID) (*Business, error) {
	query := `
		SELECT id, owner_user_id, legal_name, display_name, business_type, status, phone, email, country, currency, created_at, updated_at
		FROM businesses
		WHERE id = $1
	`
	var b Business
	var status string
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&b.ID, &b.OwnerUserID, &b.LegalName, &b.DisplayName, &b.BusinessType, &status, &b.Phone, &b.Email, &b.Country, &b.Currency, &b.CreatedAt, &b.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrBusinessNotFound
		}
		return nil, err
	}
	b.Status = BusinessStatus(status)
	return &b, nil
}

func (r *PostgresBusinessRepository) ListBusinessesForUser(ctx context.Context, userID uuid.UUID) ([]*BusinessSummary, error) {
	query := `
		SELECT b.id, b.owner_user_id, b.legal_name, b.display_name, b.business_type, b.status, b.phone, b.email, b.country, b.currency, b.created_at, b.updated_at,
		       bm.role, ba.ledger_account_id
		FROM businesses b
		INNER JOIN business_members bm ON b.id = bm.business_id
		LEFT JOIN business_accounts ba ON b.id = ba.business_id
		WHERE bm.user_id = $1 AND bm.status = 'ACTIVE' AND b.status != 'CLOSED'
		ORDER BY b.created_at DESC
	`
	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var summaries []*BusinessSummary
	for rows.Next() {
		var b Business
		var status, role string
		var ledgerAccID *uuid.UUID
		err := rows.Scan(
			&b.ID, &b.OwnerUserID, &b.LegalName, &b.DisplayName, &b.BusinessType, &status, &b.Phone, &b.Email, &b.Country, &b.Currency, &b.CreatedAt, &b.UpdatedAt,
			&role, &ledgerAccID,
		)
		if err != nil {
			return nil, err
		}
		b.Status = BusinessStatus(status)

		var balance int64
		if ledgerAccID != nil {
			bal, err := r.ledgerRepo.GetBalance(ctx, *ledgerAccID)
			if err == nil {
				balance = bal
			}
		}

		summaries = append(summaries, &BusinessSummary{
			Business:         &b,
			UserRole:         MemberRole(role),
			AvailableBalance: balance,
			Currency:         b.Currency,
		})
	}

	return summaries, nil
}

func (r *PostgresBusinessRepository) UpdateBusiness(ctx context.Context, business *Business) error {
	business.UpdatedAt = time.Now().UTC()
	query := `
		UPDATE businesses
		SET display_name = $1, business_type = $2, status = $3, phone = $4, email = $5, updated_at = $6
		WHERE id = $7
	`
	tag, err := r.pool.Exec(ctx, query, business.DisplayName, business.BusinessType, string(business.Status), business.Phone, business.Email, business.UpdatedAt, business.ID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrBusinessNotFound
	}
	return nil
}

func (r *PostgresBusinessRepository) AddMember(ctx context.Context, member *BusinessMember) error {
	if member.ID == uuid.Nil {
		member.ID = uuid.New()
	}
	now := time.Now().UTC()
	member.CreatedAt = now
	member.UpdatedAt = now

	query := `
		INSERT INTO business_members (id, business_id, user_id, role, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err := r.pool.Exec(ctx, query, member.ID, member.BusinessID, member.UserID, string(member.Role), string(member.Status), member.CreatedAt, member.UpdatedAt)
	if err != nil {
		return err
	}
	return nil
}

func (r *PostgresBusinessRepository) GetMember(ctx context.Context, businessID, userID uuid.UUID) (*BusinessMember, error) {
	query := `
		SELECT id, business_id, user_id, role, status, created_at, updated_at
		FROM business_members
		WHERE business_id = $1 AND user_id = $2
	`
	var m BusinessMember
	var role, status string
	err := r.pool.QueryRow(ctx, query, businessID, userID).Scan(&m.ID, &m.BusinessID, &m.UserID, &role, &status, &m.CreatedAt, &m.UpdatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrMemberNotFound
		}
		return nil, err
	}
	m.Role = MemberRole(role)
	m.Status = MemberStatus(status)
	return &m, nil
}

func (r *PostgresBusinessRepository) GetMemberByID(ctx context.Context, memberID uuid.UUID) (*BusinessMember, error) {
	query := `
		SELECT id, business_id, user_id, role, status, created_at, updated_at
		FROM business_members
		WHERE id = $1
	`
	var m BusinessMember
	var role, status string
	err := r.pool.QueryRow(ctx, query, memberID).Scan(&m.ID, &m.BusinessID, &m.UserID, &role, &status, &m.CreatedAt, &m.UpdatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrMemberNotFound
		}
		return nil, err
	}
	m.Role = MemberRole(role)
	m.Status = MemberStatus(status)
	return &m, nil
}

func (r *PostgresBusinessRepository) GetMembers(ctx context.Context, businessID uuid.UUID) ([]*BusinessMember, error) {
	query := `
		SELECT id, business_id, user_id, role, status, created_at, updated_at
		FROM business_members
		WHERE business_id = $1
		ORDER BY created_at ASC
	`
	rows, err := r.pool.Query(ctx, query, businessID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []*BusinessMember
	for rows.Next() {
		var m BusinessMember
		var role, status string
		if err := rows.Scan(&m.ID, &m.BusinessID, &m.UserID, &role, &status, &m.CreatedAt, &m.UpdatedAt); err != nil {
			return nil, err
		}
		m.Role = MemberRole(role)
		m.Status = MemberStatus(status)
		members = append(members, &m)
	}
	return members, nil
}

func (r *PostgresBusinessRepository) UpdateMember(ctx context.Context, member *BusinessMember) error {
	member.UpdatedAt = time.Now().UTC()
	query := `
		UPDATE business_members
		SET role = $1, status = $2, updated_at = $3
		WHERE id = $4
	`
	tag, err := r.pool.Exec(ctx, query, string(member.Role), string(member.Status), member.UpdatedAt, member.ID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrMemberNotFound
	}
	return nil
}

func (r *PostgresBusinessRepository) RemoveMember(ctx context.Context, businessID, memberID uuid.UUID) error {
	query := `
		DELETE FROM business_members
		WHERE id = $1 AND business_id = $2
	`
	tag, err := r.pool.Exec(ctx, query, memberID, businessID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrMemberNotFound
	}
	return nil
}

func (r *PostgresBusinessRepository) GetBusinessAccount(ctx context.Context, businessID uuid.UUID) (*BusinessAccount, error) {
	query := `
		SELECT id, business_id, ledger_account_id, currency, status, created_at, updated_at
		FROM business_accounts
		WHERE business_id = $1
	`
	var acc BusinessAccount
	var status string
	err := r.pool.QueryRow(ctx, query, businessID).Scan(&acc.ID, &acc.BusinessID, &acc.LedgerAccountID, &acc.Currency, &status, &acc.CreatedAt, &acc.UpdatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrBusinessAccountNotFound
		}
		return nil, err
	}
	acc.Status = BusinessAccountStatus(status)
	return &acc, nil
}

func (r *PostgresBusinessRepository) GetBusinessAccountByLedgerID(ctx context.Context, ledgerAccountID uuid.UUID) (*BusinessAccount, error) {
	query := `
		SELECT id, business_id, ledger_account_id, currency, status, created_at, updated_at
		FROM business_accounts
		WHERE ledger_account_id = $1
	`
	var acc BusinessAccount
	var status string
	err := r.pool.QueryRow(ctx, query, ledgerAccountID).Scan(&acc.ID, &acc.BusinessID, &acc.LedgerAccountID, &acc.Currency, &status, &acc.CreatedAt, &acc.UpdatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrBusinessAccountNotFound
		}
		return nil, err
	}
	acc.Status = BusinessAccountStatus(status)
	return &acc, nil
}
