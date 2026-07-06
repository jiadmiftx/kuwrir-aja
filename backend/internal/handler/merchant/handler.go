package merchant

import (
	"fmt"
	"math"
	"mime/multipart"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/model"
	"github.com/kuwrir-platform/backend/internal/pricing"
	"github.com/kuwrir-platform/backend/internal/upload"
)

type Handler struct {
	db *gorm.DB
}

func NewHandler(db *gorm.DB) *Handler {
	return &Handler{db: db}
}

// autoAssignZone sets the nearest active zone on the merchant if none is assigned.
func (h *Handler) autoAssignZone(merchant *model.Merchant) {
	if merchant.ZoneID != nil {
		return
	}
	var zones []model.DeliveryZone
	h.db.Where("is_active = ?", true).Find(&zones)
	if len(zones) == 0 {
		return
	}
	var nearest *model.DeliveryZone
	minDist := math.MaxFloat64
	for i := range zones {
		d := haversineKm(merchant.Latitude, merchant.Longitude, zones[i].Latitude, zones[i].Longitude)
		if d < minDist {
			minDist = d
			nearest = &zones[i]
		}
	}
	if nearest != nil && minDist <= 100 {
		h.db.Model(merchant).Update("zone_id", nearest.ID)
		merchant.ZoneID = &nearest.ID
	}
}

func haversineKm(lat1, lng1, lat2, lng2 float64) float64 {
	const R = 6371.0
	dLat := (lat2 - lat1) * math.Pi / 180.0
	dLng := (lng2 - lng1) * math.Pi / 180.0
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180.0)*math.Cos(lat2*math.Pi/180.0)*
			math.Sin(dLng/2)*math.Sin(dLng/2)
	return R * 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
}

