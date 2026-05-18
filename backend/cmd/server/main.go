package main

import (
	"fmt"
	"log"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"github.com/kuwrir-platform/backend/internal/config"
	adminHandler "github.com/kuwrir-platform/backend/internal/handler/admin"
	authHandler "github.com/kuwrir-platform/backend/internal/handler/auth"
	customerHandler "github.com/kuwrir-platform/backend/internal/handler/customer"
	merchantHandler "github.com/kuwrir-platform/backend/internal/handler/merchant"
	"github.com/kuwrir-platform/backend/internal/middleware"
	"github.com/kuwrir-platform/backend/internal/model"
)

func main() {
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
		&model.Address{},
		&model.Merchant{},
		&model.ProductCategory{},
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
	); err != nil {
		log.Fatalf("Failed to migrate database: %v", err)
	}

	// Seed default system settings
	seedSettings(db)

	// Setup Gin router
	r := gin.Default()
	r.Use(middleware.CORSMiddleware())

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
		authH := authHandler.NewHandler(db, cfg)
		authH.RegisterRoutes(v1)

		// Merchant handler (has both public and protected routes)
		merchH := merchantHandler.NewHandler(db)

		// Public merchant browsing (no auth)
		// merchH.RegisterRoutes(v1, protected) // Will call below after protected group is created

		// Protected routes (auth required)
		protected := v1.Group("")
		protected.Use(middleware.AuthMiddleware(cfg.JWT.Secret))
		{
			// Admin routes
			adminRoutes := protected.Group("/admin")
			adminRoutes.Use(middleware.RoleMiddleware("admin"))
			{
				adminH := adminHandler.NewHandler(db)
				adminH.RegisterRoutes(adminRoutes)
			}

			// Merchant owner routes (auth required)
			merchOwnerRoutes := protected.Group("")
			merchOwnerRoutes.Use(middleware.RoleMiddleware("merchant"))
			merchH.RegisterRoutes(v1, merchOwnerRoutes)

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

			// Driver order routes
			driverOrderH := customerHandler.NewDriverOrderHandler(db)
			driverRoutes := protected.Group("")
			driverRoutes.Use(middleware.RoleMiddleware("driver"))
			driverOrderH.RegisterRoutes(driverRoutes)
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
		{Key: "platform_markup_percentage", Value: "15", Label: "Platform Markup Percentage (%)"},
		{Key: "delivery_commission_percentage", Value: "25", Label: "Delivery Commission Percentage (%)"},
		{Key: "delivery_base_fee_inside_zone", Value: "15000", Label: "Inside Zone Delivery Fee (IDR)"},
		{Key: "delivery_fee_per_km_outside", Value: "10000", Label: "Outside Zone Fee Per KM (IDR)"},
	}

	for _, setting := range defaults {
		db.Where("key = ?", setting.Key).FirstOrCreate(&setting)
	}
}
