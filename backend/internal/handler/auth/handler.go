package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/config"
	"github.com/kuwrir-platform/backend/internal/middleware"
	"github.com/kuwrir-platform/backend/internal/model"
	"github.com/kuwrir-platform/backend/internal/service"
)

type Handler struct {
	db       *gorm.DB
	cfg      *config.Config
	whatsapp service.WhatsAppSender
}

func NewHandler(db *gorm.DB, cfg *config.Config, whatsapp service.WhatsAppSender) *Handler {
	return &Handler{db: db, cfg: cfg, whatsapp: whatsapp}
}

// RegisterRoutes sets up auth routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	auth := r.Group("/auth")
	{
		auth.POST("/register", h.Register)
		auth.POST("/login", h.Login)
		auth.POST("/google", h.GoogleLogin)
		auth.POST("/otp/request", h.RequestOTP)
		auth.POST("/otp/verify", h.VerifyOTP)
		auth.POST("/refresh", h.RefreshToken)
	}

	// Authenticated routes
	authed := r.Group("/auth")
	authed.Use(middleware.AuthMiddleware(h.cfg.JWT.Secret))
	{
		authed.GET("/me", h.GetMe)
		authed.PUT("/device-token", h.SaveDeviceToken)
		authed.POST("/verify-phone", h.VerifyPhone)
	}
}

// --- Request / Response DTOs ---

type RegisterRequest struct {
	Name     string     `json:"name" binding:"required"`
	Email    string     `json:"email" binding:"required,email"`
	Phone    string     `json:"phone" binding:"required"`
	Password string     `json:"password" binding:"required,min=6"`
	Role     model.Role `json:"role" binding:"required,oneof=customer driver merchant"`
}

type LoginRequest struct {
	Phone    string `json:"phone" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type RequestOTPRequest struct {
	Phone string `json:"phone" binding:"required"`
}

type VerifyOTPRequest struct {
	Phone string `json:"phone" binding:"required"`
	Code  string `json:"code" binding:"required"`
}

type AuthResponse struct {
	Token              string     `json:"token"`
	RefreshToken       string     `json:"refresh_token"`
	User               model.User `json:"user"`
	HasMerchantProfile *bool      `json:"has_merchant_profile,omitempty"`
}

// --- Handlers ---

// Register creates a new user account
func (h *Handler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if phone already exists
	var existingUser model.User
	if err := h.db.Where("phone = ?", req.Phone).First(&existingUser).Error; err == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "Phone number already registered"})
		return
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
		return
	}

	// Drivers and merchants start inactive — admin must verify before they can use the platform
	isActive := req.Role == model.RoleCustomer

	user := model.User{
		Name:     req.Name,
		Email:    req.Email,
		Phone:    req.Phone,
		Password: string(hashedPassword),
		Role:     req.Role,
		IsActive: isActive,
	}

	if err := h.db.Create(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
		return
	}

	token, refreshToken, err := h.generateTokens(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	// Drivers and merchants get a token too — needed to submit their
	// application/store documents — but the account stays inactive
	// (and login is blocked) until an admin approves it.
	if req.Role == model.RoleDriver || req.Role == model.RoleMerchant {
		c.JSON(http.StatusCreated, gin.H{
			"user":          user,
			"token":         token,
			"refresh_token": refreshToken,
			"message":       "Account created. Please complete your application and wait for admin verification.",
			"status":        "pending_application",
		})
		return
	}

	c.JSON(http.StatusCreated, AuthResponse{
		Token:        token,
		RefreshToken: refreshToken,
		User:         user,
	})
}

// Login authenticates a user and returns JWT tokens
func (h *Handler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user model.User
	if err := h.db.Where("phone = ?", req.Phone).First(&user).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid phone or password"})
		return
	}

	if !user.IsActive {
		c.JSON(http.StatusForbidden, gin.H{"error": "Account is deactivated"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid phone or password"})
		return
	}

	token, refreshToken, err := h.generateTokens(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	c.JSON(http.StatusOK, AuthResponse{
		Token:        token,
		RefreshToken: refreshToken,
		User:         user,
	})
}

// GoogleLogin authenticates or registers a user via Google ID token.
// Body: {"id_token": "...", "role": "customer"}
func (h *Handler) GoogleLogin(c *gin.Context) {
	var req struct {
		IDToken string     `json:"id_token" binding:"required"`
		Role    model.Role `json:"role"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if req.Role == "" {
		req.Role = model.RoleCustomer
	}

	// Verify ID token with Google
	info, err := verifyGoogleToken(req.IDToken)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid Google token"})
		return
	}

	// Find existing user by google_id or email
	var user model.User
	err = h.db.Where("google_id = ? OR (email != '' AND email = ?)", info.Sub, info.Email).First(&user).Error
	if err != nil {
		// New user — auto-register
		fakePassword, _ := bcrypt.GenerateFromPassword([]byte(uuid.New().String()), bcrypt.DefaultCost)
		user = model.User{
			Name:      info.Name,
			Email:     info.Email,
			Phone:     "", // Google users may not have phone; they can add later
			Password:  string(fakePassword),
			AvatarURL: info.Picture,
			GoogleID:  &info.Sub,
			Role:      req.Role,
			IsActive:  true,
		}
		// Phone must be unique and not-null — use a placeholder
		user.Phone = "G-" + info.Sub[:10]
		if err := h.db.Create(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create account"})
			return
		}
	} else {
		// Update google_id if linked via email
		if user.GoogleID == nil {
			h.db.Model(&user).Update("google_id", info.Sub)
		}
		if !user.IsActive {
			c.JSON(http.StatusForbidden, gin.H{"error": "Account is deactivated"})
			return
		}
	}

	token, refreshToken, err := h.generateTokens(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	resp := AuthResponse{
		Token:        token,
		RefreshToken: refreshToken,
		User:         user,
	}
	if user.Role == model.RoleMerchant {
		var count int64
		h.db.Model(&model.Merchant{}).Where("user_id = ?", user.ID).Count(&count)
		hasProfile := count > 0
		resp.HasMerchantProfile = &hasProfile
	}

	c.JSON(http.StatusOK, resp)
}

