package admin

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"sort"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/config"
	"github.com/kuwrir-platform/backend/internal/handler/driverreg"
	"github.com/kuwrir-platform/backend/internal/model"
	"github.com/kuwrir-platform/backend/internal/service"
	"github.com/kuwrir-platform/backend/internal/upload"
)

type Handler struct {
	db  *gorm.DB
	cfg *config.Config
}

func NewHandler(db *gorm.DB, cfg *config.Config) *Handler {
	return &Handler{db: db, cfg: cfg}
}

func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	// Dashboard
	r.GET("/dashboard/stats", h.DashboardStats)

	// Settings
	r.GET("/settings", h.GetSettings)
	r.PUT("/settings/:key", h.UpdateSetting)

	// User management
	r.GET("/drivers", h.GetDrivers)
	r.GET("/drivers/:id", h.GetDriverDetail)
	r.GET("/customers", h.GetCustomers)
	r.GET("/customers/:id", h.GetCustomerDetail)
	r.GET("/merchants", h.GetMerchants)
	r.GET("/merchants/:id", h.GetMerchantDetail)
	r.PUT("/merchants/:id/verify", h.VerifyMerchant)
	r.DELETE("/merchants/:id", h.DeleteMerchant)
	r.PUT("/users/:id/toggle-active", h.ToggleUserActive)

	// Driver COD deposits
	r.GET("/drivers/:id/deposits", h.GetDriverDeposits)
	r.POST("/drivers/:id/deposits", h.CreateDriverDeposit)

	// Orders
	r.GET("/orders", h.GetOrders)
	r.GET("/orders/:id/nearby-drivers", h.NearbyDriversForOrder)
	r.POST("/orders/:id/assign-driver", h.AssignDriverToOrder)
	r.POST("/orders/:id/admin-cancel", h.AdminCancelOrder)

	// Revenue analytics
	r.GET("/revenue", h.GetRevenue)

	// Refunds
	r.GET("/refunds", h.GetRefunds)
	r.POST("/refunds/:id/process", h.ProcessRefund)

	// Settlements
	r.GET("/settlements", h.GetSettlements)
	r.GET("/settlements/merchants", h.GetMerchantSettlements)
	r.POST("/settlements/merchants/:merchantId/process", h.ProcessMerchantSettlement)
	r.PUT("/settlements/:id/mark-paid", h.MarkSettlementPaid)

	// Driver applications
	r.GET("/driver-applications", driverreg.ListDriverApplications(h.db))
	r.PUT("/driver-applications/:id/review", driverreg.ReviewDriverApplication(h.db))

	// Wallet & withdrawals
	r.GET("/withdrawals", h.GetWithdrawals)
	r.GET("/drivers/:id/cod-holding", h.GetDriverCODHolding)
	r.POST("/drivers/:id/cod-deposit", h.AdminConfirmCODDeposit)

	// Promotions
	r.GET("/promotions", h.GetPromotions)
	r.POST("/promotions", h.CreatePromotion)
	r.PUT("/promotions/:id", h.UpdatePromotion)
	r.DELETE("/promotions/:id", h.DeletePromotion)
	r.PUT("/promotions/:id/toggle", h.TogglePromotion)
	r.POST("/promotions/:id/image", h.UploadPromotionImage)

	// Delivery zones (city reference points for pricing)
	r.GET("/delivery-zones", h.GetDeliveryZones)
	r.POST("/delivery-zones", h.CreateDeliveryZone)
	r.PUT("/delivery-zones/:id", h.UpdateDeliveryZone)
	r.DELETE("/delivery-zones/:id", h.DeleteDeliveryZone)

	// Zone assignment
	r.PATCH("/drivers/:id/zone", h.AssignDriverZone)
	r.PATCH("/merchants/:id/zone", h.AssignMerchantZone)

	// Food categories (global taxonomy for customer app browsing)
	r.GET("/food-categories", h.GetFoodCategories)
	r.POST("/food-categories", h.CreateFoodCategory)
	r.PUT("/food-categories/:id", h.UpdateFoodCategory)
	r.DELETE("/food-categories/:id", h.DeleteFoodCategory)

	// Homepage promo banners (customer app Home carousel)
	r.GET("/banners", h.GetBanners)
	r.POST("/banners", h.CreateBanner)
	r.PUT("/banners/:id", h.UpdateBanner)
	r.DELETE("/banners/:id", h.DeleteBanner)
	r.POST("/banners/:id/image", h.UploadBannerImage)

	// WhatsApp gateway pairing/status/logs (proxied — the gateway container
	// has no host-published port, only reachable from sibling containers)
	r.GET("/whatsapp/status", h.WhatsAppStatus)
	r.GET("/whatsapp/qr", h.WhatsAppQR)
	r.GET("/whatsapp/logs", h.WhatsAppLogs)
	r.POST("/whatsapp/send-message", h.WhatsAppSendMessage)

	// Audit trail (read-only for every admin tier, incl. cs/developer)
	r.GET("/audit-logs", h.GetAuditLogs)
}

// RegisterSuperadminRoutes registers admin-account-management routes.
// Mounted separately in cmd/server on a sub-group with an extra
// SuperadminOnlyMiddleware gate, since RegisterRoutes' group only carries
// the base RoleMiddleware("admin") + AdminTierMiddleware.
func (h *Handler) RegisterSuperadminRoutes(r *gin.RouterGroup) {
	admins := r.Group("/admins")
	{
		admins.GET("", h.GetAdmins)
		admins.POST("", h.CreateAdmin)
		admins.PUT("/:id", h.UpdateAdmin)
	}
}

// RegisterRootSuperadminRoutes registers routes limited to the platform's
// designated owner account — see RequireRootSuperadmin. Mounted on its own
// sub-group in cmd/server with that extra gate, since RegisterRoutes' group
// only carries the base RoleMiddleware("admin") + AdminTierMiddleware.
func (h *Handler) RegisterRootSuperadminRoutes(r *gin.RouterGroup) {
	r.DELETE("/users/:id", h.DeleteUserAccount)
}

// ─── DASHBOARD ────────────────────────────────────────────────────────────────

