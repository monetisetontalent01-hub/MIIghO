package auth

import (
	"strings"

	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/internal/platform/identity"
)

// AuthHandler handles HTTP requests for authentication.
type AuthHandler struct {
	service   *AuthService
	validator *common.CustomValidator
}

func NewAuthHandler(service *AuthService, validator *common.CustomValidator) *AuthHandler {
	return &AuthHandler{
		service:   service,
		validator: validator,
	}
}

func (h *AuthHandler) RegisterRoutes(g *echo.Group, authMiddleware echo.MiddlewareFunc) {
	g.POST("/auth/otp/send", h.handleSendOTP)
	g.POST("/auth/otp/verify", h.handleVerifyOTP)
	g.POST("/auth/token/refresh", h.handleRefreshToken)

	secure := g.Group("/auth")
	secure.Use(authMiddleware)
	secure.POST("/logout", h.handleLogout)
	secure.POST("/logout/all", h.handleLogoutAll)
}

func (h *AuthHandler) handleSendOTP(c echo.Context) error {
	var req SendOTPRequest
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}
	if err := h.validator.Validate(&req); err != nil {
		return common.ErrBadRequest
	}

	err := h.service.SendOTP(c.Request().Context(), req.PhoneNumber)
	if err != nil {
		return common.ErrInternal
	}

	return common.SuccessResponse(c, map[string]string{"message": "OTP sent successfully"})
}

func (h *AuthHandler) handleVerifyOTP(c echo.Context) error {
	var req VerifyOTPRequest
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}
	if err := h.validator.Validate(&req); err != nil {
		return common.ErrBadRequest
	}

	resp, err := h.service.VerifyOTP(c.Request().Context(), req.PhoneNumber, req.Code, req.DeviceInfo)
	if err != nil {
		return err
	}

	return common.SuccessResponse(c, resp)
}

func (h *AuthHandler) handleRefreshToken(c echo.Context) error {
	var req RefreshTokenRequest
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}
	if err := h.validator.Validate(&req); err != nil {
		return common.ErrBadRequest
	}

	resp, err := h.service.RefreshToken(c.Request().Context(), req.RefreshToken)
	if err != nil {
		return err
	}

	return common.SuccessResponse(c, resp)
}

func (h *AuthHandler) handleLogout(c echo.Context) error {
	authHeader := c.Request().Header.Get("Authorization")
	parts := strings.Split(authHeader, " ")
	if len(parts) == 2 {
		token := parts[1]
		_ = h.service.Logout(c.Request().Context(), token)
	}
	return common.SuccessResponse(c, map[string]string{"message": "Logged out successfully"})
}

func (h *AuthHandler) handleLogoutAll(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	_ = h.service.LogoutAll(c.Request().Context(), userIdent.ID)
	return common.SuccessResponse(c, map[string]string{"message": "Logged out from all devices"})
}
