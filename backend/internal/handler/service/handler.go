// Package service handles the jasa (service) order flow:
// laundry, bengkel, salon, cleaning, etc. with home pickup and return delivery.
//
// Flow:
//
//	Customer places order → Merchant confirms → Driver picks up FROM customer
//	→ Delivers to merchant → Merchant performs service → Marks ready
//	→ Driver picks up FROM merchant → Returns to customer → Customer pays COD
package service

import (
	"fmt"
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

func (h *Handler) RegisterRoutes(
	public *gin.RouterGroup,
	customer *gin.RouterGroup,
	merchant *gin.RouterGroup,
	driver *gin.RouterGroup,
) {
	// Public — browse service merchants
	public.GET("/service-merchants", h.ListServiceMerchants)
	public.GET("/service-merchants/:id/services", h.GetMerchantServices)

	// Customer
	customer.POST("/service-orders", h.PlaceServiceOrder)
	customer.GET("/service-orders", h.ListCustomerServiceOrders)
	customer.GET("/service-orders/:id", h.GetServiceOrder)
	customer.POST("/service-orders/:id/cancel", h.CancelServiceOrder)

	// Merchant
	merchant.GET("/my-service-orders", h.ListMerchantServiceOrders)
	merchant.POST("/my-service-orders/:id/confirm", h.ConfirmServiceOrder)
	merchant.POST("/my-service-orders/:id/in-service", h.MarkInService)
	merchant.POST("/my-service-orders/:id/ready", h.MarkReadyForReturn)

	// Driver — service pickups (two legs)
	driver.GET("/driver/service-orders/available", h.AvailableServiceJobs)
	driver.POST("/driver/service-orders/:id/accept-pickup", h.AcceptPickupLeg)
	driver.POST("/driver/service-orders/:id/item-picked-up", h.MarkItemPickedUp)
	driver.POST("/driver/service-orders/:id/accept-return", h.AcceptReturnLeg)
	driver.POST("/driver/service-orders/:id/returned", h.MarkReturned)
}

// ─── helpers ─────────────────────────────────────────────────────────────────

func (h *Handler) getMerchant(userID string) (*model.Merchant, error) {
	var m model.Merchant
	return &m, h.db.Where("user_id = ?", userID).First(&m).Error
}

func (h *Handler) getDriver(userID string) (*model.Driver, error) {
	var d model.Driver
	return &d, h.db.Where("user_id = ?", userID).First(&d).Error
}

func (h *Handler) getSettings(conn *gorm.DB) map[string]float64 {
	var settings []model.SystemSetting
	conn.Find(&settings)
	m := map[string]float64{
		"platform_markup_percentage":     15,
		"delivery_commission_percentage": 25,
		"delivery_base_fee_inside_zone":  20000, // ongkir PP untuk jasa (lebih tinggi karena 2 trip)
	}
	for _, s := range settings {
		if v, err := strconv.ParseFloat(s.Value, 64); err == nil {
			m[s.Key] = v
		}
	}
	return m
}

func nextServiceOrderNumber() string {
	return fmt.Sprintf("SVC-%s", time.Now().Format("060102150405"))
}

// ─── PUBLIC — browse service merchants ───────────────────────────────────────

// ListServiceMerchants returns active service merchants (laundry, bengkel, etc.)
func (h *Handler) ListServiceMerchants(c *gin.Context) {
	category := c.DefaultQuery("category", "") // laundry | bengkel | cleaning | salon
	lat := c.DefaultQuery("lat", "0")
	lng := c.DefaultQuery("lng", "0")
	radius := c.DefaultQuery("radius", "10")

	q := h.db.Where("type = ? AND is_active = ? AND is_verified = ?",
		model.MerchantTypeService, true, true)
	if category != "" {
		q = q.Where("service_category = ?", category)
	}
	if lat != "0" && lng != "0" {
		q = q.Where(
			"(6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude)))) < ?",
			lat, lng, lat, radius,
		)
	}

	var merchants []model.Merchant
	q.Order("rating DESC").Find(&merchants)
	c.JSON(http.StatusOK, gin.H{"merchants": merchants})
}

// GetMerchantServices returns services offered by a merchant (uses Product model)
func (h *Handler) GetMerchantServices(c *gin.Context) {
	id := c.Param("id")
	var categories []model.ProductCategory
	h.db.Where("merchant_id = ?", id).
		Preload("Products", "is_available = ?", true).
		Preload("Products.Variants").
		Order("sort_order ASC").
		Find(&categories)
	pricing.ApplyMarkupToCategories(h.db, categories)
	c.JSON(http.StatusOK, gin.H{"categories": categories})
}

// ─── CUSTOMER ─────────────────────────────────────────────────────────────────

type PlaceServiceOrderRequest struct {
	MerchantID        string  `json:"merchant_id" binding:"required"`
	PickupAddress     string  `json:"pickup_address" binding:"required"`
	PickupLat         float64 `json:"pickup_lat" binding:"required"`
	PickupLng         float64 `json:"pickup_lng" binding:"required"`
	PickupScheduledAt *string `json:"pickup_scheduled_at"` // "2026-06-05T10:00:00Z"
	ServiceNotes      string  `json:"service_notes"`
	WeightKg          float64 `json:"weight_kg"` // untuk laundry per-kg
	Items             []struct {
		ServiceID string `json:"service_id" binding:"required"` // Product ID
		Quantity  int    `json:"quantity" binding:"required,gt=0"`
		Notes     string `json:"notes"`
	} `json:"items" binding:"required,min=1"`
}

// PlaceServiceOrder creates a service order with COD payment at return.
// Pricing: base + 15% markup + round-trip delivery fee (flat).
func (h *Handler) PlaceServiceOrder(c *gin.Context) {
	customerIDStr := c.GetString("user_id")
	customerID, _ := uuid.Parse(customerIDStr)

	var req PlaceServiceOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate merchant
	var merchant model.Merchant
	if h.db.Where("id = ? AND type = ? AND is_active = ? AND is_verified = ?",
		req.MerchantID, model.MerchantTypeService, true, true).First(&merchant).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Service merchant not found or not active"})
		return
	}

	settings := h.getSettings(h.db)
	markupPct := settings["platform_markup_percentage"] / 100
	deliveryFee := settings["delivery_base_fee_inside_zone"] // round-trip flat fee
	commissionPct := settings["delivery_commission_percentage"] / 100

	// Build order items
	var subtotal float64
	var orderItems []model.OrderItem

	for _, it := range req.Items {
		var product model.Product
		if h.db.First(&product, "id = ?", it.ServiceID).Error != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Service not found: " + it.ServiceID})
			return
		}

		// For per_kg services, use weight_kg as quantity multiplier
		qty := it.Quantity
		unitBase := product.Price
		if product.PriceUnit == "per_kg" && req.WeightKg > 0 {
			unitBase = product.Price * req.WeightKg / float64(qty)
		}

		unitWithMarkup := unitBase * (1 + markupPct)
		lineTotal := unitWithMarkup * float64(qty)
		subtotal += lineTotal

		sid, _ := uuid.Parse(it.ServiceID)
		orderItems = append(orderItems, model.OrderItem{
			ProductID:  &sid,
			ItemName:   product.Name,
			Quantity:   qty,
			BasePrice:  unitBase,
			UnitPrice:  unitWithMarkup,
			TotalPrice: lineTotal,
			Notes:      it.Notes,
		})
	}

	platformMarkup := subtotal - (subtotal / (1 + markupPct))
	deliveryCommission := deliveryFee * commissionPct
	driverEarning := deliveryFee - deliveryCommission
	total := subtotal + deliveryFee

	// Parse scheduled pickup time
	var scheduledAt *time.Time
	if req.PickupScheduledAt != nil && *req.PickupScheduledAt != "" {
		if t, err := time.Parse(time.RFC3339, *req.PickupScheduledAt); err == nil {
			scheduledAt = &t
		}
	}

	merchantID, _ := uuid.Parse(req.MerchantID)
	now := time.Now()

	order := model.Order{
		OrderNumber:        nextServiceOrderNumber(),
		ServiceType:        "service",
		CustomerID:         &customerID,
		MerchantID:         &merchantID,
		Status:             model.OrderStatusPending,
		PaymentType:        "cash",
		DeliveryType:       "platform",
		Subtotal:           subtotal,
		PlatformMarkup:     platformMarkup,
		DeliveryFee:        deliveryFee,
		DeliveryCommission: deliveryCommission,
		DriverEarning:      driverEarning,
		Total:              total,
		// Pickup = customer's address
		PickupAddress: req.PickupAddress,
		PickupLat:     req.PickupLat,
		PickupLng:     req.PickupLng,
		// Dropoff = merchant address (for leg 1)
		DropoffAddress: merchant.Address,
		DropoffLat:     merchant.Latitude,
		DropoffLng:     merchant.Longitude,
		// Return = same as pickup (default)
		ReturnAddress: req.PickupAddress,
		ReturnLat:     req.PickupLat,
		ReturnLng:     req.PickupLng,
		// Service fields
		PickupScheduledAt: scheduledAt,
		ServiceNotes:      req.ServiceNotes,
		WeightKg:          req.WeightKg,
		PlacedAt:          &now,
	}

	tx := h.db.Begin()
	if err := tx.Create(&order).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create order"})
		return
	}
	for i := range orderItems {
		orderItems[i].OrderID = order.ID
		tx.Create(&orderItems[i])
	}
	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit order"})
		return
	}

	h.db.Preload("Items").First(&order, "id = ?", order.ID)
	c.JSON(http.StatusCreated, gin.H{
		"order": order,
		"pricing_breakdown": gin.H{
			"service_subtotal_with_markup": subtotal,
			"service_markup":               platformMarkup,
			"delivery_fee_round_trip":      deliveryFee,
			"delivery_commission_kuwrir":   deliveryCommission,
			"driver_earning":               driverEarning,
			"total_customer_pays_cod":      total,
			"payment_time":                 "COD saat barang dikembalikan",
		},
	})
}