// DashboardStats returns live KPI data for the admin dashboard
func (h *Handler) DashboardStats(c *gin.Context) {
	now := time.Now()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	monthStart := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())

	var totalOrders, todayOrders, activeOrders int64
	h.db.Model(&model.Order{}).Count(&totalOrders)
	h.db.Model(&model.Order{}).Where("created_at >= ?", todayStart).Count(&todayOrders)
	h.db.Model(&model.Order{}).Where("status NOT IN ?", []string{"delivered", "cancelled"}).Count(&activeOrders)

	var totalMerchants, verifiedMerchants, openMerchants int64
	h.db.Model(&model.Merchant{}).Count(&totalMerchants)
	h.db.Model(&model.Merchant{}).Where("is_verified = ?", true).Count(&verifiedMerchants)
	h.db.Model(&model.Merchant{}).Where("is_open = ?", true).Count(&openMerchants)

	var totalDrivers, onlineDrivers int64
	h.db.Model(&model.Driver{}).Count(&totalDrivers)
	h.db.Model(&model.Driver{}).Where("is_online = ?", true).Count(&onlineDrivers)

	var totalCustomers int64
	h.db.Model(&model.User{}).Where("role = ?", "customer").Count(&totalCustomers)

	var monthRevenue float64
	h.db.Model(&model.Order{}).
		Where("status = ? AND delivered_at >= ?", "delivered", monthStart).
		Select("COALESCE(SUM(platform_markup + delivery_commission + app_service_fee), 0)").
		Scan(&monthRevenue)

	var pendingDriverCash float64
	h.db.Model(&model.Driver{}).
		Select("COALESCE(SUM(cash_balance), 0)").
		Scan(&pendingDriverCash)

	var pendingMerchants int64
	h.db.Model(&model.Merchant{}).Where("is_verified = ?", false).Count(&pendingMerchants)

	c.JSON(http.StatusOK, gin.H{
		"orders": gin.H{
			"total":  totalOrders,
			"today":  todayOrders,
			"active": activeOrders,
		},
		"merchants": gin.H{
			"total":    totalMerchants,
			"verified": verifiedMerchants,
			"open":     openMerchants,
			"pending":  pendingMerchants,
		},
		"drivers": gin.H{
			"total":  totalDrivers,
			"online": onlineDrivers,
		},
		"customers": gin.H{
			"total": totalCustomers,
		},
		"revenue": gin.H{
			"this_month": monthRevenue,
		},
		"pending_driver_cash": pendingDriverCash,
	})
}

// ─── SETTINGS ────────────────────────────────────────────────────────────────

func (h *Handler) GetSettings(c *gin.Context) {
	var settings []model.SystemSetting
	if err := h.db.Find(&settings).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch settings"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"settings": settings})
}

func (h *Handler) UpdateSetting(c *gin.Context) {
	key := c.Param("key")
	var req struct {
		Value string `json:"value" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	result := h.db.Model(&model.SystemSetting{}).Where("key = ?", key).Update("value", req.Value)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update setting"})
		return
	}
	if result.RowsAffected == 0 {
		// Key doesn't exist yet — create it (label defaults to key name)
		if err := h.db.Create(&model.SystemSetting{Key: key, Value: req.Value, Label: key}).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create setting"})
			return
		}
	}
	c.JSON(http.StatusOK, gin.H{"message": "Setting updated"})
}

// ─── USER MANAGEMENT ─────────────────────────────────────────────────────────

func (h *Handler) GetDrivers(c *gin.Context) {
	var drivers []model.Driver
	if err := h.db.Preload("User").Preload("Zone").Find(&drivers).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch drivers"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"drivers": drivers})
}

func (h *Handler) GetCustomers(c *gin.Context) {
	var customers []model.User
	if err := h.db.Where("role = ?", "customer").Find(&customers).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch customers"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"customers": customers})
}

func (h *Handler) GetMerchants(c *gin.Context) {
	var merchants []model.Merchant
	if err := h.db.Preload("Zone").Find(&merchants).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch merchants"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"merchants": merchants})
}

// DeleteMerchant removes a merchant from customer-facing browsing. It's a
// soft delete (GORM's default via Base.DeletedAt) so historical orders,
// settlements, and reviews that reference this merchant stay intact — only
// the merchant row itself, and its own product catalog, stop showing up.
// is_active is cleared first because several customer-facing queries join
// merchants via raw SQL (not GORM's model scope), which doesn't
// automatically respect deleted_at — but they do already filter on
// is_active, so this guarantees the merchant disappears everywhere.
func (h *Handler) DeleteMerchant(c *gin.Context) {
	id := c.Param("id")

	var merchant model.Merchant
	if err := h.db.First(&merchant, "id = ?", id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	h.db.Model(&merchant).Update("is_active", false)

	var catIDs []string
	h.db.Model(&model.ProductCategory{}).Where("merchant_id = ?", id).Pluck("id", &catIDs)
	if len(catIDs) > 0 {
		h.db.Where("category_id IN ?", catIDs).Delete(&model.Product{})
	}
	h.db.Where("merchant_id = ?", id).Delete(&model.ProductCategory{})

	if err := h.db.Delete(&merchant).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete merchant"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Merchant deleted"})
}

// VerifyMerchant approves or rejects a merchant registration
func (h *Handler) VerifyMerchant(c *gin.Context) {
	id := c.Param("id")
	adminID := c.GetString("user_id")

	var req struct {
		Verified bool   `json:"verified"`
		Note     string `json:"note"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var merchant model.Merchant
	if h.db.First(&merchant, "id = ?", id).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	verificationStatus := "approved"
	if !req.Verified {
		verificationStatus = "rejected"
	}

	adminUID, _ := uuid.Parse(adminID)
	now := time.Now()

	h.db.Model(&merchant).Updates(map[string]interface{}{
		"is_verified":         req.Verified,
		"is_active":           req.Verified,
		"verification_status": verificationStatus,
		"verification_note":   req.Note,
		"verified_by_id":      adminUID,
		"verified_at":         now,
	})

	// Approving the store must also unlock the owner's account —
	// merchant users register with is_active=false and /auth/login
	// rejects inactive accounts until this flag flips.
	if req.Verified {
		h.db.Model(&model.User{}).Where("id = ?", merchant.UserID).Update("is_active", true)
	}

	c.JSON(http.StatusOK, gin.H{"message": "Merchant " + verificationStatus})
}

// ToggleUserActive suspends or re-activates a user
func (h *Handler) ToggleUserActive(c *gin.Context) {
	id := c.Param("id")
	var user model.User
	if h.db.First(&user, "id = ?", id).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}
	newStatus := !user.IsActive
	h.db.Model(&user).Update("is_active", newStatus)
	action := "activated"
	if !newStatus {
		action = "suspended"
	}
	c.JSON(http.StatusOK, gin.H{"message": "User " + action, "is_active": newStatus})
}

