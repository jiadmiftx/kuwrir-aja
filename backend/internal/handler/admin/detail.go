package admin

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/kuwrir-platform/backend/internal/model"
)

// ─── ENTITY DETAIL PAGES ────────────────────────────────────────────────────
//
// These back admin_panel's "lihat detail" views for a single merchant,
// driver, or customer — profile plus everything money-related about them:
// wallet balance + transaction history (their e-wallet), recent orders, and
// (for merchant/driver) how much is owed in each direction. Distinct from
// the existing list endpoints (GetMerchants/GetDrivers/GetCustomers), which
// intentionally stay lightweight for table rendering.

const detailRecentLimit = 50

// GetMerchantDetail returns a single merchant's full profile: store info,
// wallet + recent wallet transactions (online-order earnings credited via
// CreditWalletsForOnlineOrder), pending platform payout (same computation
// as GetMerchantSettlements, scoped to this merchant) plus past settlement
// records, POS receivables/payables (merchant's own tab/supplier-credit
// bookkeeping), and recent orders.
func (h *Handler) GetMerchantDetail(c *gin.Context) {
	id := c.Param("id")

	var merchant model.Merchant
	if err := h.db.Preload("Zone").Preload("Owner").First(&merchant, "id = ?", id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var wallet model.Wallet
	walletTxns := []model.WalletTransaction{}
	if h.db.Where("user_id = ? AND role = ?", merchant.UserID, model.RoleMerchant).First(&wallet).Error == nil {
		h.db.Where("wallet_id = ?", wallet.ID).Order("created_at DESC").Limit(detailRecentLimit).Find(&walletTxns)
	}

	// Pending platform payout — same query as GetMerchantSettlements,
	// scoped to this one merchant.
	var pendingPayout struct {
		TotalOrders int     `json:"total_orders"`
		TotalAmount float64 `json:"total_amount"`
	}
	h.db.Model(&model.Order{}).
		Select("COUNT(id) as total_orders, COALESCE(SUM(subtotal), 0) as total_amount").
		Where("merchant_id = ? AND status = ?", id, "delivered").
		Scan(&pendingPayout)

	settlements := []model.MerchantSettlement{}
	h.db.Where("merchant_id = ?", id).Order("created_at DESC").Find(&settlements)

	receivables := []model.MerchantReceivable{}
	h.db.Where("merchant_id = ?", id).Order("created_at DESC").Limit(detailRecentLimit).Find(&receivables)

	payables := []model.MerchantPayable{}
	h.db.Where("merchant_id = ?", id).Order("created_at DESC").Limit(detailRecentLimit).Find(&payables)

	orders := []model.Order{}
	h.db.Where("merchant_id = ?", id).Order("created_at DESC").Limit(detailRecentLimit).Find(&orders)

	var totalOrders int64
	h.db.Model(&model.Order{}).Where("merchant_id = ?", id).Count(&totalOrders)

	c.JSON(http.StatusOK, gin.H{
		"merchant": merchant,
		"wallet": gin.H{
			"balance":      wallet.Balance,
			"total_earned": wallet.TotalEarned,
			"transactions": walletTxns,
		},
		"pending_payout": pendingPayout,
		"settlements":    settlements,
		"receivables":    receivables,
		"payables":       payables,
		"orders":         orders,
		"total_orders":   totalOrders,
	})
}

// GetDriverDetail returns a single driver's full profile: vehicle/zone
// info, wallet + recent wallet transactions, COD holding (cash physically
// with the driver, owed to the platform) + deposit history, and recent
// deliveries.
func (h *Handler) GetDriverDetail(c *gin.Context) {
	id := c.Param("id")

	var driver model.Driver
	if err := h.db.Preload("Zone").Preload("User").First(&driver, "id = ?", id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Driver not found"})
		return
	}

	var wallet model.Wallet
	walletTxns := []model.WalletTransaction{}
	if h.db.Where("user_id = ? AND role = ?", driver.UserID, model.RoleDriver).First(&wallet).Error == nil {
		h.db.Where("wallet_id = ?", wallet.ID).Order("created_at DESC").Limit(detailRecentLimit).Find(&walletTxns)
	}

	deposits := []model.DriverDeposit{}
	h.db.Where("driver_id = ?", id).Order("created_at DESC").Limit(detailRecentLimit).Find(&deposits)

	orders := []model.Order{}
	h.db.Where("driver_id = ?", id).Order("created_at DESC").Limit(detailRecentLimit).Find(&orders)

	var totalDelivered int64
	h.db.Model(&model.Order{}).Where("driver_id = ? AND status = ?", id, "delivered").Count(&totalDelivered)

	c.JSON(http.StatusOK, gin.H{
		"driver": driver,
		"wallet": gin.H{
			"balance":      wallet.Balance,
			"total_earned": wallet.TotalEarned,
			"transactions": walletTxns,
		},
		"cod_holding":     driver.CodHolding,
		"deposits":        deposits,
		"orders":          orders,
		"total_delivered": totalDelivered,
	})
}

// GetCustomerDetail returns a single customer's full profile: account
// info, saved addresses, order/spending history, and their customer-role
// wallet (top-ups/refunds) + recent transactions.
func (h *Handler) GetCustomerDetail(c *gin.Context) {
	id := c.Param("id")

	var customer model.User
	if err := h.db.Where("id = ? AND role = ?", id, "customer").First(&customer).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Customer not found"})
		return
	}

	addresses := []model.Address{}
	h.db.Where("user_id = ?", id).Order("is_default DESC, created_at DESC").Find(&addresses)

	orders := []model.Order{}
	h.db.Where("customer_id = ?", id).Order("created_at DESC").Limit(detailRecentLimit).Find(&orders)

	var totalOrders int64
	var totalSpent float64
	h.db.Model(&model.Order{}).Where("customer_id = ?", id).Count(&totalOrders)
	h.db.Model(&model.Order{}).Where("customer_id = ? AND status = ?", id, "delivered").
		Select("COALESCE(SUM(total), 0)").Scan(&totalSpent)

	refunds := []model.RefundRequest{}
	h.db.Where("requested_by = ?", id).Order("created_at DESC").Limit(detailRecentLimit).Find(&refunds)

	var wallet model.Wallet
	walletTxns := []model.WalletTransaction{}
	if h.db.Where("user_id = ? AND role = ?", id, model.RoleCustomer).First(&wallet).Error == nil {
		h.db.Where("wallet_id = ?", wallet.ID).Order("created_at DESC").Limit(detailRecentLimit).Find(&walletTxns)
	}

	var bankAccount model.BankAccount
	hasBankAccount := h.db.Where("user_id = ? AND role = ?", id, model.RoleCustomer).First(&bankAccount).Error == nil

	c.JSON(http.StatusOK, gin.H{
		"customer":     customer,
		"addresses":    addresses,
		"orders":       orders,
		"total_orders": totalOrders,
		"total_spent":  totalSpent,
		"refunds":      refunds,
		"wallet": gin.H{
			"balance":      wallet.Balance,
			"total_earned": wallet.TotalEarned,
			"transactions": walletTxns,
		},
		"bank_account": func() interface{} {
			if hasBankAccount {
				return bankAccount
			}
			return nil
		}(),
	})
}
