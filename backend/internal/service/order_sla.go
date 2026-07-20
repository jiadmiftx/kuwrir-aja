package service

import (
	"log"
	"time"

	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/model"
)

// RunOrderSLASweeper periodically cancels+refunds paid online orders the
// merchant never responded to within their ConfirmationDeadline. Mirrors
// the ticker pattern used by cmd/server's runAuditLogMaintenance.
func RunOrderSLASweeper(db *gorm.DB) {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		sweepExpiredOrders(db)
	}
}

func sweepExpiredOrders(db *gorm.DB) {
	var expired []model.Order
	if err := db.Where(
		"status = ? AND payment_type != ? AND payment_status = ? AND confirmation_deadline < ?",
		model.OrderStatusPending, "cash", "paid", time.Now(),
	).Find(&expired).Error; err != nil {
		log.Printf("sweepExpiredOrders: query failed: %v", err)
		return
	}

	for i := range expired {
		order := &expired[i]
		reason := "Merchant tidak merespon dalam batas waktu — order dibatalkan otomatis"
		if err := CancelOrderAndRefund(db, order, reason); err != nil {
			log.Printf("sweepExpiredOrders: failed to cancel order %s: %v", order.OrderNumber, err)
			continue
		}
		if order.CustomerID != nil {
			SendToUser(db, *order.CustomerID,
				"Pesanan Dibatalkan Otomatis",
				"Merchant tidak merespon tepat waktu. Dana telah dikembalikan ke wallet kamu.",
				map[string]string{"order_id": order.ID.String(), "type": "order_status"})
		}
	}
}