// ─── DRIVER COD DEPOSITS ──────────────────────────────────────────────────────

// GetDriverDeposits returns deposit history for a specific driver
func (h *Handler) GetDriverDeposits(c *gin.Context) {
	driverID := c.Param("id")
	var deposits []model.DriverDeposit
	h.db.Where("driver_id = ?", driverID).
		Order("created_at DESC").
		Find(&deposits)

	var driver model.Driver
	h.db.Preload("User").First(&driver, "id = ?", driverID)

	c.JSON(http.StatusOK, gin.H{
		"driver":      driver,
		"deposits":    deposits,
		"cod_holding": driver.CodHolding,
	})
}

// CreateDriverDeposit records a COD cash deposit from a driver and clears their balance
func (h *Handler) CreateDriverDeposit(c *gin.Context) {
	driverID := c.Param("id")
	adminID := c.GetString("user_id")

	var req struct {
		Amount    float64 `json:"amount" binding:"required,gt=0"`
		Method    string  `json:"method"`    // cash, bank_transfer
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
	if h.db.First(&driver, "id = ?", driverID).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver not found"})
		return
	}

	adminUID, _ := uuid.Parse(adminID)
	now := time.Now()
	deposit := model.DriverDeposit{
		DriverID:     driver.ID,
		Amount:       req.Amount,
		Method:       req.Method,
		Reference:    req.Reference,
		Notes:        req.Notes,
		VerifiedByID: &adminUID,
		VerifiedAt:   &now,
	}

	tx := h.db.Begin()
	if err := tx.Create(&deposit).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create deposit"})
		return
	}
	// Deduct from driver cash balance
	tx.Model(&model.Driver{}).Where("id = ?", driver.ID).
		UpdateColumn("cash_balance", gorm.Expr("cash_balance - ?", req.Amount))
	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit deposit"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"deposit": deposit, "message": "Deposit recorded"})
}

// ─── ORDERS ──────────────────────────────────────────────────────────────────

func (h *Handler) GetOrders(c *gin.Context) {
	status := c.DefaultQuery("status", "")
	fromDate := c.DefaultQuery("from_date", "")
	toDate := c.DefaultQuery("to_date", "")
	var orders []model.Order
	q := h.db.Preload("Merchant").Preload("Customer").Preload("Driver.User").Preload("Items")
	if status != "" {
		q = q.Where("status = ?", status)
	}
	if fromDate != "" {
		q = q.Where("created_at >= ?", fromDate)
	}
	if toDate != "" {
		q = q.Where("created_at <= ?", toDate)
	}
	q.Order("created_at DESC").Find(&orders)
	c.JSON(http.StatusOK, gin.H{"orders": orders})
}

// ─── SETTLEMENTS ─────────────────────────────────────────────────────────────

// GetSettlements returns platform-level financial summary
func (h *Handler) GetSettlements(c *gin.Context) {
	var totalDriverCash float64
	h.db.Model(&model.Driver{}).Select("COALESCE(SUM(cash_balance), 0)").Scan(&totalDriverCash)

	var totalPlatformRevenue float64
	h.db.Model(&model.Order{}).Where("status = ?", "delivered").
		Select("COALESCE(SUM(platform_markup + delivery_commission + app_service_fee), 0)").
		Scan(&totalPlatformRevenue)

	var pendingMerchantPayout float64
	h.db.Model(&model.MerchantSettlement{}).Where("status = ?", "pending").
		Select("COALESCE(SUM(total_base_product_amount), 0)").
		Scan(&pendingMerchantPayout)

	c.JSON(http.StatusOK, gin.H{
		"total_driver_cash":        totalDriverCash,
		"total_platform_revenue":   totalPlatformRevenue,
		"pending_merchant_payout":  pendingMerchantPayout,
	})
}

// GetMerchantSettlements returns per-merchant settlement data
func (h *Handler) GetMerchantSettlements(c *gin.Context) {
	// Aggregate delivered orders per merchant (not yet settled)
	type MerchantSummary struct {
		MerchantID   string  `json:"merchant_id"`
		MerchantName string  `json:"merchant_name"`
		TotalOrders  int     `json:"total_orders"`
		TotalAmount  float64 `json:"total_amount"` // sum of subtotal (base food price)
	}

	var summaries []MerchantSummary
	h.db.Model(&model.Order{}).
		Select("orders.merchant_id, merchants.name as merchant_name, COUNT(orders.id) as total_orders, COALESCE(SUM(orders.subtotal), 0) as total_amount").
		Joins("JOIN merchants ON merchants.id = orders.merchant_id").
		Where("orders.status = ?", "delivered").
		Group("orders.merchant_id, merchants.name").
		Scan(&summaries)

	// Also return existing settlement records
	var settlements []model.MerchantSettlement
	h.db.Preload("Merchant").Order("created_at DESC").Find(&settlements)

	c.JSON(http.StatusOK, gin.H{
		"pending_payouts": summaries,
		"settlements":     settlements,
	})
}