// RegisterRoutes sets up merchant routes
func (h *Handler) RegisterRoutes(public *gin.RouterGroup, protected *gin.RouterGroup) {
	// Public routes (customer browsing)
	merchants := public.Group("/merchants")
	{
		merchants.GET("", h.ListMerchants)
		merchants.GET("/nearby", h.NearbyMerchants)
		merchants.GET("/search", h.SearchMerchants)
		merchants.GET("/popular", h.PopularMerchants)
		merchants.GET("/:id", h.GetMerchant)
		merchants.GET("/:id/products", h.GetProducts)
	}

	// Cross-merchant product search (customer app Search screen filters).
	public.GET("/products/search", h.SearchProducts)

	// Cross-merchant trending products (customer app Home "sedang rame"
	// section) — ranked by recent completed-order frequency.
	public.GET("/products/popular", h.PopularProducts)

	// Global food-category taxonomy — read-only for customer app (Home
	// filter chips) and merchant app (product tagging picker).
	public.GET("/food-categories", h.PublicFoodCategories)

	// Merchant owner routes
	owner := protected.Group("/my-store")
	{
		owner.POST("", h.CreateMerchant)          // register + submit docs (multipart)
		owner.GET("/status", h.GetMerchantStatus) // cek status verifikasi
		owner.GET("", h.GetMyMerchant)
		owner.PUT("", h.UpdateMyMerchant)
		owner.POST("/logo", h.UploadStoreLogo)
		owner.POST("/banner", h.UploadStoreBanner)
		owner.PUT("/toggle-open", h.ToggleOpen)
		owner.PUT("/toggle-self-deliver", h.ToggleSelfDeliver)
		owner.PUT("/self-delivery-fee", h.SetSelfDeliveryFee)

		// Self-delivery management
		owner.GET("/my-deliveries", h.MyDeliveries)
		owner.POST("/my-deliveries/:id/pickup", h.SelfDeliveryPickup)
		owner.POST("/my-deliveries/:id/deliver", h.SelfDeliveryDeliver)

		// Product Category management
		owner.GET("/categories", h.GetMyCategories)
		owner.POST("/categories", h.CreateCategory)
		owner.PUT("/categories/:catId", h.UpdateCategory)
		owner.DELETE("/categories/:catId", h.DeleteCategory)

		// Product management
		owner.POST("/categories/:catId/products", h.CreateProduct)
		owner.PUT("/products/:productId", h.UpdateProduct)
		owner.DELETE("/products/:productId", h.DeleteProduct)
		owner.PUT("/products/:productId/toggle", h.ToggleProductAvailability)
		owner.POST("/products/:productId/image", h.UploadProductImage)

		// Product Variant management
		owner.POST("/products/:productId/variants", h.CreateVariant)
		owner.DELETE("/variants/:variantId", h.DeleteVariant)

		// Dashboard summary
		owner.GET("/today-summary", h.TodaySummary)
		owner.GET("/dashboard-summary", h.GetDashboardSummary)
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
	Name           *string  `json:"name"`
	Description    *string  `json:"description"`
	Phone          *string  `json:"phone"`
	Address        *string  `json:"address"`
	Latitude       *float64 `json:"latitude"`
	Longitude      *float64 `json:"longitude"`
	LogoURL        *string  `json:"logo_url"`
	BannerURL      *string  `json:"banner_url"`
	TaxEnabled     *bool    `json:"tax_enabled"`
	TaxRate        *float64 `json:"tax_rate"` // null = inherit platform default
	IsFreeDelivery *bool    `json:"is_free_delivery"`
}

type CreateCategoryRequest struct {
	Name      string `json:"name" binding:"required"`
	SortOrder int    `json:"sort_order"`
}

type CreateProductRequest struct {
	Name               string     `json:"name" binding:"required"`
	Description        string     `json:"description"`
	Price              float64    `json:"price" binding:"required,gt=0"`
	ImageURL           string     `json:"image_url"`
	SortOrder          int        `json:"sort_order"`
	TrackStock         bool       `json:"track_stock"`
	StockQuantity      int        `json:"stock_quantity"`
	SKU                string     `json:"sku"`
	FoodCategoryID     *uuid.UUID `json:"food_category_id"`
	DiscountPrice      *float64   `json:"discount_price"`
	PackagingFee       float64    `json:"packaging_fee"`
	VisibleFromMinute  *int       `json:"visible_from_minute"`
	VisibleUntilMinute *int       `json:"visible_until_minute"`
}

// validateDiscountPrice checks a discount price is sane relative to the
// regular price — nil is always fine (no discount). Both bounds enforced
// here rather than a binding tag since it's a cross-field comparison.
func validateDiscountPrice(discount *float64, price float64) error {
	if discount == nil {
		return nil
	}
	if *discount <= 0 || *discount >= price {
		return fmt.Errorf("discount_price must be greater than 0 and less than price")
	}
	return nil
}

type CreateVariantRequest struct {
	GroupName  string  `json:"group_name" binding:"required"`
	Name       string  `json:"name" binding:"required"`
	Price      float64 `json:"price"`
	IsRequired bool    `json:"is_required"`
	MinSelect  int     `json:"min_select"`
	MaxSelect  int     `json:"max_select"`
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

// NearbyMerchants finds the nearest active food merchants to (lat, lng)
// within radiusKm, using a Haversine approximation, and returns each
// merchant's computed distance_km. Optionally filtered to merchants that
// carry at least one product tagged with food_category_id.
func (h *Handler) NearbyMerchants(c *gin.Context) {
	lat := c.DefaultQuery("lat", "0")
	lng := c.DefaultQuery("lng", "0")
	radiusKm := c.DefaultQuery("radius", "5") // default 5km
	foodCategoryID := c.Query("food_category_id")

	const distanceExpr = "(6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude))))"

	query := h.db.Model(&model.Merchant{}).
		Select("merchants.*, "+distanceExpr+" AS distance_km", lat, lng, lat).
		Where("is_active = ? AND is_verified = ? AND is_open = ? AND type = ?", true, true, true, model.MerchantTypeFood).
		Where(distanceExpr+" < ?", lat, lng, lat, radiusKm)

	if foodCategoryID != "" {
		query = query.Where("EXISTS (SELECT 1 FROM products WHERE products.merchant_id = merchants.id AND products.food_category_id = ?)", foodCategoryID)
	}

	var merchants []model.Merchant
	if err := query.Order("distance_km ASC").Find(&merchants).Error; err != nil {
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

// ProductSearchItem is a Product joined with just enough of its owning
// merchant for the customer app's Search screen to render a result card and
// navigate to that merchant on tap.
type ProductSearchItem struct {
	model.Product
	MerchantID      uuid.UUID `json:"merchant_id"`
	MerchantName    string    `json:"merchant_name"`
	MerchantLogoURL string    `json:"merchant_logo_url,omitempty"`
	MerchantIsOpen  bool      `json:"merchant_is_open"`
}

// SearchProducts finds products across all merchants matching a keyword
// and/or filters (food category, has-discount, merchant free-delivery).
// Powers the customer app's Search screen filter chips and the banner ->
// pre-filtered-search flow.
func (h *Handler) SearchProducts(c *gin.Context) {
	q := c.Query("q")
	foodCategoryID := c.Query("food_category_id")
	discountOnly := c.Query("discount") == "true"
	freeDeliveryOnly := c.Query("free_delivery") == "true"

	query := h.db.Table("products").
		Select("products.*, merchants.id AS merchant_id, merchants.name AS merchant_name, merchants.logo_url AS merchant_logo_url, merchants.is_open AS merchant_is_open").
		Joins("JOIN product_categories ON product_categories.id = products.category_id").
		Joins("JOIN merchants ON merchants.id = product_categories.merchant_id").
		Where("products.is_available = ? AND merchants.is_active = ? AND merchants.is_verified = ?", true, true, true)

	if q != "" {
		term := "%" + strings.ToLower(q) + "%"
		query = query.Where("LOWER(products.name) LIKE ? OR LOWER(products.description) LIKE ?", term, term)
	}
	if foodCategoryID != "" {
		query = query.Where("products.food_category_id = ?", foodCategoryID)
	}
	if discountOnly {
		query = query.Where("products.discount_price IS NOT NULL")
	}
	if freeDeliveryOnly {
		query = query.Where("merchants.is_free_delivery = ?", true)
	}

	var items []ProductSearchItem
	if err := query.Order("products.sort_order ASC").Limit(100).Scan(&items).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to search products"})
		return
	}

	ps := pricing.LoadSettings(h.db)
	for i := range items {
		items[i].Price = pricing.ApplyMarkup(items[i].Price, ps)
		if items[i].DiscountPrice != nil && *items[i].DiscountPrice > 0 {
			marked := pricing.ApplyMarkup(*items[i].DiscountPrice, ps)
			items[i].DiscountPrice = &marked
		}
	}

	c.JSON(http.StatusOK, gin.H{"products": items})
}

// PopularProducts returns the most-ordered products across all merchants
// in the last 30 days, for the customer app Home "Sedang Rame" section.
// Ranking comes from real order_items on delivered orders, not a stored
// counter — there's no popularity field on Product to keep in sync.
func (h *Handler) PopularProducts(c *gin.Context) {
	query := h.db.Table("products").
		Select(`products.*, merchants.id AS merchant_id, merchants.name AS merchant_name,
			merchants.logo_url AS merchant_logo_url, merchants.is_open AS merchant_is_open,
			COUNT(order_items.id) AS order_count`).
		Joins("JOIN product_categories ON product_categories.id = products.category_id").
		Joins("JOIN merchants ON merchants.id = product_categories.merchant_id").
		Joins("JOIN order_items ON order_items.product_id = products.id").
		Joins("JOIN orders ON orders.id = order_items.order_id").
		Where("products.is_available = ? AND merchants.is_active = ? AND merchants.is_verified = ?", true, true, true).
		Where("orders.status = ? AND orders.created_at > ?", model.OrderStatusDelivered, time.Now().AddDate(0, 0, -30)).
		Group("products.id, merchants.id")

	var items []ProductSearchItem
	if err := query.Order("order_count DESC").Limit(15).Scan(&items).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load popular products"})
		return
	}

	// No order history yet (e.g. fresh launch, nothing delivered in the last
	// 30 days) — fall back to just-added available products so the section
	// still has something to show instead of staying empty forever.
	if len(items) == 0 {
		fallback := h.db.Table("products").
			Select(`products.*, merchants.id AS merchant_id, merchants.name AS merchant_name,
				merchants.logo_url AS merchant_logo_url, merchants.is_open AS merchant_is_open,
				0 AS order_count`).
			Joins("JOIN product_categories ON product_categories.id = products.category_id").
			Joins("JOIN merchants ON merchants.id = product_categories.merchant_id").
			Where("products.is_available = ? AND merchants.is_active = ? AND merchants.is_verified = ?", true, true, true)
		if err := fallback.Order("products.created_at DESC").Limit(15).Scan(&items).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load popular products"})
			return
		}
	}

	if items == nil {
		items = []ProductSearchItem{}
	}

	ps := pricing.LoadSettings(h.db)
	for i := range items {
		items[i].Price = pricing.ApplyMarkup(items[i].Price, ps)
		if items[i].DiscountPrice != nil && *items[i].DiscountPrice > 0 {
			marked := pricing.ApplyMarkup(*items[i].DiscountPrice, ps)
			items[i].DiscountPrice = &marked
		}
	}

	c.JSON(http.StatusOK, gin.H{"products": items})
}

// PopularMerchants returns top-rated food merchants for the "Rating
// Tertinggi" home section. Optionally filtered to merchants that carry at
// least one product tagged with food_category_id.
func (h *Handler) PopularMerchants(c *gin.Context) {
	foodCategoryID := c.Query("food_category_id")

	query := h.db.Where("is_active = ? AND is_verified = ? AND type = ?", true, true, model.MerchantTypeFood)
	if foodCategoryID != "" {
		query = query.Where("EXISTS (SELECT 1 FROM products WHERE products.merchant_id = merchants.id AND products.food_category_id = ?)", foodCategoryID)
	}

	var merchants []model.Merchant
	query.Order("rating DESC, total_reviews DESC").Limit(6).Find(&merchants)
	c.JSON(http.StatusOK, gin.H{"merchants": merchants})
}

// PublicFoodCategories returns the active global food-category taxonomy,
// ordered for display as Home screen filter chips.
func (h *Handler) PublicFoodCategories(c *gin.Context) {
	var categories []model.FoodCategory
	h.db.Where("is_active = ?", true).Order("sort_order ASC, name ASC").Find(&categories)
	c.JSON(http.StatusOK, gin.H{"food_categories": categories})
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

// GetProducts returns the full product catalog for a merchant, with prices
// already including the platform markup (what the customer actually pays).
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
	pricing.ApplyMarkupToCategories(h.db, categories)
	c.JSON(http.StatusOK, gin.H{"categories": categories})
}

// GetMyCategories returns all product categories with products for the logged-in merchant
func (h *Handler) GetMyCategories(c *gin.Context) {
	userID := c.GetString("user_id")

	var merchant model.Merchant
	if err := h.db.Where("user_id = ?", userID).First(&merchant).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var categories []model.ProductCategory
	if err := h.db.Where("merchant_id = ?", merchant.ID).
		Preload("Products").
		Preload("Products.Variants").
		Order("sort_order ASC").
		Find(&categories).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch categories"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"categories": categories})
}

// --- Merchant Owner Handlers ---

// CreateMerchant registers a new merchant with documents via multipart/form-data.
// Accepts both JSON (backward compat, no docs) and multipart (with docs).
// Merchant starts inactive until admin approves.
//
// Multipart fields: name, description, phone, address, latitude, longitude
// Files: owner_ktp (foto KTP pemilik), business_license (SIUP/IUMK), store_photo
func (h *Handler) CreateMerchant(c *gin.Context) {
	userID := c.GetString("user_id")

	// Check if user already has a merchant
	var existing model.Merchant
	if err := h.db.Where("user_id = ?", userID).First(&existing).Error; err == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "You already have a store registered"})
		return
	}

	uid, _ := uuid.Parse(userID)

	// Support both multipart and JSON
	var name, description, phone, address string
	var lat, lng float64

	ct := c.ContentType()
	if strings.Contains(ct, "multipart") {
		c.Request.ParseMultipartForm(20 << 20)
		name = c.PostForm("name")
		description = c.PostForm("description")
		phone = c.PostForm("phone")
		address = c.PostForm("address")
		lat = parseFloat(c.PostForm("latitude"))
		lng = parseFloat(c.PostForm("longitude"))
	} else {
		var req CreateMerchantRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		name = req.Name
		description = req.Description
		phone = req.Phone
		address = req.Address
		lat = req.Latitude
		lng = req.Longitude
	}

	if name == "" || phone == "" || address == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "name, phone, and address are required"})
		return
	}

	// Upload documents (placeholder: local disk, later: R2)
	folder := "merchant-docs"
	ownerKtpURL := upload.MustSave(getFile(c, "owner_ktp"), folder)
	bizLicenseURL := upload.MustSave(getFile(c, "business_license"), folder)
	storePhotoURL := upload.MustSave(getFile(c, "store_photo"), folder)

	slug := strings.ToLower(strings.ReplaceAll(name, " ", "-"))

	merchant := model.Merchant{
		UserID:             uid,
		Name:               name,
		Slug:               slug,
		Description:        description,
		Phone:              phone,
		Address:            address,
		Latitude:           lat,
		Longitude:          lng,
		IsActive:           false, // inactive until admin approves
		IsVerified:         false,
		IsOpen:             false,
		OwnerKtpURL:        ownerKtpURL,
		BusinessLicenseURL: bizLicenseURL,
		StorePhotoURL:      storePhotoURL,
		VerificationStatus: "pending",
	}

	if err := h.db.Create(&merchant).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create merchant"})
		return
	}

	h.autoAssignZone(&merchant)

	c.JSON(http.StatusCreated, gin.H{
		"merchant": merchant,
		"message":  "Store registered. Admin will review within 1-2 business days.",
	})
}

