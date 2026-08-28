package contact

import (
	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/internal/platform/identity"
)

type ContactHandler struct {
	service *ContactService
}

func NewContactHandler(service *ContactService) *ContactHandler {
	return &ContactHandler{service: service}
}

func (h *ContactHandler) RegisterRoutes(g *echo.Group, authMiddleware echo.MiddlewareFunc) {
	cg := g.Group("/contacts")
	cg.Use(authMiddleware)

	cg.POST("/sync", h.syncContacts)
	cg.GET("", h.listContacts)
	cg.GET("/search", h.searchContacts)
	cg.POST("/:id/block", h.blockUser)
	cg.POST("/:id/favorite", h.favoriteUser)
}

func (h *ContactHandler) searchContacts(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}
	query := c.QueryParam("q")
	if query == "" {
		query = c.QueryParam("phone")
	}
	if query == "" {
		return common.SuccessResponse(c, []ContactUser{})
	}

	results, err := h.service.SearchUsers(c.Request().Context(), userIdent.ID, query)
	if err != nil {
		return err
	}
	if results == nil {
		results = []ContactUser{}
	}
	return common.SuccessResponse(c, results)
}

func (h *ContactHandler) syncContacts(c echo.Context) error {
	userIdent, _ := identity.GetUserIdentity(c)
	var req SyncContactsRequest
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}

	resp, err := h.service.SyncContacts(c.Request().Context(), userIdent.ID, req.PhoneNumbers)
	if err != nil {
		return err
	}

	return common.SuccessResponse(c, resp)
}

func (h *ContactHandler) listContacts(c echo.Context) error {
	userIdent, _ := identity.GetUserIdentity(c)
	contacts, err := h.service.ListContactUsers(c.Request().Context(), userIdent.ID)
	if err != nil {
		return err
	}
	if contacts == nil {
		contacts = []ContactUser{}
	}
	return common.SuccessResponse(c, contacts)
}

func (h *ContactHandler) blockUser(c echo.Context) error {
	userIdent, _ := identity.GetUserIdentity(c)
	id, _ := uuid.Parse(c.Param("id"))
	if err := h.service.BlockUser(c.Request().Context(), userIdent.ID, id); err != nil {
		return err
	}
	return common.SuccessResponse(c, map[string]string{"message": "user blocked"})
}

func (h *ContactHandler) favoriteUser(c echo.Context) error {
	userIdent, _ := identity.GetUserIdentity(c)
	id, _ := uuid.Parse(c.Param("id"))
	if err := h.service.FavoriteUser(c.Request().Context(), userIdent.ID, id); err != nil {
		return err
	}
	return common.SuccessResponse(c, map[string]string{"message": "user favorited"})
}