func (h *Handler) ListCustomerServiceOrders(c *gin.Context) {
	customerID := c.GetString("user_id")
	status := c.DefaultQuery("status", "")

	q := h.db.Where("customer_id = ? AND service_type = ?", customerID, "service")
	if status != "" {
		q = q.Where("status = ?", status)
	}

	var orders []model.Order
	q.Preload("Merchant").Preload("Items").Order("created_at DESC").Find(&orders)
	c.JSON(http.StatusOK, gin.H{"orders": orders})
}

func (h *Handler) GetServiceOrder(c *gin.Context) {
	id := c.Param("id")
	customerID := c.GetString("user_id")

	var order model.Order
	if h.db.Where("id = ? AND customer_id = ? AND service_type = ?", id, customerID, "service").
		Preload("Merchant").Preload("Driver.User").Preload("Items").
		First(&order).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"order": order})
}

func (h *Handler) CancelServiceOrder(c *gin.Context) {
	id := c.Param("id")
	customerID := c.GetString("user_id")

	var order model.Order
	if h.db.Where("id = ? AND customer_id = ? AND service_type = ? AND status = ?",
		id, customerID, "service", model.OrderStatusPending).First(&order).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found or cannot be cancelled"})
		return
	}
	now := time.Now()
	h.db.Model(&order).Updates(map[string]interface{}{"status": model.OrderStatusCancelled, "cancelled_at": now})
	c.JSON(http.StatusOK, gin.H{"message": "Order cancelled"})
}

