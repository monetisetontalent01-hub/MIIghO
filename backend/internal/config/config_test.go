package config

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestConfigValidation_Development(t *testing.T) {
	cfg := &Config{}
	cfg.Server.Mode = "development"
	cfg.Auth.JWTSecret = "secret"
	cfg.CORS.AllowedOrigins = []string{"*"}
	cfg.SMS.Provider = "mock"

	err := cfg.Validate()
	assert.NoError(t, err, "Development mode should allow default/dev values")
}

func TestConfigValidation_Production_WeakJWT(t *testing.T) {
	cfg := &Config{}
	cfg.Server.Mode = "production"
	cfg.Auth.JWTSecret = "secret" // too weak/default
	cfg.CORS.AllowedOrigins = []string{"https://miigho.com"}
	cfg.SMS.Provider = "africas_talking"
	cfg.SMS.APIKey = "real_api_key_123456"

	err := cfg.Validate()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "AUTH_JWT_SECRET")
}

func TestConfigValidation_Production_WildcardCORS(t *testing.T) {
	cfg := &Config{}
	cfg.Server.Mode = "production"
	cfg.Auth.JWTSecret = "super_strong_random_secret_at_least_32_chars_long_12345"
	cfg.CORS.AllowedOrigins = []string{"*", "https://miigho.com"}
	cfg.SMS.Provider = "africas_talking"
	cfg.SMS.APIKey = "real_api_key_123456"

	err := cfg.Validate()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "CORS wildcard '*' is strictly forbidden")
}

func TestConfigValidation_Production_MockSMSForbidden(t *testing.T) {
	cfg := &Config{}
	cfg.Server.Mode = "production"
	cfg.Auth.JWTSecret = "super_strong_random_secret_at_least_32_chars_long_12345"
	cfg.CORS.AllowedOrigins = []string{"https://miigho.com", "https://www.miigho.com"}
	cfg.SMS.Provider = "mock" // forbidden in production

	err := cfg.Validate()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "mock/dev is forbidden in production")
}

func TestConfigValidation_Production_Valid(t *testing.T) {
	cfg := &Config{}
	cfg.Server.Mode = "production"
	cfg.Auth.JWTSecret = "super_strong_random_secret_at_least_32_chars_long_12345"
	cfg.CORS.AllowedOrigins = []string{"https://miigho.com", "https://www.miigho.com"}
	cfg.SMS.Provider = "africas_talking"
	cfg.SMS.APIKey = "valid_production_api_key_secure_1234"

	err := cfg.Validate()
	assert.NoError(t, err, "Valid production config must pass validation")
}

func TestConfig_EffectivePort_Priority(t *testing.T) {
	// 1. Default fallback
	cfgDefault := &Config{}
	assert.Equal(t, "8080", cfgDefault.EffectivePort())

	// 2. SERVER_PORT takes precedence over default
	cfgServer := &Config{}
	cfgServer.Server.Port = "3000"
	assert.Equal(t, "3000", cfgServer.EffectivePort())

	// 3. PORT (Railway/Cloud) takes highest precedence
	cfgCloud := &Config{}
	cfgCloud.Server.Port = "3000"
	cfgCloud.Server.CloudPort = "8080"
	assert.Equal(t, "8080", cfgCloud.EffectivePort())
}

