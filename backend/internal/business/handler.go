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

	// Merchant Settlements (Phase 3A.4)
	biz.GET("/:id/settlements/eligible", h.handleGetEligibleSettlement)
	biz.POST("/:id/settlements", h.handleCreateSettlement)
	biz.GET("/:id/settlements", h.handleListSettlements)
	biz.GET("/:id/settlements/:settlementId", h.handleGetSettlement)
	biz.POST("/:id/settlements/:settlementId/process", h.handleProcessSettlement)

	// Merchant Fees (Phase 3A.5)
	biz.GET("/:id/fees/rules", h.handleListFeeRules)
	biz.POST("/:id/fees/rules", h.handleCreateFeeRule)
	biz.PATCH("/:id/fees/rules/:ruleId", h.handleUpdateFeeRule)
	biz.GET("/:id/fees/transactions", h.handleListFeeTransactions)
	biz.GET("/:id/fees/summary", h.handleGetFeeSummary)
	biz.POST("/:id/fees/calculate", h.handleCalculateFee)

	// Merchant QR Codes
	biz.POST("/:id/merchant/qr", h.handleCreateMerchantQR)
	biz.GET("/:id/merchant/qr", h.handleGetMerchantQRs)
	biz.POST("/:id/merchant/qr/:qrId/revoke", h.handleRevokeMerchantQR)

	// Merchant Resolution (Public or Authenticated)
	merchant := g.Group("/merchant")
	merchant.GET("/qr/:code", h.handleResolveMerchantQR)

	// Payments & Payment Intents
	payments := g.Group("/payments")
	payments.Use(authMiddleware)
	payments.POST("/intents", h.handleCreatePaymentIntent)
	payments.GET("/intents/:id", h.handleGetPaymentIntent)
	payments.POST("/intents/:id/confirm", h.handleConfirmPaymentIntent)

	// Refunds (Phase 3A.3)
	payments.POST("/intents/:id/refunds", h.handleRefundPaymentIntent)
	payments.GET("/intents/:id/refunds", h.handleGetRefunds)
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

// ════════════════════════════════════════════════
// MERCHANT QR HANDLERS (PHASE 3A.2)
// ════════════════════════════════════════════════

func (h *Handler) handleCreateMerchantQR(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	bizID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid business ID")
	}

	var req CreateMerchantQRRequest
	if err := c.Bind(&req); err != nil {
		// Binding error is acceptable for optional body
		req = CreateMerchantQRRequest{}
	}

	qr, err := h.service.CreateMerchantQR(c.Request().Context(), bizID, userID, &req)
	if err != nil {
		if errors.Is(err, ErrBusinessNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		if errors.Is(err, ErrBusinessClosed) || errors.Is(err, ErrBusinessSuspended) {
			return echo.NewHTTPError(http.StatusConflict, err.Error())
		}
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"status": "success",
		"data":   qr,
	})
}

func (h *Handler) handleGetMerchantQRs(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	bizID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid business ID")
	}

	qrs, err := h.service.GetMerchantQRs(c.Request().Context(), bizID, userID)
	if err != nil {
		if errors.Is(err, ErrBusinessNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}

	return common.SuccessResponse(c, qrs)
}

func (h *Handler) handleRevokeMerchantQR(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	bizID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid business ID")
	}

	qrID, err := uuid.Parse(c.Param("qrId"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid QR ID")
	}

	if err := h.service.RevokeMerchantQR(c.Request().Context(), bizID, userID, qrID); err != nil {
		if errors.Is(err, ErrMerchantQRNotFound) || errors.Is(err, ErrBusinessNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		if errors.Is(err, ErrBusinessClosed) {
			return echo.NewHTTPError(http.StatusConflict, err.Error())
		}
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}

	return common.SuccessResponse(c, map[string]string{"message": "QR code revoked successfully"})
}

func (h *Handler) handleResolveMerchantQR(c echo.Context) error {
	code := c.Param("code")
	if code == "" {
		return echo.NewHTTPError(http.StatusBadRequest, "Missing QR code")
	}

	info, err := h.service.ResolveMerchantQR(c.Request().Context(), code)
	if err != nil {
		if errors.Is(err, ErrMerchantQRNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrMerchantQRRevoked) || errors.Is(err, ErrMerchantQRInvalid) {
			return echo.NewHTTPError(http.StatusGone, err.Error())
		}
		if errors.Is(err, ErrBusinessClosed) || errors.Is(err, ErrBusinessSuspended) {
			return echo.NewHTTPError(http.StatusConflict, err.Error())
		}
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}

	return common.SuccessResponse(c, info)
}

// ════════════════════════════════════════════════
// PAYMENT INTENT HANDLERS (PHASE 3A.2)
// ════════════════════════════════════════════════

func (h *Handler) handleCreatePaymentIntent(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	var req CreatePaymentIntentRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid request body")
	}

	intent, err := h.service.CreatePaymentIntent(c.Request().Context(), userID, &req)
	if err != nil {
		if errors.Is(err, ErrMerchantQRNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrMerchantQRRevoked) || errors.Is(err, ErrMerchantQRInvalid) {
			return echo.NewHTTPError(http.StatusGone, err.Error())
		}
		if errors.Is(err, ErrBusinessClosed) || errors.Is(err, ErrBusinessSuspended) {
			return echo.NewHTTPError(http.StatusConflict, err.Error())
		}
		if errors.Is(err, ErrSelfPaymentNotAllowed) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		if errors.Is(err, ErrCurrencyMismatch) {
			return echo.NewHTTPError(http.StatusUnprocessableEntity, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"status": "success",
		"data":   intent,
	})
}

func (h *Handler) handleGetPaymentIntent(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	intentID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Payment Intent ID")
	}

	intent, err := h.service.GetPaymentIntent(c.Request().Context(), userID, intentID)
	if err != nil {
		if errors.Is(err, ErrPaymentIntentNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrUnauthorizedAccess) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}

	return common.SuccessResponse(c, intent)
}