// ─── MERCHANT ─────────────────────────────────────────────────────────────────

func (h *Handler) ListMerchantServiceOrders(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	status := c.DefaultQuery("status", "")
	q := h.db.Where("merchant_id = ? AND service_type = ?", merchant.ID, "service")
	if status != "" {
		q = q.Where("status = ?", status)
	}

	var orders []model.Order
	q.Preload("Customer").Preload("Driver.User").Preload("Items").
		Order("created_at DESC").Find(&orders)
	c.JSON(http.StatusOK, gin.H{"orders": orders})
}

// ConfirmServiceOrder: pending → awaiting_pickup
func (h *Handler) ConfirmServiceOrder(c *gin.Context) {
	h.merchantTransition(c, model.OrderStatusPending, model.OrderStatusAwaitingPickup,
		func(o *model.Order) { now := time.Now(); o.ConfirmedAt = &now })
}

// MarkInService: item_picked_up → in_service (merchant received item from driver)
func (h *Handler) MarkInService(c *gin.Context) {
	h.merchantTransition(c, model.OrderStatusItemPickedUp, model.OrderStatusInService,
		func(o *model.Order) { now := time.Now(); o.InServiceAt = &now })
}

// MarkReadyForReturn: in_service → ready_for_return (service done)
func (h *Handler) MarkReadyForReturn(c *gin.Context) {
	h.merchantTransition(c, model.OrderStatusInService, model.OrderStatusReadyForReturn,
		func(o *model.Order) { now := time.Now(); o.ReadyForReturnAt = &now })
}

