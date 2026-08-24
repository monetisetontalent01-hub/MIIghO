package user

import (
	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/internal/platform/identity"
)

// UserHandler handles HTTP requests for user profiles.
type UserHandler struct {
	service *UserService
}

func NewUserHandler(service *UserService) *UserHandler {
	return &UserHandler{service: service}
}

func (h *UserHandler) RegisterRoutes(g *echo.Group, authMiddleware echo.MiddlewareFunc) {
	users := g.Group("/users")
	users.Use(authMiddleware)

	users.GET("/me", h.handleGetMe)
	users.PUT("/me", h.handleUpdateMe)
	users.GET("/:id", h.handleGetProfile)
	users.GET("/:id/presence", h.handleGetPresence)
	users.PUT("/me/presence", h.handleSetPresence)
}

func (h *UserHandler) handleGetMe(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	profile, err := h.service.GetProfile(c.Request().Context(), userIdent.ID)
	if err != nil {
		return err
	}

	return common.SuccessResponse(c, profile)
}

func (h *UserHandler) handleUpdateMe(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	var req UpdateProfileRequest
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}

	profile, err := h.service.UpdateProfile(c.Request().Context(), userIdent.ID, &req)
	if err != nil {
		return err
	}

	return common.SuccessResponse(c, profile)
}

func (h *UserHandler) handleGetProfile(c echo.Context) error {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		return common.ErrBadRequest
	}

	profile, err := h.service.GetProfile(c.Request().Context(), id)
	if err != nil {
		return err
	}

	return common.SuccessResponse(c, profile)
}

func (h *UserHandler) handleGetPresence(c echo.Context) error {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		return common.ErrBadRequest
	}

	presence, err := h.service.GetPresence(c.Request().Context(), id)
	if err != nil {
		return err
	}

	return common.SuccessResponse(c, presence)
}

func (h *UserHandler) handleSetPresence(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	var req map[string]string
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}
	status := req["status"]

	if err := h.service.SetPresence(c.Request().Context(), userIdent.ID, status); err != nil {
		return common.ErrInternal
	}

	return common.SuccessResponse(c, map[string]string{"message": "presence updated"})
}
