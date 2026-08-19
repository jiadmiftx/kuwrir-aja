package wallet

import (
	"fmt"
	"net/http"

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
// (falling back to env defaults) on every call — see service.LoadDuitkuClient.
func (h *Handler) duitku() *service.DuitkuClient {
	return service.LoadDuitkuClient(h.db, h.cfg)
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

	wallet, err := service.GetOrCreateWallet(h.db, mustParseUUID(userID), model.RoleDriver)
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
	h.getTransactions(c, userID, model.RoleDriver)
}

func (h *Handler) DriverWithdraw(c *gin.Context) {
	userID := c.GetString("user_id")
	h.withdraw(c, userID, model.RoleDriver)
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

	wallet, err := service.GetOrCreateWallet(h.db, mustParseUUID(userID), model.RoleMerchant)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get wallet"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"wallet": wallet})
}

func (h *Handler) GetMerchantTransactions(c *gin.Context) {
	userID := c.GetString("user_id")
	h.getTransactions(c, userID, model.RoleMerchant)
}

func (h *Handler) MerchantWithdraw(c *gin.Context) {
	userID := c.GetString("user_id")
	h.withdraw(c, userID, model.RoleMerchant)
}

// --- Shared helpers ---

// WithdrawRequest's bank fields are optional — if omitted, ProcessWithdrawal
// falls back to the user's saved BankAccount (see /me/bank-account).
type WithdrawRequest struct {
	Amount            float64 `json:"amount" binding:"required,gt=0"`
	BankCode          string  `json:"bank_code"`
	BankAccountNumber string  `json:"bank_account_number"`
	BankAccountName   string  `json:"bank_account_name"`
}

func (h *Handler) withdraw(c *gin.Context, userID string, role model.Role) {
	var req WithdrawRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	uid := mustParseUUID(userID)
	result, err := service.ProcessWithdrawal(h.db, h.duitku(), uid, role, req.Amount, req.BankCode, req.BankAccountNumber, req.BankAccountName)
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

func (h *Handler) getTransactions(c *gin.Context, userID string, role model.Role) {
	wallet, txs, err := service.GetWalletTransactions(h.db, mustParseUUID(userID), role)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get wallet"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"wallet":       wallet,
		"transactions": txs,
	})
}

func mustParseUUID(s string) uuid.UUID {
	id, _ := uuid.Parse(s)
	return id
}
