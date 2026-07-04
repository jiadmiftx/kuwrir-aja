package main

import (
	"fmt"
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"github.com/kuwrir-platform/backend/internal/config"
	adminHandler "github.com/kuwrir-platform/backend/internal/handler/admin"
	authHandler "github.com/kuwrir-platform/backend/internal/handler/auth"
	"github.com/kuwrir-platform/backend/internal/service"
	customerHandler "github.com/kuwrir-platform/backend/internal/handler/customer"
	driverregHandler "github.com/kuwrir-platform/backend/internal/handler/driverreg"
	kasirHandler "github.com/kuwrir-platform/backend/internal/handler/kasir"
	merchantHandler "github.com/kuwrir-platform/backend/internal/handler/merchant"
	paymentHandler "github.com/kuwrir-platform/backend/internal/handler/payment"
	serviceHandler "github.com/kuwrir-platform/backend/internal/handler/service"
	supportHandler "github.com/kuwrir-platform/backend/internal/handler/support"
	walletHandler "github.com/kuwrir-platform/backend/internal/handler/wallet"
	"github.com/kuwrir-platform/backend/internal/middleware"
	"github.com/kuwrir-platform/backend/internal/model"
)

func main() {
	// Load .env file if present (dev convenience; prod uses real env vars)
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using system environment variables")
	}

	// Load config
	cfg := config.Load()

	// Set Gin mode
	gin.SetMode(cfg.Server.Mode)

	// Connect to database
	db, err := gorm.Open(postgres.Open(cfg.Database.DSN()), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Auto-migrate all models
	if err := db.AutoMigrate(
		&model.User{},
		&model.OtpCode{},
		&model.Address{},
		&model.Merchant{},
		&model.ProductCategory{},
		&model.FoodCategory{},
		&model.Banner{},
		&model.Product{},
		&model.ProductVariant{},
		&model.Driver{},
		&model.Order{},
		&model.OrderItem{},
		&model.Review{},
		&model.SystemSetting{},
		&model.DriverDeposit{},
		&model.MerchantSettlement{},
		&model.Promotion{},
		// Phase 6: Registration & Verification
		&model.DriverApplication{},
		// Phase 6: POS/Kasir models
		&model.StockMovement{},
		&model.PosTransaction{},
		&model.PosTransactionItem{},
		&model.MerchantReceivable{},
		&model.MerchantReceivablePayment{},
		&model.MerchantPayable{},
		&model.MerchantPayablePayment{},
		// Payment & Wallet
		&model.Wallet{},
		&model.WalletTransaction{},
		&model.WithdrawalRequest{},
		// Delivery zones (city reference points for pricing)
		&model.DeliveryZone{},
		// Refund requests
		&model.RefundRequest{},
		// In-order chat messages
		&model.ChatMessage{},
		// Customer ↔ Admin support chat
		&model.SupportMessage{},
	); err != nil {
		log.Fatalf("Failed to migrate database: %v", err)
	}

	// Initialize Firebase Admin SDK for push notifications
	service.InitFCM()

	// Seed default system settings and delivery zones
	seedSettings(db)
	seedDeliveryZones(db)
	seedAdminUser(db)

	// Setup Gin router
	r := gin.Default()
	r.Use(middleware.CORSMiddleware())

	// Serve uploaded files (placeholder — swap for R2 CDN URL later)
	r.Static("/uploads", "./uploads")

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":  "healthy",
			"service": "KUWRIR API",
			"version": "1.0.0",
		})
	})

	// API v1 routes
	v1 := r.Group("/api/v1")
	{
		// Public routes (no auth required)
		var whatsappSender service.WhatsAppSender = service.LogWhatsAppSender{}
		if cfg.WhatsApp.GatewayURL != "" {
			whatsappSender = service.NewHTTPWhatsAppSender(cfg.WhatsApp.GatewayURL, cfg.WhatsApp.APIKey)
		}
		authH := authHandler.NewHandler(db, cfg, whatsappSender)
		authH.RegisterRoutes(v1)

		// Merchant handler (has both public and protected routes)
		merchH := merchantHandler.NewHandler(db)

		// Public merchant browsing (no auth)
		// merchH.RegisterRoutes(v1, protected) // Will call below after protected group is created

		// Admin handler instantiated here (before the admin-only group)
		// so its public-facing methods (e.g. active promotions for the
		// customer app's Home promo carousel) can be registered on v1.
		adminH := adminHandler.NewHandler(db)
		v1.GET("/promotions/active", adminH.PublicActivePromotions)
		v1.GET("/banners/active", adminH.PublicActiveBanners)

		// Protected routes (auth required)
		protected := v1.Group("")
		protected.Use(middleware.AuthMiddleware(cfg.JWT.Secret))
		{
			// Support chat handler (used in both admin and customer sections)
			supportH := supportHandler.NewHandler(db)

			// Admin routes
			adminRoutes := protected.Group("/admin")
			adminRoutes.Use(middleware.RoleMiddleware("admin"))
			{
				adminH.RegisterRoutes(adminRoutes)
				supportH.RegisterAdminRoutes(adminRoutes)
			}

			// Merchant owner routes (auth required)
			merchOwnerRoutes := protected.Group("")
			merchOwnerRoutes.Use(middleware.RoleMiddleware("merchant"))
			merchH.RegisterRoutes(v1, merchOwnerRoutes)

			// Driver registration & application (driver role, also partially public)
			driverRegH := driverregHandler.NewHandler(db)
			driverRegH.RegisterPublicRoutes(v1)
			driverRegProtected := protected.Group("")
			driverRegProtected.Use(middleware.RoleMiddleware("driver"))
			driverRegH.RegisterProtectedRoutes(driverRegProtected)

			// Service (jasa) routes
			svcH := serviceHandler.NewHandler(db)
			svcCustRoutes := protected.Group("")
			svcCustRoutes.Use(middleware.RoleMiddleware("customer"))
			svcMerchRoutes := protected.Group("")
			svcMerchRoutes.Use(middleware.RoleMiddleware("merchant"))
			svcDriverRoutes := protected.Group("")
			svcDriverRoutes.Use(middleware.RoleMiddleware("driver"))
			svcH.RegisterRoutes(v1, svcCustRoutes, svcMerchRoutes, svcDriverRoutes)

			// POS / Kasir routes (merchant only)
			kasirOwnerRoutes := protected.Group("/my-store")
			kasirOwnerRoutes.Use(middleware.RoleMiddleware("merchant"))
			kasirH := kasirHandler.NewHandler(db)
			kasirH.RegisterRoutes(kasirOwnerRoutes)

			// Merchant order management (accept/prepare/ready)
			merchOrderH := customerHandler.NewRestaurantOrderHandler(db)
			merchOrderRoutes := protected.Group("")
			merchOrderRoutes.Use(middleware.RoleMiddleware("merchant"))
			merchOrderH.RegisterRoutes(merchOrderRoutes)

			// Customer order routes
			custH := customerHandler.NewHandler(db)
			custRoutes := protected.Group("")
			custRoutes.Use(middleware.RoleMiddleware("customer"))
			custH.RegisterRoutes(custRoutes)
			supportH.RegisterCustomerRoutes(custRoutes)

			// Driver order routes
			driverOrderH := customerHandler.NewDriverOrderHandler(db)
			driverRoutes := protected.Group("")
			driverRoutes.Use(middleware.RoleMiddleware("driver"))
			driverOrderH.RegisterRoutes(driverRoutes)

			// Payment (webhook public, create needs customer auth)
			payH := paymentHandler.NewHandler(db, cfg)
			payH.RegisterRoutes(v1, custRoutes, cfg.Server.Mode == "debug")

			// Wallet — driver & merchant
			wH := walletHandler.NewHandler(db, cfg)
			wH.RegisterDriverRoutes(driverRoutes)
			wH.RegisterMerchantRoutes(merchOwnerRoutes)
		}
	}

	// Start server
	addr := fmt.Sprintf(":%s", cfg.Server.Port)
	log.Printf("📦 KUWRIR API server starting on %s", addr)
	if err := r.Run(addr); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

