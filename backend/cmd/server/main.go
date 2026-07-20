package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

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
	"github.com/kuwrir-platform/backend/internal/legal"
	merchantHandler "github.com/kuwrir-platform/backend/internal/handler/merchant"
	paymentHandler "github.com/kuwrir-platform/backend/internal/handler/payment"
	serviceHandler "github.com/kuwrir-platform/backend/internal/handler/service"
	supportHandler "github.com/kuwrir-platform/backend/internal/handler/support"
	bankaccountHandler "github.com/kuwrir-platform/backend/internal/handler/bankaccount"
	customerwalletHandler "github.com/kuwrir-platform/backend/internal/handler/customerwallet"
	walletHandler "github.com/kuwrir-platform/backend/internal/handler/wallet"
	"github.com/kuwrir-platform/backend/internal/middleware"
	"github.com/kuwrir-platform/backend/internal/model"
	"github.com/kuwrir-platform/backend/internal/upload"
)

func main() {
	// Load .env file if present (dev convenience; prod uses real env vars)
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using system environment variables")
	}

	// Load config
	cfg := config.Load()

	// Uploads go to R2 when credentials are configured, else local disk —
	// see internal/upload's package doc for the fallback shape.
	upload.Init(cfg.R2)

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
		&model.UserRole{},
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
		&model.BankAccount{},
		&model.WalletTopupRequest{},
		// Delivery zones (city reference points for pricing)
		&model.DeliveryZone{},
		// Refund requests
		&model.RefundRequest{},
		// In-order chat messages
		&model.ChatMessage{},
		// Customer ↔ Admin support chat
		&model.SupportMessage{},
		// Audit trail
		&model.AuditLog{},
	); err != nil {
		log.Fatalf("Failed to migrate database: %v", err)
	}

	// Backfill user_roles for accounts created before multi-role support:
	// every existing user gets a row for their current primary Role so
	// role-membership checks (h.userHasRole) work uniformly for old and new
	// accounts. Idempotent — the unique index on (user_id, role) makes the
	// insert a no-op on repeat runs.
	db.Exec(`
		INSERT INTO user_roles (id, created_at, updated_at, user_id, role)
		SELECT gen_random_uuid(), now(), now(), u.id, u.role
		FROM users u
		WHERE NOT EXISTS (
			SELECT 1 FROM user_roles ur WHERE ur.user_id = u.id AND ur.role = u.role
		)
	`)

	normalizeLegacyPhones(db)

	// AutoMigrate's ADD COLUMN for admin_tier (added after this table
	// already had rows) leaves existing rows NULL, not "" — and scanning a
	// NULL SQL value into a plain Go string field errors ("converting NULL
	// to string is unsupported"), which would break every query that loads
	// a User row with a NULL admin_tier (login, admin list, phone-conflict
	// checks, ...). Backfill to "" so those rows scan cleanly; "" is
	// already the documented default meaning ("legacy admin, treated as
	// superadmin" — see middleware.SuperadminOnlyMiddleware).
	db.Exec(`UPDATE users SET admin_tier = '' WHERE admin_tier IS NULL`)

	// Google Sign-In was removed — its unique-indexed column has no
	// remaining application use and would otherwise sit dead in the schema.
	db.Exec(`ALTER TABLE users DROP COLUMN IF EXISTS google_id`)

	// Initialize Firebase Admin SDK for push notifications
	service.InitFCM()

	// Seed default system settings and delivery zones
	seedSettings(db)
	seedDeliveryZones(db)
	seedAdminUser(db)

	// Audit log retention: keep a rolling 30 days live, back the full set
	// up to R2 once a month before anything ages out. No cron library in
	// this backend — a daily ticker is simple enough for a once-a-day job.
	go runAuditLogMaintenance(db)

	// Auto-cancel + refund paid online orders the merchant never
	// accepted/rejected within their confirmation SLA.
	go service.RunOrderSLASweeper(db)

	// Resolve withdrawals Duitku left in "processing" (no disbursement
	// webhook exists — see service.RunWithdrawalReconciliation).
	go service.RunWithdrawalReconciliation(db, cfg)

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
		adminH := adminHandler.NewHandler(db, cfg)
		v1.GET("/promotions/active", adminH.PublicActivePromotions)
		v1.GET("/banners/active", adminH.PublicActiveBanners)
		v1.GET("/legal/customer-terms", getCustomerTerms(db))

		// Protected routes (auth required)
		protected := v1.Group("")
		protected.Use(middleware.AuthMiddleware(cfg.JWT.Secret))
		// Audit trail for every mutating request from any authenticated
		// role/app — see middleware.AuditLogMiddleware's doc comment.
		protected.Use(middleware.AuditLogMiddleware(db))
		{
			// Support chat handler (used in both admin and customer sections)
			supportH := supportHandler.NewHandler(db)

			// Admin routes
			adminRoutes := protected.Group("/admin")
			adminRoutes.Use(middleware.RoleMiddleware("admin"))
			adminRoutes.Use(middleware.AdminTierMiddleware())
			{
				adminH.RegisterRoutes(adminRoutes)
				supportH.RegisterAdminRoutes(adminRoutes)
			}

			// Admin-account management — superadmin only.
			superadminRoutes := protected.Group("/admin")
			superadminRoutes.Use(middleware.RoleMiddleware("admin"))
			superadminRoutes.Use(middleware.SuperadminOnlyMiddleware())
			adminH.RegisterSuperadminRoutes(superadminRoutes)

			// Customer/driver/merchant account deletion — root superadmin only.
			rootSuperadminRoutes := protected.Group("/admin")
			rootSuperadminRoutes.Use(middleware.RoleMiddleware("admin"))
			rootSuperadminRoutes.Use(adminH.RequireRootSuperadmin())
			adminH.RegisterRootSuperadminRoutes(rootSuperadminRoutes)

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

			// Wallet — customer (balance, transactions, withdraw, top-up)
			custWalletH := customerwalletHandler.NewHandler(db, cfg)
			custWalletH.RegisterRoutes(custRoutes)

			// Saved bank account (payout destination) — role-agnostic, so
			// registered once on `protected` (any authenticated role)
			// instead of per role-specific group, which would try to
			// register the same literal path multiple times and panic.
			bankH := bankaccountHandler.NewHandler(db)
			bankH.RegisterRoutes(protected)
		}
	}

	// Start server
	addr := fmt.Sprintf(":%s", cfg.Server.Port)
	log.Printf("📦 KUWRIR API server starting on %s", addr)
	if err := r.Run(addr); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

