package auth

import (
	"fmt"
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
)

type Handler struct {
	db  *gorm.DB
	cfg *config.Config
}

func NewHandler(db *gorm.DB, cfg *config.Config) *Handler {
	return &Handler{db: db, cfg: cfg}
}

// RegisterRoutes sets up auth routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	auth := r.Group("/auth")
	{
		auth.POST("/register", h.Register)
		auth.POST("/login", h.Login)
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

type AuthResponse struct {
	Token        string     `json:"token"`
	RefreshToken string     `json:"refresh_token"`
	User         model.User `json:"user"`
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

	user := model.User{
		Name:     req.Name,
		Email:    req.Email,
		Phone:    req.Phone,
		Password: string(hashedPassword),
		Role:     req.Role,
		IsActive: true,
	}

	if err := h.db.Create(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
		return
	}

	// Generate tokens
	token, refreshToken, err := h.generateTokens(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
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

func (h *Handler) generateTokens(user model.User) (string, string, error) {
	// Access token
	claims := &middleware.Claims{
		UserID: user.ID.String(),
		Role:   string(user.Role),
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
		UserID: user.ID.String(),
		Role:   string(user.Role),
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