// ProcessMerchantSettlement creates a settlement record for a merchant
func (h *Handler) ProcessMerchantSettlement(c *gin.Context) {
	merchantID := c.Param("merchantId")
	adminID := c.GetString("user_id")

	var req struct {
		PeriodStart string  `json:"period_start" binding:"required"` // "2026-06-01"
		PeriodEnd   string  `json:"period_end" binding:"required"`   // "2026-06-30"
		Reference   string  `json:"reference"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	start, err := time.Parse("2006-01-02", req.PeriodStart)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid period_start format"})
		return
	}
	end, err2 := time.Parse("2006-01-02", req.PeriodEnd)
	if err2 != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid period_end format"})
		return
	}

	// Calculate total base food amount for this period
	var result struct {
		TotalOrders int
		TotalAmount float64
	}
	h.db.Model(&model.Order{}).
		Select("COUNT(id) as total_orders, COALESCE(SUM(subtotal), 0) as total_amount").
		Where("merchant_id = ? AND status = ? AND delivered_at >= ? AND delivered_at <= ?",
			merchantID, "delivered", start, end.Add(23*time.Hour+59*time.Minute+59*time.Second)).
		Scan(&result)

	if result.TotalOrders == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No delivered orders in this period"})
		return
	}

	mUID, _ := uuid.Parse(merchantID)
	adminUID, _ := uuid.Parse(adminID)
	settlement := model.MerchantSettlement{
		MerchantID:             mUID,
		PeriodStart:            start,
		PeriodEnd:              end,
		TotalOrders:            result.TotalOrders,
		TotalBaseProductAmount: result.TotalAmount,
		Status:                 "pending",
		PaidByID:               &adminUID,
		Reference:              req.Reference,
	}

	if err := h.db.Create(&settlement).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create settlement"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"settlement": settlement})
}

// MarkSettlementPaid marks a settlement as paid
func (h *Handler) MarkSettlementPaid(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		Reference string `json:"reference"`
	}
	c.ShouldBindJSON(&req)

	now := time.Now()
	result := h.db.Model(&model.MerchantSettlement{}).Where("id = ? AND status = ?", id, "pending").
		Updates(map[string]interface{}{
			"status":    "paid",
			"paid_at":   now,
			"reference": req.Reference,
		})
	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Settlement not found or already paid"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Settlement marked as paid"})
}

// ─── PROMOTIONS ───────────────────────────────────────────────────────────────

func (h *Handler) GetPromotions(c *gin.Context) {
	var promos []model.Promotion
	h.db.Order("created_at DESC").Find(&promos)
	c.JSON(http.StatusOK, gin.H{"promotions": promos})
}

type PromoRequest struct {
	Code        string  `json:"code" binding:"required"`
	Title       string  `json:"title" binding:"required"`
	Type        string  `json:"type" binding:"required"` // percentage, fixed, free_delivery
	Value       float64 `json:"value"`                    // required > 0 unless type is free_delivery, checked below
	MinOrder    float64 `json:"min_order"`
	MaxDiscount float64 `json:"max_discount"`
	UsageLimit  int     `json:"usage_limit"`
	StartsAt    string  `json:"starts_at" binding:"required"`
	ExpiresAt   string  `json:"expires_at" binding:"required"`
}

// validatePromoValue enforces a positive value for percentage/fixed promos;
// free_delivery promos carry no numeric value (the discount is "the whole
// delivery fee"), so 0 is valid for that type only.
func validatePromoValue(req PromoRequest) error {
	if req.Type != "free_delivery" && req.Value <= 0 {
		return fmt.Errorf("value must be greater than 0")
	}
	return nil
}

func (h *Handler) CreatePromotion(c *gin.Context) {
	var req PromoRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := validatePromoValue(req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	starts, err := time.Parse("2006-01-02", req.StartsAt)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid starts_at"})
		return
	}
	expires, err := time.Parse("2006-01-02", req.ExpiresAt)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid expires_at"})
		return
	}

	promo := model.Promotion{
		Code:        req.Code,
		Title:       req.Title,
		Type:        req.Type,
		Value:       req.Value,
		MinOrder:    req.MinOrder,
		MaxDiscount: req.MaxDiscount,
		UsageLimit:  req.UsageLimit,
		IsActive:    true,
		StartsAt:    starts,
		ExpiresAt:   expires,
	}
	if err := h.db.Create(&promo).Error; err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": "Promo code already exists"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"promotion": promo})
}

func (h *Handler) UpdatePromotion(c *gin.Context) {
	id := c.Param("id")
	var req PromoRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := validatePromoValue(req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	starts, _ := time.Parse("2006-01-02", req.StartsAt)
	expires, _ := time.Parse("2006-01-02", req.ExpiresAt)

	result := h.db.Model(&model.Promotion{}).Where("id = ?", id).Updates(map[string]interface{}{
		"code": req.Code, "title": req.Title, "type": req.Type,
		"value": req.Value, "min_order": req.MinOrder, "max_discount": req.MaxDiscount,
		"usage_limit": req.UsageLimit, "starts_at": starts, "expires_at": expires,
	})
	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Promotion not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Promotion updated"})
}

// GetFoodCategories returns all food categories (admin view — includes inactive).
func (h *Handler) GetFoodCategories(c *gin.Context) {
	var categories []model.FoodCategory
	h.db.Order("sort_order ASC, name ASC").Find(&categories)
	c.JSON(http.StatusOK, gin.H{"food_categories": categories})
}

type FoodCategoryRequest struct {
	Name      string `json:"name" binding:"required"`
	Icon      string `json:"icon"`
	SortOrder int    `json:"sort_order"`
	IsActive  bool   `json:"is_active"`
}

func (h *Handler) CreateFoodCategory(c *gin.Context) {
	var req FoodCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	category := model.FoodCategory{
		Name:      req.Name,
		Icon:      req.Icon,
		SortOrder: req.SortOrder,
		IsActive:  true,
	}
	if err := h.db.Create(&category).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create food category"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"food_category": category})
}

func (h *Handler) UpdateFoodCategory(c *gin.Context) {
	id := c.Param("id")
	var req FoodCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	result := h.db.Model(&model.FoodCategory{}).Where("id = ?", id).Updates(map[string]interface{}{
		"name": req.Name, "icon": req.Icon, "sort_order": req.SortOrder, "is_active": req.IsActive,
	})
	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Food category not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Food category updated"})
}

func (h *Handler) DeleteFoodCategory(c *gin.Context) {
	id := c.Param("id")
	h.db.Where("id = ?", id).Delete(&model.FoodCategory{})
	c.JSON(http.StatusOK, gin.H{"message": "Food category deleted"})
}

// GetBanners returns all homepage promo banners (admin view — includes inactive).
func (h *Handler) GetBanners(c *gin.Context) {
	var banners []model.Banner
	h.db.Order("sort_order ASC, created_at DESC").Find(&banners)
	c.JSON(http.StatusOK, gin.H{"banners": banners})
}

type BannerRequest struct {
	Title          string  `json:"title" binding:"required"`
	Subtitle       string  `json:"subtitle"`
	CTAText        string  `json:"cta_text"`
	FoodCategoryID *string `json:"food_category_id"`
	PromoType      string  `json:"promo_type"` // "" | "discount" | "free_delivery"
	SortOrder      int     `json:"sort_order"`
	IsActive       bool    `json:"is_active"`
}

func (h *Handler) CreateBanner(c *gin.Context) {
	var req BannerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var foodCategoryUUID *uuid.UUID
	if req.FoodCategoryID != nil && *req.FoodCategoryID != "" {
		parsed, err := uuid.Parse(*req.FoodCategoryID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid food_category_id"})
			return
		}
		foodCategoryUUID = &parsed
	}

	ctaText := req.CTAText
	if ctaText == "" {
		ctaText = "Lihat Menu"
	}

	banner := model.Banner{
		Title:          req.Title,
		Subtitle:       req.Subtitle,
		CTAText:        ctaText,
		FoodCategoryID: foodCategoryUUID,
		PromoType:      req.PromoType,
		SortOrder:      req.SortOrder,
		IsActive:       true,
	}
	if err := h.db.Create(&banner).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create banner"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"banner": banner})
}

func (h *Handler) UpdateBanner(c *gin.Context) {
	id := c.Param("id")
	var req BannerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var foodCategoryUUID *uuid.UUID
	if req.FoodCategoryID != nil && *req.FoodCategoryID != "" {
		parsed, err := uuid.Parse(*req.FoodCategoryID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid food_category_id"})
			return
		}
		foodCategoryUUID = &parsed
	}

	result := h.db.Model(&model.Banner{}).Where("id = ?", id).Updates(map[string]interface{}{
		"title": req.Title, "subtitle": req.Subtitle, "cta_text": req.CTAText,
		"food_category_id": foodCategoryUUID, "promo_type": req.PromoType,
		"sort_order": req.SortOrder, "is_active": req.IsActive,
	})
	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Banner not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Banner updated"})
}

func (h *Handler) DeleteBanner(c *gin.Context) {
	id := c.Param("id")
	h.db.Where("id = ?", id).Delete(&model.Banner{})
	c.JSON(http.StatusOK, gin.H{"message": "Banner deleted"})
}

// UploadBannerImage uploads the banner's promo image, set after creation
// (mirrors merchant.UploadProductImage's create-then-upload flow).
func (h *Handler) UploadBannerImage(c *gin.Context) {
	id := c.Param("id")
	var banner model.Banner
	if err := h.db.Where("id = ?", id).First(&banner).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Banner not found"})
		return
	}

	fh, err := c.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Image file required"})
		return
	}

	url, err := upload.Save(fh, "banners")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	h.db.Model(&banner).Update("image_url", url)
	c.JSON(http.StatusOK, gin.H{"image_url": url})
}

// --- WhatsApp gateway proxy ---
// The gateway container has no host-published port (only reachable from
// sibling containers on the compose network), so every admin-panel call
// goes through these proxy routes instead of hitting it directly.

func (h *Handler) whatsappRequest(method, path string, body io.Reader) (*http.Response, error) {
	req, err := http.NewRequest(method, h.cfg.WhatsApp.GatewayURL+path, body)
	if err != nil {
		return nil, err
	}
	req.Header.Set("X-API-Key", h.cfg.WhatsApp.APIKey)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	client := &http.Client{Timeout: 15 * time.Second}
	return client.Do(req)
}

func (h *Handler) proxyWhatsAppJSON(c *gin.Context, path string) {
	resp, err := h.whatsappRequest(http.MethodGet, path, nil)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "WhatsApp gateway unreachable"})
		return
	}
	defer resp.Body.Close()
	c.Status(resp.StatusCode)
	c.Header("Content-Type", "application/json")
	io.Copy(c.Writer, resp.Body)
}

func (h *Handler) WhatsAppStatus(c *gin.Context) {
	h.proxyWhatsAppJSON(c, "/status")
}

func (h *Handler) WhatsAppLogs(c *gin.Context) {
	h.proxyWhatsAppJSON(c, "/logs")
}

func (h *Handler) WhatsAppQR(c *gin.Context) {
	resp, err := h.whatsappRequest(http.MethodGet, "/qr", nil)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "WhatsApp gateway unreachable"})
		return
	}
	defer resp.Body.Close()
	c.Status(resp.StatusCode)
	c.Header("Content-Type", resp.Header.Get("Content-Type"))
	io.Copy(c.Writer, resp.Body)
}

func (h *Handler) WhatsAppSendMessage(c *gin.Context) {
	var req struct {
		Phone   string `json:"phone" binding:"required"`
		Message string `json:"message" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	payload, _ := json.Marshal(req)
	resp, err := h.whatsappRequest(http.MethodPost, "/send-message", bytes.NewReader(payload))
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "WhatsApp gateway unreachable"})
		return
	}
	defer resp.Body.Close()
	c.Status(resp.StatusCode)
	c.Header("Content-Type", "application/json")
	io.Copy(c.Writer, resp.Body)
}