// GetMerchantStatus returns merchant verification status for the pending screen.
func (h *Handler) GetMerchantStatus(c *gin.Context) {
	userID := c.GetString("user_id")
	var merchant model.Merchant
	if h.db.Where("user_id = ?", userID).First(&merchant).Error != nil {
		c.JSON(http.StatusOK, gin.H{
			"status":  "no_store",
			"message": "No store registered yet.",
		})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"status":            merchant.VerificationStatus,
		"is_active":         merchant.IsActive,
		"is_verified":       merchant.IsVerified,
		"verification_note": merchant.VerificationNote,
		"name":              merchant.Name,
	})
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
	if req.TaxEnabled != nil {
		updates["tax_enabled"] = *req.TaxEnabled
	}
	if req.TaxRate != nil {
		updates["tax_rate"] = *req.TaxRate
	}
	if req.IsFreeDelivery != nil {
		updates["is_free_delivery"] = *req.IsFreeDelivery
	}

	if err := h.db.Model(&model.Merchant{}).Where("user_id = ?", userID).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update merchant"})
		return
	}

	// Re-assign zone if location changed and zone not yet set
	if req.Latitude != nil || req.Longitude != nil {
		var m model.Merchant
		if h.db.Where("user_id = ?", userID).First(&m).Error == nil {
			h.autoAssignZone(&m)
		}
	}

	c.JSON(http.StatusOK, gin.H{"message": "Merchant updated"})
}

