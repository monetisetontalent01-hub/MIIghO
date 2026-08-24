package common

import (
	"fmt"
	"net/http"

	"github.com/labstack/echo/v4"
)

// AppError represents an application-specific error.
type AppError struct {
	Code    int                    `json:"code"`
	Message string                 `json:"message"`
	Details map[string]interface{} `json:"details,omitempty"`
}

func (e *AppError) Error() string {
	return fmt.Sprintf("code=%d, message=%s", e.Code, e.Message)
}

// Standard application errors
var (
	ErrNotFound     = &AppError{Code: http.StatusNotFound, Message: "Resource not found"}
	ErrUnauthorized = &AppError{Code: http.StatusUnauthorized, Message: "Unauthorized access"}
	ErrForbidden    = &AppError{Code: http.StatusForbidden, Message: "Access forbidden"}
	ErrBadRequest   = &AppError{Code: http.StatusBadRequest, Message: "Bad request"}
	ErrConflict     = &AppError{Code: http.StatusConflict, Message: "Resource conflict"}
	ErrInternal     = &AppError{Code: http.StatusInternalServerError, Message: "Internal server error"}
	ErrRateLimited  = &AppError{Code: http.StatusTooManyRequests, Message: "Rate limit exceeded"}
)

// ErrorHandler maps application errors to HTTP responses in Echo.
func ErrorHandler(err error, c echo.Context) {
	if c.Response().Committed {
		return
	}

	var appErr *AppError
	if e, ok := err.(*AppError); ok {
		appErr = e
	} else if e, ok := err.(*echo.HTTPError); ok {
		appErr = &AppError{Code: e.Code, Message: fmt.Sprintf("%v", e.Message)}
	} else {
		appErr = ErrInternal
	}

	c.JSON(appErr.Code, map[string]interface{}{
		"error": appErr,
	})
}
