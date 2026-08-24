package auth

import (
	"time"

	"github.com/google/uuid"
)

// User represents a registered user in the system.
type User struct {
	ID          uuid.UUID `json:"id"`
	PhoneNumber string    `json:"phone_number"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// AuthToken represents a valid authentication token.
type AuthToken struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	TokenHash string    `json:"-"`
	Type      string    `json:"type"` // "access" or "refresh"
	ExpiresAt time.Time `json:"expires_at"`
	CreatedAt time.Time `json:"created_at"`
}

// OTPCode represents a One-Time Password for authentication.
type OTPCode struct {
	PhoneNumber string    `json:"phone_number"`
	CodeHash    string    `json:"-"`
	Attempts    int       `json:"attempts"`
	ExpiresAt   time.Time `json:"expires_at"`
}

// PushToken represents a device token for push notifications.
type PushToken struct {
	ID         uuid.UUID `json:"id"`
	UserID     uuid.UUID `json:"user_id"`
	DeviceID   string    `json:"device_id"`
	Token      string    `json:"token"`
	Platform   string    `json:"platform"`
	CreatedAt  time.Time `json:"created_at"`
	LastUsedAt time.Time `json:"last_used_at"`
}

// LoginHistory tracks user logins.
type LoginHistory struct {
	ID         uuid.UUID `json:"id"`
	UserID     uuid.UUID `json:"user_id"`
	IPAddress  string    `json:"ip_address"`
	DeviceInfo string    `json:"device_info"`
	CreatedAt  time.Time `json:"created_at"`
}

// DTOs

type SendOTPRequest struct {
	PhoneNumber string `json:"phone_number" validate:"required,phone"`
}

type VerifyOTPRequest struct {
	PhoneNumber string `json:"phone_number" validate:"required,phone"`
	Code        string `json:"code" validate:"required,len=6"`
	DeviceInfo  string `json:"device_info"`
}

type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" validate:"required"`
}

type AuthResponse struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
	ExpiresAt    time.Time `json:"expires_at"`
	User         User      `json:"user"`
}