// normalizeLegacyPhones canonicalizes phone numbers stored before
// auth.NormalizePhone existed (e.g. "081234..." instead of "+6281234...")
// so they keep matching after every auth endpoint started normalizing
// incoming numbers before lookup. Idempotent — already-canonical numbers
// are skipped.
func normalizeLegacyPhones(db *gorm.DB) {
	var users []model.User
	if err := db.Select("id", "phone").Find(&users).Error; err != nil {
		log.Printf("normalizeLegacyPhones: failed to load users: %v", err)
		return
	}
	for _, u := range users {
		normalized := authHandler.NormalizePhone(u.Phone)
		if normalized == u.Phone {
			continue
		}
		if err := db.Model(&model.User{}).Where("id = ?", u.ID).Update("phone", normalized).Error; err != nil {
			log.Printf("normalizeLegacyPhones: failed to update user %s: %v", u.ID, err)
		}
	}
}

// getCustomerTerms renders the customer Syarat & Ketentuan with the
// admin-configured support contact (support_whatsapp/support_email/support_hours
// SystemSetting rows) filled in — public, no auth, so it can be shown before
// registration and linked from the landing page.
func getCustomerTerms(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		settingValue := func(key string) string {
			var s model.SystemSetting
			db.Where("key = ?", key).First(&s)
			return s.Value
		}
		content := legal.RenderCustomerTerms(legal.ContactInfo{
			WhatsApp: settingValue("support_whatsapp"),
			Email:    settingValue("support_email"),
			Hours:    settingValue("support_hours"),
		})
		c.JSON(http.StatusOK, gin.H{"content": content, "version": legal.CurrentVersion})
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
		// Customer support contact — shown in Syarat & Ketentuan and app support screens
		{Key: "support_whatsapp", Value: "", Label: "Nomor WhatsApp CS (mis. +6281234567890)"},
		{Key: "support_email", Value: "", Label: "Email CS Resmi"},
		{Key: "support_hours", Value: "Setiap hari, 08.00–21.00 WIB", Label: "Jam Layanan CS"},
		// Duitku payment gateway — blank means "use env var default" (see
		// service.LoadDuitkuClient). Set here to override without a redeploy.
		{Key: "duitku_merchant_code", Value: "", Label: "Duitku Merchant Code"},
		{Key: "duitku_api_key", Value: "", Label: "Duitku API Key"},
		{Key: "duitku_base_url", Value: "", Label: "Duitku Base URL (kosongkan untuk default sandbox)"},
		{Key: "duitku_callback_url", Value: "", Label: "Duitku Callback URL"},
		{Key: "duitku_return_url", Value: "", Label: "Duitku Return URL"},
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
	// Stored normalized so it matches what Login normalizes incoming
	// phone numbers to before lookup — otherwise this seeded admin
	// couldn't log in until the next restart's legacy-phone backfill ran.
	phone = authHandler.NormalizePhone(phone)
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
		Name:      "Admin",
		Phone:     phone,
		Password:  string(hashed),
		Role:      model.RoleAdmin,
		AdminTier: model.AdminTierSuperadmin,
		IsActive:  true,
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

const auditLogRetentionDays = 30

// auditLogLastBackupSettingKey stores the "YYYY-MM" of the last month a
// backup was successfully uploaded, so backupAuditLogsIfDue only runs once
// per calendar month regardless of how many times the daily tick fires.
const auditLogLastBackupSettingKey = "audit_log_last_backup_month"

// runAuditLogMaintenance is a long-running background loop (call with
// `go`): once a day it purges audit_logs rows older than
// auditLogRetentionDays, and — the first time it runs in a new calendar
// month — exports everything still in the table to R2 before that
// purge would otherwise start eating into it. Runs once immediately on
// startup too, so a server that's restarted daily (or was down across a
// purge window) doesn't silently skip maintenance.
func runAuditLogMaintenance(db *gorm.DB) {
	maintain := func() {
		backupAuditLogsIfDue(db)
		purgeOldAuditLogs(db)
	}
	maintain()
	ticker := time.NewTicker(24 * time.Hour)
	for range ticker.C {
		maintain()
	}
}

func purgeOldAuditLogs(db *gorm.DB) {
	cutoff := time.Now().AddDate(0, 0, -auditLogRetentionDays)
	result := db.Where("created_at < ?", cutoff).Delete(&model.AuditLog{})
	if result.Error != nil {
		log.Printf("purgeOldAuditLogs: %v", result.Error)
		return
	}
	if result.RowsAffected > 0 {
		log.Printf("purgeOldAuditLogs: removed %d rows older than %s", result.RowsAffected, cutoff.Format("2006-01-02"))
	}
}

// backupAuditLogsIfDue exports every audit_logs row currently in the table
// (up to auditLogRetentionDays of history) to a JSON file uploaded to R2,
// once per calendar month. Skips silently (retrying on the next daily
// tick) if R2 isn't configured or the upload fails — this is a
// best-effort archival step, not something that should crash the server.
func backupAuditLogsIfDue(db *gorm.DB) {
	thisMonth := time.Now().Format("2006-01")

	var setting model.SystemSetting
	if db.Where("key = ?", auditLogLastBackupSettingKey).First(&setting).Error == nil && setting.Value == thisMonth {
		return
	}

	var logs []model.AuditLog
	if err := db.Order("created_at ASC").Find(&logs).Error; err != nil {
		log.Printf("backupAuditLogsIfDue: failed to load logs: %v", err)
		return
	}

	data, err := json.Marshal(logs)
	if err != nil {
		log.Printf("backupAuditLogsIfDue: failed to marshal logs: %v", err)
		return
	}

	filename := fmt.Sprintf("audit-log-%s.json", thisMonth)
	url, err := upload.SaveBytes(data, "audit-backups", filename, "application/json")
	if err != nil {
		log.Printf("backupAuditLogsIfDue: upload failed (will retry next tick): %v", err)
		return
	}

	result := db.Model(&model.SystemSetting{}).Where("key = ?", auditLogLastBackupSettingKey).Update("value", thisMonth)
	if result.RowsAffected == 0 {
		db.Create(&model.SystemSetting{
			Key:   auditLogLastBackupSettingKey,
			Value: thisMonth,
			Label: "Audit log: bulan backup terakhir",
		})
	}
	log.Printf("backupAuditLogsIfDue: backed up %d rows to %s", len(logs), url)
}
