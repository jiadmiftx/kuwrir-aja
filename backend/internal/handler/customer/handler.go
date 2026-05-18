package customer

import (
	"fmt"
	"math"
	"net/http"
	"strconv"
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

// RegisterRoutes sets up customer order routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	orders := r.Group("/orders")
	{
		orders.POST("", h.PlaceOrder)
		orders.GET("", h.MyOrders)
		orders.GET("/:id", h.GetOrder)
		orders.POST("/:id/cancel", h.CancelOrder)
	}
}

// --- Request DTOs ---

type OrderItemRequest struct {
	ProductID string `json:"product_id" binding:"required"`
	Quantity  int    `json:"quantity" binding:"required,gte=1"`
	Notes     string `json:"notes"`
}

type PlaceOrderRequest struct {
	MerchantID      string             `json:"merchant_id" binding:"required"`
	Items           []OrderItemRequest `json:"items" binding:"required,min=1"`
	DropoffAddress  string             `json:"dropoff_address" binding:"required"`
	DropoffLat      float64            `json:"dropoff_lat" binding:"required"`
	DropoffLng      float64            `json:"dropoff_lng" binding:"required"`
	ReceiverName    string             `json:"receiver_name"`
	ReceiverPhone   string             `json:"receiver_phone"`
	Notes           string             `json:"notes"`
}

// --- Handlers ---

// PlaceOrder creates a new order with full COD pricing calculation
func (h *Handler) PlaceOrder(c *gin.Context) {
	userID := c.GetString("user_id")

	var req PlaceOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 1. Load system settings
	settings := h.loadSettings()

	// 2. Load merchant
	var merchant model.Merchant
	if err := h.db.Where("id = ? AND is_active = ? AND is_verified = ? AND is_open = ?",
		req.MerchantID, true, true, true).First(&merchant).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Merchant not found or closed"})
		return
	}

	// 3. Calculate delivery fee
	distanceKm := haversineDistance(
		merchant.Latitude, merchant.Longitude,
		req.DropoffLat, req.DropoffLng,
	)

	deliveryFee := settings.InsideZoneFee
	if distanceKm > 5.0 { // Outside zone threshold
		extraKm := distanceKm - 5.0
		deliveryFee = settings.InsideZoneFee + (extraKm * settings.FeePerKmOutside)
	}

	// 4. Build order items with markup calculation
	var orderItems []model.OrderItem
	var subtotalWithMarkup float64
	var totalPlatformMarkup float64

	for _, reqItem := range req.Items {
		var product model.Product
		if err := h.db.Where("id = ?", reqItem.ProductID).First(&product).Error; err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Product %s not found", reqItem.ProductID)})
			return
		}

		if !product.IsAvailable {
			c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("%s is not available", product.Name)})
			return
		}

		if product.TrackStock && product.StockQuantity < reqItem.Quantity {
			c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Insufficient stock for %s", product.Name)})
			return
		}

		// Apply platform markup
		markupAmount := product.Price * (settings.PlatformMarkupPct / 100.0)
		priceWithMarkup := product.Price + markupAmount
		itemTotal := priceWithMarkup * float64(reqItem.Quantity)

		productID, _ := uuid.Parse(reqItem.ProductID)
		orderItems = append(orderItems, model.OrderItem{
			ProductID:  &productID,
			ItemName:   product.Name,
			Quantity:   reqItem.Quantity,
			BasePrice:  product.Price,
			UnitPrice:  priceWithMarkup,
			TotalPrice: itemTotal,
			Notes:      reqItem.Notes,
		})

		subtotalWithMarkup += itemTotal
		totalPlatformMarkup += markupAmount * float64(reqItem.Quantity)

		// Deduct stock if tracking
		if product.TrackStock {
			h.db.Model(&product).Update("stock_quantity", gorm.Expr("stock_quantity - ?", reqItem.Quantity))
		}
	}

	// 5. Determine delivery type and calculate accordingly
	deliveryType := "platform"
	var deliveryCommission float64
	var driverEarning float64

	if merchant.CanSelfDeliver {
		// Self-delivery: merchant delivers, uses their own fee, no platform delivery commission
		deliveryType = "self"
		deliveryFee = merchant.SelfDeliveryFee // Could be 0 (free delivery)
		deliveryCommission = 0
		driverEarning = 0
	} else {
		// Platform delivery: KUWRIR driver delivers
		deliveryCommission = deliveryFee * (settings.DeliveryCommissionPct / 100.0)
		driverEarning = deliveryFee - deliveryCommission
	}

	// 6. Grand total customer pays (cash)
	grandTotal := subtotalWithMarkup + deliveryFee

	// 7. Generate order number
	orderNumber := fmt.Sprintf("KWR-%s", time.Now().Format("060102150405"))

	customerUUID, _ := uuid.Parse(userID)
	merchantUUID, _ := uuid.Parse(req.MerchantID)
	now := time.Now()

	order := model.Order{
		OrderNumber:        orderNumber,
		ServiceType:        "ecommerce",
		CustomerID:         &customerUUID,
		MerchantID:         &merchantUUID,
		Status:             model.OrderStatusPending,
		DeliveryType:        deliveryType,
		PaymentType:        "cash",
		Subtotal:           subtotalWithMarkup,
		PlatformMarkup:     totalPlatformMarkup,
		DeliveryFee:        deliveryFee,
		DeliveryCommission: deliveryCommission,
		DriverEarning:      driverEarning,
		Total:              grandTotal,
		
		PickupAddress:      merchant.Address,
		PickupLat:          merchant.Latitude,
		PickupLng:          merchant.Longitude,
		SenderName:         merchant.Name,
		SenderPhone:        merchant.Phone,

		DropoffAddress:     req.DropoffAddress,
		DropoffLat:         req.DropoffLat,
		DropoffLng:         req.DropoffLng,
		ReceiverName:       req.ReceiverName,
		ReceiverPhone:      req.ReceiverPhone,

		DistanceKm:         distanceKm,
		Notes:              req.Notes,
		PlacedAt:           &now,
		Items:              orderItems,
	}

	if err := h.db.Create(&order).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create order"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"order": order,
		"pricing_breakdown": gin.H{
			"product_subtotal_with_markup": subtotalWithMarkup,
			"platform_markup_total":        totalPlatformMarkup,
			"delivery_fee":                 deliveryFee,
			"delivery_commission_kuwrir":   deliveryCommission,
			"driver_earning":               driverEarning,
			"total_customer_pays":          grandTotal,
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

	now := time.Now()
	h.db.Model(&order).Updates(map[string]interface{}{
		"status":       model.OrderStatusCancelled,
		"cancelled_at": &now,
	})

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
	h.db.Where("merchant_id = ? AND status IN ?", merchant.ID,
		[]string{
			string(model.OrderStatusPending),
			string(model.OrderStatusConfirmed),
			string(model.OrderStatusPreparing),
			string(model.OrderStatusReady),
		}).
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

	updates := map[string]interface{}{"status": to}
	if timestampField != "" {
		now := time.Now()
		updates[timestampField] = &now
	}

	h.db.Model(&order).Updates(updates)
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
	orders := r.Group("/driver-orders")
	{
		orders.GET("/available", h.AvailableOrders)
		orders.POST("/:id/accept", h.AcceptDelivery)
		orders.POST("/:id/pickup", h.MarkPickedUp)
		orders.POST("/:id/deliver", h.MarkDelivered)
	}
}

