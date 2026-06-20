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
	// Food / ecommerce statuses
	OrderStatusPending   OrderStatus = "pending"
	OrderStatusConfirmed OrderStatus = "confirmed"
	OrderStatusPreparing OrderStatus = "preparing"
	OrderStatusReady     OrderStatus = "ready"
	OrderStatusPickedUp  OrderStatus = "picked_up"
	OrderStatusDelivered OrderStatus = "delivered"
	OrderStatusCancelled OrderStatus = "cancelled"

	// Service (jasa) statuses — used when service_type = "service"
	OrderStatusAwaitingPickup OrderStatus = "awaiting_pickup"   // driver dikirim ke customer untuk jemput barang
	OrderStatusItemPickedUp   OrderStatus = "item_picked_up"    // barang sudah dijemput dari customer, menuju tempat jasa
	OrderStatusInService      OrderStatus = "in_service"        // barang sedang dikerjakan di tempat jasa
	OrderStatusReadyForReturn OrderStatus = "ready_for_return"  // selesai, menunggu driver untuk antar balik
	OrderStatusReturning      OrderStatus = "returning"         // driver membawa barang kembali ke customer
	OrderStatusReturned       OrderStatus = "returned"          // barang sudah dikembalikan, customer bayar COD
)

// MerchantType distinguishes food merchants from service merchants
type MerchantType string

