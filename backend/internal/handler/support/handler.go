package support

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/model"
	"github.com/kuwrir-platform/backend/internal/service"
)

type Handler struct {
	db *gorm.DB
}

func NewHandler(db *gorm.DB) *Handler {
	return &Handler{db: db}
}

func (h *Handler) RegisterCustomerRoutes(r *gin.RouterGroup) {
	r.GET("/support/messages", h.GetMyMessages)
	r.POST("/support/messages", h.SendMessage)
}

func (h *Handler) RegisterAdminRoutes(r *gin.RouterGroup) {
	r.GET("/support/users", h.ListSupportUsers)
	r.GET("/support/users/:userId/messages", h.GetUserMessages)
	r.POST("/support/users/:userId/messages", h.ReplyToUser)
}

// GET /support/messages — customer views their own support thread
func (h *Handler) GetMyMessages(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user"})
		return
	}

	var msgs []model.SupportMessage
	if err := h.db.Where("user_id = ?", userID).
		Order("created_at ASC").Find(&msgs).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load messages"})
		return
	}

	// Mark admin messages as read
	h.db.Model(&model.SupportMessage{}).
		Where("user_id = ? AND sender_role = ? AND is_read = false", userID, "admin").
		Update("is_read", true)

	c.JSON(http.StatusOK, gin.H{"messages": msgs})
}

type sendMsgRequest struct {
	Text string `json:"text" binding:"required"`
}

// POST /support/messages — customer sends a message to admin
func (h *Handler) SendMessage(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user"})
		return
	}

	var req sendMsgRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	msg := model.SupportMessage{
		UserID:     userID,
		SenderRole: "customer",
		Text:       req.Text,
	}
	if err := h.db.Create(&msg).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save message"})
		return
	}

	// Notify all admins via FCM
	var admins []model.User
	h.db.Where("role = ? AND fcm_token != ''", "admin").Find(&admins)
	for _, admin := range admins {
		service.SendToUser(h.db, admin.ID, "Pesan Support Baru", req.Text, map[string]string{
			"type":    "support",
			"user_id": userID.String(),
		})
	}

	c.JSON(http.StatusCreated, gin.H{"message": msg})
}

// GET /admin/support/users — list users who have support messages
func (h *Handler) ListSupportUsers(c *gin.Context) {
	type userRow struct {
		UserID      string `json:"user_id"`
		Name        string `json:"name"`
		Phone       string `json:"phone"`
		UnreadCount int64  `json:"unread_count"`
		LastMessage string `json:"last_message"`
	}

	var rows []userRow
	h.db.Raw(`
		SELECT
			sm.user_id::text,
			u.name,
			u.phone,
			COUNT(CASE WHEN sm.sender_role = 'customer' AND sm.is_read = false THEN 1 END) AS unread_count,
			(SELECT text FROM support_messages WHERE user_id = sm.user_id ORDER BY created_at DESC LIMIT 1) AS last_message
		FROM support_messages sm
		JOIN users u ON u.id = sm.user_id
		GROUP BY sm.user_id, u.name, u.phone
		ORDER BY MAX(sm.created_at) DESC
	`).Scan(&rows)

	c.JSON(http.StatusOK, gin.H{"users": rows})
}

// GET /admin/support/users/:userId/messages
func (h *Handler) GetUserMessages(c *gin.Context) {
	userID, err := uuid.Parse(c.Param("userId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
		return
	}

	var msgs []model.SupportMessage
	if err := h.db.Where("user_id = ?", userID).
		Order("created_at ASC").Find(&msgs).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load messages"})
		return
	}

	// Mark customer messages as read (admin has seen them)
	h.db.Model(&model.SupportMessage{}).
		Where("user_id = ? AND sender_role = ? AND is_read = false", userID, "customer").
		Update("is_read", true)

	c.JSON(http.StatusOK, gin.H{"messages": msgs})
}

// POST /admin/support/users/:userId/messages — admin replies
func (h *Handler) ReplyToUser(c *gin.Context) {
	targetUserID, err := uuid.Parse(c.Param("userId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
		return
	}

	var req sendMsgRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	msg := model.SupportMessage{
		UserID:     targetUserID,
		SenderRole: "admin",
		Text:       req.Text,
	}
	if err := h.db.Create(&msg).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save reply"})
		return
	}

	// Notify customer
	service.SendToUser(h.db, targetUserID, "Balasan dari Admin", req.Text, map[string]string{
		"type": "support_reply",
	})

	c.JSON(http.StatusCreated, gin.H{"message": msg})
}
