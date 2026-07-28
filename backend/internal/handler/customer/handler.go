package customer

import (
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/model"
	"github.com/kuwrir-platform/backend/internal/pricing"
	"github.com/kuwrir-platform/backend/internal/service"
)

type Handler struct {
	db *gorm.DB
}

func NewHandler(db *gorm.DB) *Handler {
	return &Handler{db: db}
}

// RegisterRoutes sets up customer order routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	orders := r.Group("/orders")
	{
		orders.POST("", h.PlaceOrder)
		orders.POST("/quote", h.QuoteOrder)
		orders.GET("", h.MyOrders)
		orders.GET("/:id", h.GetOrder)
		orders.POST("/:id/cancel", h.CancelOrder)
		orders.POST("/:id/refund-request", h.RequestRefund)
		orders.GET("/:id/chat", h.GetChat)
		orders.POST("/:id/chat", h.SendChat)
	}

	addresses := r.Group("/addresses")
	{
		addresses.GET("", h.MyAddresses)
		addresses.POST("", h.CreateAddress)
		addresses.PUT("/:id", h.UpdateAddress)
		addresses.DELETE("/:id", h.DeleteAddress)
		addresses.PUT("/:id/default", h.SetDefaultAddress)
	}
}

// --- Addresses ---

type AddressRequest struct {
	Label     string  `json:"label" binding:"required"`
	Address   string  `json:"address" binding:"required"`
	Detail    string  `json:"detail"`
	Latitude  float64 `json:"latitude" binding:"required"`
	Longitude float64 `json:"longitude" binding:"required"`
	IsDefault bool    `json:"is_default"`
}

// MyAddresses lists the current customer's saved addresses, default first.
func (h *Handler) MyAddresses(c *gin.Context) {
	userID := c.GetString("user_id")
	var addresses []model.Address
	h.db.Where("user_id = ?", userID).Order("is_default DESC, created_at DESC").Find(&addresses)
	c.JSON(http.StatusOK, gin.H{"addresses": addresses})
}

// CreateAddress saves a new address for the current customer. The very
// first address a user saves is always the default, regardless of what's
// sent, so there's never a moment with saved addresses but no default.
func (h *Handler) CreateAddress(c *gin.Context) {
	userID := c.GetString("user_id")

	var req AddressRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var count int64
	h.db.Model(&model.Address{}).Where("user_id = ?", userID).Count(&count)
	isDefault := req.IsDefault || count == 0

	address := model.Address{
		UserID:    uuid.MustParse(userID),
		Label:     req.Label,
		Address:   req.Address,
		Detail:    req.Detail,
		Latitude:  req.Latitude,
		Longitude: req.Longitude,
		IsDefault: isDefault,
	}

	err := h.db.Transaction(func(tx *gorm.DB) error {
		if isDefault {
			if err := tx.Model(&model.Address{}).Where("user_id = ?", userID).
				Update("is_default", false).Error; err != nil {
				return err
			}
		}
		return tx.Create(&address).Error
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save address"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"address": address})
}

// UpdateAddress edits a saved address owned by the current customer.
func (h *Handler) UpdateAddress(c *gin.Context) {
	userID := c.GetString("user_id")
	id := c.Param("id")

	var address model.Address
	if err := h.db.Where("id = ? AND user_id = ?", id, userID).First(&address).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Address not found"})
		return
	}

	var req AddressRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err := h.db.Transaction(func(tx *gorm.DB) error {
		if req.IsDefault && !address.IsDefault {
			if err := tx.Model(&model.Address{}).Where("user_id = ?", userID).
				Update("is_default", false).Error; err != nil {
				return err
			}
		}
		return tx.Model(&address).Updates(map[string]interface{}{
			"label":      req.Label,
			"address":    req.Address,
			"detail":     req.Detail,
			"latitude":   req.Latitude,
			"longitude":  req.Longitude,
			"is_default": req.IsDefault,
		}).Error
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update address"})
		return
	}

	h.db.First(&address, "id = ?", id)
	c.JSON(http.StatusOK, gin.H{"address": address})
}

// DeleteAddress removes a saved address. If the deleted address was the
// default and other addresses remain, the most recently added one becomes
// the new default so there's always a default whenever any address exists.
func (h *Handler) DeleteAddress(c *gin.Context) {
	userID := c.GetString("user_id")
	id := c.Param("id")

	var address model.Address
	if err := h.db.Where("id = ? AND user_id = ?", id, userID).First(&address).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Address not found"})
		return
	}

	h.db.Delete(&address)

	if address.IsDefault {
		var next model.Address
		if err := h.db.Where("user_id = ?", userID).Order("created_at DESC").First(&next).Error; err == nil {
			h.db.Model(&next).Update("is_default", true)
		}
	}

	c.JSON(http.StatusOK, gin.H{"message": "Address deleted"})
}

// SetDefaultAddress marks one address as the default, clearing the flag on
// every other address the customer has saved.
func (h *Handler) SetDefaultAddress(c *gin.Context) {
	userID := c.GetString("user_id")
	id := c.Param("id")

	var address model.Address
	if err := h.db.Where("id = ? AND user_id = ?", id, userID).First(&address).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Address not found"})
		return
	}

	err := h.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&model.Address{}).Where("user_id = ?", userID).
			Update("is_default", false).Error; err != nil {
			return err
		}
		return tx.Model(&address).Update("is_default", true).Error
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to set default address"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Default address updated"})
}

// --- Request DTOs ---

type OrderItemRequest struct {
	ProductID  string   `json:"product_id" binding:"required"`
	Quantity   int      `json:"quantity" binding:"required,gte=1"`
	Notes      string   `json:"notes"`
	VariantIDs []string `json:"variant_ids"`
}

// selectedVariantSnapshot is what gets stored as OrderItem.VariantsJSON —
// enough to render a receipt without re-joining ProductVariant later.
type selectedVariantSnapshot struct {
	ID        string  `json:"id"`
	GroupName string  `json:"group_name"`
	Name      string  `json:"name"`
	Price     float64 `json:"price"`
}

type PlaceOrderRequest struct {
	MerchantID     string             `json:"merchant_id" binding:"required"`
	Items          []OrderItemRequest `json:"items" binding:"required,min=1"`
	DropoffAddress string             `json:"dropoff_address" binding:"required"`
	DropoffLat     float64            `json:"dropoff_lat" binding:"required"`
	DropoffLng     float64            `json:"dropoff_lng" binding:"required"`
	ReceiverName   string             `json:"receiver_name"`
	ReceiverPhone  string             `json:"receiver_phone"`
	PaymentType    string             `json:"payment_type"` // cash | qris | virtual_account
	Notes          string             `json:"notes"`
}

// --- Handlers ---

