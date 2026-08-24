package middleware

import (
	"context"
	"fmt"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/internal/platform/identity"
	"github.com/miigho/miigho/pkg/cache"
)

// RateLimitMiddleware applies rate limiting per IP or per UserID.
func RateLimitMiddleware(valkeyClient *cache.ValkeyClient, limit int, window time.Duration) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			ctx := context.Background()

			var key string
			// Try to get UserID if authenticated
			userIdent, err := identity.GetUserIdentity(c)
			if err == nil && userIdent != nil {
				key = fmt.Sprintf("ratelimit:user:%s", userIdent.ID.String())
			} else {
				// Fallback to IP address
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
