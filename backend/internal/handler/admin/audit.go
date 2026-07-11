package admin

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/kuwrir-platform/backend/internal/model"
)

// GetAuditLogs lists recent audit trail entries (see model.AuditLog and
// middleware.AuditLogMiddleware, which is what actually writes these rows).
// Only the last 30 days ever exist in this table — see cmd/server's
// purgeOldAuditLogs — so no date-range filtering is needed here beyond
// what's already in the table. Supports optional filtering by actor role
// and a simple page/limit for pagination.
func (h *Handler) GetAuditLogs(c *gin.Context) {
	limit, err := strconv.Atoi(c.DefaultQuery("limit", "50"))
	if err != nil || limit <= 0 || limit > 200 {
		limit = 50
	}
	page, err := strconv.Atoi(c.DefaultQuery("page", "1"))
	if err != nil || page <= 0 {
		page = 1
	}

	q := h.db.Model(&model.AuditLog{})
	if role := c.Query("role"); role != "" {
		q = q.Where("actor_role = ?", role)
	}
	if actorID := c.Query("actor_id"); actorID != "" {
		q = q.Where("actor_id = ?", actorID)
	}

	var total int64
	q.Count(&total)

	var logs []model.AuditLog
	q.Order("created_at DESC").Limit(limit).Offset((page - 1) * limit).Find(&logs)

	c.JSON(http.StatusOK, gin.H{
		"logs":  logs,
		"total": total,
		"page":  page,
		"limit": limit,
	})
}