// PublicActiveBanners returns active homepage promo banners, ordered for
// display as the customer app's Home carousel — no auth required.
func (h *Handler) PublicActiveBanners(c *gin.Context) {
	var banners []model.Banner
	h.db.Where("is_active = ?", true).Order("sort_order ASC, created_at DESC").Find(&banners)
	c.JSON(http.StatusOK, gin.H{"banners": banners})
}

// PublicActivePromotions returns currently-active, non-expired promotions
// for the customer app's Home promo carousel — no auth required.
func (h *Handler) PublicActivePromotions(c *gin.Context) {
	now := time.Now()
	var promos []model.Promotion
	h.db.Where("is_active = ? AND starts_at <= ? AND expires_at >= ?", true, now, now).
		Order("starts_at DESC").
		Find(&promos)
	c.JSON(http.StatusOK, gin.H{"promotions": promos})
}

func (h *Handler) DeletePromotion(c *gin.Context) {
	id := c.Param("id")
	h.db.Where("id = ?", id).Delete(&model.Promotion{})
	c.JSON(http.StatusOK, gin.H{"message": "Promotion deleted"})
}

func (h *Handler) TogglePromotion(c *gin.Context) {
	id := c.Param("id")
	var promo model.Promotion
	if h.db.First(&promo, "id = ?", id).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Promotion not found"})
		return
	}
	h.db.Model(&promo).Update("is_active", !promo.IsActive)
	c.JSON(http.StatusOK, gin.H{"is_active": !promo.IsActive})
}

// UploadPromotionImage uploads a promo card image, set after creation
// (mirrors banner/product image upload's create-then-upload flow).
func (h *Handler) UploadPromotionImage(c *gin.Context) {
	id := c.Param("id")
	var promo model.Promotion
	if err := h.db.Where("id = ?", id).First(&promo).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Promotion not found"})
		return
	}

	fh, err := c.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Image file required"})
		return
	}

	url, err := upload.Save(fh, "promotions")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	h.db.Model(&promo).Update("image_url", url)
	c.JSON(http.StatusOK, gin.H{"image_url": url})
}

