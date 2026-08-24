package chat

import (
	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/common"
)

type ChatHandler struct {
	service *ChatService
}

func NewChatHandler(service *ChatService) *ChatHandler {
	return &ChatHandler{service: service}
}

func (h *ChatHandler) RegisterRoutes(g *echo.Group, authMiddleware echo.MiddlewareFunc) {
	chatGroup := g.Group("/chat")
	chatGroup.Use(authMiddleware)

	chatGroup.GET("/conversations", h.listConversations)
	chatGroup.POST("/conversations", h.createConversation)
	chatGroup.GET("/conversations/:id/messages", h.getMessages)
}

func (h *ChatHandler) listConversations(c echo.Context) error {
	// Stub implementation
	return common.SuccessResponse(c, []string{})
}

func (h *ChatHandler) createConversation(c echo.Context) error {
	// Stub implementation
	return common.CreatedResponse(c, map[string]string{"id": "conv123"})
}

func (h *ChatHandler) getMessages(c echo.Context) error {
	// Stub implementation
	return common.SuccessResponse(c, []string{})
}
