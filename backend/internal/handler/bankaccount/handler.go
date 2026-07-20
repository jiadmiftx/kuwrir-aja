// Package bankaccount lets any authenticated user (customer, driver, or
// merchant owner) save one payout bank account, so withdrawal requests
// don't require re-entering bank details every time. Routes are
// registered under whichever role groups need them — the handler itself
// is role-agnostic, keyed only off the JWT's user_id.
package bankaccount

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/model"
)

type Handler struct {
	db *gorm.DB
}

func NewHandler(db *gorm.DB) *Handler {
	return &Handler{db: db}
}

func (h *Handler) RegisterRoutes(group *gin.RouterGroup) {
	group.GET("/me/bank-account", h.Get)
	group.PUT("/me/bank-account", h.Upsert)
}

func (h *Handler) Get(c *gin.Context) {
	userID, err := uuid.Parse(c.GetString("user_id"))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid session"})
		return
	}

	var account model.BankAccount
	if err := h.db.Where("user_id = ?", userID).First(&account).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "No bank account saved"})
		return
	}
	c.JSON(http.StatusOK, account)
}

func (h *Handler) Upsert(c *gin.Context) {
	userID, err := uuid.Parse(c.GetString("user_id"))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid session"})
		return
	}

	var req struct {
		BankCode      string `json:"bank_code" binding:"required"`
		AccountNumber string `json:"account_number" binding:"required"`
		AccountName   string `json:"account_name" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var account model.BankAccount
	err = h.db.Where("user_id = ?", userID).First(&account).Error
	switch err {
	case gorm.ErrRecordNotFound:
		account = model.BankAccount{
			UserID:        userID,
			BankCode:      req.BankCode,
			AccountNumber: req.AccountNumber,
			AccountName:   req.AccountName,
		}
		if err := h.db.Create(&account).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save bank account"})
			return
		}
	case nil:
		account.BankCode = req.BankCode
		account.AccountNumber = req.AccountNumber
		account.AccountName = req.AccountName
		if err := h.db.Save(&account).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save bank account"})
			return
		}
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save bank account"})
		return
	}

	c.JSON(http.StatusOK, account)
}
