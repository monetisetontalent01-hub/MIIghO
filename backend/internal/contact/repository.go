package contact

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ContactRepository interface {
	BatchFindUsersByPhone(ctx context.Context, phones []string) ([]MatchedContact, error)
	UpsertContact(ctx context.Context, contact *Contact) error
	ListContacts(ctx context.Context, ownerID uuid.UUID) ([]*Contact, error)
	ListContactUsers(ctx context.Context, ownerID uuid.UUID) ([]ContactUser, error)
	SearchUsers(ctx context.Context, currentUserID uuid.UUID, query string) ([]ContactUser, error)
	UpdateContactStatus(ctx context.Context, ownerID, userID uuid.UUID, isBlocked, isFav bool) error

	// Contact request methods
	CreateContactRequest(ctx context.Context, senderID, recipientID uuid.UUID) (*ContactRequest, error)
	GetContactRequests(ctx context.Context, userID uuid.UUID, direction string) ([]ContactRequest, error)
	GetContactRequest(ctx context.Context, requestID uuid.UUID) (*ContactRequest, error)
	AcceptContactRequest(ctx context.Context, requestID, recipientID uuid.UUID) error
	RejectContactRequest(ctx context.Context, requestID, recipientID uuid.UUID) error
	AreContacts(ctx context.Context, userA, userB uuid.UUID) (bool, error)
	GetRelationshipStatus(ctx context.Context, currentUserID, otherUserID uuid.UUID) (RelationshipStatus, error)
}

type PostgresContactRepository struct {
	pool *pgxpool.Pool
}

func NewPostgresContactRepository(pool *pgxpool.Pool) *PostgresContactRepository {
	return &PostgresContactRepository{pool: pool}
}

// formatMiighoID derives a MÏÏghO ID from a UUID.
func formatMiighoID(id uuid.UUID) string {
	short := strings.ToUpper(strings.ReplaceAll(id.String(), "-", "")[:8])
	return fmt.Sprintf("@MG-%s", short)
}

// displayNameOrDefault returns the real name or the canonical placeholder.
const defaultDisplayName = "Nom à définir"

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

// ListContactUsers returns only mutually accepted contacts with real display names.
func (r *PostgresContactRepository) ListContactUsers(ctx context.Context, ownerID uuid.UUID) ([]ContactUser, error) {
	sql := `
		SELECT u.id, u.phone_number, 
		       COALESCE(NULLIF(c.contact_name, ''), NULLIF(TRIM(CONCAT(u.first_name, ' ', u.last_name)), ''), $2) as display_name,
		       u.avatar_url, u.status_message,
		       c.is_favorite,
		       EXISTS(SELECT 1 FROM blocked_users b WHERE b.blocker_id = c.user_id AND b.blocked_id = c.contact_user_id) AS is_blocked
		FROM contacts c
		JOIN users u ON u.id = c.contact_user_id AND u.deleted_at IS NULL
		WHERE c.user_id = $1
		ORDER BY c.is_favorite DESC, display_name ASC
	`
	rows, err := r.pool.Query(ctx, sql, ownerID, defaultDisplayName)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []ContactUser
	for rows.Next() {
		var u ContactUser
		var avatar, status *string
		if err := rows.Scan(&u.ID, &u.PhoneNumber, &u.DisplayName, &avatar, &status, &u.IsFavorite, &u.IsBlocked); err != nil {
			return nil, err
		}
		u.AvatarURL = avatar
		u.StatusMessage = status
		u.IsMiighoUser = true
		u.MiighoID = formatMiighoID(u.ID)
		u.RelationshipStatus = RelAccepted // Listed contacts are accepted by definition
		users = append(users, u)
	}
	return users, nil
}

