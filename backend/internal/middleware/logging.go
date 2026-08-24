package middleware

import (
	"time"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/platform/identity"
	"github.com/rs/zerolog"
)

// RequestLogger provides structured logging of HTTP requests using zerolog.
func RequestLogger(logger zerolog.Logger) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			start := time.Now()

			req := c.Request()
			res := c.Response()

			// Generate and set Request ID
			reqID := req.Header.Get(echo.HeaderXRequestID)
			if reqID == "" {
				reqID = uuid.New().String()
			}
			res.Header().Set(echo.HeaderXRequestID, reqID)

			err := next(c)
			if err != nil {
				c.Error(err)
			}

			latency := time.Since(start)

			logEvent := logger.Info()
			if res.Status >= 500 {
				logEvent = logger.Error().Err(err)
			} else if res.Status >= 400 {
				logEvent = logger.Warn().Err(err)
			}

			// Try to get UserID
			var userID string
			userIdent, _ := identity.GetUserIdentity(c)
			if userIdent != nil {
				userID = userIdent.ID.String()
			}

			logEvent.
				Str("method", req.Method).
				Str("path", req.URL.Path).
				Int("status", res.Status).
				Dur("latency", latency).
				Str("request_id", reqID).
				Str("ip", c.RealIP())

			if userID != "" {
				logEvent.Str("user_id", userID)
			}

			logEvent.Msg("HTTP Request")

			return err
		}
	}
}