const (
	MerchantTypeFood    MerchantType = "food"
	MerchantTypeService MerchantType = "service"
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
	// No DB-level default: GORM omits zero-value fields with a `default` tag from
	// INSERT, which would silently force is_active=true even when Register
	// explicitly sets false for pending driver/merchant accounts.
	IsActive bool `json:"is_active"`
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
	IsActive        bool    `gorm:"default:false" json:"is_active"`  // false until admin verifies
	IsVerified      bool    `gorm:"default:false" json:"is_verified"`
	IsOpen          bool    `gorm:"default:false" json:"is_open"`
	CanSelfDeliver  bool    `gorm:"default:false" json:"can_self_deliver"`
	SelfDeliveryFee float64 `gorm:"default:0" json:"self_delivery_fee"`

	// Verification documents (placeholder: local URLs, later: R2)
	OwnerKtpURL        string `json:"owner_ktp_url,omitempty"`
	BusinessLicenseURL string `json:"business_license_url,omitempty"` // SIUP / IUMK
	StorePhotoURL      string `json:"store_photo_url,omitempty"`

	// Merchant type & service category
	Type            MerchantType `gorm:"type:varchar(20);default:'food'" json:"type"` // food | service
	ServiceCategory string       `gorm:"type:varchar(50)" json:"service_category,omitempty"` // laundry | bengkel | cleaning | salon | other

	// Admin review
	VerificationStatus string     `gorm:"type:varchar(20);default:'pending'" json:"verification_status"` // pending, approved, rejected
	VerificationNote   string     `json:"verification_note,omitempty"`
	VerifiedByID       *uuid.UUID `gorm:"type:uuid" json:"verified_by_id,omitempty"`
	VerifiedAt         *time.Time `json:"verified_at,omitempty"`

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
	Price            float64 `gorm:"not null" json:"price"`            // Base price (merchant's price / harga jual)
	CostPrice        float64 `gorm:"default:0" json:"cost_price"`      // HPP / harga beli untuk margin analysis
	PriceUnit        string  `gorm:"type:varchar(20);default:'per_item'" json:"price_unit"` // per_item | per_kg | per_service | per_hour
	DurationEstimate string  `json:"duration_estimate,omitempty"`      // e.g. "1-2 hari", "3-5 jam"
	ImageURL      string           `json:"image_url,omitempty"`
	IsAvailable   bool             `gorm:"default:true" json:"is_available"`
	TrackStock    bool             `gorm:"default:false" json:"track_stock"`
	StockQuantity int              `gorm:"default:0" json:"stock_quantity"`
	MinStock      int              `gorm:"default:0" json:"min_stock"` // Alert when stock falls below this
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
	CodHolding     float64   `gorm:"default:0" json:"cod_holding"` // Total COD cash physically with driver, not yet deposited

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

	// Service-specific fields (service_type = "service")
	PickupScheduledAt *time.Time `json:"pickup_scheduled_at,omitempty"` // waktu jemput yang diminta customer
	ServiceNotes      string     `json:"service_notes,omitempty"`       // instruksi khusus (e.g. "pisahkan baju putih")
	ReturnAddress     string     `json:"return_address,omitempty"`      // alamat antar balik (default = pickup address)
	ReturnLat         float64    `json:"return_lat,omitempty"`
	ReturnLng         float64    `json:"return_lng,omitempty"`
	WeightKg          float64    `gorm:"default:0" json:"weight_kg,omitempty"` // untuk layanan per-kg (laundry)

	// Tax & fees (added to total beyond markup + delivery)
	TaxAmount     float64 `gorm:"default:0" json:"tax_amount"`      // PPN applied on subtotal_with_markup
	AppServiceFee float64 `gorm:"default:0" json:"app_service_fee"` // platform service fee on delivery

	// Payout tracking (what each party actually receives)
	MerchantPayout          float64 `gorm:"default:0" json:"merchant_payout"`           // = Subtotal - PlatformMarkup (merchant's base price)
	MerchantDeliveryEarning float64 `gorm:"default:0" json:"merchant_delivery_earning"` // self-deliver: merchant's cut of delivery fee

	// Payment (online gateway)
	PaymentStatus    string     `gorm:"type:varchar(20);default:'pending'" json:"payment_status"` // pending | paid | failed | expired
	PaymentRef       string     `json:"payment_ref,omitempty"`       // Duitku merchant_order_id
	PaymentURL       string     `json:"payment_url,omitempty"`       // URL bayar untuk customer
	PaymentExpiredAt *time.Time `json:"payment_expired_at,omitempty"` // kapan link expired

	// Timestamps
	PlacedAt        *time.Time `json:"placed_at,omitempty"`
	ConfirmedAt     *time.Time `json:"confirmed_at,omitempty"`
	ReadyAt         *time.Time `json:"ready_at,omitempty"`
	PickedUpAt      *time.Time `json:"picked_up_at,omitempty"`
	DeliveredAt     *time.Time `json:"delivered_at,omitempty"`
	CancelledAt     *time.Time `json:"cancelled_at,omitempty"`
	ItemPickedUpAt  *time.Time `json:"item_picked_up_at,omitempty"`  // barang diambil dari customer
	InServiceAt     *time.Time `json:"in_service_at,omitempty"`      // mulai dikerjakan
	ReadyForReturnAt *time.Time `json:"ready_for_return_at,omitempty"` // selesai dikerjakan
	ReturnedAt      *time.Time `json:"returned_at,omitempty"`        // barang sudah dikembalikan ke customer

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
	VariantsJSON *string    `gorm:"type:jsonb" json:"variants_json,omitempty"`
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

// ─────────────────────────────────────────────────────────────────────────────
// REGISTRATION & VERIFICATION MODELS
// ─────────────────────────────────────────────────────────────────────────────

// DriverApplication stores a driver's onboarding submission for admin review
type DriverApplication struct {
	Base
	UserID uuid.UUID `gorm:"type:uuid;not null;uniqueIndex" json:"user_id"`

	// Vehicle info
	VehicleType  string `gorm:"not null" json:"vehicle_type"`  // motorcycle, bicycle, car
	VehiclePlate string `gorm:"not null" json:"vehicle_plate"` // e.g. DR 1234 AB
	VehicleYear  int    `json:"vehicle_year"`
	VehicleColor string `json:"vehicle_color"`
	VehicleBrand string `json:"vehicle_brand"`

	// Document URLs (placeholder: local /uploads/, later: R2)
	KtpURL          string `json:"ktp_url,omitempty"`           // foto KTP
	SimURL          string `json:"sim_url,omitempty"`           // foto SIM (C/A)
	StnkURL         string `json:"stnk_url,omitempty"`          // foto STNK
	SelfieURL       string `json:"selfie_url,omitempty"`        // foto wajah / selfie with KTP
	VehiclePhotoURL string `json:"vehicle_photo_url,omitempty"` // foto kendaraan

	// Admin review
	Status       string     `gorm:"type:varchar(20);default:'pending'" json:"status"` // pending, approved, rejected
	ReviewNote   string     `json:"review_note,omitempty"`
	ReviewedByID *uuid.UUID `gorm:"type:uuid" json:"reviewed_by_id,omitempty"`
	ReviewedAt   *time.Time `json:"reviewed_at,omitempty"`

	User User `gorm:"foreignKey:UserID" json:"user,omitempty"`
}

// ─────────────────────────────────────────────────────────────────────────────
// POS / KASIR MODELS
// Inspired by finansial-mac: pemasukan, stok/pergerakan_stok, piutang, hutang
// ─────────────────────────────────────────────────────────────────────────────

// StockMovement tracks every change to a product's stock (like pergerakan_stok)
type StockMovement struct {
	Base
	ProductID  uuid.UUID `gorm:"type:uuid;not null;index" json:"product_id"`
	MerchantID uuid.UUID `gorm:"type:uuid;not null;index" json:"merchant_id"`
	Date       time.Time `gorm:"not null" json:"date"`
	Type       string    `gorm:"type:varchar(20);not null" json:"type"` // "in","out","opname","void"
	Quantity   int       `gorm:"not null" json:"quantity"`
	CostPrice  float64   `gorm:"default:0" json:"cost_price"` // harga beli saat gerakan ini
	Reason     string    `json:"reason,omitempty"`            // keterangan / alasan
	Reference  string    `json:"reference,omitempty"`         // nomor transaksi POS atau manual

	Product Product `gorm:"foreignKey:ProductID" json:"product,omitempty"`
}

// PosTransaction is a POS sale header (like jurnal + invoice combined for kasir)
type PosTransaction struct {
	Base
	TransactionNumber string     `gorm:"uniqueIndex;not null" json:"transaction_number"` // e.g. POS-260601143022
	MerchantID        uuid.UUID  `gorm:"type:uuid;not null;index" json:"merchant_id"`
	Date              time.Time  `gorm:"not null" json:"date"`
	CustomerName      string     `json:"customer_name,omitempty"`  // opsional, untuk tab/struk
	CustomerPhone     string     `json:"customer_phone,omitempty"` // opsional
	PaymentMethod     string     `gorm:"type:varchar(20);not null;default:'cash'" json:"payment_method"` // cash, qris, card, tab
	Status            string     `gorm:"type:varchar(20);not null;default:'completed'" json:"status"`    // completed, voided
	Notes             string     `json:"notes,omitempty"`

	// Pricing breakdown
	Subtotal    float64 `gorm:"not null;default:0" json:"subtotal"`     // sum of item prices
	Discount    float64 `gorm:"default:0" json:"discount"`              // diskon keseluruhan
	Tax         float64 `gorm:"default:0" json:"tax"`                   // pajak (jika ada)
	GrandTotal  float64 `gorm:"not null;default:0" json:"grand_total"`  // yang dibayar pelanggan
	TotalCost   float64 `gorm:"default:0" json:"total_cost"`            // total HPP semua item
	GrossProfit float64 `gorm:"default:0" json:"gross_profit"`          // grand_total - total_cost

	// Cash handling
	CashReceived float64 `gorm:"default:0" json:"cash_received"` // uang yang diterima (untuk cash)
	CashChange   float64 `gorm:"default:0" json:"cash_change"`   // kembalian

	VoidedAt     *time.Time `json:"voided_at,omitempty"`
	VoidedReason string     `json:"voided_reason,omitempty"`

	// Relations
	Merchant *Merchant        `gorm:"foreignKey:MerchantID" json:"merchant,omitempty"`
	Items    []PosTransactionItem `gorm:"foreignKey:TransactionID" json:"items,omitempty"`
}

// PosTransactionItem is a line item in a POS sale (like invoice_item)
type PosTransactionItem struct {
	Base
	TransactionID uuid.UUID  `gorm:"type:uuid;not null;index" json:"transaction_id"`
	ProductID     *uuid.UUID `gorm:"type:uuid" json:"product_id,omitempty"` // nullable for custom items
	ProductName   string     `gorm:"not null" json:"product_name"`           // snapshot
	SKU           string     `json:"sku,omitempty"`
	Quantity      int        `gorm:"not null" json:"quantity"`
	UnitPrice     float64    `gorm:"not null" json:"unit_price"`   // harga jual per unit
	UnitCost      float64    `gorm:"default:0" json:"unit_cost"`   // HPP per unit
	Discount      float64    `gorm:"default:0" json:"discount"`    // diskon item
	Subtotal      float64    `gorm:"not null" json:"subtotal"`     // (unit_price * qty) - discount
	Notes         string     `json:"notes,omitempty"`
}

// MerchantReceivable tracks credit/tab sales (like piutang di finansial-mac)
// Dibuat otomatis saat POS transaction dengan payment_method="tab"
type MerchantReceivable struct {
	Base
	MerchantID    uuid.UUID  `gorm:"type:uuid;not null;index" json:"merchant_id"`
	TransactionID *uuid.UUID `gorm:"type:uuid" json:"transaction_id,omitempty"` // link ke PosTransaction asal
	CustomerName  string     `gorm:"not null" json:"customer_name"`
	CustomerPhone string     `json:"customer_phone,omitempty"`
	Description   string     `json:"description,omitempty"`
	DueDate       *time.Time `json:"due_date,omitempty"`
	Amount        float64    `gorm:"not null" json:"amount"`
	PaidAmount    float64    `gorm:"default:0" json:"paid_amount"`
	Status        string     `gorm:"type:varchar(20);default:'unpaid'" json:"status"` // unpaid, partial, paid

	Payments []MerchantReceivablePayment `gorm:"foreignKey:ReceivableID" json:"payments,omitempty"`
}

// MerchantReceivablePayment records a payment against a receivable (like bayar_piutang)
type MerchantReceivablePayment struct {
	Base
	ReceivableID uuid.UUID `gorm:"type:uuid;not null;index" json:"receivable_id"`
	Date         time.Time `gorm:"not null" json:"date"`
	Amount       float64   `gorm:"not null" json:"amount"`
	Method       string    `gorm:"type:varchar(20);default:'cash'" json:"method"` // cash, transfer
	Notes        string    `json:"notes,omitempty"`
}

// MerchantPayable tracks purchases on credit from suppliers (like hutang di finansial-mac)
type MerchantPayable struct {
	Base
	MerchantID    uuid.UUID  `gorm:"type:uuid;not null;index" json:"merchant_id"`
	SupplierName  string     `gorm:"not null" json:"supplier_name"`
	SupplierPhone string     `json:"supplier_phone,omitempty"`
	Description   string     `json:"description,omitempty"` // barang yang dibeli
	DueDate       *time.Time `json:"due_date,omitempty"`
	Amount        float64    `gorm:"not null" json:"amount"`
	PaidAmount    float64    `gorm:"default:0" json:"paid_amount"`
	Status        string     `gorm:"type:varchar(20);default:'unpaid'" json:"status"` // unpaid, partial, paid

	Payments []MerchantPayablePayment `gorm:"foreignKey:PayableID" json:"payments,omitempty"`
}

// MerchantPayablePayment records a payment against a payable (like bayar_hutang)
type MerchantPayablePayment struct {
	Base
	PayableID uuid.UUID `gorm:"type:uuid;not null;index" json:"payable_id"`
	Date      time.Time `gorm:"not null" json:"date"`
	Amount    float64   `gorm:"not null" json:"amount"`
	Method    string    `gorm:"type:varchar(20);default:'cash'" json:"method"`
	Notes     string    `json:"notes,omitempty"`
}

// ─────────────────────────────────────────────────────────────────────────────
// WALLET & PAYMENT MODELS
// ─────────────────────────────────────────────────────────────────────────────

// Wallet holds the earnings balance for a driver or merchant.
// One wallet per user. Credits happen automatically on order completion;
// debits happen on withdrawal.
type Wallet struct {
	Base
	UserID         uuid.UUID `gorm:"type:uuid;not null;uniqueIndex" json:"user_id"`
	Balance        float64   `gorm:"default:0" json:"balance"`         // available to withdraw
	TotalEarned    float64   `gorm:"default:0" json:"total_earned"`    // lifetime credits
	TotalWithdrawn float64   `gorm:"default:0" json:"total_withdrawn"` // lifetime debits

	User         User                `gorm:"foreignKey:UserID" json:"user,omitempty"`
	Transactions []WalletTransaction `gorm:"foreignKey:WalletID" json:"transactions,omitempty"`
}

// WalletTransaction is an immutable ledger entry for every wallet movement.
type WalletTransaction struct {
	Base
	WalletID    uuid.UUID  `gorm:"type:uuid;not null;index" json:"wallet_id"`
	OrderID     *uuid.UUID `gorm:"type:uuid;index" json:"order_id,omitempty"` // source order (nullable for manual adjustments)
	Type        string     `gorm:"type:varchar(20);not null" json:"type"`      // credit | debit
	Category    string     `gorm:"type:varchar(30);not null" json:"category"`  // order_earning | withdrawal | refund | adjustment | cod_deposit
	Amount      float64    `gorm:"not null" json:"amount"`
	BalanceAfter float64   `gorm:"not null" json:"balance_after"` // snapshot of balance after this entry
	Notes       string     `json:"notes,omitempty"`
}

// DeliveryZone defines city-based delivery pricing zones for admin configuration.
// The nearest active zone to the merchant is used when calculating delivery fees.
type DeliveryZone struct {
	Base
	CityName  string  `gorm:"type:varchar(100);not null" json:"city_name"`
	Latitude  float64 `gorm:"not null" json:"latitude"`
	Longitude float64 `gorm:"not null" json:"longitude"`
	RadiusKm  float64 `gorm:"default:5" json:"radius_km"`     // inside-zone radius
	BaseFee   float64 `gorm:"default:15000" json:"base_fee"`  // fee within radius
	PerKmFee  float64 `gorm:"default:10000" json:"per_km_fee"` // fee per km beyond radius
	IsDefault bool    `gorm:"default:false" json:"is_default"` // fallback when no zone matches
	IsActive  bool    `gorm:"default:true" json:"is_active"`
}

// RefundRequest tracks a customer's refund request and admin resolution.
type RefundRequest struct {
	Base
	OrderID     uuid.UUID  `gorm:"type:uuid;not null;index" json:"order_id"`
	RequestedBy uuid.UUID  `gorm:"type:uuid;not null;index" json:"requested_by"` // customer user_id
	Reason      string     `gorm:"not null" json:"reason"`
	Amount      float64    `gorm:"not null" json:"amount"`
	// pending → approved (wallets reversed) | rejected
	Status      string     `gorm:"type:varchar(20);default:'pending'" json:"status"`
	AdminNote   string     `json:"admin_note,omitempty"`
	ProcessedBy *uuid.UUID `gorm:"type:uuid" json:"processed_by,omitempty"`
	ProcessedAt *time.Time `json:"processed_at,omitempty"`

	Order Order `gorm:"foreignKey:OrderID" json:"order,omitempty"`
}

// WithdrawalRequest tracks a payout request and its Duitku disbursement status.
type WithdrawalRequest struct {
	Base
	WalletID          uuid.UUID  `gorm:"type:uuid;not null;index" json:"wallet_id"`
	Amount            float64    `gorm:"not null" json:"amount"`
	BankCode          string     `gorm:"type:varchar(20);not null" json:"bank_code"`           // BCA, BNI, MANDIRI, etc.
	BankAccountNumber string     `gorm:"type:varchar(50);not null" json:"bank_account_number"`
	BankAccountName   string     `gorm:"type:varchar(100);not null" json:"bank_account_name"`
	Status            string     `gorm:"type:varchar(20);default:'processing'" json:"status"` // processing | success | failed
	DisbursementRef   string     `json:"disbursement_ref,omitempty"`  // reference from Duitku
	FailedReason      string     `json:"failed_reason,omitempty"`
	ProcessedAt       *time.Time `json:"processed_at,omitempty"`

	Wallet Wallet `gorm:"foreignKey:WalletID" json:"wallet,omitempty"`
}
