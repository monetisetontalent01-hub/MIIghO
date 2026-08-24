package media

import (
	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/internal/platform/identity"
)

type MediaHandler struct {
	service *MediaService
}

func NewMediaHandler(service *MediaService) *MediaHandler {
	return &MediaHandler{service: service}
}

func (h *MediaHandler) RegisterRoutes(g *echo.Group, authMiddleware echo.MiddlewareFunc) {
	mg := g.Group("/media")
	mg.Use(authMiddleware)

	mg.POST("/upload/request", h.requestUpload)
	mg.POST("/upload/complete", h.completeUpload)
}

func (h *MediaHandler) requestUpload(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	var req UploadRequest
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}

	resp, err := h.service.RequestUpload(c.Request().Context(), userIdent.ID, &req)
	if err != nil {
		return err
	}

	return common.SuccessResponse(c, resp)
}

func (h *MediaHandler) completeUpload(c echo.Context) error {
	var req UploadCompleteRequest
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}

	mf, err := h.service.CompleteUpload(c.Request().Context(), &req)
	if err != nil {
		return err
	}

	return common.SuccessResponse(c, mf)
}