const (
	otpTTL             = 5 * time.Minute
	otpResendCooldown  = 60 * time.Second
	otpMaxPerHour      = 5
	otpMaxVerifyTries  = 5
)

func hashOTP(code string) string {
	sum := sha256.Sum256([]byte(code))
	return hex.EncodeToString(sum[:])
}

// generateOTP returns a random 6-digit numeric code (zero-padded).
func generateOTP() (string, error) {
	max := int64(1000000)
	n, err := rand.Int(rand.Reader, big.NewInt(max))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

// RequestOTP generates and sends a WhatsApp OTP for phone-based login.
// POST /auth/otp/request   Body: {"phone": "..."}
func (h *Handler) RequestOTP(c *gin.Context) {
	var req RequestOTPRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	now := time.Now()

	// Resend cooldown: reject if the most recent unconsumed code for this
	// phone was issued less than otpResendCooldown ago.
	var lastOtp model.OtpCode
	if err := h.db.Where("phone = ? AND consumed_at IS NULL", req.Phone).
		Order("created_at DESC").First(&lastOtp).Error; err == nil {
		if now.Sub(lastOtp.CreatedAt) < otpResendCooldown {
			c.JSON(http.StatusTooManyRequests, gin.H{"error": "Please wait before requesting another code"})
			return
		}
	}

	// Request cap: reject beyond otpMaxPerHour requests/phone/hour.
	var countLastHour int64
	h.db.Model(&model.OtpCode{}).
		Where("phone = ? AND created_at > ?", req.Phone, now.Add(-time.Hour)).
		Count(&countLastHour)
	if countLastHour >= otpMaxPerHour {
		c.JSON(http.StatusTooManyRequests, gin.H{"error": "Too many OTP requests, try again later"})
		return
	}

	code, err := generateOTP()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate code"})
		return
	}

	otp := model.OtpCode{
		Phone:     req.Phone,
		CodeHash:  hashOTP(code),
		ExpiresAt: now.Add(otpTTL),
	}
	if err := h.db.Create(&otp).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create code"})
		return
	}

	if err := h.whatsapp.SendOTP(req.Phone, code); err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Failed to send WhatsApp message"})
		return
	}

	resp := gin.H{"message": "OTP sent"}
	if h.cfg.Server.Mode == "debug" {
		resp["debug_code"] = code
	}
	c.JSON(http.StatusOK, resp)
}

