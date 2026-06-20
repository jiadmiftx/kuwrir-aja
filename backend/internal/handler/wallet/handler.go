package wallet

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
	db     *gorm.DB
	duitku *service.DuitkuClient
}

func NewHandler(db *gorm.DB, cfg *config.Config) *Handler {
	return &Handler{
		db: db,
		duitku: &service.DuitkuClient{
			MerchantCode: cfg.Duitku.MerchantCode,
			APIKey:       cfg.Duitku.APIKey,
			BaseURL:      cfg.Duitku.BaseURL,
			CallbackURL:  cfg.Duitku.CallbackURL,
			ReturnURL:    cfg.Duitku.ReturnURL,
		},
	}
}

func (h *Handler) RegisterDriverRoutes(driver *gin.RouterGroup) {
	driver.GET("/driver/wallet", h.GetDriverWallet)
	driver.GET("/driver/wallet/transactions", h.GetDriverTransactions)
	driver.POST("/driver/wallet/withdraw", h.DriverWithdraw)
	driver.POST("/driver/cod/deposit", h.DriverCODDeposit)
}

func (h *Handler) RegisterMerchantRoutes(merchant *gin.RouterGroup) {
	merchant.GET("/my-store/wallet", h.GetMerchantWallet)
	merchant.GET("/my-store/wallet/transactions", h.GetMerchantTransactions)
	merchant.POST("/my-store/wallet/withdraw", h.MerchantWithdraw)
}

// --- Driver Wallet ---

func (h *Handler) GetDriverWallet(c *gin.Context) {
	userID := c.GetString("user_id")

	wallet, err := service.GetOrCreateWallet(h.db, mustParseUUID(userID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get wallet"})
		return
	}

	var driver model.Driver
	h.db.Where("user_id = ?", userID).First(&driver)

	c.JSON(http.StatusOK, gin.H{
		"wallet":      wallet,
		"cod_holding": driver.CodHolding,
		"to_deposit":  driver.CodHolding, // full COD cash driver still holds
	})
}

func (h *Handler) GetDriverTransactions(c *gin.Context) {
	userID := c.GetString("user_id")
	h.getTransactions(c, userID)
}

func (h *Handler) DriverWithdraw(c *gin.Context) {
	userID := c.GetString("user_id")
	h.withdraw(c, userID)
}

// DriverCODDeposit records that a driver has handed over COD cash to the platform.
// This reduces cod_holding; wallet was already credited at delivery.
func (h *Handler) DriverCODDeposit(c *gin.Context) {
	userID := c.GetString("user_id")

	var req struct {
		Amount    float64 `json:"amount" binding:"required,gt=0"`
		Method    string  `json:"method"`    // cash | bank_transfer
		Reference string  `json:"reference"` // bukti transfer
		Notes     string  `json:"notes"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if req.Method == "" {
		req.Method = "cash"
	}

	var driver model.Driver
	if err := h.db.Where("user_id = ?", userID).First(&driver).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver not found"})
		return
	}
	if driver.CodHolding < req.Amount {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":       fmt.Sprintf("Deposit amount exceeds COD holding (%.0f)", driver.CodHolding),
			"cod_holding": driver.CodHolding,
		})
		return
	}

	// Record as DriverDeposit + reduce cod_holding atomically
	adminNote := fmt.Sprintf("COD deposit %s %.0f IDR", req.Method, req.Amount)
	tx := h.db.Begin()

	deposit := model.DriverDeposit{
		DriverID:  driver.ID,
		Amount:    req.Amount,
		Method:    req.Method,
		Reference: req.Reference,
		Notes:     adminNote,
	}
	tx.Create(&deposit)
	tx.Model(&driver).UpdateColumn("cod_holding", gorm.Expr("cod_holding - ?", req.Amount))

	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to record deposit"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":         "COD deposit recorded",
		"deposited":       req.Amount,
		"remaining_holding": driver.CodHolding - req.Amount,
	})
}

// --- Merchant Wallet ---

func (h *Handler) GetMerchantWallet(c *gin.Context) {
	userID := c.GetString("user_id")

	wallet, err := service.GetOrCreateWallet(h.db, mustParseUUID(userID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get wallet"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"wallet": wallet})
}

func (h *Handler) GetMerchantTransactions(c *gin.Context) {
	userID := c.GetString("user_id")
	h.getTransactions(c, userID)
}

func (h *Handler) MerchantWithdraw(c *gin.Context) {
	userID := c.GetString("user_id")
	h.withdraw(c, userID)
}

// --- Shared helpers ---

type WithdrawRequest struct {
	Amount            float64 `json:"amount" binding:"required,gt=0"`
	BankCode          string  `json:"bank_code" binding:"required"`
	BankAccountNumber string  `json:"bank_account_number" binding:"required"`
	BankAccountName   string  `json:"bank_account_name" binding:"required"`
}

func (h *Handler) withdraw(c *gin.Context, userID string) {
	var req WithdrawRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	uid := mustParseUUID(userID)
	wallet, err := service.GetOrCreateWallet(h.db, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get wallet"})
		return
	}
	if wallet.Balance < req.Amount {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Insufficient wallet balance",
			"balance": wallet.Balance,
		})
		return
	}

	// Unique disbursement ref
	disbRef := fmt.Sprintf("WD-%s-%d", wallet.ID.String()[:8], time.Now().UnixMilli())

	result, err := h.duitku.Disburse(disbRef, req.BankCode, req.BankAccountNumber, req.BankAccountName, int64(req.Amount))
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Disbursement failed: " + err.Error()})
		return
	}

	// Record withdrawal request
	status := "processing"
	if result.Status == "SUCCESS" {
		status = "success"
	}

	wReq := model.WithdrawalRequest{
		WalletID:          wallet.ID,
		Amount:            req.Amount,
		BankCode:          req.BankCode,
		BankAccountNumber: req.BankAccountNumber,
		BankAccountName:   req.BankAccountName,
		Status:            status,
		DisbursementRef:   result.DisbursementRef,
	}
	h.db.Create(&wReq)

	// Debit wallet only if success (for processing, debit on disbursement webhook)
	if status == "success" {
		tx := h.db.Begin()
		notes := fmt.Sprintf("Withdrawal to %s %s", req.BankCode, req.BankAccountNumber)
		if err := service.DebitWallet(tx, uid, req.Amount, "withdrawal", notes); err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to debit wallet"})
			return
		}
		tx.Commit()
	}

	c.JSON(http.StatusOK, gin.H{
		"message":          "Withdrawal initiated",
		"disbursement_ref": result.DisbursementRef,
		"status":           status,
		"amount":           req.Amount,
	})
}

func (h *Handler) getTransactions(c *gin.Context, userID string) {
	wallet, err := service.GetOrCreateWallet(h.db, mustParseUUID(userID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get wallet"})
		return
	}

	var txs []model.WalletTransaction
	h.db.Where("wallet_id = ?", wallet.ID).
		Order("created_at DESC").
		Limit(50).
		Find(&txs)

	c.JSON(http.StatusOK, gin.H{
		"wallet":       wallet,
		"transactions": txs,
	})
}

func mustParseUUID(s string) uuid.UUID {
	id, _ := uuid.Parse(s)
	return id
}
