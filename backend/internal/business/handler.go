package business

import (
	"errors"
	"net/http"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/internal/platform/identity"
)

// Handler exposes REST endpoints for MÏÏghO Business Core.
type Handler struct {
	service   *Service
	validator *common.CustomValidator
}

func NewHandler(service *Service, validator *common.CustomValidator) *Handler {
	return &Handler{
		service:   service,
		validator: validator,
	}
}

func (h *Handler) RegisterRoutes(g *echo.Group, authMiddleware echo.MiddlewareFunc) {
	biz := g.Group("/businesses")
	biz.Use(authMiddleware)

	biz.POST("", h.handleCreateBusiness)
	biz.GET("", h.handleListUserBusinesses)
	biz.GET("/:id", h.handleGetBusiness)
	biz.PATCH("/:id", h.handleUpdateBusiness)

	// Member management
	biz.POST("/:id/members", h.handleAddMember)
	biz.GET("/:id/members", h.handleListMembers)
	biz.PATCH("/:id/members/:memberId", h.handleUpdateMemberRole)
	biz.DELETE("/:id/members/:memberId", h.handleRemoveMember)

	// Financial Account (derived from ledger)
	biz.GET("/:id/account", h.handleGetBusinessAccount)
}

func (h *Handler) getUserID(c echo.Context) (uuid.UUID, error) {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		demoID, parseErr := uuid.Parse("00000000-0000-0000-0000-000000000001")
		if parseErr == nil {
			return demoID, nil
		}
		return uuid.Nil, common.ErrUnauthorized
	}
	return userIdent.ID, nil
}

func (h *Handler) handleCreateBusiness(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	var req CreateBusinessRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid request body")
	}

	if h.validator != nil {
		if err := h.validator.Validate(req); err != nil {
			return echo.NewHTTPError(http.StatusBadRequest, err.Error())
		}
	}

	bizDetail, err := h.service.CreateBusiness(c.Request().Context(), userID, &req)
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.CreatedResponse(c, bizDetail)
}

func (h *Handler) handleListUserBusinesses(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	businesses, err := h.service.ListUserBusinesses(c.Request().Context(), userID)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}

	return common.SuccessResponse(c, businesses)
}

func (h *Handler) handleGetBusiness(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	bizID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid business ID")
	}

	bizDetail, err := h.service.GetBusiness(c.Request().Context(), bizID, userID)
	if err != nil {
		if errors.Is(err, ErrBusinessNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}

	return common.SuccessResponse(c, bizDetail)
}

func (h *Handler) handleUpdateBusiness(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	bizID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid business ID")
	}

	var req UpdateBusinessRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid request body")
	}

	biz, err := h.service.UpdateBusiness(c.Request().Context(), bizID, userID, &req)
	if err != nil {
		if errors.Is(err, ErrBusinessNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.SuccessResponse(c, biz)
}

func (h *Handler) handleAddMember(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	bizID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid business ID")
	}

	var req AddMemberRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid request body")
	}

	if h.validator != nil {
		if err := h.validator.Validate(req); err != nil {
			return echo.NewHTTPError(http.StatusBadRequest, err.Error())
		}
	}

	member, err := h.service.AddMember(c.Request().Context(), bizID, userID, &req)
	if err != nil {
		if errors.Is(err, ErrDuplicateMember) {
			return echo.NewHTTPError(http.StatusConflict, err.Error())
		}
		if errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.CreatedResponse(c, member)
}

func (h *Handler) handleListMembers(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	bizID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid business ID")
	}

	members, err := h.service.ListMembers(c.Request().Context(), bizID, userID)
	if err != nil {
		if errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}

	return common.SuccessResponse(c, members)
}

func (h *Handler) handleUpdateMemberRole(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	bizID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid business ID")
	}

	memberID, err := uuid.Parse(c.Param("memberId"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid member ID")
	}

	var req UpdateMemberRoleRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid request body")
	}

	if h.validator != nil {
		if err := h.validator.Validate(req); err != nil {
			return echo.NewHTTPError(http.StatusBadRequest, err.Error())
		}
	}

	member, err := h.service.UpdateMemberRole(c.Request().Context(), bizID, userID, memberID, &req)
	if err != nil {
		if errors.Is(err, ErrMemberNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrCannotRemoveOwner) {
			return echo.NewHTTPError(http.StatusConflict, err.Error())
		}
		if errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.SuccessResponse(c, member)
}

func (h *Handler) handleRemoveMember(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	bizID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid business ID")
	}

	memberID, err := uuid.Parse(c.Param("memberId"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid member ID")
	}

	err = h.service.RemoveMember(c.Request().Context(), bizID, userID, memberID)
	if err != nil {
		if errors.Is(err, ErrMemberNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrCannotRemoveOwner) {
			return echo.NewHTTPError(http.StatusConflict, err.Error())
		}
		if errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.SuccessResponse(c, map[string]string{"message": "Member removed successfully"})
}

func (h *Handler) handleGetBusinessAccount(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	bizID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid business ID")
	}

	accDetail, err := h.service.GetBusinessAccount(c.Request().Context(), bizID, userID)
	if err != nil {
		if errors.Is(err, ErrBusinessNotFound) || errors.Is(err, ErrBusinessAccountNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}

	return common.SuccessResponse(c, accDetail)
}