// validateAndConsumeOTP checks phone's latest unconsumed, unexpired code
// against code, bumping the attempt counter on mismatch and marking it
// consumed on success. Shared by VerifyOTP (login) and VerifyPhone (attach
// a verified phone to an already-authenticated account) so both enforce
// identical expiry/attempt-limit rules. status == 0 means success.
func (h *Handler) validateAndConsumeOTP(phone, code string) (status int, errMsg string) {
	var otp model.OtpCode
	if err := h.db.Where("phone = ? AND consumed_at IS NULL AND expires_at > ?", phone, time.Now()).
		Order("created_at DESC").First(&otp).Error; err != nil {
		return http.StatusBadRequest, "Code expired or not found, request a new one"
	}

	if otp.Attempts >= otpMaxVerifyTries {
		return http.StatusTooManyRequests, "Too many attempts, request a new code"
	}

	if hashOTP(code) != otp.CodeHash {
		h.db.Model(&otp).Update("attempts", otp.Attempts+1)
		return http.StatusUnauthorized, "Invalid code"
	}

	h.db.Model(&otp).Update("consumed_at", time.Now())
	return 0, ""
}

// VerifyOTP checks the code and logs the user in, auto-creating a customer
// account on first successful verify for an unknown phone number (same
// auto-register shape as GoogleLogin above). Marks the phone verified either
// way — a successful OTP check is real proof of ownership.
// POST /auth/otp/verify   Body: {"phone": "...", "code": "..."}
func (h *Handler) VerifyOTP(c *gin.Context) {
	var req VerifyOTPRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if status, msg := h.validateAndConsumeOTP(req.Phone, req.Code); status != 0 {
		c.JSON(status, gin.H{"error": msg})
		return
	}

	now := time.Now()

	var user model.User
	if err := h.db.Where("phone = ?", req.Phone).First(&user).Error; err != nil {
		// Unknown phone — auto-register a bare customer account, same
		// placeholder-password pattern GoogleLogin uses for accounts with
		// no real password.
		fakePassword, _ := bcrypt.GenerateFromPassword([]byte(uuid.New().String()), bcrypt.DefaultCost)
		user = model.User{
			Phone:           req.Phone,
			Password:        string(fakePassword),
			Role:            model.RoleCustomer,
			IsActive:        true,
			PhoneVerifiedAt: &now,
		}
		if err := h.db.Create(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create account"})
			return
		}
	} else if !user.IsActive {
		c.JSON(http.StatusForbidden, gin.H{"error": "Account is deactivated"})
		return
	} else if user.PhoneVerifiedAt == nil {
		h.db.Model(&user).Update("phone_verified_at", now)
		user.PhoneVerifiedAt = &now
	}

	token, refreshToken, err := h.generateTokens(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	c.JSON(http.StatusOK, AuthResponse{
		Token:        token,
		RefreshToken: refreshToken,
		User:         user,
	})
}

// VerifyPhone attaches and verifies a real phone number on the currently
// authenticated account — used by customer_app's mandatory phone-verify
// gate for accounts whose Phone is still GoogleLogin's placeholder
// ("G-..."). Reuses the same OTP validation as VerifyOTP but updates the
// logged-in user's row instead of looking up/creating one by phone.
// POST /auth/verify-phone   Body: {"phone": "...", "code": "..."}   (auth required)
func (h *Handler) VerifyPhone(c *gin.Context) {
	userID := c.GetString("user_id")

	var req VerifyOTPRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if status, msg := h.validateAndConsumeOTP(req.Phone, req.Code); status != 0 {
		c.JSON(status, gin.H{"error": msg})
		return
	}

	var conflicting model.User
	if err := h.db.Where("phone = ? AND id != ?", req.Phone, userID).First(&conflicting).Error; err == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "Nomor ini sudah terdaftar di akun lain"})
		return
	}

	now := time.Now()
	if err := h.db.Model(&model.User{}).Where("id = ?", userID).
		Updates(map[string]interface{}{"phone": req.Phone, "phone_verified_at": now}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update phone"})
		return
	}

	var user model.User
	if err := h.db.Where("id = ?", userID).First(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load account"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"user": user})
}

