package identity

import (
	"errors"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

// ContextKey is the key used to store UserIdentity in the Echo context.
const ContextKey = "user_identity"

// UserIdentity represents the authenticated user's core identity.
// Extracted from the auth token and injected into request context.
type UserIdentity struct {
	ID          uuid.UUID `json:"id"`
	PhoneNumber string    `json:"phone_number"`
	DisplayName string    `json:"display_name"`
}

// GetUserIdentity retrieves the UserIdentity from the Echo context.
func GetUserIdentity(c echo.Context) (*UserIdentity, error) {
	identity, ok := c.Get(ContextKey).(*UserIdentity)
	if !ok || identity == nil {
		return nil, errors.New("user identity not found in context")
	}
	return identity, nil
}

// SetUserIdentity sets the UserIdentity in the Echo context.
func SetUserIdentity(c echo.Context, identity *UserIdentity) {
	c.Set(ContextKey, identity)
}