// pricingError carries an HTTP status alongside its message so
// calculateOrderPricing's validation failures (bad product, insufficient
// stock, min order, COD cap, etc.) map to the same status codes PlaceOrder
// always returned, even though the check now lives in a shared function.
type pricingError struct {
	Status  int
	Message string
}

func (e *pricingError) Error() string { return e.Message }

// stockDeduction defers the actual stock decrement to the caller — only
// PlaceOrder should ever apply it (after the order row actually exists);
// QuoteOrder must never mutate stock just because someone previewed a cart.
type stockDeduction struct {
	Product  model.Product
	Quantity int
}

type orderPricingResult struct {
	OrderItems              []model.OrderItem
	SubtotalWithMarkup      float64
	TotalBasePrice          float64
	TotalPlatformMarkup     float64
	TotalPackagingFee       float64
	DeliveryFee             float64
	DeliveryType            string
	DeliveryCommission      float64
	DriverEarning           float64
	AppServiceFee           float64
	MerchantPayout          float64
	MerchantDeliveryEarning float64
	TaxAmount               float64
	GrandTotal              float64
	DistanceKm              float64
	SelectedZone            *model.DeliveryZone
	StockDeductions         []stockDeduction
}

// calculateOrderPricing runs the full COD pricing calculation shared by
// PlaceOrder (which then creates the order) and QuoteOrder (a read-only
// preview before the customer confirms, since the cart screen only shows a
// flat delivery-fee estimate) — kept as one function so the two paths can
// never drift out of sync. Only reads product/settings rows; never
// mutates stock or creates anything.
func (h *Handler) calculateOrderPricing(
	merchant model.Merchant,
	items []OrderItemRequest,
	dropoffLat, dropoffLng float64,
	paymentType string,
	settings settingsData,
	pricingSettings pricing.Settings,
) (*orderPricingResult, *pricingError) {
	distanceKm := haversineDistance(merchant.Latitude, merchant.Longitude, dropoffLat, dropoffLng)

	selectedZone, zoneBasisFee, zonePerKmFee := h.loadHomeKota(merchant.Latitude, merchant.Longitude, settings)

	var deliveryFee float64
	if selectedZone != nil {
		shapes := h.flatZoneShapes(selectedZone)
		deliveryFee = priceDropoff(shapes, dropoffLat, dropoffLng, zoneBasisFee, zonePerKmFee)
	} else {
		// No zones configured at all — fall back to a flat 5km radius
		// around the merchant using the system default fees.
		shapes := []pricing.ZoneShape{{Lat: merchant.Latitude, Lng: merchant.Longitude, RadiusKm: 5.0}}
		deliveryFee = priceDropoff(shapes, dropoffLat, dropoffLng, zoneBasisFee, zonePerKmFee)
	}
	// The per-km formula produces odd figures like 11,412 — round to the
	// nearest thousand rupiah so the customer sees a clean number both in
	// the checkout quote and the actual charge.
	deliveryFee = math.Round(deliveryFee/1000) * 1000

	var orderItems []model.OrderItem
	var subtotalWithMarkup float64
	var totalBasePrice float64
	var totalPlatformMarkup float64
	var totalPackagingFee float64
	var stockDeductions []stockDeduction

	for _, reqItem := range items {
		var product model.Product
		if err := h.db.Where("id = ?", reqItem.ProductID).First(&product).Error; err != nil {
			return nil, &pricingError{http.StatusBadRequest, fmt.Sprintf("Product %s not found", reqItem.ProductID)}
		}

		if !product.IsAvailable {
			return nil, &pricingError{http.StatusBadRequest, fmt.Sprintf("%s is not available", product.Name)}
		}

		if !pricing.IsVisibleNow(product.VisibleFromMinute, product.VisibleUntilMinute) {
			return nil, &pricingError{http.StatusBadRequest, fmt.Sprintf("%s is not available at this time", product.Name)}
		}

		if product.TrackStock && product.StockQuantity < reqItem.Quantity {
			return nil, &pricingError{http.StatusBadRequest, fmt.Sprintf("Insufficient stock for %s", product.Name)}
		}

		// Load this product's variant options and validate the customer's
		// selection against each group's min/max rule (derived from any
		// option in that group — every option in a group is expected to
		// carry the same rule, enforced by the merchant app UI).
		var allVariants []model.ProductVariant
		h.db.Where("product_id = ?", product.ID).Find(&allVariants)

		selectedIDs := make(map[string]bool, len(reqItem.VariantIDs))
		for _, id := range reqItem.VariantIDs {
			selectedIDs[id] = true
		}

		type groupRule struct{ min, max int }
		groupRules := map[string]groupRule{}
		groupCounts := map[string]int{}
		var selectedVariants []model.ProductVariant
		for _, v := range allVariants {
			if _, ok := groupRules[v.GroupName]; !ok {
				groupRules[v.GroupName] = groupRule{v.MinSelect, v.MaxSelect}
			}
			if selectedIDs[v.ID.String()] {
				groupCounts[v.GroupName]++
				selectedVariants = append(selectedVariants, v)
			}
		}
		for group, rule := range groupRules {
			count := groupCounts[group]
			if count < rule.min {
				return nil, &pricingError{http.StatusBadRequest, fmt.Sprintf("%s: pilih minimal %d untuk %s", product.Name, rule.min, group)}
			}
			if rule.max > 0 && count > rule.max {
				return nil, &pricingError{http.StatusBadRequest, fmt.Sprintf("%s: pilih maksimal %d untuk %s", product.Name, rule.max, group)}
			}
		}

		// Apply platform markup — same formula/rounding as the catalog price the
		// customer saw, so the charged total never drifts from what was displayed.
		// Discounted price (when set) is the markup basis, not the regular price.
		effectivePrice := pricing.EffectivePrice(product)
		priceWithMarkup := pricing.ApplyMarkup(effectivePrice, pricingSettings)

		var rawVariantSum, variantsMarkupSum float64
		var variantSnapshots []selectedVariantSnapshot
		for _, v := range selectedVariants {
			vMarked := pricing.ApplyMarkup(v.Price, pricingSettings)
			rawVariantSum += v.Price
			variantsMarkupSum += vMarked
			variantSnapshots = append(variantSnapshots, selectedVariantSnapshot{
				ID: v.ID.String(), GroupName: v.GroupName, Name: v.Name, Price: vMarked,
			})
		}
		if variantSnapshots == nil {
			variantSnapshots = []selectedVariantSnapshot{}
		}
		variantsJSONBytes, _ := json.Marshal(variantSnapshots)
		variantsJSONStr := string(variantsJSONBytes)

		unitPriceWithVariants := priceWithMarkup + variantsMarkupSum
		rawUnitWithVariants := effectivePrice + rawVariantSum
		itemMarkupAmount := unitPriceWithVariants - rawUnitWithVariants
		packagingFeeTotal := product.PackagingFee * float64(reqItem.Quantity)
		itemTotal := unitPriceWithVariants*float64(reqItem.Quantity) + packagingFeeTotal

		var originalPrice *float64
		if product.DiscountPrice != nil && *product.DiscountPrice > 0 {
			orig := product.Price
			originalPrice = &orig
		}

		productID, _ := uuid.Parse(reqItem.ProductID)
		orderItems = append(orderItems, model.OrderItem{
			ProductID:     &productID,
			ItemName:      product.Name,
			Quantity:      reqItem.Quantity,
			BasePrice:     effectivePrice,
			OriginalPrice: originalPrice,
			UnitPrice:     unitPriceWithVariants,
			TotalPrice:    itemTotal,
			Notes:         reqItem.Notes,
			VariantsJSON:  &variantsJSONStr,
		})

		baseItemTotal := rawUnitWithVariants * float64(reqItem.Quantity)
		subtotalWithMarkup += unitPriceWithVariants * float64(reqItem.Quantity)
		totalBasePrice += baseItemTotal
		totalPlatformMarkup += itemMarkupAmount * float64(reqItem.Quantity)
		totalPackagingFee += packagingFeeTotal

		if product.TrackStock {
			stockDeductions = append(stockDeductions, stockDeduction{Product: product, Quantity: reqItem.Quantity})
		}
	}

	// Determine delivery type and calculate accordingly
	deliveryType := "platform"
	var deliveryCommission float64
	var driverEarning float64
	var appServiceFee float64
	var merchantDeliveryEarning float64

	if merchant.CanSelfDeliver {
		// Self-delivery: merchant delivers themselves
		// Platform still takes a commission (Ujrah on delivery service)
		deliveryType = "self"
		deliveryFee = merchant.SelfDeliveryFee
		selfDeliverCommission := deliveryFee * (settings.SelfDeliverCommissionPct / 100.0)
		merchantDeliveryEarning = deliveryFee - selfDeliverCommission
		deliveryCommission = selfDeliverCommission
		driverEarning = 0
	} else {
		// Platform delivery: KUWRIR driver delivers
		deliveryCommission = deliveryFee * (settings.DeliveryCommissionPct / 100.0)
		driverEarning = deliveryFee - deliveryCommission
		if driverEarning < 0 {
			driverEarning = 0
		}
	}

	// App service fee is always charged to customer — applies to ALL delivery types.
	// Customer uses the platform regardless of who delivers (discovery, tracking, payments).
	appServiceFee = deliveryFee * (settings.AppServiceFeePct / 100.0)

	// Merchant receives their base product price only (platform service fee stays with platform)
	merchantPayout := totalBasePrice

	// Apply tax: use merchant's own rate if set, else platform default; 0 if merchant is non-PKP
	effectiveTaxRate := 0.0
	if merchant.TaxEnabled {
		if merchant.TaxRate != nil {
			effectiveTaxRate = *merchant.TaxRate
		} else {
			effectiveTaxRate = settings.TaxPct
		}
	}
	taxAmount := subtotalWithMarkup * (effectiveTaxRate / 100.0)

	// Grand total customer pays (app service fee is an explicit charge to
	// customer; packaging fee is a pass-through merchant cost, not taxed/marked up)
	grandTotal := subtotalWithMarkup + taxAmount + deliveryFee + appServiceFee + totalPackagingFee

	// Enforce min order amount
	if settings.MinOrderAmount > 0 && subtotalWithMarkup < settings.MinOrderAmount {
		return nil, &pricingError{http.StatusBadRequest, fmt.Sprintf("Minimum order amount is IDR %.0f", settings.MinOrderAmount)}
	}

	// Enforce COD cap
	if paymentType == "cash" && settings.MaxCODAmount > 0 && grandTotal > settings.MaxCODAmount {
		return nil, &pricingError{http.StatusBadRequest, fmt.Sprintf("COD maximum is IDR %.0f. Please use online payment for larger orders.", settings.MaxCODAmount)}
	}

	return &orderPricingResult{
		OrderItems:              orderItems,
		SubtotalWithMarkup:      subtotalWithMarkup,
		TotalBasePrice:          totalBasePrice,
		TotalPlatformMarkup:     totalPlatformMarkup,
		TotalPackagingFee:       totalPackagingFee,
		DeliveryFee:             deliveryFee,
		DeliveryType:            deliveryType,
		DeliveryCommission:      deliveryCommission,
		DriverEarning:           driverEarning,
		AppServiceFee:           appServiceFee,
		MerchantPayout:          merchantPayout,
		MerchantDeliveryEarning: merchantDeliveryEarning,
		TaxAmount:               taxAmount,
		GrandTotal:              grandTotal,
		DistanceKm:              distanceKm,
		SelectedZone:            selectedZone,
		StockDeductions:         stockDeductions,
	}, nil
}

