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

	hashedPassword, _ := bcrypt.GenerateFromPassword([]byte("admin123"), bcrypt.DefaultCost)

	admin := model.User{
		Name:     "Super Admin",
		Email:    "admin@kuwrir.com",
		Phone:    "080000000000",
		Password: string(hashedPassword),
		Role:     "admin",
		IsActive: true,
	}

	if err := db.Where("phone = ?", admin.Phone).FirstOrCreate(&admin).Error; err != nil {
		log.Fatalf("Failed to seed admin: %v", err)
	}

	fmt.Println("Admin user seeded successfully. Phone: 080000000000, Password: admin123")
}