// AvailableOrders returns ready orders that need a driver
func (h *DriverOrderHandler) AvailableOrders(c *gin.Context) {
	var orders []model.Order
	h.db.Where("status = ? AND driver_id IS NULL", model.OrderStatusReady).
		Preload("Merchant").
		Preload("Customer").
		Order("created_at ASC").
		Find(&orders)

	c.JSON(http.StatusOK, gin.H{"orders": orders})
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
	if err := h.db.Where("id = ? AND status = ? AND driver_id IS NULL",
		orderID, model.OrderStatusReady).First(&order).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Order not available for pickup"})
		return
	}

	h.db.Model(&order).Updates(map[string]interface{}{
		"driver_id": driver.ID,
	})

	c.JSON(http.StatusOK, gin.H{"message": "Delivery accepted"})
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

	c.JSON(http.StatusOK, gin.H{"message": "Order picked up", "status": model.OrderStatusPickedUp})
}

// MarkDelivered transitions: picked_up → delivered (customer pays cash)
func (h *DriverOrderHandler) MarkDelivered(c *gin.Context) {
	orderID := c.Param("id")
	userID := c.GetString("user_id")

	var driver model.Driver
	h.db.Where("user_id = ?", userID).First(&driver)

	var order model.Order
	if err := h.db.Where("id = ? AND driver_id = ? AND status = ?",
		orderID, driver.ID, model.OrderStatusPickedUp).First(&order).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot mark as delivered"})
		return
	}

	now := time.Now()
	h.db.Model(&order).Updates(map[string]interface{}{
		"status":       model.OrderStatusDelivered,
		"delivered_at": &now,
	})

	// Add cash to driver's balance (they owe this to the platform)
	h.db.Model(&driver).Update("cash_balance", gorm.Expr("cash_balance + ?", order.Total))

	// Update driver stats
	h.db.Model(&driver).Update("total_delivered", gorm.Expr("total_delivered + 1"))

	c.JSON(http.StatusOK, gin.H{
		"message":              "Order delivered! Cash collected.",
		"cash_collected":       order.Total,
		"driver_earning":       order.DriverEarning,
		"amount_owed_to_admin": order.Total - order.DriverEarning,
	})
}

// --- Settings Helper ---

type settingsData struct {
	PlatformMarkupPct     float64
	DeliveryCommissionPct float64
	InsideZoneFee         float64
	FeePerKmOutside       float64
}

func (h *Handler) loadSettings() settingsData {
	s := settingsData{
		PlatformMarkupPct:     15,
		DeliveryCommissionPct: 25,
		InsideZoneFee:         15000,
		FeePerKmOutside:       10000,
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
		case "delivery_base_fee_inside_zone":
			s.InsideZoneFee = val
		case "delivery_fee_per_km_outside":
			s.FeePerKmOutside = val
		}
	}
	return s
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
