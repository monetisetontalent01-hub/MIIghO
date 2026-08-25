package psp

import (
	"errors"
	"io"
	"net/http"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/internal/platform/identity"
)

// Handler exposes REST endpoints for PSP Gateway operations.
type Handler struct {
	service   *GatewayService
	validator *common.CustomValidator
}

func NewHandler(service *GatewayService, validator *common.CustomValidator) *Handler {
	return &Handler{
		service:   service,
		validator: validator,
	}
}

func (h *Handler) RegisterRoutes(g *echo.Group, authMiddleware echo.MiddlewareFunc) {
	pspGroup := g.Group("/psp")

	// Protected endpoints
	protected := pspGroup.Group("")
	protected.Use(authMiddleware)
	protected.POST("/payments", h.handleCreatePayment)
	protected.GET("/payments/:id", h.handleGetPaymentStatus)
	protected.POST("/refunds", h.handleRefundPayment)
	protected.POST("/payouts", h.handleInitiatePayout)
	protected.GET("/transactions/ref/:ref", h.handleGetTransactionsByRef)

	// Webhook endpoint (public with provider signature verification)
	pspGroup.POST("/webhooks/:provider", h.handleWebhook)
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

func (h *Handler) handleCreatePayment(c echo.Context) error {
	var req PSPPaymentRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid request body")
	}

	providerName := c.QueryParam("provider")
	tx, err := h.service.ExecutePayment(c.Request().Context(), providerName, &req)
	if err != nil {
		if errors.Is(err, ErrInvalidAmount) || errors.Is(err, ErrCurrencyMismatch) {
			return echo.NewHTTPError(http.StatusBadRequest, err.Error())
		}
		if errors.Is(err, ErrPSPProviderUnavailable) {
			return echo.NewHTTPError(http.StatusServiceUnavailable, err.Error())
		}
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}

	return common.SuccessResponse(c, tx)
}

func (h *Handler) handleGetPaymentStatus(c echo.Context) error {
	pspTxID := c.Param("id")
	providerName := c.QueryParam("provider")

	tx, err := h.service.GetPaymentStatus(c.Request().Context(), providerName, pspTxID)
	if err != nil {
		if errors.Is(err, ErrPSPTransactionNotFound) {
			return common.ErrNotFound
		}
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}

	return common.SuccessResponse(c, tx)
}

func (h *Handler) handleRefundPayment(c echo.Context) error {
	var req PSPRefundRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid request body")
	}

	providerName := c.QueryParam("provider")
	tx, err := h.service.ExecuteRefund(c.Request().Context(), providerName, &req)
	if err != nil {
		if errors.Is(err, ErrInvalidAmount) {
			return echo.NewHTTPError(http.StatusBadRequest, err.Error())
		}
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}

	return common.SuccessResponse(c, tx)
}

func (h *Handler) handleInitiatePayout(c echo.Context) error {
	var req PSPPayoutRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid request body")
	}

	providerName := c.QueryParam("provider")
	tx, err := h.service.ExecutePayout(c.Request().Context(), providerName, &req)
	if err != nil {
		if errors.Is(err, ErrInvalidAmount) {
			return echo.NewHTTPError(http.StatusBadRequest, err.Error())
		}
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}

	return common.SuccessResponse(c, tx)
}

func (h *Handler) handleGetTransactionsByRef(c echo.Context) error {
	internalRef := c.Param("ref")
	txs, err := h.service.GetTransactionsByInternalRef(c.Request().Context(), internalRef)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}

	return common.SuccessResponse(c, txs)
}

func (h *Handler) handleWebhook(c echo.Context) error {
	provider := c.Param("provider")
	body, err := io.ReadAll(c.Request().Body)
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Unable to read webhook payload")
	}

	headers := make(map[string]string)
	for k, v := range c.Request().Header {
		if len(v) > 0 {
			headers[k] = v[0]
		}
	}

	record, event, err := h.service.IngestWebhook(c.Request().Context(), provider, body, headers)
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.SuccessResponse(c, map[string]interface{}{
		"status":   "acknowledged",
		"event_id": record.EventID,
		"event":    event,
	})
}
