package payment

import (
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/config"
	"github.com/kuwrir-platform/backend/internal/model"
	"github.com/kuwrir-platform/backend/internal/service"
)

type Handler struct {
	db  *gorm.DB
	cfg *config.Config
}

func NewHandler(db *gorm.DB, cfg *config.Config) *Handler {
	return &Handler{db: db, cfg: cfg}
}

// duitku builds a client from the current admin-configured settings
// (falling back to env defaults) on every call, so a key rotation via the
// admin panel takes effect without a redeploy — see service.LoadDuitkuClient.
func (h *Handler) duitku() *service.DuitkuClient {
	return service.LoadDuitkuClient(h.db, h.cfg)
}

func (h *Handler) RegisterRoutes(public *gin.RouterGroup, customer *gin.RouterGroup, debugMode bool) {
	// Webhook from Duitku — must be public (no auth)
	public.POST("/payment/callback", h.Callback)

	// Customer-authenticated endpoints
	customer.GET("/payment/methods", h.GetPaymentMethods)
	customer.POST("/payment/:orderId/create", h.CreatePayment)
	customer.GET("/payment/:orderId/status", h.GetPaymentStatus)
	customer.GET("/payment/:orderId/stream", h.StreamPaymentStatus)

	// Simulation endpoint — dev/sandbox only
	if debugMode {
		customer.POST("/payment/:orderId/simulate-paid", h.SimulatePaid)
	}
}

// --- DTOs ---

type CreatePaymentRequest struct {
	PaymentMethod string `json:"payment_method" binding:"required"` // VC, QRIS, OV
	Email         string `json:"email"`
}

// GetPaymentMethods returns the live list of Duitku payment channels
// enabled for this merchant at the given amount, so the checkout screen
// renders real channels instead of a hardcoded guess.
//
// Only QRIS is surfaced to customers for now — Duitku's account for this
// merchant routes QRIS through a single acquirer and names the channel
// "LINKAJA QRIS" in paymentName, but customers should just see "QRIS".
// Every other channel (VA, e-wallet, credit card, retail, PayLater) is
// filtered out here rather than in each client, so customer_app and
// web_app can't drift on which methods are actually offered.
func (h *Handler) GetPaymentMethods(c *gin.Context) {
	amount, err := strconv.ParseInt(c.Query("amount"), 10, 64)
	if err != nil || amount <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "valid amount query param required"})
		return
	}

	methods, err := h.duitku().GetPaymentMethods(amount)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Payment gateway error: " + err.Error()})
		return
	}

	qrisOnly := make([]service.DuitkuPaymentMethod, 0, 1)
	for _, m := range methods {
		if strings.Contains(strings.ToUpper(m.PaymentName), "QRIS") {
			m.PaymentName = "QRIS"
			qrisOnly = append(qrisOnly, m)
		}
	}

	c.JSON(http.StatusOK, gin.H{"payment_methods": qrisOnly})
}

// CreatePayment creates a Duitku payment link for a pending order.
func (h *Handler) CreatePayment(c *gin.Context) {
	userID := c.GetString("user_id")
	orderID := c.Param("orderId")

	var req CreatePaymentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var order model.Order
	if err := h.db.Preload("Customer").Where("id = ? AND customer_id = ?", orderID, userID).First(&order).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	if order.PaymentType == "cash" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "This order uses COD, no payment link needed"})
		return
	}
	if order.PaymentStatus == "paid" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Order already paid"})
		return
	}

	customerName := ""
	email := req.Email
	if order.Customer != nil {
		customerName = order.Customer.Name
		if email == "" {
			email = order.Customer.Email
		}
	}
	if email == "" {
		email = "customer@kuwrir.com"
	}

	amountIDR := int64(order.Total)
	productDesc := fmt.Sprintf("Kuwrir Order %s", order.OrderNumber)

	result, err := h.duitku().CreatePayment(order.ID.String(), order.OrderNumber, amountIDR, customerName, email, req.PaymentMethod, productDesc)
	if err != nil {
		log.Printf("CreatePayment failed for order %s: %v", order.ID, err)
		c.JSON(http.StatusBadGateway, gin.H{"error": "Payment gateway error: " + err.Error()})
		return
	}

	expiredAt := time.Now().Add(60 * time.Minute)
	h.db.Model(&order).Updates(map[string]interface{}{
		"payment_ref":        result.Reference,
		"payment_url":        result.PaymentURL,
		"payment_status":     "pending",
		"payment_expired_at": expiredAt,
	})

	c.JSON(http.StatusOK, gin.H{
		"payment_url":    result.PaymentURL,
		"payment_ref":    result.Reference,
		"amount":         order.Total,
		"expires_at":     expiredAt,
	})
}

