// Package driverreg handles driver registration, document upload, and admin review.
// Upload URLs are local placeholders (./uploads/) — swap upload.Save() for R2 later.
package driverreg

import (
	"fmt"
	"mime/multipart"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/legal"
	"github.com/kuwrir-platform/backend/internal/model"
	"github.com/kuwrir-platform/backend/internal/upload"
)

type Handler struct {
	db *gorm.DB
}

func NewHandler(db *gorm.DB) *Handler {
	return &Handler{db: db}
}

func (h *Handler) RegisterPublicRoutes(_ *gin.RouterGroup) {}

// RegisterProtectedRoutes mounts driver-role routes
func (h *Handler) RegisterProtectedRoutes(r *gin.RouterGroup) {
	r.POST("/driver/apply", h.SubmitApplication)
	r.GET("/driver/application", h.GetApplicationStatus)
	r.GET("/driver/agreement/preview", h.PreviewAgreement)
	r.POST("/driver/agreement/accept", h.AcceptAgreement)
}

// ─── Driver application endpoints ────────────────────────────────────────────

// SubmitApplication accepts multipart/form-data with vehicle info + 5 document files.
// Creates or replaces the driver's pending application.
//
// Form fields:
//
//	vehicle_type, vehicle_plate, vehicle_year, vehicle_color, vehicle_brand
//	ktp          (file) — foto KTP
//	sim          (file) — foto SIM C/A
//	stnk         (file) — foto STNK
//	selfie       (file) — foto wajah / selfie
//	vehicle_photo (file) — foto kendaraan
func (h *Handler) SubmitApplication(c *gin.Context) {
	userID := c.GetString("user_id")

	if err := c.Request.ParseMultipartForm(20 << 20); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid multipart form"})
		return
	}

	vehicleType := c.PostForm("vehicle_type")
	vehiclePlate := c.PostForm("vehicle_plate")
	if vehicleType == "" || vehiclePlate == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "vehicle_type and vehicle_plate are required"})
		return
	}

	// Save uploaded documents to ./uploads/driver-docs/ (placeholder for R2)
	folder := "driver-docs"
	ktpURL := upload.MustSave(getFormFile(c, "ktp"), folder)
	simURL := upload.MustSave(getFormFile(c, "sim"), folder)
	stnkURL := upload.MustSave(getFormFile(c, "stnk"), folder)
	selfieURL := upload.MustSave(getFormFile(c, "selfie"), folder)
	vehiclePhotoURL := upload.MustSave(getFormFile(c, "vehicle_photo"), folder)

	uid, _ := uuid.Parse(userID)

	vehicleYear := 0
	fmt.Sscanf(c.PostForm("vehicle_year"), "%d", &vehicleYear)

	// Upsert: one application per driver
	var existing model.DriverApplication
	isNew := h.db.Where("user_id = ?", uid).First(&existing).Error != nil

	if isNew {
		app := model.DriverApplication{
			UserID:          uid,
			VehicleType:     vehicleType,
			VehiclePlate:    vehiclePlate,
			VehicleYear:     vehicleYear,
			VehicleColor:    c.PostForm("vehicle_color"),
			VehicleBrand:    c.PostForm("vehicle_brand"),
			NIK:             c.PostForm("nik"),
			LicenseNumber:   c.PostForm("license_number"),
			Address:         c.PostForm("address"),
			KtpURL:          ktpURL,
			SimURL:          simURL,
			StnkURL:         stnkURL,
			SelfieURL:       selfieURL,
			VehiclePhotoURL: vehiclePhotoURL,
			Status:          "pending",
		}
		if err := h.db.Create(&app).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create application"})
			return
		}
		c.JSON(http.StatusCreated, gin.H{
			"application": app,
			"message":     "Application submitted. Admin will review within 1-2 business days.",
		})
		return
	}

	// Re-submission: update fields, keep old doc URLs if no new file provided
	updates := map[string]interface{}{
		"vehicle_type":   vehicleType,
		"vehicle_plate":  vehiclePlate,
		"vehicle_year":   vehicleYear,
		"vehicle_color":  c.PostForm("vehicle_color"),
		"vehicle_brand":  c.PostForm("vehicle_brand"),
		"nik":            c.PostForm("nik"),
		"license_number": c.PostForm("license_number"),
		"address":        c.PostForm("address"),
		"status":         "pending",
		"review_note":    "",
		"reviewed_by_id": nil,
		"reviewed_at":    nil,
	}
	if ktpURL != "" {
		updates["ktp_url"] = ktpURL
	}
	if simURL != "" {
		updates["sim_url"] = simURL
	}
	if stnkURL != "" {
		updates["stnk_url"] = stnkURL
	}
	if selfieURL != "" {
		updates["selfie_url"] = selfieURL
	}
	if vehiclePhotoURL != "" {
		updates["vehicle_photo_url"] = vehiclePhotoURL
	}
	h.db.Model(&existing).Updates(updates)

	c.JSON(http.StatusOK, gin.H{
		"application": existing,
		"message":     "Application re-submitted. Admin will review shortly.",
	})
}