// SearchUsers returns users matching the query, with relationship status and real names (never phone as name).
func (r *PostgresContactRepository) SearchUsers(ctx context.Context, currentUserID uuid.UUID, query string) ([]ContactUser, error) {
	trimmed := strings.TrimSpace(query)
	if trimmed == "" {
		return []ContactUser{}, nil
	}

	searchPattern := "%" + trimmed + "%"
	sql := `
		SELECT u.id, u.phone_number, 
		       COALESCE(NULLIF(TRIM(CONCAT(u.first_name, ' ', u.last_name)), ''), $3) as display_name,
		       u.avatar_url, u.status_message,
		       COALESCE(c.is_favorite, false) as is_favorite,
		       EXISTS(SELECT 1 FROM blocked_users b WHERE b.blocker_id = $1 AND b.blocked_id = u.id) AS is_blocked,
		       CASE
		           WHEN EXISTS(SELECT 1 FROM contacts ct WHERE ct.user_id = $1 AND ct.contact_user_id = u.id) THEN 'accepted'
		           WHEN EXISTS(SELECT 1 FROM contact_requests cr WHERE cr.sender_id = $1 AND cr.recipient_id = u.id AND cr.status = 'pending') THEN 'pending_sent'
		           WHEN EXISTS(SELECT 1 FROM contact_requests cr WHERE cr.sender_id = u.id AND cr.recipient_id = $1 AND cr.status = 'pending') THEN 'pending_received'
		           WHEN EXISTS(SELECT 1 FROM contact_requests cr 
		                       WHERE ((cr.sender_id = $1 AND cr.recipient_id = u.id) OR (cr.sender_id = u.id AND cr.recipient_id = $1))
		                       AND cr.status = 'rejected') THEN 'rejected'
		           ELSE 'none'
		       END as relationship_status
		FROM users u
		LEFT JOIN contacts c ON c.user_id = $1 AND c.contact_user_id = u.id
		WHERE u.id != $1 
		  AND u.deleted_at IS NULL
		  AND (u.phone_number ILIKE $2 OR u.first_name ILIKE $2 OR u.last_name ILIKE $2)
		ORDER BY u.created_at DESC
		LIMIT 30
	`
	rows, err := r.pool.Query(ctx, sql, currentUserID, searchPattern, defaultDisplayName)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []ContactUser
	for rows.Next() {
		var u ContactUser
		var avatar, status *string
		var relStatus string
		if err := rows.Scan(&u.ID, &u.PhoneNumber, &u.DisplayName, &avatar, &status, &u.IsFavorite, &u.IsBlocked, &relStatus); err != nil {
			return nil, err
		}
		u.AvatarURL = avatar
		u.StatusMessage = status
		u.IsMiighoUser = true
		u.MiighoID = formatMiighoID(u.ID)
		u.RelationshipStatus = RelationshipStatus(relStatus)
		users = append(users, u)
	}
	return users, nil
}

// ---- Contact Request methods ----

func (r *PostgresContactRepository) CreateContactRequest(ctx context.Context, senderID, recipientID uuid.UUID) (*ContactRequest, error) {
	var req ContactRequest
	query := `
		INSERT INTO contact_requests (sender_id, recipient_id, status)
		VALUES ($1, $2, 'pending')
		ON CONFLICT (sender_id, recipient_id) DO UPDATE SET
		    status = CASE 
		        WHEN contact_requests.status = 'rejected' THEN 'pending'
		        ELSE contact_requests.status
		    END,
		    updated_at = NOW()
		RETURNING id, sender_id, recipient_id, status, created_at, updated_at
	`
	err := r.pool.QueryRow(ctx, query, senderID, recipientID).Scan(
		&req.ID, &req.SenderID, &req.RecipientID, &req.Status, &req.CreatedAt, &req.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &req, nil
}

func (r *PostgresContactRepository) GetContactRequests(ctx context.Context, userID uuid.UUID, direction string) ([]ContactRequest, error) {
	var query string
	if direction == "incoming" {
		query = `
			SELECT cr.id, cr.sender_id, cr.recipient_id, cr.status, cr.created_at, cr.updated_at,
			       COALESCE(NULLIF(TRIM(CONCAT(u.first_name, ' ', u.last_name)), ''), $2) as sender_name,
			       u.avatar_url
			FROM contact_requests cr
			JOIN users u ON u.id = cr.sender_id AND u.deleted_at IS NULL
			WHERE cr.recipient_id = $1 AND cr.status = 'pending'
			ORDER BY cr.created_at DESC
		`
	} else {
		query = `
			SELECT cr.id, cr.sender_id, cr.recipient_id, cr.status, cr.created_at, cr.updated_at,
			       COALESCE(NULLIF(TRIM(CONCAT(u.first_name, ' ', u.last_name)), ''), $2) as recipient_name,
			       u.avatar_url
			FROM contact_requests cr
			JOIN users u ON u.id = cr.recipient_id AND u.deleted_at IS NULL
			WHERE cr.sender_id = $1 AND cr.status = 'pending'
			ORDER BY cr.created_at DESC
		`
	}

	rows, err := r.pool.Query(ctx, query, userID, defaultDisplayName)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var requests []ContactRequest
	for rows.Next() {
		var req ContactRequest
		var name string
		var avatar *string
		if err := rows.Scan(&req.ID, &req.SenderID, &req.RecipientID, &req.Status, &req.CreatedAt, &req.UpdatedAt, &name, &avatar); err != nil {
			return nil, err
		}
		if direction == "incoming" {
			req.SenderName = name
			req.SenderAvatar = avatar
		} else {
			req.RecipientName = name
		}
		requests = append(requests, req)
	}
	if requests == nil {
		requests = []ContactRequest{}
	}
	return requests, nil
}

func (r *PostgresContactRepository) GetContactRequest(ctx context.Context, requestID uuid.UUID) (*ContactRequest, error) {
	var req ContactRequest
	query := "SELECT id, sender_id, recipient_id, status, created_at, updated_at FROM contact_requests WHERE id = $1"
	err := r.pool.QueryRow(ctx, query, requestID).Scan(
		&req.ID, &req.SenderID, &req.RecipientID, &req.Status, &req.CreatedAt, &req.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &req, nil
}

// AcceptContactRequest atomically updates the request to 'accepted' and creates reciprocal contact entries.
func (r *PostgresContactRepository) AcceptContactRequest(ctx context.Context, requestID, recipientID uuid.UUID) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// 1. Update the request status (only recipient can accept)
	var senderID uuid.UUID
	err = tx.QueryRow(ctx,
		"UPDATE contact_requests SET status = 'accepted', updated_at = NOW() WHERE id = $1 AND recipient_id = $2 AND status = 'pending' RETURNING sender_id",
		requestID, recipientID,
	).Scan(&senderID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("contact request not found or already processed")
		}
		return err
	}

	// 2. Create reciprocal contact entries (A->B and B->A)
	_, err = tx.Exec(ctx,
		"INSERT INTO contacts (user_id, contact_user_id, is_favorite, created_at) VALUES ($1, $2, false, NOW()) ON CONFLICT DO NOTHING",
		senderID, recipientID,
	)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx,
		"INSERT INTO contacts (user_id, contact_user_id, is_favorite, created_at) VALUES ($1, $2, false, NOW()) ON CONFLICT DO NOTHING",
		recipientID, senderID,
	)
	if err != nil {
		return err
	}

	// 3. If there was a reciprocal pending request, accept it too (mutual)
	_, _ = tx.Exec(ctx,
		"UPDATE contact_requests SET status = 'accepted', updated_at = NOW() WHERE sender_id = $1 AND recipient_id = $2 AND status = 'pending'",
		recipientID, senderID,
	)

	return tx.Commit(ctx)
}

