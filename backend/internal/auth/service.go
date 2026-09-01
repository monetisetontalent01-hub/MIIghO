package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/internal/config"
	"github.com/miigho/miigho/pkg/cache"
)

// SMSProvider interface defines sms sending capabilities.
type SMSProvider interface {
	SendSMS(phone, message string) error
}

// AuthService contains business logic for authentication.
type AuthService struct {
	repo        AuthRepository
	valkey      *cache.ValkeyClient
	smsProvider SMSProvider
	config      *config.Config
}

func NewAuthService(repo AuthRepository, valkey *cache.ValkeyClient, sms SMSProvider, cfg *config.Config) *AuthService {
	return &AuthService{
		repo:        repo,
		valkey:      valkey,
		smsProvider: sms,
		config:      cfg,
	}
}

func (s *AuthService) SendOTP(ctx context.Context, phone string) error {
	// Generate OTP
	code := "123456" // Hardcoded for MVP, in production use crypto/rand

	hash := sha256.Sum256([]byte(code))
	codeHash := hex.EncodeToString(hash[:])

	otp := &OTPCode{
		PhoneNumber: phone,
		CodeHash:    codeHash,
		ExpiresAt:   time.Now().Add(s.config.Auth.OTPTTL),
	}

	if err := s.repo.StoreOTP(ctx, otp); err != nil {
		return fmt.Errorf("failed to store OTP: %w", err)
	}

	msg := fmt.Sprintf("Your MÏÏghO code is %s", code)
	if err := s.smsProvider.SendSMS(phone, msg); err != nil {
		return fmt.Errorf("failed to send SMS: %w", err)
	}

	return nil
}

func (s *AuthService) VerifyOTP(ctx context.Context, phone, code, deviceInfo string) (*AuthResponse, error) {
	otp, err := s.repo.GetOTP(ctx, phone)
	if err != nil {
		return nil, fmt.Errorf("failed to get OTP: %w", err)
	}
	if otp == nil {
		return nil, common.ErrBadRequest
	}

	if time.Now().After(otp.ExpiresAt) {
		return nil, common.ErrBadRequest
	}

	hash := sha256.Sum256([]byte(code))
	codeHash := hex.EncodeToString(hash[:])

	if otp.CodeHash != codeHash {
		s.repo.IncrementOTPAttempts(ctx, phone)
		return nil, common.ErrUnauthorized
	}

	s.repo.DeleteOTP(ctx, phone)

	user, err := s.repo.FindUserByPhone(ctx, phone)
	if err != nil {
		return nil, fmt.Errorf("failed to check user: %w", err)
	}

	if user == nil {
		user = &User{
			ID:          uuid.New(),
			PhoneNumber: phone,
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		}
		if err := s.repo.CreateUser(ctx, user); err != nil {
			return nil, fmt.Errorf("failed to create user: %w", err)
		}
	}

	return s.generateTokenPair(ctx, user)
}

func (s *AuthService) RefreshToken(ctx context.Context, refreshTokenStr string) (*AuthResponse, error) {
	hash := sha256.Sum256([]byte(refreshTokenStr))
	tokenHash := hex.EncodeToString(hash[:])

	token, err := s.repo.FindTokenByHash(ctx, tokenHash)
	if err != nil {
		return nil, fmt.Errorf("failed to find token: %w", err)
	}
	if token == nil || token.Type != "refresh" || time.Now().After(token.ExpiresAt) {
		return nil, common.ErrUnauthorized
	}

	// Single-use refresh token
	s.repo.DeleteToken(ctx, token.ID)

	user, err := s.repo.FindUserByID(ctx, token.UserID)
	if err != nil || user == nil {
		user = &User{ID: token.UserID}
	}

	return s.generateTokenPair(ctx, user)
}

func (s *AuthService) Logout(ctx context.Context, tokenStr string) error {
	hash := sha256.Sum256([]byte(tokenStr))
	tokenHash := hex.EncodeToString(hash[:])

	token, err := s.repo.FindTokenByHash(ctx, tokenHash)
	if err != nil || token == nil {
		return nil // Ignore if already invalid
	}

	return s.repo.DeleteToken(ctx, token.ID)
}

func (s *AuthService) LogoutAll(ctx context.Context, userID uuid.UUID) error {
	return s.repo.DeleteAllUserTokens(ctx, userID)
}

func (s *AuthService) generateTokenPair(ctx context.Context, user *User) (*AuthResponse, error) {
	accessTokenStr := s.generateRandomToken()
	refreshTokenStr := s.generateRandomToken()

	accHash := sha256.Sum256([]byte(accessTokenStr))
	refHash := sha256.Sum256([]byte(refreshTokenStr))

	now := time.Now()
	accToken := &AuthToken{
		ID:        uuid.New(),
		UserID:    user.ID,
		TokenHash: hex.EncodeToString(accHash[:]),
		Type:      "access",
		ExpiresAt: now.Add(s.config.Auth.AccessTokenTTL),
		CreatedAt: now,
	}

	refToken := &AuthToken{
		ID:        uuid.New(),
		UserID:    user.ID,
		TokenHash: hex.EncodeToString(refHash[:]),
		Type:      "refresh",
		ExpiresAt: now.Add(s.config.Auth.RefreshTokenTTL),
		CreatedAt: now,
	}

	if err := s.repo.StoreToken(ctx, accToken); err != nil {
		return nil, err
	}
	if err := s.repo.StoreToken(ctx, refToken); err != nil {
		return nil, err
	}

	return &AuthResponse{
		AccessToken:  accessTokenStr,
		RefreshToken: refreshTokenStr,
		ExpiresAt:    accToken.ExpiresAt,
		User:         *user,
	}, nil
}

func (s *AuthService) generateRandomToken() string {
	b := make([]byte, 32)
	rand.Read(b)
	return hex.EncodeToString(b)
}
