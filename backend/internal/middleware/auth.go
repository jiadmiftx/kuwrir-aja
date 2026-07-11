package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/model"
)

// Claims represents the JWT token payload. TokenType distinguishes access
// ("access") from refresh ("refresh") tokens so a refresh token can't be
// used to call ordinary authed endpoints and vice versa. Tokens issued
// before this field existed decode with TokenType == "" and are treated as
// access tokens (unchanged behavior) — they're short-lived anyway.
type Claims struct {
	UserID    string `json:"user_id"`
	Role      string `json:"role"`
	// AdminTier only ever has a value when Role == "admin" — see
	// model.User.AdminTier and AdminTierMiddleware.
	AdminTier string `json:"admin_tier,omitempty"`
	TokenType string `json:"token_type,omitempty"`
	jwt.RegisteredClaims
}

// ParseToken validates a JWT's signature and expiry and returns its claims.
// Shared by AuthMiddleware and the /auth/refresh handler so both enforce
// identical validation.
func ParseToken(secret, tokenString string) (*Claims, error) {
	claims := &Claims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte(secret), nil
	})
	if err != nil || !token.Valid {
		if err == nil {
			err = jwt.ErrTokenInvalidClaims
		}
		return nil, err
	}
	return claims, nil
}

// AuthMiddleware validates JWT tokens and injects user claims into context
func AuthMiddleware(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		if tokenString == authHeader {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Bearer token required"})
			return
		}

		claims, err := ParseToken(secret, tokenString)
		if err != nil || claims.TokenType == "refresh" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired token"})
			return
		}

		// Inject user info into context
		c.Set("user_id", claims.UserID)
		c.Set("user_role", claims.Role)
		c.Set("admin_tier", claims.AdminTier)
		c.Next()
	}
}

// RoleMiddleware restricts access to specific roles
func RoleMiddleware(allowedRoles ...string) gin.HandlerFunc {
	return func(c *gin.Context) {
		role, exists := c.Get("user_role")
		if !exists {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "Role not found"})
			return
		}

		roleStr := role.(string)
		for _, allowed := range allowedRoles {
			if roleStr == allowed {
				c.Next()
				return
			}
		}

		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "Insufficient permissions"})
	}
}

// AdminTierMiddleware scopes what an admin-tier account can do beyond the
// base RoleMiddleware("admin") gate (see model.AdminTier* constants):
//   - superadmin: unrestricted.
//   - cs: read-only (GET), plus mutating requests under /admin/support
//     (replying to customers).
//   - developer: read-only (GET) everywhere, incl. /admin/audit-logs.
//   - admin / empty tier (legacy accounts predating tiers): unrestricted,
//     same as today — this middleware only ever narrows access for the
//     three newer tiers, never removes what a plain "admin" already had.
//
// Superadmin-only actions (e.g. managing other admin accounts) are gated
// separately by SuperadminOnlyMiddleware on their own route group, not
// here.
func AdminTierMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		tierVal, _ := c.Get("admin_tier")
		tier, _ := tierVal.(string)

		if tier == "" || tier == "superadmin" || tier == "admin" {
			c.Next()
			return
		}
		if c.Request.Method == http.MethodGet {
			c.Next()
			return
		}
		if tier == "cs" && strings.HasPrefix(c.FullPath(), "/api/v1/admin/support") {
			c.Next()
			return
		}

		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "Tier akun admin ini tidak punya akses untuk aksi ini"})
	}
}

// SuperadminOnlyMiddleware gates the admin-account-management routes —
// only a superadmin can create/edit/deactivate other admin accounts.
func SuperadminOnlyMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		tierVal, _ := c.Get("admin_tier")
		tier, _ := tierVal.(string)
		// Empty tier = a legacy admin account predating tiers; treat as
		// superadmin so the very first bootstrapped admin can still reach
		// this group to start assigning tiers to everyone else.
		if tier == "" || tier == "superadmin" {
			c.Next()
			return
		}
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "Hanya superadmin yang bisa mengelola akun admin"})
	}
}

// AuditLogMiddleware records every mutating (non-GET) authenticated
// request — actor, method, path, response status, IP — to the audit_logs
// table, regardless of which app or role made it. Mounted once on the
// shared authenticated route group in cmd/server so coverage is automatic
// for every current and future endpoint, rather than each handler having
// to remember to log itself. The write happens in a goroutine after the
// response so it never adds latency to the request it's logging, and a
// logging failure is silently dropped (this is an audit trail, not a
// critical-path write — never let it break the actual request).
func AuditLogMiddleware(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()

		if c.Request.Method == http.MethodGet {
			return
		}
		userIDVal, ok := c.Get("user_id")
		if !ok {
			return
		}
		userID, err := uuid.Parse(userIDVal.(string))
		if err != nil {
			return
		}
		roleVal, _ := c.Get("user_role")
		role, _ := roleVal.(string)
		path := c.FullPath()
		if path == "" {
			path = c.Request.URL.Path
		}
		status := c.Writer.Status()
		ip := c.ClientIP()

		go func() {
			var name string
			db.Model(&model.User{}).Select("name").Where("id = ?", userID).Scan(&name)
			db.Create(&model.AuditLog{
				ActorID:    userID,
				ActorName:  name,
				ActorRole:  role,
				Method:     c.Request.Method,
				Path:       path,
				StatusCode: status,
				IPAddress:  ip,
			})
		}()
	}
}

// CORSMiddleware handles Cross-Origin Resource Sharing
func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, PATCH, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}
