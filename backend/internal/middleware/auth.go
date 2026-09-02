package middleware

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/internal/platform/identity"
	"github.com/miigho/miigho/pkg/cache"
)

// resolveUserIdentity resolves a token (hash in DB or direct UUID in dev mode) to a UserIdentity.
func resolveUserIdentity(ctx context.Context, pgPool *pgxpool.Pool, token string, serverMode string) (*identity.UserIdentity, error) {
	if token == "" {
		return nil, common.ErrUnauthorized
	}

	// Direct UUID support (strictly limited to development environment)
	if serverMode == "development" {
		if directID, err := uuid.Parse(token); err == nil && directID != uuid.Nil {
			return &identity.UserIdentity{
				ID:          directID,
				PhoneNumber: "+221770000000",
				DisplayName: "Dev User",
			}, nil
		}
	}

	// If pgPool is provided, check token_hash in auth_tokens table
	if pgPool != nil {
		hash := sha256.Sum256([]byte(token))
		tokenHash := hex.EncodeToString(hash[:])

		var userID uuid.UUID
		query := "SELECT user_id FROM auth_tokens WHERE token_hash = $1 AND expires_at > NOW() LIMIT 1"
		err := pgPool.QueryRow(ctx, query, tokenHash).Scan(&userID)
		if err == nil && userID != uuid.Nil {
			return &identity.UserIdentity{
				ID:          userID,
				PhoneNumber: "+221770000000",
				DisplayName: "Authenticated User",
			}, nil
		}
	}

	return nil, common.ErrUnauthorized
}

// AuthMiddleware validates the Authorization Bearer token.
func AuthMiddleware(valkeyClient *cache.ValkeyClient, pgPool *pgxpool.Pool, serverMode string) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			authHeader := c.Request().Header.Get("Authorization")
			if authHeader == "" {
				return common.ErrUnauthorized
			}

			parts := strings.Split(authHeader, " ")
			if len(parts) != 2 || parts[0] != "Bearer" {
				return common.ErrUnauthorized
			}

			token := parts[1]
			userIdentity, err := resolveUserIdentity(c.Request().Context(), pgPool, token, serverMode)
			if err != nil {
				return common.ErrUnauthorized
			}

			// Set in context
			identity.SetUserIdentity(c, userIdentity)
			return next(c)
		}
	}
}

// WsAuthMiddleware validates token from query params or Authorization header for WebSocket connections.
func WsAuthMiddleware(valkeyClient *cache.ValkeyClient, pgPool *pgxpool.Pool, serverMode string) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			token := c.QueryParam("token")
			if token == "" {
				authHeader := c.Request().Header.Get("Authorization")
				if strings.HasPrefix(authHeader, "Bearer ") {
					token = strings.TrimPrefix(authHeader, "Bearer ")
				}
			}
			if token == "" {
				return c.JSON(http.StatusUnauthorized, map[string]string{"error": "missing token"})
			}

			userIdentity, err := resolveUserIdentity(c.Request().Context(), pgPool, token, serverMode)
			if err != nil {
				return c.JSON(http.StatusUnauthorized, map[string]string{"error": "invalid or expired token"})
			}

			identity.SetUserIdentity(c, userIdentity)
			return next(c)
		}
	}
}