// QuoteRequest is the same shape as the item/merchant/dropoff portion of
// PlaceOrderRequest — everything needed to run the pricing calculation
// except the parts (receiver, notes) that don't affect price.
type QuoteRequest struct {
	MerchantID  string             `json:"merchant_id" binding:"required"`
	Items       []OrderItemRequest `json:"items" binding:"required,min=1"`
	DropoffLat  float64            `json:"dropoff_lat" binding:"required"`
	DropoffLng  float64            `json:"dropoff_lng" binding:"required"`
	PaymentType string             `json:"payment_type"`
}

// QuoteOrder computes the real delivery fee, tax, and total for the
// customer app's checkout confirmation screen — without creating an order
// or touching stock. The cart screen only ever shows a flat delivery-fee
// estimate; this is what lets the confirmation step show real numbers
// before the customer commits.
func (h *Handler) QuoteOrder(c *gin.Context) {
	var req QuoteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	settings := h.loadSettings()
	pricingSettings := pricing.LoadSettings(h.db)

	var merchant model.Merchant
	if err := h.db.Where("id = ? AND is_active = ? AND is_verified = ? AND is_open = ?",
		req.MerchantID, true, true, true).First(&merchant).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Merchant not found or closed"})
		return
	}

	result, perr := h.calculateOrderPricing(
		merchant, req.Items, req.DropoffLat, req.DropoffLng, req.PaymentType, settings, pricingSettings)
	if perr != nil {
		c.JSON(perr.Status, gin.H{"error": perr.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"subtotal":        result.SubtotalWithMarkup,
		"packaging_fee":   result.TotalPackagingFee,
		"delivery_fee":    result.DeliveryFee,
		"delivery_type":   result.DeliveryType,
		"app_service_fee": result.AppServiceFee,
		"tax_amount":      result.TaxAmount,
		"total":           result.GrandTotal,
		"distance_km":     result.DistanceKm,
	})
}

