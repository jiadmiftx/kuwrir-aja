package merchant

import (
	"fmt"
	"log"
	"math"
	"mime/multipart"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/legal"
	"github.com/kuwrir-platform/backend/internal/model"
	"github.com/kuwrir-platform/backend/internal/pricing"
	"github.com/kuwrir-platform/backend/internal/service"
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
		owner.GET("/agreement/preview", h.PreviewAgreement)
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

		// Promo codes (merchant-owned — only ever discount this merchant's
		// own orders, separate from admin's platform-wide promos)
		owner.GET("/promotions", h.GetMyPromotions)
		owner.POST("/promotions", h.CreateMyPromotion)
		owner.PUT("/promotions/:id", h.UpdateMyPromotion)
		owner.DELETE("/promotions/:id", h.DeleteMyPromotion)
		owner.PUT("/promotions/:id/toggle", h.ToggleMyPromotion)

		// Homepage banner slots (paid, admin-approved)
		owner.GET("/banners", h.GetMyBanners)
		owner.POST("/banners", h.CreateMyBanner)
		owner.POST("/banners/:id/image", h.UploadMyBannerImage)
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
	NIK         string  `json:"nik"`
	AgreeTerms  bool    `json:"agree_terms"`
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

	// Check if user already has a merchant. Unscoped so a merchant the user
	// previously had soft-deleted (e.g. by an admin) is still found here —
	// otherwise it stays invisible to this check but still occupies the
	// unique index on user_id, and the later db.Create silently 500s.
	var existing model.Merchant
	err := h.db.Unscoped().Where("user_id = ?", userID).First(&existing).Error
	if err == nil {
		if existing.DeletedAt.Valid {
			if err := h.db.Unscoped().Delete(&existing).Error; err != nil {
				log.Printf("CreateMerchant: failed to purge soft-deleted merchant %s: %v", existing.ID, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create merchant"})
				return
			}
		} else {
			c.JSON(http.StatusConflict, gin.H{"error": "You already have a store registered"})
			return
		}
	}

	uid, _ := uuid.Parse(userID)

	// Support both multipart and JSON
	var name, description, phone, address, nik string
	var lat, lng float64
	agreeTerms := false

	ct := c.ContentType()
	if strings.Contains(ct, "multipart") {
		c.Request.ParseMultipartForm(20 << 20)
		name = c.PostForm("name")
		description = c.PostForm("description")
		phone = c.PostForm("phone")
		address = c.PostForm("address")
		lat = parseFloat(c.PostForm("latitude"))
		lng = parseFloat(c.PostForm("longitude"))
		nik = c.PostForm("nik")
		agreeTerms = c.PostForm("agree_terms") == "true"
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
		nik = req.NIK
		agreeTerms = req.AgreeTerms
	}

	if name == "" || phone == "" || address == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "name, phone, and address are required"})
		return
	}
	if !agreeTerms {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Anda harus menyetujui Perjanjian Kemitraan Merchant"})
		return
	}

	// Upload documents (placeholder: local disk, later: R2)
	folder := "merchant-docs"
	ownerKtpURL := upload.MustSave(getFile(c, "owner_ktp"), folder)
	bizLicenseURL := upload.MustSave(getFile(c, "business_license"), folder)
	storePhotoURL := upload.MustSave(getFile(c, "store_photo"), folder)

	slug := strings.ToLower(strings.ReplaceAll(name, " ", "-"))
	// The slug column is unique (including soft-deleted rows, since the DB
	// index doesn't know about deleted_at), so two merchants named the same
	// thing would otherwise collide and silently 500. Disambiguate here.
	var slugTaken int64
	h.db.Unscoped().Model(&model.Merchant{}).Where("slug = ?", slug).Count(&slugTaken)
	if slugTaken > 0 {
		slug = slug + "-" + uid.String()[:8]
	}

	var owner model.User
	h.db.Select("name").First(&owner, "id = ?", userID)
	agreementText := legal.RenderMerchantAgreement(legal.MerchantSignerData{
		OwnerName: owner.Name,
		NIK:       nik,
		StoreName: name,
		Phone:     phone,
		Address:   address,
	})
	now := time.Now()

	merchant := model.Merchant{
		UserID:              uid,
		Name:                name,
		Slug:                slug,
		Description:         description,
		Phone:               phone,
		Address:             address,
		Latitude:            lat,
		Longitude:           lng,
		IsActive:            false, // inactive until admin approves
		IsVerified:          false,
		IsOpen:              false,
		OwnerKtpURL:         ownerKtpURL,
		BusinessLicenseURL:  bizLicenseURL,
		StorePhotoURL:       storePhotoURL,
		VerificationStatus:  "pending",
		AgreementAcceptedAt: &now,
		AgreementVersion:    legal.CurrentVersion,
		AgreementSnapshot:   agreementText,
	}

	if err := h.db.Create(&merchant).Error; err != nil {
		log.Printf("CreateMerchant: db.Create failed for user %s: %v", userID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create merchant"})
		return
	}
	if nik != "" {
		h.db.Model(&model.User{}).Where("id = ?", userID).Update("nik", nik)
	}

	h.autoAssignZone(&merchant)

	c.JSON(http.StatusCreated, gin.H{
		"merchant": merchant,
		"message":  "Store registered. Admin will review within 1-2 business days.",
	})
}

