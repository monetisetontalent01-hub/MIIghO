package middleware

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/internal/platform/identity"
	"github.com/miigho/miigho/pkg/cache"
)

// RateLimitMiddleware applies rate limiting per UserID (for authenticated requests) or per IP (for anonymous requests).
func RateLimitMiddleware(valkeyClient *cache.ValkeyClient, pgPool *pgxpool.Pool, serverMode string, limit int, window time.Duration) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			ctx := c.Request().Context()
			if ctx == nil {
				ctx = context.Background()
			}

			var key string
			// 1. Check if user identity is already set in context
			userIdent, err := identity.GetUserIdentity(c)
			if err != nil || userIdent == nil {
				// 2. If not yet in context, check Authorization Bearer header to resolve canonical UserID
				authHeader := c.Request().Header.Get("Authorization")
				if strings.HasPrefix(authHeader, "Bearer ") {
					token := strings.TrimPrefix(authHeader, "Bearer ")
					if u, rErr := resolveUserIdentity(ctx, pgPool, token, serverMode); rErr == nil && u != nil {
						userIdent = u
						identity.SetUserIdentity(c, u)
					}
				}
			}

			if userIdent != nil {
				key = fmt.Sprintf("ratelimit:user:%s", userIdent.ID.String())
			} else {
				// Fallback to IP address for anonymous requests
				key = fmt.Sprintf("ratelimit:ip:%s", c.RealIP())
			}

			count, err := valkeyClient.IncrementRateLimit(ctx, key, window)
			if err != nil {
				// Log error, but allow request to pass to avoid total failure on cache down
				return next(c)
			}

			if count > int64(limit) {
				c.Response().Header().Set("Retry-After", fmt.Sprintf("%.0f", window.Seconds()))
				return common.ErrRateLimited
			}

			return next(c)
		}
	}
}