// seedSettings inserts default configurable settings if they don't exist
func seedSettings(db *gorm.DB) {
	defaults := []model.SystemSetting{
		// Platform service fee on products (Wakalah/Ujrah — disclosed to merchant, visible in breakdown)
		{Key: "platform_markup_percentage", Value: "15", Label: "Platform Service Fee / Ujrah on Products (%)"},
		// How the product markup is applied to the customer-facing catalog price.
		{Key: "product_markup_mode", Value: "percentage", Label: "Product Markup Mode (percentage|fixed)"},
		{Key: "product_markup_fixed_amount", Value: "1000", Label: "Fixed Markup Amount per Product (IDR, used when mode=fixed)"},
		// Delivery split
		{Key: "delivery_commission_percentage", Value: "20", Label: "Platform Commission on Delivery Fee (%)"},
		{Key: "app_service_fee_percentage", Value: "5", Label: "App Tech Fee on Delivery (%)"},
		// Self-deliver: merchant keeps delivery fee minus this commission
		{Key: "self_deliver_commission_percentage", Value: "10", Label: "Self-Deliver Commission for Platform (%)"},
		// Zone fallback fees (used when no DeliveryZone matches)
		{Key: "delivery_base_fee_inside_zone", Value: "15000", Label: "Default Inside Zone Delivery Fee (IDR)"},
		{Key: "delivery_fee_per_km_outside", Value: "10000", Label: "Default Outside Zone Fee Per KM (IDR)"},
		{Key: "service_delivery_fee_round_trip", Value: "20000", Label: "Service Round-Trip Delivery Fee (IDR)"},
		// Tax
		{Key: "tax_percentage", Value: "11", Label: "Tax/PPN Percentage (%)"},
		// Order guardrails
		{Key: "min_order_amount", Value: "0", Label: "Minimum Order Amount (IDR, 0 = no minimum)"},
		{Key: "max_cod_amount", Value: "500000", Label: "Maximum COD Order Amount (IDR)"},
	}

	for _, setting := range defaults {
		db.Where("key = ?", setting.Key).FirstOrCreate(&setting)
	}
}

