package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/platform/identity"
	"github.com/stretchr/testify/assert"
)

func TestAuthMiddleware_Production_RejectsRawUUID(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	rawUUID := uuid.New().String()
	req.Header.Set("Authorization", "Bearer "+rawUUID)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	authMw := AuthMiddleware(nil, nil, "production")
	handler := authMw(func(c echo.Context) error {
		return c.String(http.StatusOK, "should_not_reach")
	})

	err := handler(c)
	assert.Error(t, err, "Raw UUID token must be rejected in production mode")
}

func TestAuthMiddleware_Development_AllowsRawUUID(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	rawUUID := uuid.New().String()
	req.Header.Set("Authorization", "Bearer "+rawUUID)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	authMw := AuthMiddleware(nil, nil, "development")
	var capturedUser *identity.UserIdentity
	handler := authMw(func(c echo.Context) error {
		capturedUser, _ = identity.GetUserIdentity(c)
		return c.String(http.StatusOK, "ok")
	})

	err := handler(c)
	assert.NoError(t, err, "Raw UUID token is allowed in development mode")
	assert.NotNil(t, capturedUser)
	assert.Equal(t, rawUUID, capturedUser.ID.String())
}

func TestWsAuthMiddleware_Production_RejectsRawUUID(t *testing.T) {
	e := echo.New()
	rawUUID := uuid.New().String()
	req := httptest.NewRequest(http.MethodGet, "/ws?token="+rawUUID, nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	wsAuthMw := WsAuthMiddleware(nil, nil, "production")
	handler := wsAuthMw(func(c echo.Context) error {
		return c.String(http.StatusOK, "should_not_reach")
	})

	_ = handler(c)
	assert.Equal(t, http.StatusUnauthorized, rec.Code, "Raw UUID query param must be rejected in production mode")
}

func TestWsAuthMiddleware_Development_AllowsRawUUID(t *testing.T) {
	e := echo.New()
	rawUUID := uuid.New().String()
	req := httptest.NewRequest(http.MethodGet, "/ws?token="+rawUUID, nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	wsAuthMw := WsAuthMiddleware(nil, nil, "development")
	var capturedUser *identity.UserIdentity
	handler := wsAuthMw(func(c echo.Context) error {
		capturedUser, _ = identity.GetUserIdentity(c)
		return c.String(http.StatusOK, "ok")
	})

	err := handler(c)
	assert.NoError(t, err, "Raw UUID token is allowed in development mode")
	assert.NotNil(t, capturedUser)
	assert.Equal(t, rawUUID, capturedUser.ID.String())
}