// ─── WALLET & WITHDRAWALS ────────────────────────────────────────────────────

// GetWithdrawals returns all withdrawal requests across all users.
func (h *Handler) GetWithdrawals(c *gin.Context) {
	status := c.DefaultQuery("status", "")
	var requests []model.WithdrawalRequest
	q := h.db.Preload("Wallet.User")
	if status != "" {
		q = q.Where("status = ?", status)
	}
	q.Order("created_at DESC").Find(&requests)
	c.JSON(http.StatusOK, gin.H{"withdrawals": requests})
}

// GetDriverCODHolding returns a driver's COD cash balance and deposit history.
func (h *Handler) GetDriverCODHolding(c *gin.Context) {
	driverID := c.Param("id")
	var driver model.Driver
	if h.db.Preload("User").First(&driver, "id = ?", driverID).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver not found"})
		return
	}
	var deposits []model.DriverDeposit
	h.db.Where("driver_id = ?", driverID).Order("created_at DESC").Find(&deposits)
	c.JSON(http.StatusOK, gin.H{
		"driver":      driver,
		"cod_holding": driver.CodHolding,
		"deposits":    deposits,
	})
}

// AdminConfirmCODDeposit allows admin to record a COD deposit on behalf of a driver.
func (h *Handler) AdminConfirmCODDeposit(c *gin.Context) {
	driverID := c.Param("id")
	adminID := c.GetString("user_id")

	var req struct {
		Amount    float64 `json:"amount" binding:"required,gt=0"`
		Method    string  `json:"method"`
		Reference string  `json:"reference"`
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
	if h.db.First(&driver, "id = ?", driverID).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver not found"})
		return
	}
	if driver.CodHolding < req.Amount {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":       "Amount exceeds driver COD holding",
			"cod_holding": driver.CodHolding,
		})
		return
	}

	adminUID, _ := uuid.Parse(adminID)
	now := time.Now()
	deposit := model.DriverDeposit{
		DriverID:     driver.ID,
		Amount:       req.Amount,
		Method:       req.Method,
		Reference:    req.Reference,
		Notes:        req.Notes,
		VerifiedByID: &adminUID,
		VerifiedAt:   &now,
	}

	tx := h.db.Begin()
	tx.Create(&deposit)
	tx.Model(&driver).UpdateColumn("cod_holding", gorm.Expr("cod_holding - ?", req.Amount))
	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to record deposit"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"deposit":           deposit,
		"remaining_holding": driver.CodHolding - req.Amount,
	})
}

// ─── DELIVERY ZONES ──────────────────────────────────────────────────────────

// GetDeliveryZones returns parent zones with their children (kecamatan) embedded.
func (h *Handler) GetDeliveryZones(c *gin.Context) {
	var parents []model.DeliveryZone
	h.db.Where("parent_zone_id IS NULL").Order("city_name ASC").Find(&parents)
	for i := range parents {
		h.db.Where("parent_zone_id = ?", parents[i].ID).Order("city_name ASC").Find(&parents[i].Children)
	}
	c.JSON(http.StatusOK, gin.H{"zones": parents})
}

// CreateDeliveryZone adds a new delivery zone (parent = kota, or child = kecamatan).
func (h *Handler) CreateDeliveryZone(c *gin.Context) {
	var req struct {
		CityName        string  `json:"city_name" binding:"required"`
		Latitude        float64 `json:"latitude" binding:"required"`
		Longitude       float64 `json:"longitude" binding:"required"`
		RadiusKm        float64 `json:"radius_km"`
		BaseFee         float64 `json:"base_fee"`
		PerKmFee        float64 `json:"per_km_fee"`
		IsDefault       bool    `json:"is_default"`
		OsmRelationID   *int64  `json:"osm_relation_id"`
		BoundaryGeoJSON *string `json:"boundary_geojson"`
		ParentZoneID    *string `json:"parent_zone_id"` // nil = parent zone, else = kecamatan
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var parentUID *uuid.UUID
	if req.ParentZoneID != nil && *req.ParentZoneID != "" {
		uid, err := uuid.Parse(*req.ParentZoneID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid parent_zone_id"})
			return
		}
		parentUID = &uid
	}

	isChild := parentUID != nil
	if !isChild {
		if req.RadiusKm == 0 {
			req.RadiusKm = 5
		}
		if req.BaseFee == 0 {
			req.BaseFee = 15000
		}
		if req.PerKmFee == 0 {
			req.PerKmFee = 10000
		}
		if req.IsDefault {
			h.db.Model(&model.DeliveryZone{}).Where("is_default = ?", true).Update("is_default", false)
		}
	}

	zone := model.DeliveryZone{
		CityName:        req.CityName,
		Latitude:        req.Latitude,
		Longitude:       req.Longitude,
		RadiusKm:        req.RadiusKm,
		BaseFee:         req.BaseFee,
		PerKmFee:        req.PerKmFee,
		IsDefault:       req.IsDefault && !isChild,
		IsActive:        true,
		OsmRelationID:   req.OsmRelationID,
		BoundaryGeoJSON: req.BoundaryGeoJSON,
		ParentZoneID:    parentUID,
	}
	if err := h.db.Create(&zone).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create zone"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"zone": zone})
}

// UpdateDeliveryZone edits an existing city zone.
func (h *Handler) UpdateDeliveryZone(c *gin.Context) {
	id := c.Param("id")
	var zone model.DeliveryZone
	if h.db.First(&zone, "id = ?", id).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Zone not found"})
		return
	}

	var req struct {
		CityName        string  `json:"city_name"`
		Latitude        float64 `json:"latitude"`
		Longitude       float64 `json:"longitude"`
		RadiusKm        float64 `json:"radius_km"`
		BaseFee         float64 `json:"base_fee"`
		PerKmFee        float64 `json:"per_km_fee"`
		IsDefault       bool    `json:"is_default"`
		IsActive        bool    `json:"is_active"`
		OsmRelationID   *int64  `json:"osm_relation_id"`
		BoundaryGeoJSON *string `json:"boundary_geojson"`
		ParentZoneID    *string `json:"parent_zone_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var parentUID *uuid.UUID
	if req.ParentZoneID != nil && *req.ParentZoneID != "" {
		uid, err := uuid.Parse(*req.ParentZoneID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid parent_zone_id"})
			return
		}
		parentUID = &uid
	}

	if req.IsDefault && parentUID == nil {
		h.db.Model(&model.DeliveryZone{}).Where("id != ? AND is_default = ?", id, true).Update("is_default", false)
	}

	updates := map[string]interface{}{
		"city_name":        req.CityName,
		"latitude":         req.Latitude,
		"longitude":        req.Longitude,
		"radius_km":        req.RadiusKm,
		"base_fee":         req.BaseFee,
		"per_km_fee":       req.PerKmFee,
		"is_default":       req.IsDefault && parentUID == nil,
		"is_active":         req.IsActive,
		"osm_relation_id":   req.OsmRelationID,
		"boundary_geo_json": req.BoundaryGeoJSON,
		"parent_zone_id":    parentUID,
	}
	if err := h.db.Model(&zone).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update zone: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"zone": zone})
}

// DeleteDeliveryZone removes a city zone.
func (h *Handler) DeleteDeliveryZone(c *gin.Context) {
	id := c.Param("id")
	h.db.Where("id = ?", id).Delete(&model.DeliveryZone{})
	c.JSON(http.StatusOK, gin.H{"message": "Zone deleted"})
}

// ─── ZONE ASSIGNMENT ─────────────────────────────────────────────────────────

// AssignDriverZone sets or clears the operating zone for a driver.
func (h *Handler) AssignDriverZone(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		ZoneID *string `json:"zone_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	updates := map[string]interface{}{"zone_id": nil}
	if req.ZoneID != nil && *req.ZoneID != "" {
		parsed, err := uuid.Parse(*req.ZoneID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid zone_id"})
			return
		}
		updates["zone_id"] = parsed
	}

	if err := h.db.Model(&model.Driver{}).Where("id = ?", id).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update driver zone"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Driver zone updated"})
}

