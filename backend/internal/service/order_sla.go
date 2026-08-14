package service

import (
	"fmt"
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
		sweepExpiredModificationRequests(db)
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

// sweepExpiredModificationRequests auto-cancels+refunds any order whose
// item-replacement request (see customer.Handler.RequestItemChange) went
// unresolved past its deadline — the customer never picked a replacement
// or cancelled themselves, so the order can't sit "pending decision"
// forever.
func sweepExpiredModificationRequests(db *gorm.DB) {
	var expired []model.OrderModificationRequest
	if err := db.Where("status = ? AND expires_at < ?", "pending", time.Now()).Find(&expired).Error; err != nil {
		log.Printf("sweepExpiredModificationRequests: query failed: %v", err)
		return
	}

	for i := range expired {
		modReq := &expired[i]
		var order model.Order
		if err := db.Where("id = ?", modReq.OrderID).First(&order).Error; err != nil {
			log.Printf("sweepExpiredModificationRequests: order %s not found: %v", modReq.OrderID, err)
			continue
		}

		reason := "Customer tidak merespon permintaan ganti item — order dibatalkan otomatis"
		if err := CancelOrderAndRefund(db, &order, reason); err != nil {
			log.Printf("sweepExpiredModificationRequests: failed to cancel order %s: %v", order.OrderNumber, err)
			continue
		}
		now := time.Now()
		db.Model(modReq).Updates(map[string]interface{}{"status": "expired", "resolved_at": &now})

		if order.CustomerID != nil {
			SendToUser(db, *order.CustomerID,
				"Pesanan Dibatalkan Otomatis",
				fmt.Sprintf("Kamu tidak merespon permintaan ganti item order #%s tepat waktu. Dana dikembalikan ke wallet kamu.", order.OrderNumber),
				map[string]string{"order_id": order.ID.String(), "type": "order_status"})
		}
		if order.MerchantID != nil {
			var merchant model.Merchant
			if db.Where("id = ?", *order.MerchantID).First(&merchant).Error == nil {
				SendToUser(db, merchant.UserID,
					"Pesanan Dibatalkan Otomatis",
					fmt.Sprintf("Customer tidak merespon permintaan ganti item tepat waktu. Order #%s dibatalkan otomatis.", order.OrderNumber),
					map[string]string{"order_id": order.ID.String(), "type": "order_status"})
			}
		}
	}
}
