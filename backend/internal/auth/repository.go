package auth

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// AuthRepository defines operations on auth entities.
type AuthRepository interface {
	FindUserByPhone(ctx context.Context, phone string) (*User, error)
	CreateUser(ctx context.Context, user *User) error
	StoreOTP(ctx context.Context, otp *OTPCode) error
	GetOTP(ctx context.Context, phone string) (*OTPCode, error)
	DeleteOTP(ctx context.Context, phone string) error
	IncrementOTPAttempts(ctx context.Context, phone string) error
	StoreToken(ctx context.Context, token *AuthToken) error
	FindTokenByHash(ctx context.Context, hash string) (*AuthToken, error)
	DeleteToken(ctx context.Context, id uuid.UUID) error
	DeleteAllUserTokens(ctx context.Context, userID uuid.UUID) error
	LogLogin(ctx context.Context, log *LoginHistory) error
}

// PostgresAuthRepository is a PostgreSQL implementation of AuthRepository.
type PostgresAuthRepository struct {
	pool *pgxpool.Pool
}

func NewPostgresAuthRepository(pool *pgxpool.Pool) *PostgresAuthRepository {
	return &PostgresAuthRepository{pool: pool}
}

func (r *PostgresAuthRepository) FindUserByPhone(ctx context.Context, phone string) (*User, error) {
	var user User
	err := r.pool.QueryRow(ctx, "SELECT id, phone_number, created_at, updated_at FROM users WHERE phone_number = $1", phone).
		Scan(&user.ID, &user.PhoneNumber, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil // Not found is handled nicely
		}
		return nil, err
	}
	return &user, nil
}

func (r *PostgresAuthRepository) CreateUser(ctx context.Context, user *User) error {
	_, err := r.pool.Exec(ctx, "INSERT INTO users (id, phone_number, created_at, updated_at) VALUES ($1, $2, $3, $4)",
		user.ID, user.PhoneNumber, user.CreatedAt, user.UpdatedAt)
	return err
}

func (r *PostgresAuthRepository) StoreOTP(ctx context.Context, otp *OTPCode) error {
	_, err := r.pool.Exec(ctx, "INSERT INTO otp_codes (phone_number, code_hash, expires_at) VALUES ($1, $2, $3) ON CONFLICT (phone_number) DO UPDATE SET code_hash = $2, expires_at = $3, attempts = 0",
		otp.PhoneNumber, otp.CodeHash, otp.ExpiresAt)
	return err
}

func (r *PostgresAuthRepository) GetOTP(ctx context.Context, phone string) (*OTPCode, error) {
	var otp OTPCode
	err := r.pool.QueryRow(ctx, "SELECT phone_number, code_hash, attempts, expires_at FROM otp_codes WHERE phone_number = $1", phone).
		Scan(&otp.PhoneNumber, &otp.CodeHash, &otp.Attempts, &otp.ExpiresAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &otp, nil
}

func (r *PostgresAuthRepository) DeleteOTP(ctx context.Context, phone string) error {
	_, err := r.pool.Exec(ctx, "DELETE FROM otp_codes WHERE phone_number = $1", phone)
	return err
}

func (r *PostgresAuthRepository) IncrementOTPAttempts(ctx context.Context, phone string) error {
	_, err := r.pool.Exec(ctx, "UPDATE otp_codes SET attempts = attempts + 1 WHERE phone_number = $1", phone)
	return err
}

func (r *PostgresAuthRepository) StoreToken(ctx context.Context, token *AuthToken) error {
	_, err := r.pool.Exec(ctx, "INSERT INTO auth_tokens (id, user_id, token_hash, type, expires_at, created_at) VALUES ($1, $2, $3, $4, $5, $6)",
		token.ID, token.UserID, token.TokenHash, token.Type, token.ExpiresAt, token.CreatedAt)
	return err
}

func (r *PostgresAuthRepository) FindTokenByHash(ctx context.Context, hash string) (*AuthToken, error) {
	var token AuthToken
	err := r.pool.QueryRow(ctx, "SELECT id, user_id, token_hash, type, expires_at, created_at FROM auth_tokens WHERE token_hash = $1", hash).
		Scan(&token.ID, &token.UserID, &token.TokenHash, &token.Type, &token.ExpiresAt, &token.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &token, nil
}

func (r *PostgresAuthRepository) DeleteToken(ctx context.Context, id uuid.UUID) error {
	_, err := r.pool.Exec(ctx, "DELETE FROM auth_tokens WHERE id = $1", id)
	return err
}

func (r *PostgresAuthRepository) DeleteAllUserTokens(ctx context.Context, userID uuid.UUID) error {
	_, err := r.pool.Exec(ctx, "DELETE FROM auth_tokens WHERE user_id = $1", userID)
	return err
}

func (r *PostgresAuthRepository) LogLogin(ctx context.Context, log *LoginHistory) error {
	_, err := r.pool.Exec(ctx, "INSERT INTO login_history (id, user_id, ip_address, device_info, created_at) VALUES ($1, $2, $3, $4, $5)",
		log.ID, log.UserID, log.IPAddress, log.DeviceInfo, log.CreatedAt)
	return err
}
