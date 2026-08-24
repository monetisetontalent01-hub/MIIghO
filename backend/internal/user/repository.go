package user

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// UserRepository defines operations on user profiles.
type UserRepository interface {
	GetProfile(ctx context.Context, id uuid.UUID) (*UserProfile, error)
	UpdateProfile(ctx context.Context, profile *UserProfile) error
	UpdateAvatar(ctx context.Context, id uuid.UUID, url string) error
	SearchByPhone(ctx context.Context, phone string) (*UserProfile, error)
}

// PostgresUserRepository implements UserRepository.
type PostgresUserRepository struct {
	pool *pgxpool.Pool
}

func NewPostgresUserRepository(pool *pgxpool.Pool) *PostgresUserRepository {
	return &PostgresUserRepository{pool: pool}
}

func (r *PostgresUserRepository) GetProfile(ctx context.Context, id uuid.UUID) (*UserProfile, error) {
	var profile UserProfile
	err := r.pool.QueryRow(ctx, "SELECT id, phone_number, COALESCE(first_name, ''), COALESCE(last_name, ''), COALESCE(avatar_url, ''), COALESCE(status_message, ''), language, created_at, updated_at, deleted_at FROM users WHERE id = $1 AND deleted_at IS NULL", id).
		Scan(&profile.ID, &profile.PhoneNumber, &profile.FirstName, &profile.LastName, &profile.AvatarURL, &profile.StatusMessage, &profile.Language, &profile.CreatedAt, &profile.UpdatedAt, &profile.DeletedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &profile, nil
}

func (r *PostgresUserRepository) UpdateProfile(ctx context.Context, profile *UserProfile) error {
	profile.UpdatedAt = time.Now()
	_, err := r.pool.Exec(ctx, "UPDATE users SET first_name = $1, last_name = $2, status_message = $3, language = $4, updated_at = $5 WHERE id = $6 AND deleted_at IS NULL",
		profile.FirstName, profile.LastName, profile.StatusMessage, profile.Language, profile.UpdatedAt, profile.ID)
	return err
}

func (r *PostgresUserRepository) UpdateAvatar(ctx context.Context, id uuid.UUID, url string) error {
	_, err := r.pool.Exec(ctx, "UPDATE users SET avatar_url = $1, updated_at = $2 WHERE id = $3 AND deleted_at IS NULL",
		url, time.Now(), id)
	return err
}

func (r *PostgresUserRepository) SearchByPhone(ctx context.Context, phone string) (*UserProfile, error) {
	var profile UserProfile
	err := r.pool.QueryRow(ctx, "SELECT id, phone_number, COALESCE(first_name, ''), COALESCE(last_name, ''), COALESCE(avatar_url, ''), COALESCE(status_message, ''), language, created_at, updated_at, deleted_at FROM users WHERE phone_number = $1 AND deleted_at IS NULL", phone).
		Scan(&profile.ID, &profile.PhoneNumber, &profile.FirstName, &profile.LastName, &profile.AvatarURL, &profile.StatusMessage, &profile.Language, &profile.CreatedAt, &profile.UpdatedAt, &profile.DeletedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &profile, nil
}
