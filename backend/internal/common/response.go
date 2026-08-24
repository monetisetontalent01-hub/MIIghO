package common

import (
	"net/http"

	"github.com/labstack/echo/v4"
)

// SuccessResponse formats and returns a standard successful JSON response.
func SuccessResponse(c echo.Context, data interface{}) error {
	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    data,
	})
}

// CreatedResponse formats and returns a standard resource creation JSON response.
func CreatedResponse(c echo.Context, data interface{}) error {
	return c.JSON(http.StatusCreated, map[string]interface{}{
		"success": true,
		"data":    data,
	})
}

// PaginatedResponse formats and returns a standard paginated JSON response.
func PaginatedResponse(c echo.Context, data interface{}, nextCursor string) error {
	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    data,
		"meta": map[string]interface{}{
			"next_cursor": nextCursor,
		},
	})
}
