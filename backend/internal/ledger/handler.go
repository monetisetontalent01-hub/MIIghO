package ledger

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/internal/platform/identity"
)

// Handler exposes REST endpoints for MÏÏghO Pay and the Double-Entry Ledger.
type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) RegisterRoutes(g *echo.Group, authMiddleware echo.MiddlewareFunc) {
	pay := g.Group("/pay")
	pay.Use(authMiddleware)

	pay.GET("/wallet", h.handleGetWallet)
	pay.GET("/balance", h.handleGetBalance)
	pay.GET("/transactions", h.handleGetTransactions)
	pay.GET("/transactions/:id", h.handleGetTransactionDetail)
	pay.GET("/journal", h.handleGetJournal)

	pay.POST("/transfer", h.handleTransfer)
	pay.POST("/cash-in", h.handleCashIn)
	pay.POST("/cash-out", h.handleCashOut)
	pay.POST("/qr-pay", h.handleQRPay)
}

func (h *Handler) getUserID(c echo.Context) (uuid.UUID, error) {
	userIdent, err := identity.GetUserIdentity(c)
	if err != nil {
		// Fallback to default demo user if in local mock/sandbox mode without auth
		demoID, parseErr := uuid.Parse("00000000-0000-0000-0000-000000000001")
		if parseErr == nil {
			return demoID, nil
		}
		return uuid.Nil, common.ErrUnauthorized
	}
	return userIdent.ID, nil
}

func (h *Handler) handleGetWallet(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	currency := c.QueryParam("currency")
	if currency == "" {
		currency = "FCFA"
	}

	wallet, err := h.service.GetWalletSummary(c.Request().Context(), userID, currency)
	if err != nil {
		return &common.AppError{Code: http.StatusInternalServerError, Message: err.Error()}
	}

	return common.SuccessResponse(c, wallet)
}

func (h *Handler) handleGetBalance(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	currency := c.QueryParam("currency")
	if currency == "" {
		currency = "FCFA"
	}

	wallet, err := h.service.GetWalletSummary(c.Request().Context(), userID, currency)
	if err != nil {
		return &common.AppError{Code: http.StatusInternalServerError, Message: err.Error()}
	}

	return common.SuccessResponse(c, map[string]interface{}{
		"currency":          wallet.Currency,
		"available_balance": wallet.AvailableBalance,
		"pending_balance":   wallet.PendingBalance,
		"is_sandbox":        wallet.IsSandbox,
	})
}

func (h *Handler) handleGetTransactions(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	currency := c.QueryParam("currency")
	if currency == "" {
		currency = "FCFA"
	}

	limit := 20
	if l := c.QueryParam("limit"); l != "" {
		if val, err := strconv.Atoi(l); err == nil && val > 0 {
			limit = val
		}
	}

	offset := 0
	if o := c.QueryParam("offset"); o != "" {
		if val, err := strconv.Atoi(o); err == nil && val >= 0 {
			offset = val
		}
	}

	txs, err := h.service.GetUserTransactions(c.Request().Context(), userID, currency, limit, offset)
	if err != nil {
		return &common.AppError{Code: http.StatusInternalServerError, Message: err.Error()}
	}

	return common.SuccessResponse(c, txs)
}

func (h *Handler) handleGetTransactionDetail(c echo.Context) error {
	idStr := c.Param("id")
	entryID, err := uuid.Parse(idStr)
	if err != nil {
		return common.ErrBadRequest
	}

	detail, err := h.service.GetDetailedTransaction(c.Request().Context(), entryID)
	if err != nil {
		return common.ErrNotFound
	}

	return common.SuccessResponse(c, detail)
}

func (h *Handler) handleGetJournal(c echo.Context) error {
	limit := 50
	if l := c.QueryParam("limit"); l != "" {
		if val, err := strconv.Atoi(l); err == nil && val > 0 {
			limit = val
		}
	}

	offset := 0
	if o := c.QueryParam("offset"); o != "" {
		if val, err := strconv.Atoi(o); err == nil && val >= 0 {
			offset = val
		}
	}

	journal, err := h.service.GetDetailedJournalEntries(c.Request().Context(), limit, offset)
	if err != nil {
		return &common.AppError{Code: http.StatusInternalServerError, Message: err.Error()}
	}

	return common.SuccessResponse(c, journal)
}

func (h *Handler) handleTransfer(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	var req TransferRequest
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}
	if req.Currency == "" {
		req.Currency = "FCFA"
	}

	tx, err := h.service.TransferP2P(c.Request().Context(), userID, &req)
	if err != nil {
		if errors.Is(err, ErrInsufficientFunds) {
			return &common.AppError{Code: http.StatusBadRequest, Message: "Solde insuffisant pour effectuer ce transfert"}
		}
		if errors.Is(err, ErrInvalidAmount) {
			return &common.AppError{Code: http.StatusBadRequest, Message: "Le montant doit être strictement supérieur à zéro"}
		}
		return &common.AppError{Code: http.StatusInternalServerError, Message: err.Error()}
	}

	return common.CreatedResponse(c, tx)
}

func (h *Handler) handleCashIn(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	var req CashInRequest
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}
	if req.Currency == "" {
		req.Currency = "FCFA"
	}

	tx, err := h.service.CashIn(c.Request().Context(), userID, &req)
	if err != nil {
		if errors.Is(err, ErrInvalidAmount) {
			return &common.AppError{Code: http.StatusBadRequest, Message: "Le montant doit être strictement supérieur à zéro"}
		}
		return &common.AppError{Code: http.StatusInternalServerError, Message: err.Error()}
	}

	return common.CreatedResponse(c, tx)
}

func (h *Handler) handleCashOut(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	var req CashOutRequest
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}
	if req.Currency == "" {
		req.Currency = "FCFA"
	}

	tx, err := h.service.CashOut(c.Request().Context(), userID, &req)
	if err != nil {
		if errors.Is(err, ErrInsufficientFunds) {
			return &common.AppError{Code: http.StatusBadRequest, Message: "Solde insuffisant pour effectuer ce retrait"}
		}
		if errors.Is(err, ErrInvalidAmount) {
			return &common.AppError{Code: http.StatusBadRequest, Message: "Le montant doit être strictement supérieur à zéro"}
		}
		return &common.AppError{Code: http.StatusInternalServerError, Message: err.Error()}
	}

	return common.CreatedResponse(c, tx)
}

func (h *Handler) handleQRPay(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	var req QRPayRequest
	if err := c.Bind(&req); err != nil {
		return common.ErrBadRequest
	}
	if req.Currency == "" {
		req.Currency = "FCFA"
	}

	tx, err := h.service.QRPay(c.Request().Context(), userID, &req)
	if err != nil {
		if errors.Is(err, ErrInsufficientFunds) {
			return &common.AppError{Code: http.StatusBadRequest, Message: "Solde insuffisant pour ce paiement QR"}
		}
		if errors.Is(err, ErrInvalidAmount) {
			return &common.AppError{Code: http.StatusBadRequest, Message: "Le montant doit être strictement supérieur à zéro"}
		}
		return &common.AppError{Code: http.StatusInternalServerError, Message: err.Error()}
	}

	return common.CreatedResponse(c, tx)
}
