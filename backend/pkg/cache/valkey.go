package cache

import (
	"context"
	"fmt"
	"time"

	"github.com/miigho/miigho/internal/config"
	"github.com/redis/go-redis/v9"
)

// ValkeyClient is a wrapper around the go-redis client.
type ValkeyClient struct {
	client *redis.Client
}

// NewValkeyClient initializes a new Valkey (Redis compatible) client.
func NewValkeyClient(ctx context.Context, cfg *config.Config) (*ValkeyClient, error) {
	rdb := redis.NewClient(&redis.Options{
		Addr:     cfg.Valkey.Addr,
		Password: cfg.Valkey.Password,
		DB:       cfg.Valkey.DB,
	})

	if err := rdb.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to ping valkey: %w", err)
	}

	return &ValkeyClient{client: rdb}, nil
}

// HealthCheck verifies the connection to the cache.
func (v *ValkeyClient) HealthCheck(ctx context.Context) error {
	return v.client.Ping(ctx).Err()
}

func (v *ValkeyClient) SetWithTTL(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
	return v.client.Set(ctx, key, value, ttl).Err()
}

func (v *ValkeyClient) Get(ctx context.Context, key string) (string, error) {
	return v.client.Get(ctx, key).Result()
}

func (v *ValkeyClient) Delete(ctx context.Context, key string) error {
	return v.client.Del(ctx, key).Err()
}

func (v *ValkeyClient) SetPresence(ctx context.Context, userID string, status string, ttl time.Duration) error {
	key := fmt.Sprintf("presence:%s", userID)
	return v.SetWithTTL(ctx, key, status, ttl)
}

func (v *ValkeyClient) GetPresence(ctx context.Context, userID string) (string, error) {
	key := fmt.Sprintf("presence:%s", userID)
	return v.Get(ctx, key)
}

// IncrementRateLimit increments the rate limit counter and sets the expiration if it's a new key.
func (v *ValkeyClient) IncrementRateLimit(ctx context.Context, key string, window time.Duration) (int64, error) {
	pipe := v.client.TxPipeline()
	incr := pipe.Incr(ctx, key)
	pipe.Expire(ctx, key, window)
	if _, err := pipe.Exec(ctx); err != nil {
		return 0, err
	}
	return incr.Val(), nil
}