func (r *PostgresContactRepository) RejectContactRequest(ctx context.Context, requestID, recipientID uuid.UUID) error {
	tag, err := r.pool.Exec(ctx,
		"UPDATE contact_requests SET status = 'rejected', updated_at = NOW() WHERE id = $1 AND recipient_id = $2 AND status = 'pending'",
		requestID, recipientID,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("contact request not found or already processed")
	}
	return nil
}

// AreContacts checks if two users have a mutual contact relationship.
func (r *PostgresContactRepository) AreContacts(ctx context.Context, userA, userB uuid.UUID) (bool, error) {
	var exists bool
	query := "SELECT EXISTS(SELECT 1 FROM contacts WHERE user_id = $1 AND contact_user_id = $2)"
	err := r.pool.QueryRow(ctx, query, userA, userB).Scan(&exists)
	return exists, err
}

// GetRelationshipStatus returns the relationship status between two users.
func (r *PostgresContactRepository) GetRelationshipStatus(ctx context.Context, currentUserID, otherUserID uuid.UUID) (RelationshipStatus, error) {
	// Check contacts first (accepted)
	var exists bool
	err := r.pool.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM contacts WHERE user_id = $1 AND contact_user_id = $2)",
		currentUserID, otherUserID,
	).Scan(&exists)
	if err != nil {
		return RelNone, err
	}
	if exists {
		return RelAccepted, nil
	}

	// Check pending sent
	var status string
	err = r.pool.QueryRow(ctx,
		"SELECT status FROM contact_requests WHERE sender_id = $1 AND recipient_id = $2 ORDER BY updated_at DESC LIMIT 1",
		currentUserID, otherUserID,
	).Scan(&status)
	if err == nil {
		if status == "pending" {
			return RelPendingSent, nil
		}
		if status == "rejected" {
			return RelRejected, nil
		}
	}

	// Check pending received
	err = r.pool.QueryRow(ctx,
		"SELECT status FROM contact_requests WHERE sender_id = $1 AND recipient_id = $2 ORDER BY updated_at DESC LIMIT 1",
		otherUserID, currentUserID,
	).Scan(&status)
	if err == nil {
		if status == "pending" {
			return RelPendingReceived, nil
		}
	}

	return RelNone, nil
}