// PlaceOrder creates a new order with full COD pricing calculation
func (h *Handler) PlaceOrder(c *gin.Context) {
	userID := c.GetString("user_id")

	var req PlaceOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	settings := h.loadSettings()
	pricingSettings := pricing.LoadSettings(h.db)

	var merchant model.Merchant
	if err := h.db.Where("id = ? AND is_active = ? AND is_verified = ? AND is_open = ?",
		req.MerchantID, true, true, true).First(&merchant).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Merchant not found or closed"})
		return
	}

	result, perr := h.calculateOrderPricing(
		merchant, req.Items, req.DropoffLat, req.DropoffLng, req.PaymentType, settings, pricingSettings)
	if perr != nil {
		c.JSON(perr.Status, gin.H{"error": perr.Message})
		return
	}

	orderNumber := fmt.Sprintf("KWR-%s", time.Now().Format("060102150405"))

	customerUUID, _ := uuid.Parse(userID)
	merchantUUID, _ := uuid.Parse(req.MerchantID)
	now := time.Now()

	paymentType := req.PaymentType
	if paymentType == "" {
		paymentType = "cash"
	}
	// Wallet is not a valid order payment method: Wallet.UserID is the
	// account's single shared balance across every role that phone number
	// holds (customer/driver/merchant are separate apps but the same
	// account row), so paying an order from "wallet" could silently spend
	// a driver's delivery earnings or a merchant's payout. Online payment
	// goes through Duitku instead (see payment.Handler.GetPaymentMethods).
	if paymentType == "wallet" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Wallet is not a supported payment method for orders"})
		return
	}

	order := model.Order{
		OrderNumber:             orderNumber,
		ServiceType:             "ecommerce",
		CustomerID:              &customerUUID,
		MerchantID:              &merchantUUID,
		Status:                  model.OrderStatusPending,
		DeliveryType:            result.DeliveryType,
		PaymentType:             paymentType,
		Subtotal:                result.SubtotalWithMarkup,
		PlatformMarkup:          result.TotalPlatformMarkup,
		TaxAmount:               result.TaxAmount,
		AppServiceFee:           result.AppServiceFee,
		PackagingFee:            result.TotalPackagingFee,
		DeliveryFee:             result.DeliveryFee,
		DeliveryCommission:      result.DeliveryCommission,
		DriverEarning:           result.DriverEarning,
		MerchantPayout:          result.MerchantPayout,
		MerchantDeliveryEarning: result.MerchantDeliveryEarning,
		Total:                   result.GrandTotal,

		PickupAddress: merchant.Address,
		PickupLat:     merchant.Latitude,
		PickupLng:     merchant.Longitude,
		SenderName:    merchant.Name,
		SenderPhone:   merchant.Phone,

		DropoffAddress: req.DropoffAddress,
		DropoffLat:     req.DropoffLat,
		DropoffLng:     req.DropoffLng,
		ReceiverName:   req.ReceiverName,
		ReceiverPhone:  req.ReceiverPhone,

		DistanceKm: result.DistanceKm,
		Notes:      req.Notes,
		PlacedAt:   &now,
		Items:      result.OrderItems,
	}
	if result.SelectedZone != nil {
		order.ZoneID = &result.SelectedZone.ID
	}

	tx := h.db.Begin()
	if err := tx.Create(&order).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create order"})
		return
	}

	// Deduct stock now that the order actually exists.
	for _, d := range result.StockDeductions {
		tx.Model(&model.Product{}).Where("id = ?", d.Product.ID).
			Update("stock_quantity", gorm.Expr("stock_quantity - ?", d.Quantity))
	}

	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create order"})
		return
	}

	// Notify merchant owner about new order
	var merchantOwner model.User
	if h.db.Where("id = ?", merchant.UserID).First(&merchantOwner).Error == nil {
		service.SendToUser(h.db, merchantOwner.ID,
			"Pesanan Baru! 🛍️",
			fmt.Sprintf("Order #%s masuk — segera konfirmasi", order.OrderNumber),
			map[string]string{"order_id": order.ID.String(), "type": "new_order"},
		)
	}

	c.JSON(http.StatusCreated, gin.H{
		"order": order,
		"pricing_breakdown": gin.H{
			"product_subtotal_with_markup": result.SubtotalWithMarkup,
			"platform_markup_total":        result.TotalPlatformMarkup,
			"tax_amount":                   result.TaxAmount,
			"delivery_fee":                 result.DeliveryFee,
			"app_service_fee":              result.AppServiceFee,
			"delivery_commission_kuwrir":   result.DeliveryCommission,
			"driver_earning":               result.DriverEarning,
			"total_customer_pays":          result.GrandTotal,
		},
	})
}

// MyOrders returns all orders for the logged-in customer
func (h *Handler) MyOrders(c *gin.Context) {
	userID := c.GetString("user_id")
	status := c.DefaultQuery("status", "")

	query := h.db.Where("customer_id = ?", userID).
		Preload("Merchant").
		Preload("Items").
		Order("created_at DESC")

	if status != "" {
		query = query.Where("status = ?", status)
	}

	var orders []model.Order
	if err := query.Find(&orders).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch orders"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"orders": orders})
}

// GetOrder returns a single order by ID
func (h *Handler) GetOrder(c *gin.Context) {
	userID := c.GetString("user_id")
	orderID := c.Param("id")

	var order model.Order
	if err := h.db.Where("id = ? AND customer_id = ?", orderID, userID).
		Preload("Merchant").
		Preload("Items").
		First(&order).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"order": order})
}

// CancelOrder cancels an order (only if pending)
func (h *Handler) CancelOrder(c *gin.Context) {
	userID := c.GetString("user_id")
	orderID := c.Param("id")

	var order model.Order
	if err := h.db.Where("id = ? AND customer_id = ?", orderID, userID).First(&order).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	if order.Status != model.OrderStatusPending {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Only pending orders can be cancelled"})
		return
	}

	reason := fmt.Sprintf("Order cancelled by customer: %s", order.OrderNumber)
	if err := service.CancelOrderAndRefund(h.db, &order, reason); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to cancel order"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Order cancelled"})
}

// --- Merchant Order Handlers (for merchant app) ---

type RestaurantOrderHandler struct {
	db *gorm.DB
}

func NewRestaurantOrderHandler(db *gorm.DB) *RestaurantOrderHandler {
	return &RestaurantOrderHandler{db: db}
}