// seedDeliveryZones creates the default delivery zone if none exist.
// Admin can update zone details via the admin panel.
// seedAdminUser creates the default admin account if none exists.
// Credentials from ADMIN_PHONE / ADMIN_PASSWORD env vars (defaults: 08000000000 / admin123).
func seedAdminUser(db *gorm.DB) {
	var count int64
	db.Model(&model.User{}).Where("role = ?", model.RoleAdmin).Count(&count)
	if count > 0 {
		return
	}
	phone := os.Getenv("ADMIN_PHONE")
	if phone == "" {
		phone = "08000000000"
	}
	password := os.Getenv("ADMIN_PASSWORD")
	if password == "" {
		password = "admin123"
	}
	hashed, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("seedAdminUser: failed to hash password: %v", err)
		return
	}
	admin := model.User{
		Name:     "Admin",
		Phone:    phone,
		Password: string(hashed),
		Role:     model.RoleAdmin,
		IsActive: true,
	}
	if err := db.Create(&admin).Error; err != nil {
		log.Printf("seedAdminUser: failed to create admin: %v", err)
		return
	}
	log.Printf("Admin user created — phone: %s", phone)
}

func seedDeliveryZones(db *gorm.DB) {
	var count int64
	db.Model(&model.DeliveryZone{}).Count(&count)
	if count > 0 {
		return
	}
	db.Create(&model.DeliveryZone{
		CityName:  "Default Zone",
		Latitude:  0,
		Longitude: 0,
		RadiusKm:  50,
		BaseFee:   15000,
		PerKmFee:  5000,
		IsDefault: true,
		IsActive:  true,
	})
}