// PreviewAgreement renders the partnership agreement with the not-yet-submitted
// registration data the user has entered so far, so the app can show a finished
// contract before the "Setuju & Daftar" step. Query params: nik, store_name,
// phone, address (owner name is read from the account).
func (h *Handler) PreviewAgreement(c *gin.Context) {
	userID := c.GetString("user_id")
	var owner model.User
	h.db.Select("name").First(&owner, "id = ?", userID)

	content := legal.RenderMerchantAgreement(legal.MerchantSignerData{
		OwnerName: owner.Name,
		NIK:       c.Query("nik"),
		StoreName: c.Query("store_name"),
		Phone:     c.Query("phone"),
		Address:   c.Query("address"),
	})
	c.JSON(http.StatusOK, gin.H{"content": content, "version": legal.CurrentVersion})
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

// --- Promo Code Handlers ---
//
// Mirrors admin's platform-wide promo CRUD (admin/handler.go), but every
// query is scoped to "merchant_id = this merchant's own ID" — a merchant can
// never see or touch another merchant's promo, or a platform-wide one.

type MerchantPromoRequest struct {
	Code        string  `json:"code" binding:"required"`
	Title       string  `json:"title" binding:"required"`
	Type        string  `json:"type" binding:"required"` // percentage, fixed, free_delivery
	Value       float64 `json:"value"`                    // required > 0 unless type is free_delivery
	MinOrder    float64 `json:"min_order"`
	MaxDiscount float64 `json:"max_discount"`
	UsageLimit  int     `json:"usage_limit"`
	StartsAt    string  `json:"starts_at" binding:"required"`
	ExpiresAt   string  `json:"expires_at" binding:"required"`
}

func validateMerchantPromoValue(req MerchantPromoRequest) error {
	if req.Type != "free_delivery" && req.Value <= 0 {
		return fmt.Errorf("value must be greater than 0")
	}
	return nil
}

func (h *Handler) GetMyPromotions(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var promos []model.Promotion
	h.db.Where("merchant_id = ?", merchant.ID).Order("created_at DESC").Find(&promos)
	c.JSON(http.StatusOK, gin.H{"promotions": promos})
}

func (h *Handler) CreateMyPromotion(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var req MerchantPromoRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := validateMerchantPromoValue(req); err != nil {
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
		MerchantID:  &merchant.ID,
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

func (h *Handler) UpdateMyPromotion(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var req MerchantPromoRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := validateMerchantPromoValue(req); err != nil {
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

	result := h.db.Model(&model.Promotion{}).
		Where("id = ? AND merchant_id = ?", id, merchant.ID).
		Updates(map[string]interface{}{
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

func (h *Handler) DeleteMyPromotion(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	result := h.db.Where("id = ? AND merchant_id = ?", id, merchant.ID).Delete(&model.Promotion{})
	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Promotion not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Promotion deleted"})
}

func (h *Handler) ToggleMyPromotion(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var promo model.Promotion
	if err := h.db.Where("id = ? AND merchant_id = ?", id, merchant.ID).First(&promo).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Promotion not found"})
		return
	}
	h.db.Model(&promo).Update("is_active", !promo.IsActive)
	c.JSON(http.StatusOK, gin.H{"is_active": !promo.IsActive})
}

// --- Homepage Banner Slot Handlers ---
//
// A merchant can buy a homepage carousel slot for a flat price per day,
// paid out of their existing Wallet balance (same balance/ledger as order
// payouts and withdrawals — see service.DebitMerchantWallet). The slot
// doesn't go live until an admin approves it (Banner.Status).

// defaultBannerPricePerDay is used until an admin sets a real value via the
// "banner_price_per_day" system_settings key.
const defaultBannerPricePerDay = 50000

func (h *Handler) loadBannerPricePerDay() float64 {
	var s model.SystemSetting
	if err := h.db.Where("key = ?", "banner_price_per_day").First(&s).Error; err == nil {
		if v, err := strconv.ParseFloat(s.Value, 64); err == nil && v > 0 {
			return v
		}
	}
	return defaultBannerPricePerDay
}

type BannerPurchaseRequest struct {
	Title    string `json:"title" binding:"required"`
	Subtitle string `json:"subtitle"`
	CTAText  string `json:"cta_text"`
	Days     int    `json:"days" binding:"required,min=1"`
}

func (h *Handler) GetMyBanners(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var banners []model.Banner
	h.db.Where("merchant_id = ?", merchant.ID).Order("created_at DESC").Find(&banners)
	c.JSON(http.StatusOK, gin.H{"banners": banners})
}

func (h *Handler) CreateMyBanner(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var req BannerPurchaseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	pricePerDay := h.loadBannerPricePerDay()
	cost := pricePerDay * float64(req.Days)
	now := time.Now()
	expires := now.AddDate(0, 0, req.Days)

	ctaText := req.CTAText
	if ctaText == "" {
		ctaText = "Lihat Menu"
	}

	banner := model.Banner{
		MerchantID: &merchant.ID,
		Title:      req.Title,
		Subtitle:   req.Subtitle,
		CTAText:    ctaText,
		IsActive:   true,
		Status:     "pending_review",
		StartsAt:   &now,
		ExpiresAt:  &expires,
		PricePaid:  cost,
	}

	tx := h.db.Begin()
	notes := fmt.Sprintf("Slot banner homepage %d hari (%s)", req.Days, req.Title)
	if err := service.DebitMerchantWallet(tx, merchant.ID, cost, "banner_ad", nil, notes); err != nil {
		tx.Rollback()
		c.JSON(http.StatusBadRequest, gin.H{"error": "Saldo wallet tidak cukup untuk membeli slot ini. Silakan top up terlebih dahulu."})
		return
	}
	if err := tx.Create(&banner).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create banner"})
		return
	}
	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create banner"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"banner": banner})
}

// UploadMyBannerImage sets the image for a banner slot the merchant just
// purchased. Separate step (create-then-upload) rather than one multipart
// request, mirroring admin's UploadPromotionImage.
func (h *Handler) UploadMyBannerImage(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchantByUser(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var banner model.Banner
	if err := h.db.Where("id = ? AND merchant_id = ?", id, merchant.ID).First(&banner).Error; err != nil {
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
