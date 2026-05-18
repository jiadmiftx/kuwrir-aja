package model

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Base model with UUID primary key
type Base struct {
	ID        uuid.UUID      `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

// Role enum
type Role string

const (
	RoleCustomer Role = "customer"
	RoleDriver   Role = "driver"
	RoleMerchant Role = "merchant"
	RoleAdmin    Role = "admin"
)

// OrderStatus enum
type OrderStatus string

const (
	OrderStatusPending   OrderStatus = "pending"
	OrderStatusConfirmed OrderStatus = "confirmed"
	OrderStatusPreparing OrderStatus = "preparing"
	OrderStatusReady     OrderStatus = "ready"
	OrderStatusPickedUp  OrderStatus = "picked_up"
	OrderStatusDelivered OrderStatus = "delivered"
	OrderStatusCancelled OrderStatus = "cancelled"
)

// DeliveryStatus enum
type DeliveryStatus string

const (
	DeliveryStatusSearching  DeliveryStatus = "searching"
	DeliveryStatusAssigned   DeliveryStatus = "assigned"
	DeliveryStatusPickup     DeliveryStatus = "pickup"
	DeliveryStatusDelivering DeliveryStatus = "delivering"
	DeliveryStatusCompleted  DeliveryStatus = "completed"
)

// User represents all platform users (customer, driver, merchant owner, admin)
type User struct {
	Base
	Name            string     `gorm:"not null" json:"name"`
	Email           string     `gorm:"uniqueIndex" json:"email"`
	Phone           string     `gorm:"uniqueIndex;not null" json:"phone"`
	Password        string     `gorm:"not null" json:"-"`
	AvatarURL       string     `json:"avatar_url,omitempty"`
	Role            Role       `gorm:"type:varchar(20);not null;index" json:"role"`
	IsActive        bool       `gorm:"default:true" json:"is_active"`
	EmailVerifiedAt *time.Time `json:"email_verified_at,omitempty"`

	// Relations
	Addresses []Address `gorm:"foreignKey:UserID" json:"addresses,omitempty"`
	Merchant  *Merchant `gorm:"foreignKey:UserID" json:"merchant,omitempty"`
	Driver    *Driver   `gorm:"foreignKey:UserID" json:"driver,omitempty"`
}

// Address for customer delivery addresses
type Address struct {
	Base
	UserID    uuid.UUID `gorm:"type:uuid;not null;index" json:"user_id"`
	Label     string    `gorm:"not null" json:"label"` // "Home", "Office", etc.
	Address   string    `gorm:"not null" json:"address"`
	Latitude  float64   `gorm:"not null" json:"latitude"`
	Longitude float64   `gorm:"not null" json:"longitude"`
	IsDefault bool      `gorm:"default:false" json:"is_default"`
}

// Merchant represents a store or business
type Merchant struct {
	Base
	UserID       uuid.UUID `gorm:"type:uuid;not null;uniqueIndex" json:"user_id"`
	Name         string    `gorm:"not null" json:"name"`
	Slug         string    `gorm:"uniqueIndex;not null" json:"slug"`
	Description  string    `json:"description,omitempty"`
	Phone        string    `json:"phone"`
	LogoURL      string    `json:"logo_url,omitempty"`
	BannerURL    string    `json:"banner_url,omitempty"`
	Address      string    `gorm:"not null" json:"address"`
	Latitude     float64   `gorm:"not null" json:"latitude"`
	Longitude    float64   `gorm:"not null" json:"longitude"`
	Rating       float64   `gorm:"default:0" json:"rating"`
	TotalReviews int       `gorm:"default:0" json:"total_reviews"`
	IsActive        bool    `gorm:"default:true" json:"is_active"`
	IsVerified      bool    `gorm:"default:false" json:"is_verified"`
	IsOpen          bool    `gorm:"default:true" json:"is_open"`
	CanSelfDeliver  bool    `gorm:"default:false" json:"can_self_deliver"`
	SelfDeliveryFee float64 `gorm:"default:0" json:"self_delivery_fee"` // 0 = free delivery

	// Relations
	Owner      User              `gorm:"foreignKey:UserID" json:"owner,omitempty"`
	Categories []ProductCategory `gorm:"foreignKey:MerchantID" json:"categories,omitempty"`
}

// ProductCategory groups products
type ProductCategory struct {
	Base
	MerchantID uuid.UUID `gorm:"type:uuid;not null;index" json:"merchant_id"`
	Name       string    `gorm:"not null" json:"name"`
	SortOrder  int       `gorm:"default:0" json:"sort_order"`
	Products   []Product `gorm:"foreignKey:CategoryID" json:"products,omitempty"`
}

// Product is an item sold by the merchant
type Product struct {
	Base
	CategoryID    uuid.UUID        `gorm:"type:uuid;not null;index" json:"category_id"`
	Name          string           `gorm:"not null" json:"name"`
	Description   string           `json:"description,omitempty"`
	Price         float64          `gorm:"not null" json:"price"` // Base price (merchant's price)
	ImageURL      string           `json:"image_url,omitempty"`
	IsAvailable   bool             `gorm:"default:true" json:"is_available"`
	TrackStock    bool             `gorm:"default:false" json:"track_stock"`
	StockQuantity int              `gorm:"default:0" json:"stock_quantity"`
	SKU           string           `json:"sku,omitempty"`
	SortOrder     int              `gorm:"default:0" json:"sort_order"`
	Variants      []ProductVariant `gorm:"foreignKey:ProductID" json:"variants,omitempty"`
}

// ProductVariant represents options/modifiers for a product
type ProductVariant struct {
	Base
	ProductID  uuid.UUID `gorm:"type:uuid;not null;index" json:"product_id"`
	GroupName  string    `gorm:"not null" json:"group_name"` // e.g., "Size", "Color"
	Name       string    `gorm:"not null" json:"name"`       // e.g., "Large", "Red"
	Price      float64   `gorm:"default:0" json:"price"`
	IsRequired bool      `gorm:"default:false" json:"is_required"`
}

// Driver represents a delivery driver
type Driver struct {
	Base
	UserID         uuid.UUID `gorm:"type:uuid;not null;uniqueIndex" json:"user_id"`
	VehicleType    string    `gorm:"not null" json:"vehicle_type"` // "motorcycle", "bicycle"
	VehiclePlate   string    `gorm:"not null" json:"vehicle_plate"`
	LicenseNumber  string    `json:"license_number"`
	Latitude       float64   `json:"latitude"`
	Longitude      float64   `json:"longitude"`
	IsOnline       bool      `gorm:"default:false" json:"is_online"`
	IsAvailable    bool      `gorm:"default:true" json:"is_available"`
	Rating         float64   `gorm:"default:5.0" json:"rating"`
	TotalDelivered int       `gorm:"default:0" json:"total_delivered"`
	CashBalance    float64   `gorm:"default:0" json:"cash_balance"` // Cash owed to platform

	User User `gorm:"foreignKey:UserID" json:"user,omitempty"`
}

// Order represents a transaction (ecommerce, send, ride, pos)
type Order struct {
	Base
	OrderNumber string      `gorm:"uniqueIndex;not null" json:"order_number"`
	ServiceType string      `gorm:"type:varchar(20);not null;default:'ecommerce';index" json:"service_type"` // ecommerce, send, ride, pos
	CustomerID  *uuid.UUID  `gorm:"type:uuid;index" json:"customer_id,omitempty"`                             // Nullable for POS anonymous
	MerchantID  *uuid.UUID  `gorm:"type:uuid;index" json:"merchant_id,omitempty"`                             // Nullable for Send/Ride
	DriverID    *uuid.UUID  `gorm:"type:uuid;index" json:"driver_id,omitempty"`
	Status       OrderStatus `gorm:"type:varchar(20);not null;default:'pending';index" json:"status"`
	DeliveryType string      `gorm:"type:varchar(20);not null;default:'platform'" json:"delivery_type"` // "platform" or "self"
	PaymentType  string      `gorm:"type:varchar(20);not null;default:'cash'" json:"payment_type"`     // cash, qris, card

	// Pricing (all amounts in IDR)
	Subtotal           float64 `gorm:"not null;default:0" json:"subtotal"`            // Sum of item prices
	PlatformMarkup     float64 `gorm:"not null;default:0" json:"platform_markup"`     // Total markup amount (for ecommerce)
	DeliveryFee        float64 `gorm:"not null;default:0" json:"delivery_fee"`        // Delivery fee
	DeliveryCommission float64 `gorm:"not null;default:0" json:"delivery_commission"` // Platform's cut from delivery
	DriverEarning      float64 `gorm:"not null;default:0" json:"driver_earning"`      // Driver's share of delivery
	Total              float64 `gorm:"not null;default:0" json:"total"`               // Grand total customer pays

	// Routing Information (A-to-B)
	PickupAddress string  `json:"pickup_address,omitempty"`
	PickupLat     float64 `json:"pickup_lat,omitempty"`
	PickupLng     float64 `json:"pickup_lng,omitempty"`
	SenderName    string  `json:"sender_name,omitempty"`
	SenderPhone   string  `json:"sender_phone,omitempty"`

	DropoffAddress string  `json:"dropoff_address,omitempty"`
	DropoffLat     float64 `json:"dropoff_lat,omitempty"`
	DropoffLng     float64 `json:"dropoff_lng,omitempty"`
	ReceiverName   string  `json:"receiver_name,omitempty"`
	ReceiverPhone  string  `json:"receiver_phone,omitempty"`

	DistanceKm float64 `json:"distance_km"`
	Notes      string  `json:"notes,omitempty"`

	// Timestamps
	PlacedAt    *time.Time `json:"placed_at,omitempty"`
	ConfirmedAt *time.Time `json:"confirmed_at,omitempty"`
	ReadyAt     *time.Time `json:"ready_at,omitempty"`
	PickedUpAt  *time.Time `json:"picked_up_at,omitempty"`
	DeliveredAt *time.Time `json:"delivered_at,omitempty"`
	CancelledAt *time.Time `json:"cancelled_at,omitempty"`

	// Relations
	Customer *User       `gorm:"foreignKey:CustomerID" json:"customer,omitempty"`
	Merchant *Merchant   `gorm:"foreignKey:MerchantID" json:"merchant,omitempty"`
	Driver   *Driver     `gorm:"foreignKey:DriverID" json:"driver,omitempty"`
	Items    []OrderItem `gorm:"foreignKey:OrderID" json:"items,omitempty"`
	Review   *Review     `gorm:"foreignKey:OrderID" json:"review,omitempty"`
}

// OrderItem snapshot of what was ordered
type OrderItem struct {
	Base
	OrderID      uuid.UUID  `gorm:"type:uuid;not null;index" json:"order_id"`
	ProductID    *uuid.UUID `gorm:"type:uuid" json:"product_id,omitempty"` // Nullable for custom items
	ItemName     string     `gorm:"not null" json:"item_name"`             // Snapshot
	Quantity     int        `gorm:"not null" json:"quantity"`
	BasePrice    float64    `gorm:"not null" json:"base_price"`   // Merchant's original price
	UnitPrice    float64    `gorm:"not null" json:"unit_price"`   // Price with markup
	TotalPrice   float64    `gorm:"not null" json:"total_price"`  // UnitPrice * Quantity + variants
	VariantsJSON string     `gorm:"type:jsonb" json:"variants_json,omitempty"`
	Notes        string     `json:"notes,omitempty"`
}

// Review from customer
type Review struct {
	Base
	OrderID        uuid.UUID  `gorm:"type:uuid;not null;uniqueIndex" json:"order_id"`
	CustomerID     uuid.UUID  `gorm:"type:uuid;not null;index" json:"customer_id"`
	MerchantID     *uuid.UUID `gorm:"type:uuid;index" json:"merchant_id,omitempty"`
	DriverID       *uuid.UUID `gorm:"type:uuid;index" json:"driver_id,omitempty"`
	MerchantRating *int       `json:"merchant_rating,omitempty"` // 1-5
	DriverRating   *int       `json:"driver_rating,omitempty"`   // 1-5
	Comment        string     `json:"comment,omitempty"`
}

// SystemSetting stores configurable platform parameters
type SystemSetting struct {
	Key       string    `gorm:"primaryKey;type:varchar(100)" json:"key"`
	Value     string    `gorm:"not null" json:"value"`
	Label     string    `gorm:"not null" json:"label"` // Human-readable label
	UpdatedAt time.Time `json:"updated_at"`
}

// DriverDeposit tracks cash deposits from drivers to admin
type DriverDeposit struct {
	Base
	DriverID     uuid.UUID  `gorm:"type:uuid;not null;index" json:"driver_id"`
	Amount       float64    `gorm:"not null" json:"amount"`
	Method       string     `gorm:"not null" json:"method"` // "bank_transfer", "cash"
	Reference    string     `json:"reference,omitempty"`    // Transfer receipt number
	Notes        string     `json:"notes,omitempty"`
	VerifiedByID *uuid.UUID `gorm:"type:uuid" json:"verified_by_id,omitempty"`
	VerifiedAt   *time.Time `json:"verified_at,omitempty"`

	Driver Driver `gorm:"foreignKey:DriverID" json:"driver,omitempty"`
}

// MerchantSettlement tracks monthly payouts to merchants
type MerchantSettlement struct {
	Base
	MerchantID             uuid.UUID  `gorm:"type:uuid;not null;index" json:"merchant_id"`
	PeriodStart            time.Time  `gorm:"not null" json:"period_start"`
	PeriodEnd              time.Time  `gorm:"not null" json:"period_end"`
	TotalOrders            int        `gorm:"not null" json:"total_orders"`
	TotalBaseProductAmount float64    `gorm:"not null" json:"total_base_product_amount"` // Sum of base prices
	Status                 string     `gorm:"type:varchar(20);default:'pending'" json:"status"` // "pending", "paid"
	PaidAt                 *time.Time `json:"paid_at,omitempty"`
	PaidByID               *uuid.UUID `gorm:"type:uuid" json:"paid_by_id,omitempty"`
	Reference              string     `json:"reference,omitempty"` // Bank transfer reference

	Merchant Merchant `gorm:"foreignKey:MerchantID" json:"merchant,omitempty"`
}

// Promotion represents a promo code
type Promotion struct {
	Base
	Code        string    `gorm:"uniqueIndex;not null" json:"code"`
	Title       string    `gorm:"not null" json:"title"`
	Type        string    `gorm:"type:varchar(20);not null" json:"type"` // "percentage", "fixed", "free_delivery"
	Value       float64   `gorm:"not null" json:"value"`
	MinOrder    float64   `gorm:"default:0" json:"min_order"`
	MaxDiscount float64   `gorm:"default:0" json:"max_discount"`
	UsageLimit  int       `gorm:"default:0" json:"usage_limit"`
	UsedCount   int       `gorm:"default:0" json:"used_count"`
	IsActive    bool      `gorm:"default:true" json:"is_active"`
	StartsAt    time.Time `gorm:"not null" json:"starts_at"`
	ExpiresAt   time.Time `gorm:"not null" json:"expires_at"`
}