func (h *RestaurantOrderHandler) RegisterRoutes(r *gin.RouterGroup) {
	orders := r.Group("/merchant-orders")
	{
		orders.GET("", h.ActiveOrders)
		orders.POST("/:id/accept", h.AcceptOrder)
		orders.POST("/:id/reject", h.RejectOrder)
		orders.POST("/:id/preparing", h.MarkPreparing)
		orders.POST("/:id/ready", h.MarkReady)
	}
}

// ActiveOrders returns orders for the merchant owner
func (h *RestaurantOrderHandler) ActiveOrders(c *gin.Context) {
	userID := c.GetString("user_id")

	var merchant model.Merchant
	if err := h.db.Where("user_id = ?", userID).First(&merchant).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var orders []model.Order
	h.db.Where("merchant_id = ? AND status IN ? AND (payment_type = ? OR payment_status = ?)", merchant.ID,
		[]string{
			string(model.OrderStatusPending),
			string(model.OrderStatusConfirmed),
			string(model.OrderStatusPreparing),
			string(model.OrderStatusReady),
		}, "cash", "paid").
		Preload("Customer").
		Preload("Items").
		Order("created_at ASC").
		Find(&orders)

	c.JSON(http.StatusOK, gin.H{"orders": orders})
}

// AcceptOrder transitions: pending → confirmed
func (h *RestaurantOrderHandler) AcceptOrder(c *gin.Context) {
	h.transitionOrder(c, model.OrderStatusPending, model.OrderStatusConfirmed, "confirmed_at")
}

// RejectOrder cancels an order the merchant won't fulfill. If the order was
// already paid (online or wallet payment), the customer is instantly
// refunded to their wallet — see service.CancelOrderAndRefund.
func (h *RestaurantOrderHandler) RejectOrder(c *gin.Context) {
	orderID := c.Param("id")
	userID := c.GetString("user_id")

	var req struct {
		Reason string `json:"reason"`
	}
	_ = c.ShouldBindJSON(&req)

	var merchant model.Merchant
	if err := h.db.Where("user_id = ?", userID).First(&merchant).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var order model.Order
	if err := h.db.Where("id = ? AND merchant_id = ? AND status = ?",
		orderID, merchant.ID, model.OrderStatusPending).First(&order).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Order not found or not pending"})
		return
	}
	if !order.IsAwaitingMerchantAction() {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Order payment not yet completed"})
		return
	}

	reason := req.Reason
	if reason == "" {
		reason = fmt.Sprintf("Order rejected by merchant: %s", order.OrderNumber)
	}
	if err := service.CancelOrderAndRefund(h.db, &order, reason); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to reject order"})
		return
	}

	if order.CustomerID != nil {
		service.SendToUser(h.db, *order.CustomerID,
			"Pesanan Ditolak",
			fmt.Sprintf("Order #%s ditolak merchant. Dana dikembalikan ke wallet kamu.", order.OrderNumber),
			map[string]string{"order_id": order.ID.String(), "type": "order_status"})
	}

	c.JSON(http.StatusOK, gin.H{"message": "Order rejected", "status": model.OrderStatusCancelled})
}

// MarkPreparing transitions: confirmed → preparing
func (h *RestaurantOrderHandler) MarkPreparing(c *gin.Context) {
	h.transitionOrder(c, model.OrderStatusConfirmed, model.OrderStatusPreparing, "")
}

// MarkReady transitions: preparing → ready
func (h *RestaurantOrderHandler) MarkReady(c *gin.Context) {
	h.transitionOrder(c, model.OrderStatusPreparing, model.OrderStatusReady, "ready_at")
}

func (h *RestaurantOrderHandler) transitionOrder(c *gin.Context, from, to model.OrderStatus, timestampField string) {
	orderID := c.Param("id")
	userID := c.GetString("user_id")

	var merchant model.Merchant
	if err := h.db.Where("user_id = ?", userID).First(&merchant).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var order model.Order
	if err := h.db.Where("id = ? AND merchant_id = ? AND status = ?",
		orderID, merchant.ID, from).First(&order).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Order not found or not in '%s' status", from)})
		return
	}
	if from == model.OrderStatusPending && !order.IsAwaitingMerchantAction() {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Order payment not yet completed"})
		return
	}

	updates := map[string]interface{}{"status": to}
	if timestampField != "" {
		now := time.Now()
		updates[timestampField] = &now
	}

	h.db.Model(&order).Updates(updates)

	// Push notifications to customer on key status changes
	if order.CustomerID != nil {
		var title, body string
		switch to {
		case model.OrderStatusConfirmed:
			title = "Pesanan Dikonfirmasi ✅"
			body = fmt.Sprintf("Order #%s sedang dipersiapkan", order.OrderNumber)
		case model.OrderStatusReady:
			title = "Pesanan Siap! 📦"
			body = fmt.Sprintf("Order #%s siap, menunggu driver", order.OrderNumber)
		}
		if title != "" {
			service.SendToUser(h.db, *order.CustomerID, title, body,
				map[string]string{"order_id": order.ID.String(), "type": "order_status"})
		}
	}

	c.JSON(http.StatusOK, gin.H{"message": fmt.Sprintf("Order marked as %s", to), "status": to})
}

// --- Driver Order Handlers ---

type DriverOrderHandler struct {
	db *gorm.DB
}

func NewDriverOrderHandler(db *gorm.DB) *DriverOrderHandler {
	return &DriverOrderHandler{db: db}
}

func (h *DriverOrderHandler) RegisterRoutes(r *gin.RouterGroup) {
	// Driver status toggle
	r.PATCH("/driver/status", h.SetDriverStatus)

	orders := r.Group("/driver-orders")
	{
		orders.GET("/available", h.AvailableOrders)
		orders.GET("/current", h.CurrentDelivery)
		orders.POST("/:id/accept", h.AcceptDelivery)
		orders.POST("/:id/pickup", h.MarkPickedUp)
		orders.POST("/:id/deliver", h.MarkDelivered)
		orders.GET("/:id/chat", h.GetChat)
		orders.POST("/:id/chat", h.SendChat)
	}
}

