package chat

import (
	"net/http"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/internal/platform/identity"
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
	chatGroup.POST("/conversations/:id/messages", h.sendMessage)
	chatGroup.POST("/conversations/:id/read", h.markRead)
}

// listConversations returns paginated conversations for the authenticated user.
func (h *ChatHandler) listConversations(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	cursor := c.QueryParam("cursor")
	conversations, nextCursor, err := h.service.repo.ListConversations(c.Request().Context(), userIdent.ID, cursor, 20)
	if err != nil {
		return common.ErrInternal
	}

	return common.PaginatedResponse(c, conversations, nextCursor)
}

// createConversation creates a new direct conversation between two users.
func (h *ChatHandler) createConversation(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	var req struct {
		RecipientID string `json:"recipient_id"`
	}
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}

	recipientID, err := uuid.Parse(req.RecipientID)
	if err != nil {
		return &common.AppError{Code: http.StatusBadRequest, Message: "invalid recipient_id"}
	}

	conv, err := h.service.repo.CreateDirectConversation(c.Request().Context(), userIdent.ID, recipientID)
	if err != nil {
		return common.ErrInternal
	}

	return common.CreatedResponse(c, conv)
}

// getMessages returns paginated messages for a conversation.
func (h *ChatHandler) getMessages(c echo.Context) error {
	_, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	convID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return common.ErrBadRequest
	}

	cursor := c.QueryParam("cursor")
	messages, nextCursor, err := h.service.repo.GetMessages(c.Request().Context(), convID, cursor, 50)
	if err != nil {
		return common.ErrInternal
	}

	return common.PaginatedResponse(c, messages, nextCursor)
}

// sendMessage sends a new message in a conversation.
func (h *ChatHandler) sendMessage(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	convID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return common.ErrBadRequest
	}

	var req struct {
		Content string `json:"content"`
		Type    string `json:"type"`
	}
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}
	if req.Content == "" {
		return &common.AppError{Code: http.StatusBadRequest, Message: "content is required"}
	}

	msgType := MsgText
	switch MessageType(req.Type) {
	case MsgImage, MsgVideo, MsgAudio, MsgVoice, MsgFile:
		msgType = MessageType(req.Type)
	}

	msg, err := h.service.SendMessage(c.Request().Context(), convID, userIdent.ID, []byte(req.Content), msgType)
	if err != nil {
		return common.ErrInternal
	}

	return common.CreatedResponse(c, msg)
}

// markRead marks all messages in a conversation as read up to a specific message.
func (h *ChatHandler) markRead(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	convID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return common.ErrBadRequest
	}

	var req struct {
		MessageID string `json:"message_id"`
	}
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}

	msgID, err := uuid.Parse(req.MessageID)
	if err != nil {
		return &common.AppError{Code: http.StatusBadRequest, Message: "invalid message_id"}
	}

	if err := h.service.MarkRead(c.Request().Context(), convID, userIdent.ID, msgID); err != nil {
		return common.ErrInternal
	}

	return common.SuccessResponse(c, map[string]string{"message": "marked as read"})
}