// AssignMerchantZone sets or clears the operating zone for a merchant.
func (h *Handler) AssignMerchantZone(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		ZoneID *string `json:"zone_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	updates := map[string]interface{}{"zone_id": nil}
	if req.ZoneID != nil && *req.ZoneID != "" {
		parsed, err := uuid.Parse(*req.ZoneID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid zone_id"})
			return
		}
		updates["zone_id"] = parsed
	}

	if err := h.db.Model(&model.Merchant{}).Where("id = ?", id).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update merchant zone"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Merchant zone updated"})
}

// ─── DRIVER ASSIGNMENT ────────────────────────────────────────────────────────

// NearbyDriversForOrder returns online available drivers sorted by distance from the order's pickup point.
func (h *Handler) NearbyDriversForOrder(c *gin.Context) {
	orderID := c.Param("id")

	var order model.Order
	if err := h.db.First(&order, "id = ?", orderID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	var drivers []model.Driver
	h.db.Preload("User").Where("is_online = ? AND is_available = ?", true, true).Find(&drivers)

	type DriverWithDistance struct {
		model.Driver
		DistanceKm float64 `json:"distance_km"`
	}

	var result []DriverWithDistance
	for _, d := range drivers {
		dist := haversineKm(order.PickupLat, order.PickupLng, d.Latitude, d.Longitude)
		result = append(result, DriverWithDistance{Driver: d, DistanceKm: dist})
	}

	sort.Slice(result, func(i, j int) bool {
		return result[i].DistanceKm < result[j].DistanceKm
	})

	c.JSON(http.StatusOK, gin.H{"drivers": result, "order_id": orderID})
}

// AssignDriverToOrder pre-assigns a specific driver to a ready order.
// The assigned driver sees it exclusively; other drivers cannot accept it.
func (h *Handler) AssignDriverToOrder(c *gin.Context) {
	orderID := c.Param("id")
	adminID := c.GetString("user_id")

	var req struct {
		DriverID string `json:"driver_id" binding:"required"`
		Note     string `json:"note"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var order model.Order
	if err := h.db.First(&order, "id = ? AND status = ?", orderID, model.OrderStatusReady).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Order not found or not in ready state"})
		return
	}

	// Find the driver record to verify they exist and are active
	var driver model.Driver
	if err := h.db.Preload("User").First(&driver, "id = ?", req.DriverID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver not found"})
		return
	}

	driverUID, _ := uuid.Parse(req.DriverID)
	h.db.Model(&order).Update("driver_id", driverUID)

	c.JSON(http.StatusOK, gin.H{
		"message":     "Driver assigned",
		"order_id":    orderID,
		"driver_id":   req.DriverID,
		"driver_name": driver.User.Name,
		"assigned_by": adminID,
		"note":        req.Note,
	})
}

