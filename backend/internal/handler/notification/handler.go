// Package notification gives any authenticated user (customer, driver, or
// merchant owner) a persisted history of the pushes service.SendToUser has
// sent them — role-agnostic, keyed only off the JWT's user_id, same shape
// as the bankaccount package. Mounted once on the generic `protected` group
// rather than per role-specific group, for the same reason bankaccount is:
// registering the same literal path multiple times would panic.
package notification

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/model"
)

type Handler struct {
	db *gorm.DB
}

func NewHandler(db *gorm.DB) *Handler {
	return &Handler{db: db}
}

func (h *Handler) RegisterRoutes(group *gin.RouterGroup) {
	group.GET("/me/notifications", h.List)
	group.POST("/me/notifications/:id/read", h.MarkRead)
}

func (h *Handler) List(c *gin.Context) {
	userID, err := uuid.Parse(c.GetString("user_id"))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid session"})
		return
	}

	var notifications []model.Notification
	h.db.Where("user_id = ?", userID).
		Order("created_at DESC").Limit(50).Find(&notifications)

	c.JSON(http.StatusOK, gin.H{"notifications": notifications})
}

func (h *Handler) MarkRead(c *gin.Context) {
	userID, err := uuid.Parse(c.GetString("user_id"))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid session"})
		return
	}

	if err := h.db.Model(&model.Notification{}).
		Where("id = ? AND user_id = ?", c.Param("id"), userID).
		Update("is_read", true).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update notification"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Notification marked as read"})
}
