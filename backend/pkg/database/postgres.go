package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/miigho/miigho/internal/config"
)

func NewPostgresPool(ctx context.Context, cfg *config.Config) (*pgxpool.Pool, error) {
	var connString string
	if cfg.Database.URL != "" {
		connString = cfg.Database.URL
	} else {
		connString = fmt.Sprintf(
			"postgres://%s:%s@%s:%d/%s?sslmode=%s",
			cfg.Database.User,
			cfg.Database.Password,
			cfg.Database.Host,
			cfg.Database.Port,
			cfg.Database.DBName,
			cfg.Database.SSLMode,
		)
	}

	poolConfig, err := pgxpool.ParseConfig(connString)
	if err != nil {
		return nil, fmt.Errorf("failed to parse config: %w", err)
	}

	poolConfig.MaxConns = cfg.Database.MaxConns
	poolConfig.MinConns = 5
	poolConfig.HealthCheckPeriod = 1 * time.Minute
	poolConfig.MaxConnLifetime = 1 * time.Hour
	poolConfig.MaxConnIdleTime = 30 * time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to create pool: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	return pool, nil
}

// HealthCheck verifies the connection to the database.
func HealthCheck(ctx context.Context, pool *pgxpool.Pool) error {
	return pool.Ping(ctx)
}

// EnsureSchema guarantees that critical application tables and indices exist.
func EnsureSchema(ctx context.Context, pool *pgxpool.Pool) error {
	queries := []string{
		`CREATE TABLE IF NOT EXISTS contact_requests (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			status VARCHAR(20) NOT NULL DEFAULT 'pending',
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			CONSTRAINT chk_contact_request_status CHECK (status IN ('pending', 'accepted', 'rejected')),
			CONSTRAINT chk_no_self_request CHECK (sender_id != recipient_id),
			CONSTRAINT unique_contact_request UNIQUE (sender_id, recipient_id)
		);`,
		`CREATE INDEX IF NOT EXISTS idx_contact_requests_recipient_status ON contact_requests(recipient_id, status);`,
		`CREATE INDEX IF NOT EXISTS idx_contact_requests_sender_status ON contact_requests(sender_id, status);`,
		`ALTER TABLE messages ADD COLUMN IF NOT EXISTS client_message_id VARCHAR(64);`,
		`CREATE INDEX IF NOT EXISTS idx_messages_client_message_id
			ON messages (conversation_id, client_message_id)
			WHERE client_message_id IS NOT NULL;`,
	}

	for _, q := range queries {
		if _, err := pool.Exec(ctx, q); err != nil {
			return fmt.Errorf("failed to execute schema migration query: %w", err)
		}
	}
	return nil
}
