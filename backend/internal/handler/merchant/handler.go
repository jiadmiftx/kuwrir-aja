package merchant

import (
	"net/http"
	"strings"
	"time"

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

// RegisterRoutes sets up merchant routes
func (h *Handler) RegisterRoutes(public *gin.RouterGroup, protected *gin.RouterGroup) {
	// Public routes (customer browsing)
	merchants := public.Group("/merchants")
	{
		merchants.GET("", h.ListMerchants)
		merchants.GET("/nearby", h.NearbyMerchants)
		merchants.GET("/search", h.SearchMerchants)
		merchants.GET("/:id", h.GetMerchant)
		merchants.GET("/:id/products", h.GetProducts)
	}

	// Merchant owner routes
	owner := protected.Group("/my-store")
	{
		owner.POST("", h.CreateMerchant)
		owner.GET("", h.GetMyMerchant)
		owner.PUT("", h.UpdateMyMerchant)
		owner.PUT("/toggle-open", h.ToggleOpen)
		owner.PUT("/toggle-self-deliver", h.ToggleSelfDeliver)
		owner.PUT("/self-delivery-fee", h.SetSelfDeliveryFee)

		// Self-delivery management
		owner.GET("/my-deliveries", h.MyDeliveries)
		owner.POST("/my-deliveries/:id/pickup", h.SelfDeliveryPickup)
		owner.POST("/my-deliveries/:id/deliver", h.SelfDeliveryDeliver)

		// Product Category management
		owner.POST("/categories", h.CreateCategory)
		owner.PUT("/categories/:catId", h.UpdateCategory)
		owner.DELETE("/categories/:catId", h.DeleteCategory)

		// Product management
		owner.POST("/categories/:catId/products", h.CreateProduct)
		owner.PUT("/products/:productId", h.UpdateProduct)
		owner.DELETE("/products/:productId", h.DeleteProduct)
		owner.PUT("/products/:productId/toggle", h.ToggleProductAvailability)

		// Product Variant management
		owner.POST("/products/:productId/variants", h.CreateVariant)
		owner.DELETE("/variants/:variantId", h.DeleteVariant)
	}
}

// --- Request DTOs ---

type CreateMerchantRequest struct {
	Name        string  `json:"name" binding:"required"`
	Description string  `json:"description"`
	Phone       string  `json:"phone" binding:"required"`
	Address     string  `json:"address" binding:"required"`
	Latitude    float64 `json:"latitude" binding:"required"`
	Longitude   float64 `json:"longitude" binding:"required"`
}

type UpdateMerchantRequest struct {
	Name        *string  `json:"name"`
	Description *string  `json:"description"`
	Phone       *string  `json:"phone"`
	Address     *string  `json:"address"`
	Latitude    *float64 `json:"latitude"`
	Longitude   *float64 `json:"longitude"`
	LogoURL     *string  `json:"logo_url"`
	BannerURL   *string  `json:"banner_url"`
}

type CreateCategoryRequest struct {
	Name      string `json:"name" binding:"required"`
	SortOrder int    `json:"sort_order"`
}

type CreateProductRequest struct {
	Name          string  `json:"name" binding:"required"`
	Description   string  `json:"description"`
	Price         float64 `json:"price" binding:"required,gt=0"`
	ImageURL      string  `json:"image_url"`
	SortOrder     int     `json:"sort_order"`
	TrackStock    bool    `json:"track_stock"`
	StockQuantity int     `json:"stock_quantity"`
	SKU           string  `json:"sku"`
}

type CreateVariantRequest struct {
	GroupName  string  `json:"group_name" binding:"required"`
	Name       string  `json:"name" binding:"required"`
	Price      float64 `json:"price"`
	IsRequired bool    `json:"is_required"`
}

// --- Public Handlers ---

// ListMerchants returns all active and verified merchants
func (h *Handler) ListMerchants(c *gin.Context) {
	var merchants []model.Merchant
	query := h.db.Where("is_active = ? AND is_verified = ?", true, true)

	if err := query.Find(&merchants).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch merchants"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"merchants": merchants})
}

// NearbyMerchants finds merchants within a radius using PostGIS-compatible distance calculation
func (h *Handler) NearbyMerchants(c *gin.Context) {
	lat := c.DefaultQuery("lat", "0")
	lng := c.DefaultQuery("lng", "0")
	radiusKm := c.DefaultQuery("radius", "5") // default 5km

	var merchants []model.Merchant
	// Haversine formula approximation using plain SQL
	err := h.db.Where("is_active = ? AND is_verified = ? AND is_open = ?", true, true, true).
		Where("(6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude)))) < ?",
			lat, lng, lat, radiusKm).
		Order("rating DESC").
		Find(&merchants).Error

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch nearby merchants"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"merchants": merchants})
}

// SearchMerchants searches merchants by keyword
func (h *Handler) SearchMerchants(c *gin.Context) {
	q := c.DefaultQuery("q", "")
	if q == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Search query required"})
		return
	}

	searchTerm := "%" + strings.ToLower(q) + "%"

	var merchants []model.Merchant
	h.db.Where("is_active = ? AND is_verified = ? AND (LOWER(name) LIKE ? OR LOWER(description) LIKE ?)",
		true, true, searchTerm, searchTerm).
		Find(&merchants)

	c.JSON(http.StatusOK, gin.H{"merchants": merchants})
}

