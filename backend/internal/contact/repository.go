package contact

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ContactRepository interface {
	BatchFindUsersByPhone(ctx context.Context, phones []string) ([]MatchedContact, error)
	UpsertContact(ctx context.Context, contact *Contact) error
	ListContacts(ctx context.Context, ownerID uuid.UUID) ([]*Contact, error)
	UpdateContactStatus(ctx context.Context, ownerID, userID uuid.UUID, isBlocked, isFav bool) error
}

type PostgresContactRepository struct {
	pool *pgxpool.Pool
}

func NewPostgresContactRepository(pool *pgxpool.Pool) *PostgresContactRepository {
	return &PostgresContactRepository{pool: pool}
}

func (r *PostgresContactRepository) BatchFindUsersByPhone(ctx context.Context, phones []string) ([]MatchedContact, error) {
	if len(phones) == 0 {
		return []MatchedContact{}, nil
	}

	query := "SELECT phone_number, id FROM users WHERE phone_number = ANY($1) AND deleted_at IS NULL"
	rows, err := r.pool.Query(ctx, query, phones)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var matches []MatchedContact
	for rows.Next() {
		var m MatchedContact
		if err := rows.Scan(&m.PhoneNumber, &m.UserID); err != nil {
			return nil, err
		}
		matches = append(matches, m)
	}
	return matches, nil
}

func (r *PostgresContactRepository) UpsertContact(ctx context.Context, contact *Contact) error {
	query := `
		INSERT INTO contacts (user_id, contact_user_id, contact_name, is_favorite, created_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (user_id, contact_user_id) 
		DO UPDATE SET contact_name = EXCLUDED.contact_name, is_favorite = EXCLUDED.is_favorite
	`
	_, err := r.pool.Exec(ctx, query, contact.OwnerID, contact.UserID, contact.Alias, contact.IsFav, contact.CreatedAt)
	return err
}

func (r *PostgresContactRepository) ListContacts(ctx context.Context, ownerID uuid.UUID) ([]*Contact, error) {
	query := `
		SELECT c.user_id, c.contact_user_id, COALESCE(c.contact_name, ''), c.is_favorite, c.created_at,
		       EXISTS(SELECT 1 FROM blocked_users b WHERE b.blocker_id = c.user_id AND b.blocked_id = c.contact_user_id) AS is_blocked
		FROM contacts c
		WHERE c.user_id = $1
		ORDER BY c.is_favorite DESC, c.contact_name ASC
	`
	rows, err := r.pool.Query(ctx, query, ownerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var contacts []*Contact
	for rows.Next() {
		var c Contact
		if err := rows.Scan(&c.OwnerID, &c.UserID, &c.Alias, &c.IsFav, &c.CreatedAt, &c.IsBlocked); err != nil {
			return nil, err
		}
		c.UpdatedAt = c.CreatedAt
		contacts = append(contacts, &c)
	}
	return contacts, nil
}

func (r *PostgresContactRepository) UpdateContactStatus(ctx context.Context, ownerID, userID uuid.UUID, isBlocked, isFav bool) error {
	if isBlocked {
		_, err := r.pool.Exec(ctx, "INSERT INTO blocked_users (blocker_id, blocked_id) VALUES ($1, $2) ON CONFLICT DO NOTHING", ownerID, userID)
		if err != nil {
			return err
		}
	} else {
		_, err := r.pool.Exec(ctx, "DELETE FROM blocked_users WHERE blocker_id = $1 AND blocked_id = $2", ownerID, userID)
		if err != nil {
			return err
		}
	}

	_, err := r.pool.Exec(ctx, "UPDATE contacts SET is_favorite = $1 WHERE user_id = $2 AND contact_user_id = $3", isFav, ownerID, userID)
	return err
}
