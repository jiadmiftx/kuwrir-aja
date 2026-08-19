// Package customerwallet gives customers the same wallet/withdraw
// capability driver_app/merchant_app already have (see internal/handler/
// wallet), plus a top-up flow so a customer's wallet has money in it
// before it's usable as a payment method for orders.
package customerwallet

import (
	"fmt"
	"net/http"
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

func (h *Handler) duitku() *service.DuitkuClient {
	return service.LoadDuitkuClient(h.db, h.cfg)
}

func (h *Handler) RegisterRoutes(customer *gin.RouterGroup) {
	customer.GET("/customer/wallet", h.GetWallet)
	customer.GET("/customer/wallet/transactions", h.GetTransactions)
	customer.POST("/customer/wallet/withdraw", h.Withdraw)
	customer.POST("/customer/wallet/topup", h.Topup)
}

func (h *Handler) GetWallet(c *gin.Context) {
	userID := mustParseUUID(c.GetString("user_id"))
	wallet, err := service.GetOrCreateWallet(h.db, userID, model.RoleCustomer)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get wallet"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"wallet": wallet})
}

func (h *Handler) GetTransactions(c *gin.Context) {
	userID := mustParseUUID(c.GetString("user_id"))
	wallet, txs, err := service.GetWalletTransactions(h.db, userID, model.RoleCustomer)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get wallet"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"wallet": wallet, "transactions": txs})
}

func (h *Handler) Withdraw(c *gin.Context) {
	userID := mustParseUUID(c.GetString("user_id"))

	var req struct {
		Amount            float64 `json:"amount" binding:"required,gt=0"`
		BankCode          string  `json:"bank_code"`
		BankAccountNumber string  `json:"bank_account_number"`
		BankAccountName   string  `json:"bank_account_name"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	result, err := service.ProcessWithdrawal(h.db, h.duitku(), userID, model.RoleCustomer, req.Amount, req.BankCode, req.BankAccountNumber, req.BankAccountName)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":          "Withdrawal initiated",
		"disbursement_ref": result.Withdrawal.DisbursementRef,
		"status":           result.Status,
		"amount":           req.Amount,
	})
}

// Topup creates a Duitku payment request for adding funds to the
// customer's wallet. MerchantOrderID uses a "TOPUP-" prefix so
// payment.Handler.Callback can route the webhook here instead of to
// order-payment handling.
func (h *Handler) Topup(c *gin.Context) {
	userID := mustParseUUID(c.GetString("user_id"))

	var req struct {
		Amount        float64 `json:"amount" binding:"required,gt=0"`
		PaymentMethod string  `json:"payment_method" binding:"required"` // VC, QRIS, OV
		Email         string  `json:"email"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user model.User
	h.db.Where("id = ?", userID).First(&user)
	email := req.Email
	if email == "" {
		email = user.Email
	}
	if email == "" {
		email = "customer@kuwrir.com"
	}

	merchantOrderID := fmt.Sprintf("TOPUP-%s", uuid.New().String()[:12])
	amountIDR := int64(req.Amount)

	result, err := h.duitku().CreatePayment("", merchantOrderID, amountIDR, user.Name, email, req.PaymentMethod, "Top Up Wallet Kuwrir")
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Payment gateway error: " + err.Error()})
		return
	}

	expiredAt := time.Now().Add(60 * time.Minute)
	topup := model.WalletTopupRequest{
		UserID:          userID,
		Amount:          req.Amount,
		MerchantOrderID: merchantOrderID,
		PaymentRef:      result.Reference,
		PaymentURL:      result.PaymentURL,
		Status:          "pending",
		ExpiredAt:       &expiredAt,
	}
	if err := h.db.Create(&topup).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to record top-up request"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"payment_url": result.PaymentURL,
		"payment_ref": result.Reference,
		"amount":      req.Amount,
		"expires_at":  expiredAt,
	})
}

func mustParseUUID(s string) uuid.UUID {
	id, _ := uuid.Parse(s)
	return id
}
