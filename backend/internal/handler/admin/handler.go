package admin

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/handler/driverreg"
	"github.com/kuwrir-platform/backend/internal/model"
)

type Handler struct {
	db *gorm.DB
}

func NewHandler(db *gorm.DB) *Handler {
	return &Handler{db: db}
}

func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	// Dashboard
	r.GET("/dashboard/stats", h.DashboardStats)

	// Settings
	r.GET("/settings", h.GetSettings)
	r.PUT("/settings/:key", h.UpdateSetting)

	// User management
	r.GET("/drivers", h.GetDrivers)
	r.GET("/customers", h.GetCustomers)
	r.GET("/merchants", h.GetMerchants)
	r.PUT("/merchants/:id/verify", h.VerifyMerchant)
	r.PUT("/users/:id/toggle-active", h.ToggleUserActive)

	// Driver COD deposits
	r.GET("/drivers/:id/deposits", h.GetDriverDeposits)
	r.POST("/drivers/:id/deposits", h.CreateDriverDeposit)

	// Orders
	r.GET("/orders", h.GetOrders)

	// Settlements
	r.GET("/settlements", h.GetSettlements)
	r.GET("/settlements/merchants", h.GetMerchantSettlements)
	r.POST("/settlements/merchants/:merchantId/process", h.ProcessMerchantSettlement)
	r.PUT("/settlements/:id/mark-paid", h.MarkSettlementPaid)

	// Driver applications
	r.GET("/driver-applications", driverreg.ListDriverApplications(h.db))
	r.PUT("/driver-applications/:id/review", driverreg.ReviewDriverApplication(h.db))

	// Promotions
	r.GET("/promotions", h.GetPromotions)
	r.POST("/promotions", h.CreatePromotion)
	r.PUT("/promotions/:id", h.UpdatePromotion)
	r.DELETE("/promotions/:id", h.DeletePromotion)
	r.PUT("/promotions/:id/toggle", h.TogglePromotion)
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
		Select("COALESCE(SUM(platform_markup + delivery_commission), 0)").
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
		c.JSON(http.StatusNotFound, gin.H{"error": "Setting not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Setting updated"})
}

// ─── USER MANAGEMENT ─────────────────────────────────────────────────────────

func (h *Handler) GetDrivers(c *gin.Context) {
	var drivers []model.Driver
	if err := h.db.Preload("User").Find(&drivers).Error; err != nil {
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
	if err := h.db.Find(&merchants).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch merchants"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"merchants": merchants})
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
		"cash_balance": driver.CashBalance,
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
	var orders []model.Order
	q := h.db.Preload("Merchant").Preload("Customer").Preload("Driver").Preload("Items")
	if status != "" {
		q = q.Where("status = ?", status)
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
		Select("COALESCE(SUM(platform_markup + delivery_commission), 0)").
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
	Value       float64 `json:"value" binding:"required,gt=0"`
	MinOrder    float64 `json:"min_order"`
	MaxDiscount float64 `json:"max_discount"`
	UsageLimit  int     `json:"usage_limit"`
	StartsAt    string  `json:"starts_at" binding:"required"`
	ExpiresAt   string  `json:"expires_at" binding:"required"`
}

func (h *Handler) CreatePromotion(c *gin.Context) {
	var req PromoRequest
	if err := c.ShouldBindJSON(&req); err != nil {
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