// SetDriverStatus sets the driver online/offline and updates availability.
func (h *DriverOrderHandler) SetDriverStatus(c *gin.Context) {
	userID := c.GetString("user_id")

	var req struct {
		Online bool `json:"online"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var driver model.Driver
	if err := h.db.Where("user_id = ?", userID).First(&driver).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver profile not found"})
		return
	}

	h.db.Model(&driver).Updates(map[string]interface{}{
		"is_online":    req.Online,
		"is_available": req.Online,
	})

	status := "offline"
	if req.Online {
		status = "online"
	}
	c.JSON(http.StatusOK, gin.H{"status": status, "is_online": req.Online})
}

// AvailableOrders returns ready orders that need a driver
func (h *DriverOrderHandler) AvailableOrders(c *gin.Context) {
	userID := c.GetString("user_id")

	var driver model.Driver
	if err := h.db.Where("user_id = ?", userID).First(&driver).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver profile not found"})
		return
	}

	if !driver.IsOnline || !driver.IsAvailable {
		c.JSON(http.StatusOK, gin.H{"orders": []model.Order{}, "message": "Go online to see available orders"})
		return
	}

	var orders []model.Order
	// Show: (a) unassigned orders, OR (b) orders admin pre-assigned to this
	// specific driver that they haven't accepted yet (accepted_at still
	// nil) — once accepted, it must drop out of this list even though
	// driver_id still matches, or it just keeps reappearing on every poll.
	// If driver has a zone, only show orders from that zone (or orders with no zone = legacy/fallback)
	query := h.db.Where("status = ? AND (driver_id IS NULL OR (driver_id = ? AND accepted_at IS NULL))", model.OrderStatusReady, driver.ID)
	if driver.ZoneID != nil {
		query = query.Where("zone_id = ? OR zone_id IS NULL", driver.ZoneID)
	}
	query.Preload("Merchant").Preload("Customer").Order("created_at ASC").Find(&orders)

	c.JSON(http.StatusOK, gin.H{"orders": orders})
}

// CurrentDelivery returns the order the driver has already accepted (or is
// mid-delivery on), if any — so the app can resume the active-delivery
// screen after a restart instead of showing an empty job board with no way
// back to an order that's already theirs (it's intentionally excluded from
// AvailableOrders once accepted_at is set).
func (h *DriverOrderHandler) CurrentDelivery(c *gin.Context) {
	userID := c.GetString("user_id")

	var driver model.Driver
	if err := h.db.Where("user_id = ?", userID).First(&driver).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver profile not found"})
		return
	}

	var order model.Order
	err := h.db.Preload("Merchant").Preload("Customer").
		Where("driver_id = ? AND accepted_at IS NOT NULL AND status IN ?",
			driver.ID, []model.OrderStatus{model.OrderStatusReady, model.OrderStatusPickedUp}).
		Order("accepted_at DESC").First(&order).Error
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"order": nil})
		return
	}

	c.JSON(http.StatusOK, gin.H{"order": order})
}

// AcceptDelivery assigns the driver to an order: ready → picked_up flow
func (h *DriverOrderHandler) AcceptDelivery(c *gin.Context) {
	orderID := c.Param("id")
	userID := c.GetString("user_id")

	var driver model.Driver
	if err := h.db.Where("user_id = ?", userID).First(&driver).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver profile not found"})
		return
	}

	var order model.Order
	// Allow accept if: not yet assigned to anyone, OR admin pre-assigned to
	// this driver and they haven't accepted it yet.
	if err := h.db.Where("id = ? AND status = ? AND (driver_id IS NULL OR (driver_id = ? AND accepted_at IS NULL))",
		orderID, model.OrderStatusReady, driver.ID).First(&order).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Order not available for pickup"})
		return
	}

	now := time.Now()
	h.db.Model(&order).Updates(map[string]interface{}{
		"driver_id":   driver.ID,
		"accepted_at": &now,
	})

	// Reload with merchant info for the Flutter app
	h.db.Preload("Merchant").First(&order, "id = ?", order.ID)

	// Notify customer that driver is on the way
	if order.CustomerID != nil {
		service.SendToUser(h.db, *order.CustomerID,
			"Driver Ditemukan! 🏍️",
			"Driver sedang menuju merchant untuk mengambil pesananmu",
			map[string]string{"order_id": order.ID.String(), "type": "driver_assigned"},
		)
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Delivery accepted",
		"order":   order,
	})
}

// MarkPickedUp transitions: (driver assigned) → picked_up
func (h *DriverOrderHandler) MarkPickedUp(c *gin.Context) {
	orderID := c.Param("id")
	userID := c.GetString("user_id")

	var driver model.Driver
	h.db.Where("user_id = ?", userID).First(&driver)

	now := time.Now()
	result := h.db.Model(&model.Order{}).
		Where("id = ? AND driver_id = ? AND status = ?", orderID, driver.ID, model.OrderStatusReady).
		Updates(map[string]interface{}{
			"status":       model.OrderStatusPickedUp,
			"picked_up_at": &now,
		})

	if result.RowsAffected == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot mark as picked up"})
		return
	}

	// Notify customer that order is on the way, and hand the updated order
	// back to the driver app — without this it can't tell locally that
	// status is now picked_up, so the "Sudah Diambil" button never goes
	// away and a driver who taps it again (thinking nothing happened) gets
	// a confusing "cannot mark as picked up" on the harmless second try.
	var pickedOrder model.Order
	h.db.Where("id = ?", orderID).First(&pickedOrder)
	if pickedOrder.CustomerID != nil {
		service.SendToUser(h.db, *pickedOrder.CustomerID,
			"Pesanan Sedang Diantar 🛵",
			"Driver sedang dalam perjalanan menuju lokasimu",
			map[string]string{"order_id": orderID, "type": "picked_up"},
		)
	}

	c.JSON(http.StatusOK, gin.H{"message": "Order picked up", "status": model.OrderStatusPickedUp, "order": pickedOrder})
}

// MarkDelivered transitions: picked_up → delivered.
// For COD: credits driver and merchant wallets immediately, tracks cash holding.
// For online payment: wallets already credited at payment confirmation, no extra action.
func (h *DriverOrderHandler) MarkDelivered(c *gin.Context) {
	orderID := c.Param("id")
	userID := c.GetString("user_id")

	var driver model.Driver
	h.db.Where("user_id = ?", userID).First(&driver)

	var order model.Order
	if err := h.db.Preload("Merchant").Where("id = ? AND driver_id = ? AND status = ?",
		orderID, driver.ID, model.OrderStatusPickedUp).First(&order).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot mark as delivered"})
		return
	}

	now := time.Now()
	orderUUID := order.ID

	tx := h.db.Begin()

	tx.Model(&order).Updates(map[string]interface{}{
		"status":       model.OrderStatusDelivered,
		"delivered_at": &now,
	})
	tx.Model(&driver).Updates(map[string]interface{}{
		"is_available":    true,
		"total_delivered": gorm.Expr("total_delivered + 1"),
	})

	merchantNotes := fmt.Sprintf("Order %s delivered", order.OrderNumber)
	driverNotes := fmt.Sprintf("Earning order %s", order.OrderNumber)

	// Merchant receives their base product price (MerchantPayout).
	// For self-deliver: also receives their cut of the delivery fee (MerchantDeliveryEarning).
	// Platform keeps the markup + its commission share — this is the transparent Ujrah/Wakalah model.
	merchantCredit := order.MerchantPayout
	if order.DeliveryType == "self" {
		merchantCredit += order.MerchantDeliveryEarning
	}
	// Fallback for orders placed before this migration (MerchantPayout = 0)
	if merchantCredit == 0 {
		merchantCredit = order.Subtotal - order.PlatformMarkup
		if merchantCredit <= 0 {
			merchantCredit = order.Subtotal
		}
	}

	creditWallets := func() error {
		if err := service.CreditMerchantWallet(tx, *order.MerchantID, merchantCredit, "order_earning", &orderUUID, merchantNotes); err != nil {
			return err
		}
		if order.DriverEarning > 0 {
			if err := service.CreditWallet(tx, driver.UserID, order.DriverEarning, "order_earning", &orderUUID, driverNotes); err != nil {
				return err
			}
		}
		return nil
	}

	if order.PaymentType == "cash" {
		// COD: credit wallets immediately; track COD cash driver is physically holding
		if err := creditWallets(); err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to credit wallets"})
			return
		}
		tx.Model(&driver).Update("cod_holding", gorm.Expr("cod_holding + ?", order.Total))
	} else if order.PaymentStatus == "paid" {
		// Online payment already collected by platform — credit wallets at delivery
		if err := creditWallets(); err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to credit wallets"})
			return
		}
	}

	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to complete delivery"})
		return
	}

	// Notify customer that order has arrived
	if order.CustomerID != nil {
		service.SendToUser(h.db, *order.CustomerID,
			"Pesanan Tiba! 🎉",
			fmt.Sprintf("Order #%s sudah sampai. Selamat menikmati!", order.OrderNumber),
			map[string]string{"order_id": order.ID.String(), "type": "delivered"},
		)
	}

	resp := gin.H{
		"message":        "Order delivered!",
		"driver_earning": order.DriverEarning,
	}
	if order.PaymentType == "cash" {
		resp["cash_collected"] = order.Total
		resp["to_deposit"] = order.Total - order.DriverEarning
	}
	c.JSON(http.StatusOK, resp)
}

// GetChat returns chat messages for a driver-order.
func (h *DriverOrderHandler) GetChat(c *gin.Context) {
	userID := c.GetString("user_id")
	orderID := c.Param("id")

	var driver model.Driver
	if err := h.db.Where("user_id = ?", userID).First(&driver).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver profile not found"})
		return
	}

	// Verify driver is assigned to this order
	var order model.Order
	if err := h.db.Where("id = ? AND driver_id = ?", orderID, driver.ID).First(&order).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	var msgs []model.ChatMessage
	h.db.Where("order_id = ?", orderID).Order("created_at ASC").Find(&msgs)
	c.JSON(http.StatusOK, gin.H{"messages": msgs})
}

// SendChat sends a chat message from driver to customer.
func (h *DriverOrderHandler) SendChat(c *gin.Context) {
	userID := c.GetString("user_id")
	orderID := c.Param("id")

	var req struct {
		Text string `json:"text" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var driver model.Driver
	if err := h.db.Where("user_id = ?", userID).First(&driver).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver profile not found"})
		return
	}

	var order model.Order
	if err := h.db.Where("id = ? AND driver_id = ?", orderID, driver.ID).First(&order).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	senderUID, _ := uuid.Parse(userID)
	orderUID, _ := uuid.Parse(orderID)
	msg := model.ChatMessage{
		OrderID:    orderUID,
		SenderID:   senderUID,
		SenderRole: "driver",
		Text:       req.Text,
	}
	h.db.Create(&msg)

	// Notify customer
	if order.CustomerID != nil {
		service.SendToUser(h.db, *order.CustomerID,
			"Pesan dari Driver 💬",
			req.Text,
			map[string]string{"order_id": orderID, "type": "chat"},
		)
	}

	c.JSON(http.StatusCreated, gin.H{"message": msg})
}

