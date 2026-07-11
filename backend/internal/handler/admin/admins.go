package admin

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"

	authHandler "github.com/kuwrir-platform/backend/internal/handler/auth"
	"github.com/kuwrir-platform/backend/internal/model"
)

// ─── ADMIN ACCOUNT MANAGEMENT (superadmin only) ────────────────────────────
//
// Mounted on its own route group in cmd/server, gated by
// middleware.SuperadminOnlyMiddleware in addition to the base
// RoleMiddleware("admin") — see main.go.

var validAdminTiers = map[string]bool{
	model.AdminTierSuperadmin: true,
	model.AdminTierAdmin:      true,
	model.AdminTierCS:         true,
	model.AdminTierDeveloper:  true,
}

// GetAdmins lists every admin-role account.
func (h *Handler) GetAdmins(c *gin.Context) {
	var admins []model.User
	if err := h.db.Where("role = ?", model.RoleAdmin).Order("created_at ASC").Find(&admins).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch admins"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"admins": admins})
}

// CreateAdmin creates a new admin-role account with a given tier.
func (h *Handler) CreateAdmin(c *gin.Context) {
	var req struct {
		Name      string `json:"name" binding:"required"`
		Phone     string `json:"phone" binding:"required"`
		Password  string `json:"password" binding:"required,min=6"`
		AdminTier string `json:"admin_tier" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if !validAdminTiers[req.AdminTier] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Tier admin tidak valid"})
		return
	}
	phone := authHandler.NormalizePhone(req.Phone)

	var existing model.User
	if h.db.Where("phone = ?", phone).First(&existing).Error == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "Nomor ini sudah terdaftar di akun lain"})
		return
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
		return
	}

	admin := model.User{
		Name:      req.Name,
		Phone:     phone,
		Password:  string(hashed),
		Role:      model.RoleAdmin,
		AdminTier: req.AdminTier,
		IsActive:  true,
	}
	if err := h.db.Create(&admin).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create admin"})
		return
	}
	h.db.Where(model.UserRole{UserID: admin.ID, Role: model.RoleAdmin}).
		FirstOrCreate(&model.UserRole{UserID: admin.ID, Role: model.RoleAdmin})

	c.JSON(http.StatusCreated, gin.H{"admin": admin})
}

// UpdateAdmin changes an admin account's tier and/or active status.
func (h *Handler) UpdateAdmin(c *gin.Context) {
	id := c.Param("id")

	var admin model.User
	if err := h.db.Where("id = ? AND role = ?", id, model.RoleAdmin).First(&admin).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Admin not found"})
		return
	}

	var req struct {
		AdminTier *string `json:"admin_tier"`
		IsActive  *bool   `json:"is_active"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	updates := map[string]interface{}{}
	if req.AdminTier != nil {
		if !validAdminTiers[*req.AdminTier] {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Tier admin tidak valid"})
			return
		}
		updates["admin_tier"] = *req.AdminTier
	}
	if req.IsActive != nil {
		if !*req.IsActive && admin.ID.String() == c.GetString("user_id") {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Tidak bisa menonaktifkan akun sendiri"})
			return
		}
		updates["is_active"] = *req.IsActive
	}
	if len(updates) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Tidak ada perubahan"})
		return
	}

	if err := h.db.Model(&admin).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update admin"})
		return
	}
	h.db.First(&admin, "id = ?", id)
	c.JSON(http.StatusOK, gin.H{"admin": admin})
}