// GetMerchant returns a single merchant
func (h *Handler) GetMerchant(c *gin.Context) {
	id := c.Param("id")

	var merchant model.Merchant
	if err := h.db.Where("id = ? AND is_active = ?", id, true).First(&merchant).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"merchant": merchant})
}

// GetProducts returns the full product catalog for a merchant
func (h *Handler) GetProducts(c *gin.Context) {
	id := c.Param("id")

	var categories []model.ProductCategory
	if err := h.db.Where("merchant_id = ?", id).
		Preload("Products", "is_available = ?", true).
		Preload("Products.Variants").
		Order("sort_order ASC").
		Find(&categories).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch products"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"categories": categories})
}

// --- Merchant Owner Handlers ---

// CreateMerchant registers a new merchant for the logged-in user
func (h *Handler) CreateMerchant(c *gin.Context) {
	userID := c.GetString("user_id")

	var req CreateMerchantRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if user already has a merchant
	var existing model.Merchant
	if err := h.db.Where("user_id = ?", userID).First(&existing).Error; err == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "You already have a store registered"})
		return
	}

	uid, _ := uuid.Parse(userID)
	slug := strings.ToLower(strings.ReplaceAll(req.Name, " ", "-"))

	merchant := model.Merchant{
		UserID:      uid,
		Name:        req.Name,
		Slug:        slug,
		Description: req.Description,
		Phone:       req.Phone,
		Address:     req.Address,
		Latitude:    req.Latitude,
		Longitude:   req.Longitude,
		IsActive:    true,
		IsVerified:  false, // Admin must verify
		IsOpen:      false,
	}

	if err := h.db.Create(&merchant).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create merchant"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"merchant": merchant})
}

// GetMyMerchant returns the current user's merchant
func (h *Handler) GetMyMerchant(c *gin.Context) {
	userID := c.GetString("user_id")

	var merchant model.Merchant
	if err := h.db.Where("user_id = ?", userID).
		Preload("Categories", func(db *gorm.DB) *gorm.DB {
			return db.Order("sort_order ASC")
		}).
		Preload("Categories.Products", func(db *gorm.DB) *gorm.DB {
			return db.Order("sort_order ASC")
		}).
		Preload("Categories.Products.Variants").
		First(&merchant).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"merchant": merchant})
}

