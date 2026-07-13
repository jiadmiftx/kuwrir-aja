package admin

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"

	authHandler "github.com/kuwrir-platform/backend/internal/handler/auth"
	"github.com/kuwrir-platform/backend/internal/model"
	"github.com/kuwrir-platform/backend/internal/service"
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

// rootSuperadminPhone is the platform's designated primary/owner
// superadmin account. Account-management actions (tier change,
// deactivate, phone/name/password change) against this account are
// blocked from every other admin — including other superadmins — in
// UpdateAdmin, so platform ownership can't be silently reassigned or the
// owner locked out by anyone but themselves.
const rootSuperadminPhone = "+6281907031"

func isRootSuperadmin(phone string) bool { return phone == rootSuperadminPhone }

// RequireRootSuperadmin gates routes to only the platform's designated
// owner account (rootSuperadminPhone) — stricter than
// middleware.SuperadminOnlyMiddleware, which allows any account tiered
// "superadmin". Deleting a customer/driver/merchant account is
// irreversible enough that it's scoped to the single owner, not every
// superadmin.
func (h *Handler) RequireRootSuperadmin() gin.HandlerFunc {
	return func(c *gin.Context) {
		var requester model.User
		if err := h.db.First(&requester, "id = ?", c.GetString("user_id")).Error; err != nil || !isRootSuperadmin(requester.Phone) {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "Hanya superadmin utama yang bisa menghapus akun pengguna"})
			return
		}
		c.Next()
	}
}

// DeleteUserAccount permanently deactivates and soft-deletes a
// customer/driver/merchant account from the admin panel — the same
// underlying operation as the app's own "delete my account" (see
// service.DeleteUserAccount), just triggered by the root superadmin
// against someone else's account instead of self-service. Refuses to
// touch admin-role accounts; use the /admins endpoints for those.
func (h *Handler) DeleteUserAccount(c *gin.Context) {
	id := c.Param("id")

	var user model.User
	if err := h.db.First(&user, "id = ?", id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Akun tidak ditemukan"})
		return
	}
	if user.Role == model.RoleAdmin {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Gunakan menu Kelola Admin untuk akun admin"})
		return
	}

	blockReason, err := service.DeleteUserAccount(h.db, user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal menghapus akun"})
		return
	}
	if blockReason != "" {
		c.JSON(http.StatusConflict, gin.H{"error": blockReason})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Akun berhasil dihapus"})
}

// adminResponse augments model.User with is_root so the frontend can grey
// out account-management actions for the protected owner account without
// needing to hardcode/duplicate the phone number itself.
type adminResponse struct {
	model.User
	IsRoot bool `json:"is_root"`
}

func toAdminResponse(u model.User) adminResponse {
	return adminResponse{User: u, IsRoot: isRootSuperadmin(u.Phone)}
}

// GetAdmins lists every admin-role account.
func (h *Handler) GetAdmins(c *gin.Context) {
	var admins []model.User
	if err := h.db.Where("role = ?", model.RoleAdmin).Order("created_at ASC").Find(&admins).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch admins"})
		return
	}
	out := make([]adminResponse, len(admins))
	for i, a := range admins {
		out[i] = toAdminResponse(a)
	}
	c.JSON(http.StatusOK, gin.H{"admins": out})
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

	c.JSON(http.StatusCreated, gin.H{"admin": toAdminResponse(admin)})
}

// UpdateAdmin changes an admin account's name/phone/tier/password/active
// status. The designated root superadmin account (rootSuperadminPhone) is
// off-limits to everyone but itself — see that constant's doc comment.
func (h *Handler) UpdateAdmin(c *gin.Context) {
	id := c.Param("id")

	var admin model.User
	if err := h.db.Where("id = ? AND role = ?", id, model.RoleAdmin).First(&admin).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Admin not found"})
		return
	}

	if isRootSuperadmin(admin.Phone) && admin.ID.String() != c.GetString("user_id") {
		c.JSON(http.StatusForbidden, gin.H{"error": "Akun superadmin utama ini dilindungi dan hanya bisa diubah oleh pemiliknya sendiri"})
		return
	}

	var req struct {
		Name      *string `json:"name"`
		Phone     *string `json:"phone"`
		AdminTier *string `json:"admin_tier"`
		IsActive  *bool   `json:"is_active"`
		Password  *string `json:"password"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	updates := map[string]interface{}{}
	if req.Name != nil && *req.Name != "" {
		updates["name"] = *req.Name
	}
	if req.Phone != nil && *req.Phone != "" {
		phone := authHandler.NormalizePhone(*req.Phone)
		if phone != admin.Phone {
			var conflicting model.User
			if h.db.Where("phone = ? AND id != ?", phone, admin.ID).First(&conflicting).Error == nil {
				c.JSON(http.StatusConflict, gin.H{"error": "Nomor ini sudah terdaftar di akun lain"})
				return
			}
			updates["phone"] = phone
		}
	}
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
	if req.Password != nil && *req.Password != "" {
		if len(*req.Password) < 6 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Password minimal 6 karakter"})
			return
		}
		hashed, err := bcrypt.GenerateFromPassword([]byte(*req.Password), bcrypt.DefaultCost)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
			return
		}
		updates["password"] = string(hashed)
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
	c.JSON(http.StatusOK, gin.H{"admin": toAdminResponse(admin)})
}