// GetPaymentStatus returns the current payment status of an order.
func (h *Handler) GetPaymentStatus(c *gin.Context) {
	userID := c.GetString("user_id")
	orderID := c.Param("orderId")

	var order model.Order
	if err := h.db.Where("id = ? AND customer_id = ?", orderID, userID).First(&order).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"order_id":       order.ID,
		"payment_status": order.PaymentStatus,
		"payment_url":    order.PaymentURL,
		"payment_ref":    order.PaymentRef,
		"expires_at":     order.PaymentExpiredAt,
	})
}

// isTerminalPaymentStatus reports whether a payment_status will never
// change again on its own — once here, there's nothing left to stream.
func isTerminalPaymentStatus(status string) bool {
	return status == "paid" || status == "failed" || status == "expired"
}

// StreamPaymentStatus holds an SSE connection open for a single order and
// pushes payment_status the instant Duitku's webhook (Callback, below)
// updates it — replaces the client having to poll GetPaymentStatus every
// few seconds while waiting for a payment to confirm.
func (h *Handler) StreamPaymentStatus(c *gin.Context) {
	userID := c.GetString("user_id")
	orderID := c.Param("orderId")

	var order model.Order
	if err := h.db.Where("id = ? AND customer_id = ?", orderID, userID).First(&order).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	c.Writer.Header().Set("Content-Type", "text/event-stream")
	c.Writer.Header().Set("Cache-Control", "no-cache")
	c.Writer.Header().Set("Connection", "keep-alive")
	// Tells nginx not to buffer this response, so events flush to the
	// client immediately instead of waiting for the proxy's buffer to fill.
	c.Writer.Header().Set("X-Accel-Buffering", "no")

	writeEvent := func(status string) {
		c.SSEvent("payment_status", service.PaymentEvent{OrderID: order.ID.String(), PaymentStatus: status})
		c.Writer.Flush()
	}

	// Send the current status right away — closes the race where payment
	// already completed before the client opened the stream.
	writeEvent(order.PaymentStatus)
	if isTerminalPaymentStatus(order.PaymentStatus) {
		return
	}

	events, unsubscribe := service.SubscribePaymentEvents(order.ID.String())
	defer unsubscribe()

	heartbeat := time.NewTicker(20 * time.Second)
	defer heartbeat.Stop()

	for {
		select {
		case <-c.Request.Context().Done():
			return
		case evt := <-events:
			writeEvent(evt.PaymentStatus)
			if isTerminalPaymentStatus(evt.PaymentStatus) {
				return
			}
		case <-heartbeat.C:
			// A bare SSE comment line — keeps the connection alive under
			// nginx/Cloudflare's idle timeouts without the client having to
			// treat it as a real event.
			c.Writer.WriteString(": keep-alive\n\n")
			c.Writer.Flush()
		}
	}
}

// Callback handles Duitku payment notifications (webhook).
// Duitku POST-es to this endpoint after payment is completed/failed.
func (h *Handler) Callback(c *gin.Context) {
	var payload struct {
		MerchantCode    string `form:"merchantCode"`
		Amount          string `form:"amount"`
		MerchantOrderID string `form:"merchantOrderId"` // our order_number
		ResultCode      string `form:"resultCode"`      // 00 = success
		Signature       string `form:"signature"`
		Reference       string `form:"reference"`
	}
	if err := c.ShouldBind(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if !h.duitku().VerifyCallbackSignature(payload.Amount, payload.MerchantOrderID, payload.Signature) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid signature"})
		return
	}

	if strings.HasPrefix(payload.MerchantOrderID, "TOPUP-") {
		h.handleTopupCallback(payload.MerchantOrderID, payload.ResultCode)
		c.String(http.StatusOK, "OK")
		return
	}

	var order model.Order
	if err := h.db.Where("order_number = ?", payload.MerchantOrderID).First(&order).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	if payload.ResultCode == "00" {
		deadline := time.Now().Add(5 * time.Minute)
		h.db.Model(&order).Updates(map[string]interface{}{
			"payment_status":        "paid",
			"confirmation_deadline": &deadline,
		})
		service.PublishPaymentEvent(order.ID.String(), "paid")
	} else {
		h.db.Model(&order).Update("payment_status", "failed")
		service.PublishPaymentEvent(order.ID.String(), "failed")
	}

	// Duitku expects plain "OK" text response
	c.String(http.StatusOK, "OK")
}