// AdminCancelOrder allows admin to cancel any non-delivered order and triggers refund if needed.
func (h *Handler) AdminCancelOrder(c *gin.Context) {
	orderID := c.Param("id")
	adminID := c.GetString("user_id")

	var req struct {
		Reason string `json:"reason" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var order model.Order
	if err := h.db.First(&order, "id = ?", orderID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}
	if order.Status == model.OrderStatusDelivered || order.Status == model.OrderStatusCancelled {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot cancel a delivered or already-cancelled order"})
		return
	}

	now := time.Now()
	tx := h.db.Begin()
	tx.Model(&order).Updates(map[string]interface{}{
		"status":       model.OrderStatusCancelled,
		"cancelled_at": &now,
	})

	// If online payment was collected, issue wallet refund to customer
	if order.PaymentStatus == "paid" && order.CustomerID != nil {
		refundNotes := "Admin cancelled order " + order.OrderNumber + ": " + req.Reason
		orderUUID := order.ID
		_ = service.CreditWallet(tx, *order.CustomerID, order.Total, "refund", &orderUUID, refundNotes)
	}

	// Create audit refund record
	adminUID, _ := uuid.Parse(adminID)
	refund := model.RefundRequest{
		OrderID:     order.ID,
		RequestedBy: adminUID,
		Reason:      req.Reason,
		Amount:      order.Total,
		Status:      "approved",
		AdminNote:   "Admin-initiated cancellation",
		ProcessedBy: &adminUID,
		ProcessedAt: &now,
	}
	tx.Create(&refund)

	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to cancel order"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Order cancelled", "refund_issued": order.PaymentStatus == "paid"})
}

// ─── REVENUE ANALYTICS ────────────────────────────────────────────────────────

// GetRevenue returns platform revenue breakdown for a given period.
func (h *Handler) GetRevenue(c *gin.Context) {
	period := c.DefaultQuery("period", "month") // today | week | month | all

	now := time.Now()
	var from time.Time
	switch period {
	case "today":
		from = time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	case "week":
		from = now.AddDate(0, 0, -7)
	case "month":
		from = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())
	default:
		from = time.Time{} // all time
	}

	q := h.db.Model(&model.Order{}).Where("status = ?", "delivered")
	if !from.IsZero() {
		q = q.Where("delivered_at >= ?", from)
	}

	type RevenueRow struct {
		TotalOrders          int64   `json:"total_orders"`
		TotalGMV             float64 `json:"total_gmv"`              // grand total customer paid
		PlatformMarkupTotal  float64 `json:"platform_markup_total"`  // ujrah on products
		DeliveryCommission   float64 `json:"delivery_commission"`    // platform cut on delivery
		AppServiceFee        float64 `json:"app_service_fee"`        // tech fee on delivery
		TaxCollected         float64 `json:"tax_collected"`          // PPN collected
		TotalPlatformRevenue float64 `json:"total_platform_revenue"` // sum of all above
		MerchantPayoutTotal  float64 `json:"merchant_payout_total"`  // what merchants received
		DriverEarningTotal   float64 `json:"driver_earning_total"`   // what drivers received
	}

	var row RevenueRow
	q.Select(`
		COUNT(id) as total_orders,
		COALESCE(SUM(total), 0) as total_gmv,
		COALESCE(SUM(platform_markup), 0) as platform_markup_total,
		COALESCE(SUM(delivery_commission), 0) as delivery_commission,
		COALESCE(SUM(app_service_fee), 0) as app_service_fee,
		COALESCE(SUM(tax_amount), 0) as tax_collected,
		COALESCE(SUM(platform_markup + delivery_commission + app_service_fee), 0) as total_platform_revenue,
		COALESCE(SUM(merchant_payout + merchant_delivery_earning), 0) as merchant_payout_total,
		COALESCE(SUM(driver_earning), 0) as driver_earning_total
	`).Scan(&row)

	// Daily breakdown for chart (last 30 days or period)
	type DayRow struct {
		Day     string  `json:"day"`
		Orders  int64   `json:"orders"`
		Revenue float64 `json:"revenue"`
		GMV     float64 `json:"gmv"`
	}
	var daily []DayRow
	dailyQ := h.db.Model(&model.Order{}).Where("status = ?", "delivered")
	if !from.IsZero() {
		dailyQ = dailyQ.Where("delivered_at >= ?", from)
	}
	dailyQ.Select(`
		DATE(delivered_at) as day,
		COUNT(id) as orders,
		COALESCE(SUM(platform_markup + delivery_commission + app_service_fee), 0) as revenue,
		COALESCE(SUM(total), 0) as gmv
	`).Group("DATE(delivered_at)").Order("day ASC").Scan(&daily)

	c.JSON(http.StatusOK, gin.H{
		"period":  period,
		"summary": row,
		"daily":   daily,
	})
}

// ─── REFUND MANAGEMENT ────────────────────────────────────────────────────────

// GetRefunds returns all refund requests with optional status filter.
func (h *Handler) GetRefunds(c *gin.Context) {
	status := c.DefaultQuery("status", "")
	var refunds []model.RefundRequest
	q := h.db.Preload("Order").Order("created_at DESC")
	if status != "" {
		q = q.Where("status = ?", status)
	}
	q.Find(&refunds)
	c.JSON(http.StatusOK, gin.H{"refunds": refunds})
}

// ProcessRefund approves or rejects a customer refund request.
// On approval: reverses merchant wallet credit and (for online payment) credits customer wallet.
func (h *Handler) ProcessRefund(c *gin.Context) {
	refundID := c.Param("id")
	adminID := c.GetString("user_id")

	var req struct {
		Approve   bool   `json:"approve"`
		AdminNote string `json:"admin_note"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var refund model.RefundRequest
	if err := h.db.Preload("Order").First(&refund, "id = ?", refundID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Refund request not found"})
		return
	}
	if refund.Status != "pending" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Refund already processed"})
		return
	}

	now := time.Now()
	adminUID, _ := uuid.Parse(adminID)
	status := "rejected"
	if req.Approve {
		status = "approved"
	}

	tx := h.db.Begin()

	if req.Approve {
		order := refund.Order
		orderUUID := order.ID
		refundNotes := "Refund approved for order " + order.OrderNumber

		// Reverse merchant wallet credit
		if order.MerchantID != nil {
			merchantCredit := order.MerchantPayout
			if merchantCredit == 0 {
				merchantCredit = order.Subtotal - order.PlatformMarkup
			}
			if merchantCredit > 0 {
				_ = service.DebitWallet(tx, *order.MerchantID, merchantCredit, "refund", &orderUUID, "Refund reversal: "+order.OrderNumber)
			}
		}

		// For online paid orders: credit customer wallet
		if order.PaymentStatus == "paid" && order.CustomerID != nil {
			_ = service.CreditWallet(tx, *order.CustomerID, order.Total, "refund", &orderUUID, refundNotes)
		}
		// For COD: refund is manual cash — just record the approval; admin handles cash separately
	}

	tx.Model(&refund).Updates(map[string]interface{}{
		"status":       status,
		"admin_note":   req.AdminNote,
		"processed_by": adminUID,
		"processed_at": now,
	})

	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to process refund"})
		return
	}

	msg := "Refund rejected"
	if req.Approve {
		msg = "Refund approved. Merchant wallet reversed."
		if refund.Order.PaymentStatus == "paid" {
			msg += " Customer wallet credited."
		} else {
			msg += " COD order — handle cash refund manually."
		}
	}
	c.JSON(http.StatusOK, gin.H{"message": msg, "refund": refund})
}

// haversineKm calculates the distance between two GPS coordinates in km.
func haversineKm(lat1, lng1, lat2, lng2 float64) float64 {
	const R = 6371.0
	dLat := (lat2 - lat1) * math.Pi / 180.0
	dLng := (lng2 - lng1) * math.Pi / 180.0
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180.0)*math.Cos(lat2*math.Pi/180.0)*
			math.Sin(dLng/2)*math.Sin(dLng/2)
	return R * 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
}

