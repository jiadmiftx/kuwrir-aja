package admin

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/model"
)

type Handler struct {
	db *gorm.DB
}

func NewHandler(db *gorm.DB) *Handler {
	return &Handler{db: db}
}

// RegisterRoutes sets up admin routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	settings := r.Group("/settings")
	{
		settings.GET("", h.GetSettings)
		settings.PUT("/:key", h.UpdateSetting)
	}

	r.GET("/drivers", h.GetDrivers)
	r.GET("/customers", h.GetCustomers)
	r.GET("/merchants", h.GetMerchants)
	r.GET("/orders", h.GetOrders)
	r.GET("/settlements", h.GetSettlements)
}

// GetSettings returns all system settings
func (h *Handler) GetSettings(c *gin.Context) {
	var settings []model.SystemSetting
	if err := h.db.Find(&settings).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch settings"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"settings": settings})
}

// UpdateSetting updates a single system setting by key
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

	c.JSON(http.StatusOK, gin.H{"message": "Setting updated successfully"})
}

// GetDrivers returns all drivers
func (h *Handler) GetDrivers(c *gin.Context) {
	var drivers []model.Driver
	if err := h.db.Preload("User").Find(&drivers).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch drivers"})
		return
	}
	c.JSON(http.StatusOK, drivers)
}

// GetCustomers returns all customers (Users with role 'customer')
func (h *Handler) GetCustomers(c *gin.Context) {
	var customers []model.User
	if err := h.db.Where("role = ?", "customer").Find(&customers).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch customers"})
		return
	}
	c.JSON(http.StatusOK, customers)
}

// GetMerchants returns all merchants
func (h *Handler) GetMerchants(c *gin.Context) {
	var merchants []model.Merchant
	if err := h.db.Find(&merchants).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch merchants"})
		return
	}
	c.JSON(http.StatusOK, merchants)
}

// GetOrders returns all orders
func (h *Handler) GetOrders(c *gin.Context) {
	var orders []model.Order
	if err := h.db.Preload("Merchant").Preload("Customer").Preload("Driver").Find(&orders).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch orders"})
		return
	}
	c.JSON(http.StatusOK, orders)
}

// GetSettlements returns financial data
func (h *Handler) GetSettlements(c *gin.Context) {
	// Simple aggregate query for settlements
	var totalDriverCash float64
	h.db.Model(&model.Driver{}).Select("COALESCE(SUM(cash_balance), 0)").Scan(&totalDriverCash)

	var totalPlatformRevenue float64
	h.db.Model(&model.Order{}).Where("status = ?", "delivered").Select("COALESCE(SUM(platform_markup), 0)").Scan(&totalPlatformRevenue)

	c.JSON(http.StatusOK, gin.H{
		"total_driver_cash":      totalDriverCash,
		"total_platform_revenue": totalPlatformRevenue,
	})
}