// UpdateMyMerchant updates merchant profile
func (h *Handler) UpdateMyMerchant(c *gin.Context) {
	userID := c.GetString("user_id")

	var req UpdateMerchantRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	updates := make(map[string]interface{})
	if req.Name != nil {
		updates["name"] = *req.Name
	}
	if req.Description != nil {
		updates["description"] = *req.Description
	}
	if req.Phone != nil {
		updates["phone"] = *req.Phone
	}
	if req.Address != nil {
		updates["address"] = *req.Address
	}
	if req.Latitude != nil {
		updates["latitude"] = *req.Latitude
	}
	if req.Longitude != nil {
		updates["longitude"] = *req.Longitude
	}
	if req.LogoURL != nil {
		updates["logo_url"] = *req.LogoURL
	}
	if req.BannerURL != nil {
		updates["banner_url"] = *req.BannerURL
	}

	if err := h.db.Model(&model.Merchant{}).Where("user_id = ?", userID).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update merchant"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Merchant updated"})
}

// ToggleOpen toggles the merchant's open/closed status
func (h *Handler) ToggleOpen(c *gin.Context) {
	userID := c.GetString("user_id")

	var merchant model.Merchant
	if err := h.db.Where("user_id = ?", userID).First(&merchant).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	h.db.Model(&merchant).Update("is_open", !merchant.IsOpen)
	c.JSON(http.StatusOK, gin.H{"is_open": !merchant.IsOpen})
}

// --- Product Category Handlers ---

func (h *Handler) CreateCategory(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var req CreateCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	category := model.ProductCategory{
		MerchantID: merchant.ID,
		Name:       req.Name,
		SortOrder:  req.SortOrder,
	}

	if err := h.db.Create(&category).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create category"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"category": category})
}

func (h *Handler) UpdateCategory(c *gin.Context) {
	catID := c.Param("catId")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var req CreateCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	result := h.db.Model(&model.ProductCategory{}).
		Where("id = ? AND merchant_id = ?", catID, merchant.ID).
		Updates(map[string]interface{}{"name": req.Name, "sort_order": req.SortOrder})

	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Category not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Category updated"})
}

func (h *Handler) DeleteCategory(c *gin.Context) {
	catID := c.Param("catId")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	h.db.Where("id = ? AND merchant_id = ?", catID, merchant.ID).Delete(&model.ProductCategory{})
	c.JSON(http.StatusOK, gin.H{"message": "Category deleted"})
}

// --- Product Handlers ---

func (h *Handler) CreateProduct(c *gin.Context) {
	catID := c.Param("catId")
	userID := c.GetString("user_id")
	if _, err := h.getMerchantByUser(userID); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var req CreateProductRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	categoryUUID, _ := uuid.Parse(catID)
	product := model.Product{
		CategoryID:    categoryUUID,
		Name:          req.Name,
		Description:   req.Description,
		Price:         req.Price,
		ImageURL:      req.ImageURL,
		IsAvailable:   true,
		SortOrder:     req.SortOrder,
		TrackStock:    req.TrackStock,
		StockQuantity: req.StockQuantity,
		SKU:           req.SKU,
	}

	if err := h.db.Create(&product).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create product"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"product": product})
}

func (h *Handler) UpdateProduct(c *gin.Context) {
	productID := c.Param("productId")

	var req CreateProductRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	updates := map[string]interface{}{
		"name": req.Name, "description": req.Description,
		"price": req.Price, "image_url": req.ImageURL, "sort_order": req.SortOrder,
		"track_stock": req.TrackStock, "stock_quantity": req.StockQuantity, "sku": req.SKU,
	}

	h.db.Model(&model.Product{}).Where("id = ?", productID).Updates(updates)
	c.JSON(http.StatusOK, gin.H{"message": "Product updated"})
}

func (h *Handler) DeleteProduct(c *gin.Context) {
	productID := c.Param("productId")
	h.db.Where("id = ?", productID).Delete(&model.Product{})
	c.JSON(http.StatusOK, gin.H{"message": "Product deleted"})
}

func (h *Handler) ToggleProductAvailability(c *gin.Context) {
	productID := c.Param("productId")

	var product model.Product
	if err := h.db.Where("id = ?", productID).First(&product).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	h.db.Model(&product).Update("is_available", !product.IsAvailable)
	c.JSON(http.StatusOK, gin.H{"is_available": !product.IsAvailable})
}