// GetApplicationStatus returns the current driver's application, is_active
// flag, and (once approved — see Driver row existing) their rating/delivery
// stats, so driver_app's stats screen can reuse this one call instead of a
// dedicated endpoint.
func (h *Handler) GetApplicationStatus(c *gin.Context) {
	userID := c.GetString("user_id")

	var app model.DriverApplication
	if h.db.Where("user_id = ?", userID).First(&app).Error != nil {
		c.JSON(http.StatusOK, gin.H{
			"status":  "no_application",
			"message": "No application found. Please submit your documents.",
		})
		return
	}

	var user model.User
	h.db.First(&user, "id = ?", userID)

	resp := gin.H{
		"application": app,
		"is_active":   user.IsActive,
	}
	var driver model.Driver
	if h.db.Where("user_id = ?", userID).First(&driver).Error == nil {
		resp["rating"] = driver.Rating
		resp["total_delivered"] = driver.TotalDelivered
		resp["total_reviews"] = driver.TotalReviews
	}

	c.JSON(http.StatusOK, resp)
}

// PreviewAgreement renders the partnership agreement with the driver's own
// application data filled in, so the app can show it before the final
// "Saya Menyetujui" step.
func (h *Handler) PreviewAgreement(c *gin.Context) {
	userID := c.GetString("user_id")

	var app model.DriverApplication
	if h.db.Where("user_id = ?", userID).First(&app).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Lengkapi data kendaraan & dokumen terlebih dahulu"})
		return
	}
	var user model.User
	h.db.Select("name", "phone").First(&user, "id = ?", userID)

	content := legal.RenderDriverAgreement(legal.DriverSignerData{
		FullName:     user.Name,
		NIK:          app.NIK,
		LicenseNo:    app.LicenseNumber,
		VehiclePlate: app.VehiclePlate,
		Phone:        user.Phone,
		Address:      app.Address,
	})
	c.JSON(http.StatusOK, gin.H{"content": content, "version": legal.CurrentVersion})
}

// AcceptAgreement records the driver's consent to the partnership agreement,
// snapshotting the exact rendered text so admin can review precisely what
// was agreed even if the template is edited later.
func (h *Handler) AcceptAgreement(c *gin.Context) {
	userID := c.GetString("user_id")

	var app model.DriverApplication
	if h.db.Where("user_id = ?", userID).First(&app).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Lengkapi data kendaraan & dokumen terlebih dahulu"})
		return
	}
	var user model.User
	h.db.Select("id", "name", "phone").First(&user, "id = ?", userID)

	content := legal.RenderDriverAgreement(legal.DriverSignerData{
		FullName:     user.Name,
		NIK:          app.NIK,
		LicenseNo:    app.LicenseNumber,
		VehiclePlate: app.VehiclePlate,
		Phone:        user.Phone,
		Address:      app.Address,
	})
	now := time.Now()
	h.db.Model(&app).Updates(map[string]interface{}{
		"agreement_accepted_at": now,
		"agreement_version":     legal.CurrentVersion,
		"agreement_snapshot":    content,
	})
	if app.NIK != "" {
		h.db.Model(&model.User{}).Where("id = ?", userID).Update("nik", app.NIK)
	}
	c.JSON(http.StatusOK, gin.H{"message": "Persetujuan tersimpan", "accepted_at": now})
}

// ─── Admin review handlers (registered via admin handler) ────────────────────

// ListDriverApplications returns driver applications filtered by status.
func ListDriverApplications(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		status := c.DefaultQuery("status", "pending")
		var apps []model.DriverApplication
		q := db.Preload("User")
		if status != "all" {
			q = q.Where("status = ?", status)
		}
		q.Order("created_at ASC").Find(&apps)
		c.JSON(http.StatusOK, gin.H{"applications": apps})
	}
}

// ReviewDriverApplication approves or rejects a driver application.
// On approval: activates the user and creates a Driver record.
func ReviewDriverApplication(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.Param("id")
		adminID := c.GetString("user_id")

		var req struct {
			Action string `json:"action" binding:"required,oneof=approve reject"`
			Note   string `json:"note"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		var app model.DriverApplication
		if db.Preload("User").First(&app, "id = ?", id).Error != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Application not found"})
			return
		}
		if app.Status != "pending" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Application already reviewed"})
			return
		}

		adminUID, _ := uuid.Parse(adminID)
		now := time.Now()
		newStatus := req.Action + "d" // "approved" | "rejected"

		tx := db.Begin()

		tx.Model(&app).Updates(map[string]interface{}{
			"status":         newStatus,
			"review_note":    req.Note,
			"reviewed_by_id": adminUID,
			"reviewed_at":    now,
		})

		if req.Action == "approve" {
			tx.Model(&model.User{}).Where("id = ?", app.UserID).Update("is_active", true)

			// Create Driver record if not yet exists
			var existing model.Driver
			if tx.Where("user_id = ?", app.UserID).First(&existing).Error != nil {
				driver := model.Driver{
					UserID:              app.UserID,
					VehicleType:         app.VehicleType,
					VehiclePlate:        app.VehiclePlate,
					LicenseNumber:       app.LicenseNumber,
					Address:             app.Address,
					IsOnline:            false,
					IsAvailable:         true,
					Rating:              5.0,
					AgreementAcceptedAt: app.AgreementAcceptedAt,
					AgreementVersion:    app.AgreementVersion,
					AgreementSnapshot:   app.AgreementSnapshot,
				}
				tx.Create(&driver)
			}
			if app.NIK != "" {
				tx.Model(&model.User{}).Where("id = ?", app.UserID).Update("nik", app.NIK)
			}
		}

		if err := tx.Commit().Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to review application"})
			return
		}

		msg := "Driver approved. Account is now active."
		if req.Action == "reject" {
			msg = "Driver application rejected."
		}
		c.JSON(http.StatusOK, gin.H{"message": msg, "status": newStatus})
	}
}

// ─── helpers ─────────────────────────────────────────────────────────────────

func getFormFile(c *gin.Context, field string) *multipart.FileHeader {
	fh, _ := c.FormFile(field)
	return fh
}
