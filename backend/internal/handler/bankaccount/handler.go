// Package bankaccount lets any authenticated user (customer, driver, or
// merchant owner) save one payout bank account per role, so withdrawal
// requests don't require re-entering bank details every time. Mounted once
// on the generic `protected` group (any authenticated role) rather than
// per role-specific group — registering the same literal path multiple
// times would panic — so the role is read from the JWT's own `user_role`
// claim (set at login, see middleware.AuthMiddleware) instead of being
// implied by which route group registered it.
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
	role := model.Role(c.GetString("user_role"))

	var account model.BankAccount
	if err := h.db.Where("user_id = ? AND role = ?", userID, role).First(&account).Error; err != nil {
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
	role := model.Role(c.GetString("user_role"))

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
	err = h.db.Where("user_id = ? AND role = ?", userID, role).First(&account).Error
	switch err {
	case gorm.ErrRecordNotFound:
		account = model.BankAccount{
			UserID:        userID,
			Role:          role,
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