// --- Variant Handlers ---

func (h *Handler) CreateVariant(c *gin.Context) {
	productID := c.Param("productId")

	var req CreateVariantRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	productUUID, _ := uuid.Parse(productID)
	variant := model.ProductVariant{
		ProductID:  productUUID,
		GroupName:  req.GroupName,
		Name:       req.Name,
		Price:      req.Price,
		IsRequired: req.IsRequired,
	}

	if err := h.db.Create(&variant).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create variant"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"variant": variant})
}

func (h *Handler) DeleteVariant(c *gin.Context) {
	variantID := c.Param("variantId")
	h.db.Where("id = ?", variantID).Delete(&model.ProductVariant{})
	c.JSON(http.StatusOK, gin.H{"message": "Variant deleted"})
}

// --- Helper ---

func (h *Handler) getMerchantByUser(userID string) (*model.Merchant, error) {
	var merchant model.Merchant
	err := h.db.Where("user_id = ?", userID).First(&merchant).Error
	return &merchant, err
}

// --- Self-Delivery Handlers ---

// ToggleSelfDeliver toggles self-delivery mode
func (h *Handler) ToggleSelfDeliver(c *gin.Context) {
	userID := c.GetString("user_id")

	var merchant model.Merchant
	if err := h.db.Where("user_id = ?", userID).First(&merchant).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	h.db.Model(&merchant).Update("can_self_deliver", !merchant.CanSelfDeliver)
	c.JSON(http.StatusOK, gin.H{
		"can_self_deliver": !merchant.CanSelfDeliver,
		"message":          "Self-delivery toggled",
	})
}

// SetSelfDeliveryFee sets the merchant's self-delivery fee
func (h *Handler) SetSelfDeliveryFee(c *gin.Context) {
	userID := c.GetString("user_id")

	var req struct {
		Fee float64 `json:"fee"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	result := h.db.Model(&model.Merchant{}).Where("user_id = ?", userID).
		Update("self_delivery_fee", req.Fee)
	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"self_delivery_fee": req.Fee})
}

// MyDeliveries returns orders that this merchant needs to self-deliver
func (h *Handler) MyDeliveries(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var orders []model.Order
	h.db.Where("merchant_id = ? AND delivery_type = ? AND status IN ?",
		merchant.ID, "self", []string{"ready", "picked_up"}).
		Preload("Items").
		Order("created_at DESC").
		Find(&orders)

	c.JSON(http.StatusOK, gin.H{"orders": orders})
}

// SelfDeliveryPickup marks a self-delivery order as picked up by the merchant
func (h *Handler) SelfDeliveryPickup(c *gin.Context) {
	orderID := c.Param("id")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var order model.Order
	if err := h.db.Where("id = ? AND merchant_id = ? AND delivery_type = ? AND status = ?",
		orderID, merchant.ID, "self", "ready").First(&order).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found or not ready"})
		return
	}

	now := time.Now()
	h.db.Model(&order).Updates(map[string]interface{}{
		"status":       "picked_up",
		"picked_up_at": now,
	})

	c.JSON(http.StatusOK, gin.H{"message": "Order picked up by merchant", "status": "picked_up"})
}

// SelfDeliveryDeliver marks a self-delivery order as delivered
func (h *Handler) SelfDeliveryDeliver(c *gin.Context) {
	orderID := c.Param("id")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var order model.Order
	if err := h.db.Where("id = ? AND merchant_id = ? AND delivery_type = ? AND status = ?",
		orderID, merchant.ID, "self", "picked_up").First(&order).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found or not picked up"})
		return
	}

	now := time.Now()
	h.db.Model(&order).Updates(map[string]interface{}{
		"status":       "delivered",
		"delivered_at": now,
	})

	c.JSON(http.StatusOK, gin.H{"message": "Order delivered by merchant", "status": "delivered"})
}