// UploadStoreLogo uploads and sets the merchant's own store logo.
// POST /my-store/logo   multipart field "image"
func (h *Handler) UploadStoreLogo(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	fh, err := c.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Image file required"})
		return
	}

	url, err := upload.Save(fh, "merchants")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	h.db.Model(merchant).Update("logo_url", url)
	c.JSON(http.StatusOK, gin.H{"logo_url": url})
}

// UploadStoreBanner uploads and sets the merchant's own store banner —
// shown at the top of its detail page in customer_app.
// POST /my-store/banner   multipart field "image"
func (h *Handler) UploadStoreBanner(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	fh, err := c.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Image file required"})
		return
	}

	url, err := upload.Save(fh, "merchants")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	h.db.Model(merchant).Update("banner_url", url)
	c.JSON(http.StatusOK, gin.H{"banner_url": url})
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

	var category model.ProductCategory
	if err := h.db.Where("id = ? AND merchant_id = ?", catID, merchant.ID).First(&category).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Category not found"})
		return
	}

	var productCount int64
	h.db.Model(&model.Product{}).Where("category_id = ?", catID).Count(&productCount)
	if productCount > 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": fmt.Sprintf("Kategori masih punya %d produk. Hapus atau pindahkan produknya dulu.", productCount),
		})
		return
	}

	if err := h.db.Delete(&category).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete category"})
		return
	}
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
	if err := validateDiscountPrice(req.DiscountPrice, req.Price); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	categoryUUID, _ := uuid.Parse(catID)
	product := model.Product{
		CategoryID:         categoryUUID,
		FoodCategoryID:     req.FoodCategoryID,
		Name:               req.Name,
		Description:        req.Description,
		Price:              req.Price,
		ImageURL:           req.ImageURL,
		IsAvailable:        true,
		SortOrder:          req.SortOrder,
		TrackStock:         req.TrackStock,
		StockQuantity:      req.StockQuantity,
		SKU:                req.SKU,
		DiscountPrice:      req.DiscountPrice,
		PackagingFee:       req.PackagingFee,
		VisibleFromMinute:  req.VisibleFromMinute,
		VisibleUntilMinute: req.VisibleUntilMinute,
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
	if err := validateDiscountPrice(req.DiscountPrice, req.Price); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	updates := map[string]interface{}{
		"name": req.Name, "description": req.Description,
		"price": req.Price, "sort_order": req.SortOrder,
		"track_stock": req.TrackStock, "stock_quantity": req.StockQuantity, "sku": req.SKU,
		"food_category_id":     req.FoodCategoryID,
		"discount_price":       req.DiscountPrice,
		"packaging_fee":        req.PackagingFee,
		"visible_from_minute":  req.VisibleFromMinute,
		"visible_until_minute": req.VisibleUntilMinute,
	}
	// Photos are set via the separate UploadProductImage endpoint, not this
	// JSON body — the app never sends image_url here, so req.ImageURL is
	// always the zero value "" on edit. Including it unconditionally would
	// wipe the existing photo on every save that doesn't also re-upload one.
	if req.ImageURL != "" {
		updates["image_url"] = req.ImageURL
	}

	h.db.Model(&model.Product{}).Where("id = ?", productID).Updates(updates)
	c.JSON(http.StatusOK, gin.H{"message": "Product updated"})
}