func (h *Handler) merchantTransition(c *gin.Context, from, to model.OrderStatus, fn func(*model.Order)) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var order model.Order
	if h.db.Where("id = ? AND merchant_id = ? AND service_type = ? AND status = ?",
		id, merchant.ID, "service", from).First(&order).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found or wrong status"})
		return
	}

	fn(&order)
	order.Status = to
	h.db.Save(&order)
	c.JSON(http.StatusOK, gin.H{"message": "Status updated", "status": to})
}

// ─── DRIVER ──────────────────────────────────────────────────────────────────

// AvailableServiceJobs returns service orders a driver can take.
// Two types of jobs:
//  1. Leg 1 pickup jobs: status=awaiting_pickup (no driver yet → jemput dari customer)
//  2. Leg 2 return jobs: status=ready_for_return (driver needed → antar balik ke customer)
func (h *Handler) AvailableServiceJobs(c *gin.Context) {
	var leg1, leg2 []model.Order

	h.db.Where("service_type = ? AND status = ? AND driver_id IS NULL", "service", model.OrderStatusAwaitingPickup).
		Preload("Merchant").Preload("Items").
		Order("created_at ASC").Find(&leg1)

	h.db.Where("service_type = ? AND status = ? AND driver_id IS NULL", "service", model.OrderStatusReadyForReturn).
		Preload("Merchant").Preload("Items").
		Order("ready_for_return_at ASC").Find(&leg2)

	c.JSON(http.StatusOK, gin.H{
		"pickup_jobs": leg1, // jemput dari customer → bawa ke merchant
		"return_jobs": leg2, // ambil dari merchant → antar ke customer
	})
}

// AcceptPickupLeg: driver accepts leg 1 (customer → merchant).
// awaiting_pickup → awaiting_pickup (with driver assigned)
func (h *Handler) AcceptPickupLeg(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	driver, err := h.getDriver(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver not found"})
		return
	}

	var order model.Order
	if h.db.Where("id = ? AND service_type = ? AND status = ? AND driver_id IS NULL",
		id, "service", model.OrderStatusAwaitingPickup).First(&order).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Job not available"})
		return
	}

	h.db.Model(&order).Updates(map[string]interface{}{"driver_id": driver.ID})
	c.JSON(http.StatusOK, gin.H{
		"message":        "Pickup job accepted. Head to customer's address to pick up items.",
		"pickup_address": order.PickupAddress,
		"pickup_lat":     order.PickupLat,
		"pickup_lng":     order.PickupLng,
		"service_notes":  order.ServiceNotes,
	})
}

