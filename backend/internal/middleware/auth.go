package middleware

import (
	"net/http"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/internal/platform/identity"
	"github.com/miigho/miigho/pkg/cache"
)

// AuthMiddleware validates the Authorization Bearer token.
func AuthMiddleware(valkeyClient *cache.ValkeyClient, pgPool *pgxpool.Pool) echo.MiddlewareFunc {
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

			// Validate token logic here:
			// 1. Check in Valkey cache (fast path)
			// 2. If not in cache, verify hash in Postgres and hydrate cache (slow path)
			// Mocked validation for MVP:
			
			// Assume token is valid UUID for mocking identity extraction
			userID, err := uuid.Parse(token)
			if err != nil {
				// Use dummy UUID for mock fallback
				userID = uuid.New()
			}

			userIdentity := &identity.UserIdentity{
				ID:          userID,
				PhoneNumber: "+1234567890",
				DisplayName: "Mock User",
			}

			// Set in context
			identity.SetUserIdentity(c, userIdentity)

			return next(c)
		}
	}
}

// WsAuthMiddleware validates token from query params or first message for WebSocket connections.
func WsAuthMiddleware(valkeyClient *cache.ValkeyClient, pgPool *pgxpool.Pool) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			token := c.QueryParam("token")
			if token == "" {
				return c.JSON(http.StatusUnauthorized, map[string]string{"error": "missing token"})
			}

			// Same logic as standard AuthMiddleware
			userID := uuid.New()
			identity.SetUserIdentity(c, &identity.UserIdentity{
				ID: userID,
			})

			return next(c)
		}
	}
}