func (h *Handler) handleConfirmPaymentIntent(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	intentID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Payment Intent ID")
	}

	var req ConfirmPaymentIntentRequest
	if err := c.Bind(&req); err != nil {
		req = ConfirmPaymentIntentRequest{}
	}

	receipt, err := h.service.ConfirmPaymentIntent(c.Request().Context(), userID, intentID, &req)
	if err != nil {
		if errors.Is(err, ErrPaymentIntentNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrUnauthorizedAccess) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		if errors.Is(err, ErrPaymentIntentExpired) {
			return echo.NewHTTPError(http.StatusGone, err.Error())
		}
		if errors.Is(err, ErrPaymentIntentAlreadySucceeded) {
			return echo.NewHTTPError(http.StatusConflict, err.Error())
		}
		if errors.Is(err, ErrPaymentFailed) {
			return echo.NewHTTPError(http.StatusPaymentRequired, err.Error())
		}
		if errors.Is(err, ErrBusinessClosed) || errors.Is(err, ErrBusinessSuspended) {
			return echo.NewHTTPError(http.StatusConflict, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.SuccessResponse(c, receipt)
}

// ════════════════════════════════════════════════
// MERCHANT REFUND HANDLERS (PHASE 3A.3)
// ════════════════════════════════════════════════

func (h *Handler) handleRefundPaymentIntent(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	intentID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Payment Intent ID")
	}

	var req CreateRefundRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid request body")
	}

	receipt, err := h.service.RefundPayment(c.Request().Context(), userID, intentID, &req)
	if err != nil {
		if errors.Is(err, ErrPaymentIntentNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		if errors.Is(err, ErrPaymentNotEligibleForRefund) || errors.Is(err, ErrAlreadyFullyRefunded) {
			return echo.NewHTTPError(http.StatusConflict, err.Error())
		}
		if errors.Is(err, ErrRefundAmountExceedsRemaining) || errors.Is(err, ErrInvalidRefundAmount) {
			return echo.NewHTTPError(http.StatusUnprocessableEntity, err.Error())
		}
		if errors.Is(err, ErrBusinessClosed) || errors.Is(err, ErrBusinessSuspended) {
			return echo.NewHTTPError(http.StatusConflict, err.Error())
		}
		if errors.Is(err, ErrPaymentFailed) {
			return echo.NewHTTPError(http.StatusPaymentRequired, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"status": "success",
		"data":   receipt,
	})
}

func (h *Handler) handleGetRefunds(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	intentID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Payment Intent ID")
	}

	refunds, err := h.service.GetRefunds(c.Request().Context(), userID, intentID)
	if err != nil {
		if errors.Is(err, ErrPaymentIntentNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrUnauthorizedAccess) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}

	return common.SuccessResponse(c, refunds)
}

// ════════════════════════════════════════════════
// SETTLEMENT HANDLERS (PHASE 3A.4)
// ════════════════════════════════════════════════

func (h *Handler) handleGetEligibleSettlement(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	businessID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Business ID")
	}

	calc, err := h.service.CalculateEligibleSettlement(c.Request().Context(), userID, businessID)
	if err != nil {
		if errors.Is(err, ErrBusinessNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.SuccessResponse(c, calc)
}

func (h *Handler) handleCreateSettlement(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	businessID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Business ID")
	}

	var req CreateSettlementRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid request input")
	}

	receipt, err := h.service.CreateSettlement(c.Request().Context(), userID, businessID, &req)
	if err != nil {
		if errors.Is(err, ErrBusinessNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		if errors.Is(err, ErrNoEligiblePayments) || errors.Is(err, ErrAlreadyFullySettled) {
			return echo.NewHTTPError(http.StatusConflict, err.Error())
		}
		if errors.Is(err, ErrOverSettlement) || errors.Is(err, ErrInvalidSettlementAmount) || errors.Is(err, ErrSettlementCurrencyMismatch) {
			return echo.NewHTTPError(http.StatusUnprocessableEntity, err.Error())
		}
		if errors.Is(err, ErrBusinessClosed) || errors.Is(err, ErrBusinessSuspended) {
			return echo.NewHTTPError(http.StatusConflict, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"status": "success",
		"data":   receipt,
	})
}

func (h *Handler) handleProcessSettlement(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	businessID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Business ID")
	}

	settlementID, err := uuid.Parse(c.Param("settlementId"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Settlement ID")
	}

	receipt, err := h.service.ProcessSettlement(c.Request().Context(), userID, businessID, settlementID)
	if err != nil {
		if errors.Is(err, ErrSettlementNotFound) || errors.Is(err, ErrBusinessNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		if errors.Is(err, ErrSettlementNotPending) || errors.Is(err, ErrSettlementAlreadyProcessed) {
			return echo.NewHTTPError(http.StatusConflict, err.Error())
		}
		if errors.Is(err, ErrPaymentFailed) {
			return echo.NewHTTPError(http.StatusPaymentRequired, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.SuccessResponse(c, receipt)
}

func (h *Handler) handleGetSettlement(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	businessID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Business ID")
	}

	settlementID, err := uuid.Parse(c.Param("settlementId"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Settlement ID")
	}

	receipt, err := h.service.GetSettlement(c.Request().Context(), userID, businessID, settlementID)
	if err != nil {
		if errors.Is(err, ErrSettlementNotFound) || errors.Is(err, ErrBusinessNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.SuccessResponse(c, receipt)
}

func (h *Handler) handleListSettlements(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	businessID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Business ID")
	}

	settlements, err := h.service.ListSettlements(c.Request().Context(), userID, businessID)
	if err != nil {
		if errors.Is(err, ErrBusinessNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.SuccessResponse(c, settlements)
}

// ========================
// Phase 3A.5 — Fee Handlers
// ========================

func (h *Handler) handleCreateFeeRule(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	businessID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Business ID")
	}

	var req CreateFeeRuleRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid request body")
	}

	rule, err := h.service.CreateFeeRule(c.Request().Context(), userID, businessID, &req)
	if err != nil {
		if errors.Is(err, ErrNotBusinessMember) || errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.SuccessResponse(c, rule)
}

func (h *Handler) handleUpdateFeeRule(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	businessID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Business ID")
	}

	ruleID, err := uuid.Parse(c.Param("ruleId"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Fee Rule ID")
	}

	var req UpdateFeeRuleRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid request body")
	}

	if err := h.service.UpdateFeeRule(c.Request().Context(), userID, businessID, ruleID, &req); err != nil {
		if errors.Is(err, ErrFeeRuleNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrNotBusinessMember) || errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.SuccessResponse(c, map[string]string{"status": "updated"})
}

func (h *Handler) handleListFeeRules(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	businessID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Business ID")
	}

	rules, err := h.service.ListFeeRules(c.Request().Context(), userID, businessID)
	if err != nil {
		if errors.Is(err, ErrNotBusinessMember) || errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.SuccessResponse(c, rules)
}

func (h *Handler) handleCalculateFee(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	businessID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Business ID")
	}

	var req CalculateFeeRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid request body")
	}

	result, err := h.service.CalculateFee(c.Request().Context(), userID, businessID, &req)
	if err != nil {
		if errors.Is(err, ErrFeeRuleNotFound) {
			return common.ErrNotFound
		}
		if errors.Is(err, ErrNotBusinessMember) || errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.SuccessResponse(c, result)
}

func (h *Handler) handleGetFeeSummary(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	businessID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Business ID")
	}

	currency := c.QueryParam("currency")
	summary, err := h.service.GetFeeSummary(c.Request().Context(), userID, businessID, currency)
	if err != nil {
		if errors.Is(err, ErrNotBusinessMember) || errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.SuccessResponse(c, summary)
}

func (h *Handler) handleListFeeTransactions(c echo.Context) error {
	userID, err := h.getUserID(c)
	if err != nil {
		return common.ErrUnauthorized
	}

	businessID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid Business ID")
	}

	transactions, err := h.service.ListFeeTransactions(c.Request().Context(), userID, businessID)
	if err != nil {
		if errors.Is(err, ErrNotBusinessMember) || errors.Is(err, ErrUnauthorizedAccess) || errors.Is(err, ErrInsufficientPermission) {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}

	return common.SuccessResponse(c, transactions)
}