// MarkItemPickedUp: driver picked up from customer → heading to merchant.
// awaiting_pickup → item_picked_up
func (h *Handler) MarkItemPickedUp(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	driver, err := h.getDriver(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver not found"})
		return
	}

	var order model.Order
	if h.db.Preload("Merchant").Where("id = ? AND service_type = ? AND status = ? AND driver_id = ?",
		id, "service", model.OrderStatusAwaitingPickup, driver.ID).First(&order).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	now := time.Now()
	h.db.Model(&order).Updates(map[string]interface{}{
		"status":            model.OrderStatusItemPickedUp,
		"item_picked_up_at": now,
	})
	c.JSON(http.StatusOK, gin.H{
		"message":         "Items picked up. Deliver to service merchant.",
		"dropoff_address": order.DropoffAddress,
		"dropoff_lat":     order.DropoffLat,
		"dropoff_lng":     order.DropoffLng,
	})
}

// AcceptReturnLeg: driver accepts leg 2 (merchant → customer).
// ready_for_return → returning (with driver assigned)
func (h *Handler) AcceptReturnLeg(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	driver, err := h.getDriver(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver not found"})
		return
	}

	var order model.Order
	if h.db.Preload("Merchant").Where("id = ? AND service_type = ? AND status = ? AND driver_id IS NULL",
		id, "service", model.OrderStatusReadyForReturn).First(&order).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Return job not available"})
		return
	}

	h.db.Model(&order).Updates(map[string]interface{}{
		"driver_id": driver.ID,
		"status":    model.OrderStatusReturning,
	})
	c.JSON(http.StatusOK, gin.H{
		"message":          "Return job accepted. Pick up items from merchant, then deliver to customer.",
		"merchant_address": order.Merchant.Address,
		"return_address":   order.ReturnAddress,
		"return_lat":       order.ReturnLat,
		"return_lng":       order.ReturnLng,
		"total_cod":        order.Total,
	})
}

// MarkReturned: driver delivered items back to customer, customer pays COD.
// returning → returned. Credits driver and merchant wallets; tracks COD holding.
func (h *Handler) MarkReturned(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	driver, err := h.getDriver(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver not found"})
		return
	}

	var order model.Order
	if h.db.Where("id = ? AND service_type = ? AND status = ? AND driver_id = ?",
		id, "service", model.OrderStatusReturning, driver.ID).First(&order).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	now := time.Now()
	orderUUID := order.ID

	tx := h.db.Begin()
	tx.Model(&order).Updates(map[string]interface{}{
		"status":      model.OrderStatusReturned,
		"returned_at": now,
	})
	tx.Model(&model.Driver{}).Where("id = ?", driver.ID).
		Update("is_available", true)

	merchantNotes := fmt.Sprintf("Service order %s returned", order.OrderNumber)
	driverNotes := fmt.Sprintf("Earning service order %s", order.OrderNumber)

	if order.PaymentType == "cash" {
		if err := service.CreditMerchantWallet(tx, *order.MerchantID, order.Subtotal, "order_earning", &orderUUID, merchantNotes); err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to credit merchant wallet"})
			return
		}
		if err := service.CreditWallet(tx, driver.UserID, model.RoleDriver, order.DriverEarning, "order_earning", &orderUUID, driverNotes); err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to credit driver wallet"})
			return
		}
		tx.Model(&model.Driver{}).Where("id = ?", driver.ID).
			UpdateColumn("cod_holding", gorm.Expr("cod_holding + ?", order.Total))
	} else if order.PaymentStatus == "paid" {
		if err := service.CreditMerchantWallet(tx, *order.MerchantID, order.Subtotal, "order_earning", &orderUUID, merchantNotes); err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to credit merchant wallet"})
			return
		}
		if err := service.CreditWallet(tx, driver.UserID, model.RoleDriver, order.DriverEarning, "order_earning", &orderUUID, driverNotes); err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to credit driver wallet"})
			return
		}
	}

	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update"})
		return
	}

	resp := gin.H{
		"message":        "Order completed.",
		"driver_earning": order.DriverEarning,
	}
	if order.PaymentType == "cash" {
		resp["cash_collected"] = order.Total
		resp["to_deposit"] = order.Total - order.DriverEarning
	}
	c.JSON(http.StatusOK, resp)
}