// SaveDeviceToken stores the FCM device token for push notifications.
// PUT /auth/device-token   Body: {"token": "..."}
func (h *Handler) GetMe(c *gin.Context) {
	userID := c.GetString("user_id")
	var user model.User
	if err := h.db.First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"user": user})
}

func (h *Handler) SaveDeviceToken(c *gin.Context) {
	userID := c.GetString("user_id")
	var req struct {
		Token string `json:"token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.db.Model(&model.User{}).Where("id = ?", userID).Update("fcm_token", req.Token).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Device token saved"})
}

// --- Google token verification ---

type googleTokenInfo struct {
	Sub     string `json:"sub"`
	Email   string `json:"email"`
	Name    string `json:"name"`
	Picture string `json:"picture"`
}

func verifyGoogleToken(idToken string) (*googleTokenInfo, error) {
	resp, err := http.Get("https://oauth2.googleapis.com/tokeninfo?id_token=" + idToken)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("google rejected token: %s", string(body))
	}
	var info googleTokenInfo
	if err := json.Unmarshal(body, &info); err != nil {
		return nil, err
	}
	if info.Sub == "" {
		return nil, fmt.Errorf("invalid token: missing sub")
	}
	return &info, nil
}

// RefreshToken exchanges a still-valid refresh token for a new access +
// refresh token pair (sliding expiration) — as long as a user opens any app
// at least once within JWT_REFRESH_EXPIRY_HOURS, they never have to
// fully re-authenticate via OTP/Google/password. Rejects access tokens
// presented here (TokenType must be "refresh") and deactivated accounts.
// POST /auth/refresh   Body: {"refresh_token": "..."}
func (h *Handler) RefreshToken(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refresh_token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	claims, err := middleware.ParseToken(h.cfg.JWT.Secret, req.RefreshToken)
	if err != nil || claims.TokenType != "refresh" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired refresh token"})
		return
	}

	var user model.User
	if err := h.db.Where("id = ?", claims.UserID).First(&user).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Account not found"})
		return
	}
	if !user.IsActive {
		c.JSON(http.StatusForbidden, gin.H{"error": "Account is deactivated"})
		return
	}

	token, refreshToken, err := h.generateTokens(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	c.JSON(http.StatusOK, AuthResponse{
		Token:        token,
		RefreshToken: refreshToken,
		User:         user,
	})
}

func (h *Handler) generateTokens(user model.User) (string, string, error) {
	// Access token
	claims := &middleware.Claims{
		UserID:    user.ID.String(),
		Role:      string(user.Role),
		TokenType: "access",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(h.cfg.JWT.ExpiryHours) * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			ID:        uuid.New().String(),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(h.cfg.JWT.Secret))
	if err != nil {
		return "", "", fmt.Errorf("failed to sign token: %w", err)
	}

	// Refresh token
	refreshClaims := &middleware.Claims{
		UserID:    user.ID.String(),
		Role:      string(user.Role),
		TokenType: "refresh",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(h.cfg.JWT.RefreshExpiryHours) * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			ID:        uuid.New().String(),
		},
	}

	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshTokenString, err := refreshToken.SignedString([]byte(h.cfg.JWT.Secret))
	if err != nil {
		return "", "", fmt.Errorf("failed to sign refresh token: %w", err)
	}

	return tokenString, refreshTokenString, nil
}
