package config

import (
	"errors"
	"strings"
	"time"

	"github.com/kelseyhightower/envconfig"
)

// Config represents the application configuration loaded from environment variables.
type Config struct {
	Server struct {
		Port       string `envconfig:"SERVER_PORT" default:""`
		CloudPort  string `envconfig:"PORT" default:""`
		Host       string `envconfig:"SERVER_HOST" default:"0.0.0.0"`
		Mode       string `envconfig:"SERVER_MODE" default:"development"`
	}

	Database struct {
		URL      string `envconfig:"DATABASE_URL" default:""`
		Host     string `envconfig:"DB_HOST" default:"localhost"`
		Port     int    `envconfig:"DB_PORT" default:"5432"`
		User     string `envconfig:"DB_USER" default:"postgres"`
		Password string `envconfig:"DB_PASSWORD" default:"postgres"`
		DBName   string `envconfig:"DB_NAME" default:"miigho"`
		MaxConns int32  `envconfig:"DB_MAX_CONNS" default:"20"`
		SSLMode  string `envconfig:"DB_SSLMODE" default:"disable"`
	}

	Valkey struct {
		URL      string `envconfig:"VALKEY_URL" default:""`
		RedisURL string `envconfig:"REDIS_URL" default:""`
		Addr     string `envconfig:"VALKEY_ADDR" default:"localhost:6379"`
		Password string `envconfig:"VALKEY_PASSWORD" default:""`
		DB       int    `envconfig:"VALKEY_DB" default:"0"`
	}

	MinIO struct {
		Endpoint   string `envconfig:"MINIO_ENDPOINT" default:"localhost:9000"`
		AccessKey  string `envconfig:"MINIO_ACCESS_KEY" default:"minioadmin"`
		SecretKey  string `envconfig:"MINIO_SECRET_KEY" default:"minioadmin"`
		BucketName string `envconfig:"MINIO_BUCKET_NAME" default:"miigho-media"`
		UseSSL     bool   `envconfig:"MINIO_USE_SSL" default:"false"`
	}

	NATS struct {
		URL string `envconfig:"NATS_URL" default:"nats://localhost:4222"`
	}

	CORS struct {
		AllowedOrigins []string `envconfig:"CORS_ALLOWED_ORIGINS" default:"http://localhost:3000,http://localhost:8080,http://localhost:5000,http://localhost:5173,http://127.0.0.1:3000,http://127.0.0.1:8080,http://127.0.0.1:5000,http://127.0.0.1:5173"`
	}

	Auth struct {
		AccessTokenTTL  time.Duration `envconfig:"AUTH_ACCESS_TOKEN_TTL" default:"15m"`
		RefreshTokenTTL time.Duration `envconfig:"AUTH_REFRESH_TOKEN_TTL" default:"720h"` // 30 days
		OTPLength       int           `envconfig:"AUTH_OTP_LENGTH" default:"6"`
		OTPMaxAttempts  int           `envconfig:"AUTH_OTP_MAX_ATTEMPTS" default:"3"`
		OTPTTL          time.Duration `envconfig:"AUTH_OTP_TTL" default:"5m"`
		JWTSecret       string        `envconfig:"AUTH_JWT_SECRET" default:"secret"`
	}

	SMS struct {
		Provider string `envconfig:"SMS_PROVIDER" default:"mock"`
		APIKey   string `envconfig:"SMS_API_KEY" default:""`
		SenderID string `envconfig:"SMS_SENDER_ID" default:"MIIGHO"`
	}

	PSP struct {
		Provider string `envconfig:"PSP_PROVIDER" default:"sandbox"`
	}
}

// EffectivePort resolves the port to listen on following the priority:
// PORT (Railway/Cloud) > SERVER_PORT > 8080 (default).
func (c *Config) EffectivePort() string {
	if c.Server.CloudPort != "" {
		return c.Server.CloudPort
	}
	if c.Server.Port != "" {
		return c.Server.Port
	}
	return "8080"
}

// Validate checks the configuration for production safety rules.
func (c *Config) Validate() error {
	if c.Server.Mode == "production" {
		// 1. JWT Secret strength check in production
		if c.Auth.JWTSecret == "" || c.Auth.JWTSecret == "secret" || len(c.Auth.JWTSecret) < 32 {
			return errors.New("security error: production mode requires a strong AUTH_JWT_SECRET (minimum 32 characters, not default)")
		}

		// 2. CORS Wildcard restriction in production
		for _, origin := range c.CORS.AllowedOrigins {
			if strings.TrimSpace(origin) == "*" {
				return errors.New("security error: CORS wildcard '*' is strictly forbidden in production mode")
			}
		}

		// 3. SMS Provider check in production: Dev/Mock provider is forbidden
		if c.SMS.Provider == "mock" || c.SMS.Provider == "dev" || c.SMS.Provider == "" {
			return errors.New("configuration error: production mode requires a configured real SMS_PROVIDER (mock/dev is forbidden in production)")
		}
		if c.SMS.APIKey == "" {
			return errors.New("configuration error: production mode requires a valid SMS_API_KEY for SMS_PROVIDER")
		}
	}

	return nil
}

// Load reads configuration from environment variables, resolves priorities, validates safety constraints, and returns a Config struct.
func Load() (*Config, error) {
	var cfg Config
	err := envconfig.Process("", &cfg)
	if err != nil {
		return nil, err
	}
	// Normalize port
	cfg.Server.Port = cfg.EffectivePort()
	if err := cfg.Validate(); err != nil {
		return nil, err
	}
	return &cfg, nil
}

