package chat

import (
	"errors"
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
	chatGroup.GET("/conversations/:id", h.getConversation)
	chatGroup.GET("/conversations/:id/messages", h.getMessages)
	chatGroup.POST("/conversations/:id/messages", h.sendMessage)
	chatGroup.POST("/conversations/:id/read", h.markRead)

	// Message Actions
	chatGroup.PATCH("/messages/:id", h.editMessage)
	chatGroup.DELETE("/messages/:id", h.deleteMessage)
	chatGroup.POST("/messages/:id/reactions", h.addReaction)
	chatGroup.DELETE("/messages/:id/reactions", h.removeReaction)
}

// getConversation returns a single conversation after IDOR validation.
func (h *ChatHandler) getConversation(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	convID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return common.ErrBadRequest
	}

	conv, err := h.service.GetConversation(c.Request().Context(), convID, userIdent.ID)
	if err != nil {
		if errors.Is(err, common.ErrForbidden) {
			return common.ErrForbidden
		}
		return common.ErrNotFound
	}

	return common.SuccessResponse(c, conv)
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

// createConversation creates a new direct or group conversation.
func (h *ChatHandler) createConversation(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	var req CreateConversationRequest
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}

	if req.Type == TypeGroup || (req.Name != nil && *req.Name != "") {
		groupName := "Nouveau Groupe"
		if req.Name != nil && *req.Name != "" {
			groupName = *req.Name
		}

		var memberUUIDs []uuid.UUID
		for _, mStr := range req.MemberIDs {
			if mID, err := uuid.Parse(mStr); err == nil {
				memberUUIDs = append(memberUUIDs, mID)
			}
		}

		conv, err := h.service.CreateGroupConversation(c.Request().Context(), userIdent.ID, groupName, memberUUIDs)
		if err != nil {
			var appErr *common.AppError
			if errors.As(err, &appErr) {
				return appErr
			}
			return common.ErrInternal
		}
		return common.CreatedResponse(c, conv)
	}

	// Direct conversation
	if req.RecipientID == nil || *req.RecipientID == "" {
		return &common.AppError{Code: http.StatusBadRequest, Message: "recipient_id is required for direct conversations"}
	}

	recipientID, err := uuid.Parse(*req.RecipientID)
	if err != nil {
		return &common.AppError{Code: http.StatusBadRequest, Message: "invalid recipient_id"}
	}

	conv, err := h.service.CreateDirectConversation(c.Request().Context(), userIdent.ID, recipientID)
	if err != nil {
		var appErr *common.AppError
		if errors.As(err, &appErr) {
			return appErr
		}
		return common.ErrInternal
	}

	return common.CreatedResponse(c, conv)
}

// getMessages returns paginated messages for a conversation after IDOR validation.
func (h *ChatHandler) getMessages(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	convID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return common.ErrBadRequest
	}

	// IDOR check: verify user is member of conversation
	isMember, err := h.service.IsMember(c.Request().Context(), convID, userIdent.ID)
	if err != nil {
		return common.ErrInternal
	}
	if !isMember {
		return common.ErrForbidden
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

	var req SendMessageRequest
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}
	if req.Content == "" && req.Type == string(MsgText) {
		return &common.AppError{Code: http.StatusBadRequest, Message: "content is required"}
	}

	msgType := MsgText
	switch MessageType(req.Type) {
	case MsgImage, MsgVideo, MsgAudio, MsgVoice, MsgFile, MsgSystem:
		msgType = MessageType(req.Type)
	}

	var replyToUUID *uuid.UUID
	if req.ReplyToID != nil && *req.ReplyToID != "" {
		if parsed, err := uuid.Parse(*req.ReplyToID); err == nil {
			replyToUUID = &parsed
		}
	}

	if req.Metadata == nil {
		req.Metadata = make(map[string]interface{})
	}
	if req.ClientMessageID != "" {
		req.Metadata["client_message_id"] = req.ClientMessageID
	}

	msg, err := h.service.SendMessage(c.Request().Context(), convID, userIdent.ID, []byte(req.Content), msgType, replyToUUID, req.Metadata)
	if err != nil {
		if errors.Is(err, common.ErrForbidden) {
			return common.ErrForbidden
		}
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

	var req MarkReadRequest
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}

	msgID, err := uuid.Parse(req.MessageID)
	if err != nil {
		return &common.AppError{Code: http.StatusBadRequest, Message: "invalid message_id"}
	}

	if err := h.service.MarkRead(c.Request().Context(), convID, userIdent.ID, msgID); err != nil {
		if errors.Is(err, common.ErrForbidden) {
			return common.ErrForbidden
		}
		return common.ErrInternal
	}

	return common.SuccessResponse(c, map[string]string{"message": "marked as read"})
}

// editMessage updates an existing message's content (sender only).
func (h *ChatHandler) editMessage(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	msgID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return common.ErrBadRequest
	}

	var req UpdateMessageRequest
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}
	if req.Content == "" {
		return &common.AppError{Code: http.StatusBadRequest, Message: "content is required"}
	}

	msg, err := h.service.EditMessage(c.Request().Context(), msgID, userIdent.ID, []byte(req.Content))
	if err != nil {
		if errors.Is(err, common.ErrForbidden) {
			return common.ErrForbidden
		}
		return common.ErrInternal
	}

	return common.SuccessResponse(c, msg)
}

// deleteMessage soft-deletes a message (sender only).
func (h *ChatHandler) deleteMessage(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	msgID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return common.ErrBadRequest
	}

	if err := h.service.DeleteMessage(c.Request().Context(), msgID, userIdent.ID); err != nil {
		if errors.Is(err, common.ErrForbidden) {
			return common.ErrForbidden
		}
		return common.ErrInternal
	}

	return common.SuccessResponse(c, map[string]string{"message": "message deleted"})
}

// addReaction adds an emoji reaction to a message.
func (h *ChatHandler) addReaction(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	msgID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return common.ErrBadRequest
	}

	var req ReactionRequest
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}
	if req.Emoji == "" {
		return &common.AppError{Code: http.StatusBadRequest, Message: "emoji is required"}
	}

	if err := h.service.AddReaction(c.Request().Context(), msgID, userIdent.ID, req.Emoji); err != nil {
		if errors.Is(err, common.ErrForbidden) {
			return common.ErrForbidden
		}
		return common.ErrInternal
	}

	return common.SuccessResponse(c, map[string]string{"message": "reaction added"})
}

// removeReaction removes an emoji reaction from a message.
func (h *ChatHandler) removeReaction(c echo.Context) error {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	msgID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return common.ErrBadRequest
	}

	emoji := c.QueryParam("emoji")
	if emoji == "" {
		var req ReactionRequest
		_ = c.Bind(&req)
		emoji = req.Emoji
	}
	if emoji == "" {
		return &common.AppError{Code: http.StatusBadRequest, Message: "emoji is required"}
	}

	if err := h.service.RemoveReaction(c.Request().Context(), msgID, userIdent.ID, emoji); err != nil {
		if errors.Is(err, common.ErrForbidden) {
			return common.ErrForbidden
		}
		return common.ErrInternal
	}

	return common.SuccessResponse(c, map[string]string{"message": "reaction removed"})
}
