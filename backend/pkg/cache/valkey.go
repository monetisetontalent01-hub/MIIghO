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
// Priority: VALKEY_URL > REDIS_URL > Valkey Addr/Password/DB.
func NewValkeyClient(ctx context.Context, cfg *config.Config) (*ValkeyClient, error) {
	var rdb *redis.Client

	targetURL := cfg.Valkey.URL
	if targetURL == "" {
		targetURL = cfg.Valkey.RedisURL
	}

	if targetURL != "" {
		opt, err := redis.ParseURL(targetURL)
		if err != nil {
			return nil, fmt.Errorf("failed to parse valkey/redis url: %w", err)
		}
		rdb = redis.NewClient(opt)
	} else {
		rdb = redis.NewClient(&redis.Options{
			Addr:     cfg.Valkey.Addr,
			Password: cfg.Valkey.Password,
			DB:       cfg.Valkey.DB,
		})
	}

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
// Uses an atomic Lua script to ensure EXPIRE is set only once (when count == 1),
// preventing rolling window extension on subsequent requests.
func (v *ValkeyClient) IncrementRateLimit(ctx context.Context, key string, window time.Duration) (int64, error) {
	script := `
		local current = redis.call('INCR', KEYS[1])
		if current == 1 then
			redis.call('EXPIRE', KEYS[1], ARGV[1])
		end
		return current
	`
	ttlSeconds := int(window.Seconds())
	if ttlSeconds <= 0 {
		ttlSeconds = 60
	}
	res, err := v.client.Eval(ctx, script, []string{key}, ttlSeconds).Int64()
	if err != nil {
		return 0, err
	}
	return res, nil
}
