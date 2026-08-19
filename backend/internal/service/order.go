package service

import (
	"fmt"
	"time"

	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/model"
)

// CancelOrderAndRefund cancels a still-pending order, restocks its items,
// and — if the order was already paid (online payment or wallet payment) —
// refunds the customer's wallet for the full amount. Shared by the
// customer's own cancel, a merchant's reject, and the SLA timeout sweeper,
// so all three paths behave identically instead of duplicating this logic.
func CancelOrderAndRefund(db *gorm.DB, order *model.Order, reason string) error {
	tx := db.Begin()
	if tx.Error != nil {
		return tx.Error
	}

	var items []model.OrderItem
	if err := tx.Where("order_id = ?", order.ID).Find(&items).Error; err != nil {
		tx.Rollback()
		return fmt.Errorf("load order items: %w", err)
	}
	for _, item := range items {
		if item.ProductID == nil {
			continue
		}
		if err := tx.Model(&model.Product{}).Where("id = ?", *item.ProductID).
			UpdateColumn("stock_quantity", gorm.Expr("stock_quantity + ?", item.Quantity)).Error; err != nil {
			tx.Rollback()
			return fmt.Errorf("restock item: %w", err)
		}
	}

	now := time.Now()
	updates := map[string]interface{}{
		"status":       model.OrderStatusCancelled,
		"cancelled_at": &now,
	}
	if reason != "" {
		updates["cancellation_reason"] = &reason
	}
	if err := tx.Model(order).Updates(updates).Error; err != nil {
		tx.Rollback()
		return fmt.Errorf("cancel order: %w", err)
	}

	if order.PaymentStatus == "paid" && order.CustomerID != nil {
		if err := CreditWallet(tx, *order.CustomerID, model.RoleCustomer, order.Total, "refund", &order.ID, reason); err != nil {
			tx.Rollback()
			return fmt.Errorf("refund customer wallet: %w", err)
		}
	}

	if err := tx.Commit().Error; err != nil {
		return err
	}
	PublishOrderStatusEvent(order.ID.String(), string(model.OrderStatusCancelled))
	return nil
}
