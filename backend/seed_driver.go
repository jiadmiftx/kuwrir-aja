package main

import (
	"fmt"
	"log"

	"github.com/kuwrir-platform/backend/internal/model"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func main() {
	dsn := "host=localhost user=kuwrir password=kuwrir_secret dbname=kuwrir_db port=5432 sslmode=disable TimeZone=Asia/Jakarta"
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	hashedPassword, _ := bcrypt.GenerateFromPassword([]byte("driver123"), bcrypt.DefaultCost)

	// Create driver user
	driver := model.User{
		Name:     "Pak Anto Driver",
		Email:    "driver@kuwrir.com",
		Phone:    "081111111111",
		Password: string(hashedPassword),
		Role:     "driver",
		IsActive: true,
	}
	if err := db.Where("phone = ?", driver.Phone).FirstOrCreate(&driver).Error; err != nil {
		log.Fatalf("Failed to seed driver user: %v", err)
	}

	// Create driver profile
	driverProfile := model.Driver{
		UserID:       driver.ID,
		VehicleType:  "motorcycle",
		VehiclePlate: "DR 1234 AB",
		IsOnline:     true,
		IsAvailable:  true,
	}
	if err := db.Where("user_id = ?", driver.ID).FirstOrCreate(&driverProfile).Error; err != nil {
		log.Fatalf("Failed to seed driver profile: %v", err)
	}

	// Also seed a merchant user for testing
	hashedPassword2, _ := bcrypt.GenerateFromPassword([]byte("merchant123"), bcrypt.DefaultCost)
	merchant := model.User{
		Name:     "Bu Eka Warung",
		Email:    "merchant@kuwrir.com",
		Phone:    "082222222222",
		Password: string(hashedPassword2),
		Role:     "merchant",
		IsActive: true,
	}
	if err := db.Where("phone = ?", merchant.Phone).FirstOrCreate(&merchant).Error; err != nil {
		log.Fatalf("Failed to seed merchant user: %v", err)
	}

	// Also seed a customer user for testing
	hashedPassword3, _ := bcrypt.GenerateFromPassword([]byte("customer123"), bcrypt.DefaultCost)
	customer := model.User{
		Name:     "John Tourist",
		Email:    "customer@kuwrir.com",
		Phone:    "083333333333",
		Password: string(hashedPassword3),
		Role:     "customer",
		IsActive: true,
	}
	if err := db.Where("phone = ?", customer.Phone).FirstOrCreate(&customer).Error; err != nil {
		log.Fatalf("Failed to seed customer user: %v", err)
	}

	fmt.Println("✅ All test accounts seeded successfully!")
	fmt.Println("")
	fmt.Println("📱 Driver App:     081111111111 / driver123")
	fmt.Println("🏪 Restaurant App: 082222222222 / merchant123")
	fmt.Println("👤 Customer App:   083333333333 / customer123")
	fmt.Println("🔧 Admin Panel:    080000000000 / admin123")
}