// RequestRefund allows a customer to submit a refund request for a delivered order.
func (h *Handler) RequestRefund(c *gin.Context) {
	userID := c.GetString("user_id")
	orderID := c.Param("id")

	var req struct {
		Reason string `json:"reason" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var order model.Order
	if err := h.db.Where("id = ? AND customer_id = ?", orderID, userID).First(&order).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	if order.Status != model.OrderStatusDelivered && order.Status != model.OrderStatusCancelled {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Refund only allowed for delivered or cancelled orders"})
		return
	}

	// Prevent duplicate requests
	var existing model.RefundRequest
	if h.db.Where("order_id = ?", order.ID).First(&existing).Error == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "Refund request already submitted", "refund": existing})
		return
	}

	userUID, _ := uuid.Parse(userID)
	refund := model.RefundRequest{
		OrderID:     order.ID,
		RequestedBy: userUID,
		Reason:      req.Reason,
		Amount:      order.Total,
		Status:      "pending",
	}
	if err := h.db.Create(&refund).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to submit refund request"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"refund": refund, "message": "Refund request submitted. Admin will review within 1-2 business days."})
}

// GetChat returns chat messages for an order (customer side).
func (h *Handler) GetChat(c *gin.Context) {
	userID := c.GetString("user_id")
	orderID := c.Param("id")

	// Verify customer owns order
	var order model.Order
	if err := h.db.Where("id = ? AND customer_id = ?", orderID, userID).First(&order).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	var msgs []model.ChatMessage
	h.db.Where("order_id = ?", orderID).Order("created_at ASC").Find(&msgs)
	c.JSON(http.StatusOK, gin.H{"messages": msgs})
}

// SendChat sends a chat message from customer to driver.
func (h *Handler) SendChat(c *gin.Context) {
	userID := c.GetString("user_id")
	orderID := c.Param("id")

	var req struct {
		Text string `json:"text" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var order model.Order
	if err := h.db.Where("id = ? AND customer_id = ?", orderID, userID).First(&order).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	senderUID, _ := uuid.Parse(userID)
	orderUID, _ := uuid.Parse(orderID)
	msg := model.ChatMessage{
		OrderID:    orderUID,
		SenderID:   senderUID,
		SenderRole: "customer",
		Text:       req.Text,
	}
	h.db.Create(&msg)

	// Notify driver if assigned
	if order.DriverID != nil {
		var driver model.Driver
		if h.db.Where("id = ?", order.DriverID).First(&driver).Error == nil {
			service.SendToUser(h.db, driver.UserID,
				"Pesan dari Customer 💬",
				req.Text,
				map[string]string{"order_id": orderID, "type": "chat"},
			)
		}
	}

	c.JSON(http.StatusCreated, gin.H{"message": msg})
}

// --- Settings Helper ---

type settingsData struct {
	PlatformMarkupPct        float64
	DeliveryCommissionPct    float64
	SelfDeliverCommissionPct float64
	InsideZoneFee            float64
	FeePerKmOutside          float64
	TaxPct                   float64
	AppServiceFeePct         float64
	MinOrderAmount           float64
	MaxCODAmount             float64
}

func (h *Handler) loadSettings() settingsData {
	s := settingsData{
		PlatformMarkupPct:        15,
		DeliveryCommissionPct:    25,
		SelfDeliverCommissionPct: 10,
		InsideZoneFee:            15000,
		FeePerKmOutside:          10000,
		TaxPct:                   11,
		AppServiceFeePct:         5,
		MinOrderAmount:           0,
		MaxCODAmount:             500000,
	}

	var settings []model.SystemSetting
	h.db.Find(&settings)

	for _, setting := range settings {
		val, _ := strconv.ParseFloat(setting.Value, 64)
		switch setting.Key {
		case "platform_markup_percentage":
			s.PlatformMarkupPct = val
		case "delivery_commission_percentage":
			s.DeliveryCommissionPct = val
		case "self_deliver_commission_percentage":
			s.SelfDeliverCommissionPct = val
		case "delivery_base_fee_inside_zone":
			s.InsideZoneFee = val
		case "delivery_fee_per_km_outside":
			s.FeePerKmOutside = val
		case "tax_percentage":
			s.TaxPct = val
		case "app_service_fee_percentage":
			s.AppServiceFeePct = val
		case "min_order_amount":
			s.MinOrderAmount = val
		case "max_cod_amount":
			s.MaxCODAmount = val
		}
	}
	return s
}

// loadHomeKota finds the merchant's kota (parent zone), which decides which
// BaseFee/PerKmFee schedule applies and is stored as the order's ZoneID. It
// does not by itself decide the flat-fee delivery area — see flatZoneShapes
// for that; a kota with kecamatan configured prices deliveries against just
// those kecamatan, not the kota's own boundary.
// Priority: (1) an active kecamatan polygon containing the point backstops a
// parent with no polygon of its own, (2) parent's own shape (polygon, else a
// radius circle around the parent's own reference point), (3) nearest
// parent within 50km, (4) default zone, (5) nearest parent regardless of
// distance.
func (h *Handler) loadHomeKota(lat, lng float64, fallback settingsData) (zone *model.DeliveryZone, baseFee, perKmFee float64) {
	// Priority 1: kecamatan polygon backstop
	var children []model.DeliveryZone
	h.db.Where("parent_zone_id IS NOT NULL AND is_active = true AND boundary_geojson IS NOT NULL").Find(&children)
	for i := range children {
		if pricing.PointInPolygon(lat, lng, *children[i].BoundaryGeoJSON) {
			var parent model.DeliveryZone
			if h.db.First(&parent, "id = ?", children[i].ParentZoneID).Error == nil {
				return &parent, parent.BaseFee, parent.PerKmFee
			}
		}
	}

	// Priority 2+: search parent zones only
	var parents []model.DeliveryZone
	h.db.Where("parent_zone_id IS NULL AND is_active = true").Find(&parents)

	if len(parents) == 0 {
		return nil, fallback.InsideZoneFee, fallback.FeePerKmOutside
	}

	// Priority 2: parent's own shape contains the merchant
	for i := range parents {
		shape := pricing.ZoneShape{
			Lat: parents[i].Latitude, Lng: parents[i].Longitude,
			RadiusKm: parents[i].RadiusKm, BoundaryGeoJSON: parents[i].BoundaryGeoJSON,
		}
		if pricing.IsInsideShape(lat, lng, shape) {
			return &parents[i], parents[i].BaseFee, parents[i].PerKmFee
		}
	}

	// Priority 3: nearest parent zone by haversine (within 50km)
	var nearest *model.DeliveryZone
	var defaultZone *model.DeliveryZone
	minDist := math.MaxFloat64
	for i := range parents {
		if parents[i].IsDefault {
			defaultZone = &parents[i]
		}
		d := haversineDistance(lat, lng, parents[i].Latitude, parents[i].Longitude)
		if d < minDist {
			minDist = d
			nearest = &parents[i]
		}
	}

	if nearest != nil && minDist <= 50 {
		return nearest, nearest.BaseFee, nearest.PerKmFee
	}
	if defaultZone != nil {
		return defaultZone, defaultZone.BaseFee, defaultZone.PerKmFee
	}
	if nearest != nil {
		return nearest, nearest.BaseFee, nearest.PerKmFee
	}
	return nil, fallback.InsideZoneFee, fallback.FeePerKmOutside
}

// flatZoneShapes returns the flat-fee area(s) for a resolved kota: the union
// of its active kecamatan if any are configured, otherwise the kota's own
// shape. Configuring kecamatan under a kota narrows the flat area down to
// just those kecamatan — the kota's own boundary no longer counts once it
// has children.
func (h *Handler) flatZoneShapes(parent *model.DeliveryZone) []pricing.ZoneShape {
	var children []model.DeliveryZone
	h.db.Where("parent_zone_id = ? AND is_active = true", parent.ID).Find(&children)
	if len(children) == 0 {
		return []pricing.ZoneShape{{
			Lat: parent.Latitude, Lng: parent.Longitude,
			RadiusKm: parent.RadiusKm, BoundaryGeoJSON: parent.BoundaryGeoJSON,
		}}
	}
	shapes := make([]pricing.ZoneShape, len(children))
	for i, c := range children {
		shapes[i] = pricing.ZoneShape{Lat: c.Latitude, Lng: c.Longitude, RadiusKm: c.RadiusKm, BoundaryGeoJSON: c.BoundaryGeoJSON}
	}
	return shapes
}

// priceDropoff bills baseFee if the dropoff falls inside any of the given
// shapes, else baseFee plus perKmFee times the distance to the nearest
// shape's boundary.
func priceDropoff(shapes []pricing.ZoneShape, dropLat, dropLng, baseFee, perKmFee float64) float64 {
	minExcess := math.MaxFloat64
	for _, s := range shapes {
		if pricing.IsInsideShape(dropLat, dropLng, s) {
			return baseFee
		}
		if d := pricing.DistanceToShapeBoundaryKm(dropLat, dropLng, s); d < minExcess {
			minExcess = d
		}
	}
	if minExcess == math.MaxFloat64 {
		return baseFee
	}
	return baseFee + minExcess*perKmFee
}

// haversineDistance calculates distance between two GPS coordinates in km
func haversineDistance(lat1, lng1, lat2, lng2 float64) float64 {
	const R = 6371.0 // Earth radius in km
	dLat := (lat2 - lat1) * math.Pi / 180.0
	dLng := (lng2 - lng1) * math.Pi / 180.0

	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180.0)*math.Cos(lat2*math.Pi/180.0)*
			math.Sin(dLng/2)*math.Sin(dLng/2)

	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return R * c
}
