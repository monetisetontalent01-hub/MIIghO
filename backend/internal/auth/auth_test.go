package auth_test

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/auth"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/internal/config"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type memoryAuthRepo struct {
	users      map[string]*auth.User
	usersByID  map[uuid.UUID]*auth.User
	otps       map[string]*auth.OTPCode
	tokens     map[string]*auth.AuthToken
	loginLogs  []*auth.LoginHistory
}

func newMemoryAuthRepo() *memoryAuthRepo {
	return &memoryAuthRepo{
		users:     make(map[string]*auth.User),
		usersByID: make(map[uuid.UUID]*auth.User),
		otps:      make(map[string]*auth.OTPCode),
		tokens:    make(map[string]*auth.AuthToken),
	}
}

func (m *memoryAuthRepo) FindUserByPhone(ctx context.Context, phone string) (*auth.User, error) {
	return m.users[phone], nil
}

func (m *memoryAuthRepo) FindUserByID(ctx context.Context, id uuid.UUID) (*auth.User, error) {
	return m.usersByID[id], nil
}

func (m *memoryAuthRepo) CreateUser(ctx context.Context, user *auth.User) error {
	m.users[user.PhoneNumber] = user
	m.usersByID[user.ID] = user
	return nil
}

func (m *memoryAuthRepo) StoreOTP(ctx context.Context, otp *auth.OTPCode) error {
	m.otps[otp.PhoneNumber] = otp
	return nil
}

func (m *memoryAuthRepo) GetOTP(ctx context.Context, phone string) (*auth.OTPCode, error) {
	return m.otps[phone], nil
}

func (m *memoryAuthRepo) DeleteOTP(ctx context.Context, phone string) error {
	delete(m.otps, phone)
	return nil
}

func (m *memoryAuthRepo) IncrementOTPAttempts(ctx context.Context, phone string) error {
	if otp, ok := m.otps[phone]; ok {
		otp.Attempts++
	}
	return nil
}

func (m *memoryAuthRepo) StoreToken(ctx context.Context, token *auth.AuthToken) error {
	m.tokens[token.TokenHash] = token
	return nil
}

func (m *memoryAuthRepo) FindTokenByHash(ctx context.Context, hash string) (*auth.AuthToken, error) {
	return m.tokens[hash], nil
}

func (m *memoryAuthRepo) DeleteToken(ctx context.Context, id uuid.UUID) error {
	for k, v := range m.tokens {
		if v.ID == id {
			delete(m.tokens, k)
			break
		}
	}
	return nil
}

func (m *memoryAuthRepo) DeleteAllUserTokens(ctx context.Context, userID uuid.UUID) error {
	for k, v := range m.tokens {
		if v.UserID == userID {
			delete(m.tokens, k)
		}
	}
	return nil
}

func (m *memoryAuthRepo) LogLogin(ctx context.Context, log *auth.LoginHistory) error {
	m.loginLogs = append(m.loginLogs, log)
	return nil
}

type mockSMSProvider struct{}

func (s *mockSMSProvider) SendSMS(phone, message string) error {
	return nil
}

func TestAuthService_FullLifecycle_And_Rotation(t *testing.T) {
	repo := newMemoryAuthRepo()
	cfg := &config.Config{}
	cfg.Auth.AccessTokenTTL = 15 * time.Minute
	cfg.Auth.RefreshTokenTTL = 720 * time.Hour
	cfg.Auth.OTPLength = 6
	cfg.Auth.OTPMaxAttempts = 3
	cfg.Auth.OTPTTL = 5 * time.Minute

	service := auth.NewAuthService(repo, nil, &mockSMSProvider{}, cfg)
	ctx := context.Background()

	// 1. Send OTP
	phone := "+2250506169325"
	err := service.SendOTP(ctx, phone)
	require.NoError(t, err)

	otp, err := repo.GetOTP(ctx, phone)
	require.NoError(t, err)
	require.NotNil(t, otp)

	// Simulate known OTP
	code := "123456"
	codeHashBytes := sha256.Sum256([]byte(code))
	otp.CodeHash = hex.EncodeToString(codeHashBytes[:])

	// 2. Verify OTP
	authResp, err := service.VerifyOTP(ctx, phone, code, "test_device")
	require.NoError(t, err)
	require.NotEmpty(t, authResp.AccessToken)
	require.NotEmpty(t, authResp.RefreshToken)
	require.Equal(t, phone, authResp.User.PhoneNumber)

	initialAccessToken := authResp.AccessToken
	initialRefreshToken := authResp.RefreshToken

	// 3. Refresh Token - 1st time (valid rotation)
	refreshedResp, err := service.RefreshToken(ctx, initialRefreshToken)
	require.NoError(t, err)
	require.NotEmpty(t, refreshedResp.AccessToken)
	require.NotEmpty(t, refreshedResp.RefreshToken)
	assert.NotEqual(t, initialAccessToken, refreshedResp.AccessToken)
	assert.NotEqual(t, initialRefreshToken, refreshedResp.RefreshToken)

	// 4. Refresh Token - 2nd time with OLD refresh token (Must fail due to single-use rotation!)
	_, err = service.RefreshToken(ctx, initialRefreshToken)
	assert.ErrorIs(t, err, common.ErrUnauthorized)

	// 5. Refresh Token with the NEW refresh token (Must succeed!)
	secondRefreshedResp, err := service.RefreshToken(ctx, refreshedResp.RefreshToken)
	require.NoError(t, err)
	require.NotEmpty(t, secondRefreshedResp.AccessToken)

	// 6. Logout with active access token
	err = service.Logout(ctx, secondRefreshedResp.AccessToken)
	require.NoError(t, err)

	// Verify token was deleted from storage
	accHash := sha256.Sum256([]byte(secondRefreshedResp.AccessToken))
	accTokenHash := hex.EncodeToString(accHash[:])
	storedToken, err := repo.FindTokenByHash(ctx, accTokenHash)
	require.NoError(t, err)
	assert.Nil(t, storedToken)
}
