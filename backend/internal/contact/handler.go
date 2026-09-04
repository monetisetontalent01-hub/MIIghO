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

	// Contact request routes
	cg.POST("/requests", h.sendContactRequest)
	cg.GET("/requests", h.getContactRequests)
	cg.POST("/requests/:id/accept", h.acceptContactRequest)
	cg.POST("/requests/:id/reject", h.rejectContactRequest)
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

// ---- Contact Request handlers ----

type sendContactRequestPayload struct {
	RecipientID string `json:"recipient_id"`
}

func (h *ContactHandler) sendContactRequest(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	var payload sendContactRequestPayload
	if err := c.Bind(&payload); err != nil {
		return common.ErrBadRequest
	}

	recipientID, err := uuid.Parse(payload.RecipientID)
	if err != nil {
		return &common.AppError{Code: 400, Message: "Invalid recipient_id"}
	}

	req, err := h.service.SendContactRequest(c.Request().Context(), userIdent.ID, recipientID)
	if err != nil {
		return &common.AppError{Code: 400, Message: err.Error()}
	}

	return common.SuccessResponse(c, req)
}

func (h *ContactHandler) getContactRequests(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	direction := c.QueryParam("direction")
	if direction == "" {
		direction = "incoming"
	}

	requests, err := h.service.GetContactRequests(c.Request().Context(), userIdent.ID, direction)
	if err != nil {
		return err
	}

	return common.SuccessResponse(c, requests)
}

func (h *ContactHandler) acceptContactRequest(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	requestID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return &common.AppError{Code: 400, Message: "Invalid request ID"}
	}

	if err := h.service.AcceptContactRequest(c.Request().Context(), requestID, userIdent.ID); err != nil {
		return &common.AppError{Code: 400, Message: err.Error()}
	}

	return common.SuccessResponse(c, map[string]string{"message": "contact request accepted"})
}

func (h *ContactHandler) rejectContactRequest(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	requestID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return &common.AppError{Code: 400, Message: "Invalid request ID"}
	}

	if err := h.service.RejectContactRequest(c.Request().Context(), requestID, userIdent.ID); err != nil {
		return &common.AppError{Code: 400, Message: err.Error()}
	}

	return common.SuccessResponse(c, map[string]string{"message": "contact request rejected"})
}