// UploadProductImage uploads a photo for a product owned by the calling merchant.
func (h *Handler) UploadProductImage(c *gin.Context) {
	productID := c.Param("productId")
	userID := c.GetString("user_id")

	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var product model.Product
	if err := h.db.
		Joins("JOIN product_categories ON product_categories.id = products.category_id").
		Where("products.id = ? AND product_categories.merchant_id = ?", productID, merchant.ID).
		First(&product).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	fh, err := c.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Image file required"})
		return
	}

	url, err := upload.Save(fh, "products")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	h.db.Model(&product).Update("image_url", url)
	c.JSON(http.StatusOK, gin.H{"image_url": url})
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

	// MaxSelect defaults to 1 (single-select) when unset, matching the
	// original required/optional toggle's behavior. MinSelect derives
	// IsRequired for older clients that only read that field.
	if req.MaxSelect <= 0 {
		req.MaxSelect = 1
	}
	if req.IsRequired && req.MinSelect == 0 {
		req.MinSelect = 1
	}

	productUUID, _ := uuid.Parse(productID)
	variant := model.ProductVariant{
		ProductID:  productUUID,
		GroupName:  req.GroupName,
		Name:       req.Name,
		Price:      req.Price,
		IsRequired: req.MinSelect > 0,
		MinSelect:  req.MinSelect,
		MaxSelect:  req.MaxSelect,
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

// --- Helpers ---

func getFile(c *gin.Context, field string) *multipart.FileHeader {
	fh, _ := c.FormFile(field)
	return fh
}

func parseFloat(s string) float64 {
	var v float64
	fmt.Sscanf(s, "%f", &v)
	return v
}

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

// TodaySummary returns today's order count and revenue for the merchant's dashboard.
func (h *Handler) TodaySummary(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var orderCount int64
	var totalRevenue float64

	today := time.Now().Truncate(24 * time.Hour)
	tomorrow := today.Add(24 * time.Hour)

	h.db.Model(&model.Order{}).
		Where("merchant_id = ? AND created_at >= ? AND created_at < ? AND status NOT IN (?)",
			merchant.ID, today, tomorrow, []string{"cancelled"}).
		Count(&orderCount)

	h.db.Model(&model.Order{}).
		Select("COALESCE(SUM(subtotal), 0)").
		Where("merchant_id = ? AND created_at >= ? AND created_at < ? AND status = ?",
			merchant.ID, today, tomorrow, "delivered").
		Scan(&totalRevenue)

	c.JSON(http.StatusOK, gin.H{
		"order_count":   orderCount,
		"total_revenue": totalRevenue,
		"date":          today.Format("2006-01-02"),
	})
}

// GetDashboardSummary returns today's order counts broken down by the merchant
// dashboard's four buckets (Baru / Diproses / Kurir dalam perjalanan /
// Selesai), today's revenue, and the merchant's rating — everything the
// Dashboard tab needs in one call.
func (h *Handler) GetDashboardSummary(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	today := time.Now().Truncate(24 * time.Hour)
	tomorrow := today.Add(24 * time.Hour)

	countByStatus := func(statuses ...string) int64 {
		var count int64
		h.db.Model(&model.Order{}).
			Where("merchant_id = ? AND created_at >= ? AND created_at < ? AND status IN (?)",
				merchant.ID, today, tomorrow, statuses).
			Count(&count)
		return count
	}

	var totalRevenue float64
	h.db.Model(&model.Order{}).
		Select("COALESCE(SUM(subtotal), 0)").
		Where("merchant_id = ? AND created_at >= ? AND created_at < ? AND status = ?",
			merchant.ID, today, tomorrow, "delivered").
		Scan(&totalRevenue)

	c.JSON(http.StatusOK, gin.H{
		"date":              today.Format("2006-01-02"),
		"new_orders":        countByStatus("pending"),
		"processing_orders": countByStatus("confirmed", "preparing"),
		"courier_en_route":  countByStatus("ready", "picked_up"),
		"completed_orders":  countByStatus("delivered"),
		"cancelled_orders":  countByStatus("cancelled"),
		"today_revenue":     totalRevenue,
		"rating":            merchant.Rating,
		"total_reviews":     merchant.TotalReviews,
		"top_products":      h.topProducts(merchant.ID),
	})
}

// TopProductItem is a lightweight product projection for the merchant
// Dashboard's "Menu Terlaris" rail — just enough to render a row, ranked
// by real order frequency rather than a stored counter.
type TopProductItem struct {
	ID            uuid.UUID `json:"id"`
	Name          string    `json:"name"`
	ImageURL      string    `json:"image_url,omitempty"`
	Price         float64   `json:"price"`
	DiscountPrice *float64  `json:"discount_price,omitempty"`
	OrderCount    int       `json:"order_count"`
}

// topProducts ranks this merchant's own products by delivered-order
// frequency in the last 30 days. Falls back to the merchant's most
// recently added available products when there's no order history yet
// (e.g. a brand-new store), so the rail isn't just empty.
func (h *Handler) topProducts(merchantID uuid.UUID) []TopProductItem {
	var items []TopProductItem
	h.db.Table("products").
		Select("products.id, products.name, products.image_url, products.price, products.discount_price, COUNT(order_items.id) AS order_count").
		Joins("JOIN product_categories ON product_categories.id = products.category_id").
		Joins("JOIN order_items ON order_items.product_id = products.id").
		Joins("JOIN orders ON orders.id = order_items.order_id").
		Where("product_categories.merchant_id = ? AND orders.status = ? AND orders.created_at > ?",
			merchantID, model.OrderStatusDelivered, time.Now().AddDate(0, 0, -30)).
		Group("products.id").
		Order("order_count DESC").
		Limit(5).
		Scan(&items)

	if len(items) == 0 {
		h.db.Table("products").
			Select("products.id, products.name, products.image_url, products.price, products.discount_price, 0 AS order_count").
			Joins("JOIN product_categories ON product_categories.id = products.category_id").
			Where("product_categories.merchant_id = ? AND products.is_available = ?", merchantID, true).
			Order("products.created_at DESC").
			Limit(5).
			Scan(&items)
	}

	if items == nil {
		items = []TopProductItem{}
	}
	return items
}