// handleTopupCallback credits a customer's wallet once a wallet top-up
// payment succeeds. Uses the same signature verification as order
// payments (Callback) — only the routing (by "TOPUP-" prefix) differs.
func (h *Handler) handleTopupCallback(merchantOrderID, resultCode string) {
	var topup model.WalletTopupRequest
	if err := h.db.Where("merchant_order_id = ?", merchantOrderID).First(&topup).Error; err != nil {
		return
	}
	if topup.Status != "pending" {
		return
	}

	if resultCode != "00" {
		h.db.Model(&topup).Update("status", "failed")
		return
	}

	tx := h.db.Begin()
	if err := tx.Model(&topup).Update("status", "paid").Error; err != nil {
		tx.Rollback()
		return
	}
	notes := fmt.Sprintf("Wallet top-up %s", merchantOrderID)
	if err := service.CreditWallet(tx, topup.UserID, topup.Amount, "topup", nil, notes); err != nil {
		tx.Rollback()
		return
	}
	tx.Commit()
}

// SimulatePaid marks an order as paid without calling Duitku.
// Only available when SERVER_MODE=debug.
func (h *Handler) SimulatePaid(c *gin.Context) {
	userID := c.GetString("user_id")
	orderID := c.Param("orderId")

	var order model.Order
	if err := h.db.Where("id = ? AND customer_id = ?", orderID, userID).First(&order).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}
	if order.PaymentType == "cash" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "COD orders do not need payment simulation"})
		return
	}
	if order.PaymentStatus == "paid" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Order already paid"})
		return
	}

	deadline := time.Now().Add(5 * time.Minute)
	h.db.Model(&order).Updates(map[string]interface{}{
		"payment_status":        "paid",
		"payment_ref":           fmt.Sprintf("SIM-%s", order.OrderNumber),
		"confirmation_deadline": &deadline,
	})
	service.PublishPaymentEvent(order.ID.String(), "paid")

	c.JSON(http.StatusOK, gin.H{
		"message":        "Payment simulated successfully",
		"order_id":       order.ID,
		"order_number":   order.OrderNumber,
		"payment_status": "paid",
		"total":          order.Total,
		"note":           "Order is now paid. Proceed with merchant confirmation flow.",
	})
}

// creditWalletsForOnlineOrder is called after an online-paid order is delivered.
// For COD this is handled in MarkDelivered; online payments credit here.
func CreditWalletsForOnlineOrder(db *gorm.DB, order model.Order) error {
	if order.PaymentType == "cash" {
		return nil // COD handled at delivery
	}
	if order.PaymentStatus != "paid" {
		return nil
	}

	orderUUID := order.ID
	tx := db.Begin()

	merchantNote := fmt.Sprintf("Online payment order %s delivered", order.OrderNumber)
	driverNote := fmt.Sprintf("Online payment earning order %s", order.OrderNumber)

	if err := service.CreditMerchantWallet(tx, *order.MerchantID, order.Subtotal, "order_earning", &orderUUID, merchantNote); err != nil {
		tx.Rollback()
		return err
	}
	if order.DriverID != nil {
		var driver model.Driver
		if db.Where("id = ?", *order.DriverID).First(&driver).Error == nil {
			if err := service.CreditWallet(tx, driver.UserID, order.DriverEarning, "order_earning", &orderUUID, driverNote); err != nil {
				tx.Rollback()
				return err
			}
		}
	}
	return tx.Commit().Error
}

// GetDuitkuClientFromConfig builds a DuitkuClient from app config.
func GetDuitkuClientFromConfig(cfg *config.Config) *service.DuitkuClient {
	return &service.DuitkuClient{
		MerchantCode: cfg.Duitku.MerchantCode,
		APIKey:       cfg.Duitku.APIKey,
		BaseURL:      cfg.Duitku.BaseURL,
		CallbackURL:  cfg.Duitku.CallbackURL,
		ReturnURL:    cfg.Duitku.ReturnURL,
	}
}

// unused import guard
var _ = uuid.New
