package config

import (
	"time"

	"github.com/kelseyhightower/envconfig"
)

// Config represents the application configuration loaded from environment variables.
type Config struct {
	Server struct {
		Port string `envconfig:"SERVER_PORT" default:"8080"`
		Host string `envconfig:"SERVER_HOST" default:"0.0.0.0"`
		Mode string `envconfig:"SERVER_MODE" default:"development"`
	}

	Database struct {
		Host     string `envconfig:"DB_HOST" default:"localhost"`
		Port     int    `envconfig:"DB_PORT" default:"5432"`
		User     string `envconfig:"DB_USER" default:"postgres"`
		Password string `envconfig:"DB_PASSWORD" default:"postgres"`
		DBName   string `envconfig:"DB_NAME" default:"miigho"`
		MaxConns int32  `envconfig:"DB_MAX_CONNS" default:"20"`
		SSLMode  string `envconfig:"DB_SSLMODE" default:"disable"`
	}

	Valkey struct {
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

// Load reads configuration from environment variables and returns a Config struct.
func Load() (*Config, error) {
	var cfg Config
	err := envconfig.Process("", &cfg)
	if err != nil {
		return nil, err
	}
	return &cfg, nil
}
