package kasir

import (
	"fmt"
	"net/http"
	"time"

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

// RegisterRoutes mounts all POS/Kasir routes under /my-store/pos
func (h *Handler) RegisterRoutes(owner *gin.RouterGroup) {
	pos := owner.Group("/pos")
	{
		// POS Transactions (pemasukan / penjualan)
		pos.POST("/transactions", h.CreateTransaction)
		pos.GET("/transactions", h.ListTransactions)
		pos.GET("/transactions/:id", h.GetTransaction)
		pos.POST("/transactions/:id/void", h.VoidTransaction)

		// Stock management (stok / pergerakan_stok)
		pos.GET("/products", h.ListProductsWithStock)
		pos.PUT("/products/:productId/stock", h.AdjustStock)
		pos.GET("/products/:productId/stock-history", h.StockHistory)

		// Accounts Receivable / Tab (piutang)
		pos.GET("/receivables", h.ListReceivables)
		pos.POST("/receivables", h.CreateReceivable)
		pos.GET("/receivables/:id", h.GetReceivable)
		pos.POST("/receivables/:id/pay", h.PayReceivable)

		// Accounts Payable / Hutang supplier (hutang)
		pos.GET("/payables", h.ListPayables)
		pos.POST("/payables", h.CreatePayable)
		pos.GET("/payables/:id", h.GetPayable)
		pos.POST("/payables/:id/pay", h.PayPayable)

		// Reports (laporan: laba-rugi, arus-kas, stok)
		pos.GET("/reports/summary", h.ReportSummary)
		pos.GET("/reports/laba-rugi", h.ReportLabaRugi)
		pos.GET("/reports/arus-kas", h.ReportArusKas)
		pos.GET("/reports/stok", h.ReportStok)
	}
}

// ─── helpers ────────────────────────────────────────────────────────────────

func (h *Handler) getMerchant(userID string) (*model.Merchant, error) {
	var m model.Merchant
	return &m, h.db.Where("user_id = ?", userID).First(&m).Error
}

func nextTxNumber() string {
	return fmt.Sprintf("POS-%s", time.Now().Format("060102150405"))
}

// parseDateRange reads ?from= and ?to= query params, defaulting to current month
func parseDateRange(c *gin.Context) (time.Time, time.Time) {
	now := time.Now()
	fromStr := c.DefaultQuery("from", fmt.Sprintf("%d-%02d-01", now.Year(), now.Month()))
	toStr := c.DefaultQuery("to", now.Format("2006-01-02"))

	from, err := time.Parse("2006-01-02", fromStr)
	if err != nil {
		from = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.Local)
	}
	to, err2 := time.Parse("2006-01-02", toStr)
	if err2 != nil {
		to = now
	}
	// include the full last day
	to = to.Add(23*time.Hour + 59*time.Minute + 59*time.Second)
	return from, to
}

// updateReceivableStatus recomputes status after a payment
func (h *Handler) updateReceivableStatus(id uuid.UUID) {
	var r model.MerchantReceivable
	if h.db.First(&r, "id = ?", id).Error != nil {
		return
	}
	status := "unpaid"
	if r.PaidAmount >= r.Amount {
		status = "paid"
	} else if r.PaidAmount > 0 {
		status = "partial"
	}
	h.db.Model(&r).Update("status", status)
}

// updatePayableStatus recomputes status after a payment
func (h *Handler) updatePayableStatus(id uuid.UUID) {
	var p model.MerchantPayable
	if h.db.First(&p, "id = ?", id).Error != nil {
		return
	}
	status := "unpaid"
	if p.PaidAmount >= p.Amount {
		status = "paid"
	} else if p.PaidAmount > 0 {
		status = "partial"
	}
	h.db.Model(&p).Update("status", status)
}

// ─── POS TRANSACTIONS ────────────────────────────────────────────────────────

// CreateTransactionRequest mirrors finansial-mac pemasukan mode=per_produk
type CreateTransactionRequest struct {
	CustomerName  string  `json:"customer_name"`
	CustomerPhone string  `json:"customer_phone"`
	PaymentMethod string  `json:"payment_method"` // cash, qris, card, tab
	Discount      float64 `json:"discount"`
	Tax           float64 `json:"tax"`
	CashReceived  float64 `json:"cash_received"` // untuk payment_method=cash
	Notes         string  `json:"notes"`
	Items         []struct {
		ProductID *string `json:"product_id"` // nullable untuk item custom
		Name      string  `json:"name"`       // wajib jika product_id null
		SKU       string  `json:"sku"`
		Quantity  int     `json:"quantity" binding:"required,gt=0"`
		UnitPrice float64 `json:"unit_price" binding:"required,gt=0"`
		Discount  float64 `json:"discount"`
		Notes     string  `json:"notes"`
	} `json:"items" binding:"required,min=1"`
}

// CreateTransaction creates a POS sale, decrements stock, and auto-creates
// a MerchantReceivable when payment_method="tab" (mirip pemasukan+piutang di finansial-mac)
func (h *Handler) CreateTransaction(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var req CreateTransactionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.PaymentMethod == "" {
		req.PaymentMethod = "cash"
	}

	// Build items, resolve products, validate stock
	type resolvedItem struct {
		productID *uuid.UUID
		product   *model.Product
		name      string
		sku       string
		quantity  int
		unitPrice float64
		unitCost  float64
		discount  float64
		subtotal  float64
		notes     string
	}

	var resolved []resolvedItem
	var subtotal float64
	var totalCost float64

	for _, it := range req.Items {
		ri := resolvedItem{
			name:      it.Name,
			sku:       it.SKU,
			quantity:  it.Quantity,
			unitPrice: it.UnitPrice,
			discount:  it.Discount,
			notes:     it.Notes,
		}

		if it.ProductID != nil && *it.ProductID != "" {
			pid, parseErr := uuid.Parse(*it.ProductID)
			if parseErr != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid product_id: " + *it.ProductID})
				return
			}
			var p model.Product
			if h.db.First(&p, "id = ?", pid).Error != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Product not found: " + *it.ProductID})
				return
			}
			// stock check
			if p.TrackStock && p.StockQuantity < it.Quantity {
				c.JSON(http.StatusBadRequest, gin.H{
					"error": fmt.Sprintf("Stok %s tidak mencukupi. Tersedia: %d", p.Name, p.StockQuantity),
				})
				return
			}
			ri.productID = &pid
			ri.product = &p
			ri.unitCost = p.CostPrice
			if ri.name == "" {
				ri.name = p.Name
			}
			if ri.sku == "" {
				ri.sku = p.SKU
			}
		}

		ri.subtotal = float64(ri.quantity)*ri.unitPrice - ri.discount
		subtotal += ri.subtotal
		totalCost += float64(ri.quantity) * ri.unitCost
		resolved = append(resolved, ri)
	}

	grandTotal := subtotal - req.Discount + req.Tax
	grossProfit := grandTotal - totalCost
	cashChange := 0.0
	if req.PaymentMethod == "cash" && req.CashReceived > 0 {
		cashChange = req.CashReceived - grandTotal
	}

	tx := h.db.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	now := time.Now()
	posTx := model.PosTransaction{
		TransactionNumber: nextTxNumber(),
		MerchantID:        merchant.ID,
		Date:              now,
		CustomerName:      req.CustomerName,
		CustomerPhone:     req.CustomerPhone,
		PaymentMethod:     req.PaymentMethod,
		Status:            "completed",
		Notes:             req.Notes,
		Subtotal:          subtotal,
		Discount:          req.Discount,
		Tax:               req.Tax,
		GrandTotal:        grandTotal,
		TotalCost:         totalCost,
		GrossProfit:       grossProfit,
		CashReceived:      req.CashReceived,
		CashChange:        cashChange,
	}

	if err := tx.Create(&posTx).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create transaction"})
		return
	}

	// Save items, decrement stock, record stock movements
	for _, ri := range resolved {
		var pID *uuid.UUID
		if ri.productID != nil {
			pID = ri.productID
		}
		item := model.PosTransactionItem{
			TransactionID: posTx.ID,
			ProductID:     pID,
			ProductName:   ri.name,
			SKU:           ri.sku,
			Quantity:      ri.quantity,
			UnitPrice:     ri.unitPrice,
			UnitCost:      ri.unitCost,
			Discount:      ri.discount,
			Subtotal:      ri.subtotal,
			Notes:         ri.notes,
		}
		if err := tx.Create(&item).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save item"})
			return
		}

		// Stok decrement + movement log (mirip pergerakan_stok KELUAR di finansial-mac)
		if ri.product != nil && ri.product.TrackStock {
			tx.Model(&model.Product{}).Where("id = ?", ri.product.ID).
				UpdateColumn("stock_quantity", gorm.Expr("stock_quantity - ?", ri.quantity))

			mov := model.StockMovement{
				ProductID:  ri.product.ID,
				MerchantID: merchant.ID,
				Date:       now,
				Type:       "out",
				Quantity:   ri.quantity,
				CostPrice:  ri.unitCost,
				Reason:     "Penjualan POS",
				Reference:  posTx.TransactionNumber,
			}
			tx.Create(&mov)
		}
	}

	// Auto-create piutang when payment_method="tab"
	var receivable *model.MerchantReceivable
	if req.PaymentMethod == "tab" {
		txID := posTx.ID
		rec := model.MerchantReceivable{
			MerchantID:    merchant.ID,
			TransactionID: &txID,
			CustomerName:  req.CustomerName,
			CustomerPhone: req.CustomerPhone,
			Description:   fmt.Sprintf("Tab dari transaksi %s", posTx.TransactionNumber),
			Amount:        grandTotal,
			PaidAmount:    0,
			Status:        "unpaid",
		}
		if err := tx.Create(&rec).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create receivable"})
			return
		}
		receivable = &rec
	}

	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	resp := gin.H{"transaction": posTx}
	if receivable != nil {
		resp["receivable"] = receivable
	}
	c.JSON(http.StatusCreated, resp)
}

// ListTransactions returns POS transactions for the merchant (with date filter)
func (h *Handler) ListTransactions(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	from, to := parseDateRange(c)
	status := c.DefaultQuery("status", "")

	q := h.db.Where("merchant_id = ? AND date >= ? AND date <= ?", merchant.ID, from, to)
	if status != "" {
		q = q.Where("status = ?", status)
	}

	var txs []model.PosTransaction
	q.Preload("Items").Order("date DESC").Find(&txs)

	// Summary stats
	var totalRevenue, totalCost, totalGrossProfit float64
	for _, t := range txs {
		if t.Status == "completed" {
			totalRevenue += t.GrandTotal
			totalCost += t.TotalCost
			totalGrossProfit += t.GrossProfit
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"transactions": txs,
		"summary": gin.H{
			"total_revenue":      totalRevenue,
			"total_cost":         totalCost,
			"total_gross_profit": totalGrossProfit,
			"total_count":        len(txs),
		},
	})
}

// GetTransaction returns a single POS transaction with items
func (h *Handler) GetTransaction(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var posTx model.PosTransaction
	if h.db.Where("id = ? AND merchant_id = ?", id, merchant.ID).
		Preload("Items").First(&posTx).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Transaction not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"transaction": posTx})
}

// VoidTransaction voids a completed POS transaction (retur penjualan)
// Reverses stock movements and marks the transaction as voided
func (h *Handler) VoidTransaction(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var req struct {
		Reason string `json:"reason"`
	}
	c.ShouldBindJSON(&req)

	var posTx model.PosTransaction
	if h.db.Where("id = ? AND merchant_id = ? AND status = ?", id, merchant.ID, "completed").
		Preload("Items").First(&posTx).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Transaction not found or already voided"})
		return
	}

	tx := h.db.Begin()
	now := time.Now()

	// Reverse stock for each item (mirip retur_penjualan di finansial-mac)
	for _, item := range posTx.Items {
		if item.ProductID == nil {
			continue
		}
		var p model.Product
		if tx.First(&p, "id = ?", *item.ProductID).Error != nil {
			continue
		}
		if !p.TrackStock {
			continue
		}
		tx.Model(&model.Product{}).Where("id = ?", p.ID).
			UpdateColumn("stock_quantity", gorm.Expr("stock_quantity + ?", item.Quantity))

		mov := model.StockMovement{
			ProductID:  p.ID,
			MerchantID: merchant.ID,
			Date:       now,
			Type:       "void",
			Quantity:   item.Quantity,
			CostPrice:  item.UnitCost,
			Reason:     "Void transaksi POS",
			Reference:  posTx.TransactionNumber,
		}
		tx.Create(&mov)
	}

	// Mark piutang/tab as cancelled if exists
	tx.Model(&model.MerchantReceivable{}).
		Where("transaction_id = ? AND status = ?", posTx.ID, "unpaid").
		Updates(map[string]interface{}{"status": "cancelled", "paid_amount": 0})

	tx.Model(&posTx).Updates(map[string]interface{}{
		"status":        "voided",
		"voided_at":     now,
		"voided_reason": req.Reason,
	})

	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to void transaction"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Transaction voided", "transaction_number": posTx.TransactionNumber})
}

// ─── STOCK MANAGEMENT ────────────────────────────────────────────────────────

// ListProductsWithStock returns the merchant's products including stock info
// Includes low-stock alerts (mirip halaman stok di finansial-mac)
func (h *Handler) ListProductsWithStock(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var products []model.Product
	h.db.Joins("JOIN product_categories ON products.category_id = product_categories.id").
		Where("product_categories.merchant_id = ?", merchant.ID).
		Preload("Variants").
		Find(&products)

	// Tag low-stock items
	type productWithAlert struct {
		model.Product
		LowStock bool `json:"low_stock"`
	}
	result := make([]productWithAlert, 0, len(products))
	for _, p := range products {
		result = append(result, productWithAlert{
			Product:  p,
			LowStock: p.TrackStock && p.StockQuantity <= p.MinStock,
		})
	}

	c.JSON(http.StatusOK, gin.H{"products": result})
}

// AdjustStock manually adjusts stock for a product (MASUK / OPNAME)
// For incoming stock (restocking) or stock count correction
func (h *Handler) AdjustStock(c *gin.Context) {
	productID := c.Param("productId")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var req struct {
		Type      string  `json:"type" binding:"required"`     // "in" (masuk), "opname" (koreksi)
		Quantity  int     `json:"quantity" binding:"required"` // untuk opname: stok akhir yang benar
		CostPrice float64 `json:"cost_price"`                  // harga beli per unit (untuk masuk)
		Reason    string  `json:"reason"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Verify product belongs to this merchant
	var product model.Product
	if h.db.Joins("JOIN product_categories ON products.category_id = product_categories.id").
		Where("products.id = ? AND product_categories.merchant_id = ?", productID, merchant.ID).
		First(&product).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	now := time.Now()
	mov := model.StockMovement{
		ProductID:  product.ID,
		MerchantID: merchant.ID,
		Date:       now,
		Type:       req.Type,
		Quantity:   req.Quantity,
		CostPrice:  req.CostPrice,
		Reason:     req.Reason,
	}

	tx := h.db.Begin()
	switch req.Type {
	case "in":
		// Stok masuk (restock dari supplier)
		tx.Model(&model.Product{}).Where("id = ?", product.ID).
			UpdateColumn("stock_quantity", gorm.Expr("stock_quantity + ?", req.Quantity))
		// Update cost price if provided
		if req.CostPrice > 0 {
			tx.Model(&model.Product{}).Where("id = ?", product.ID).
				Update("cost_price", req.CostPrice)
		}
	case "opname":
		// Stock opname: set ke nilai yang benar
		mov.Quantity = req.Quantity - product.StockQuantity // delta
		tx.Model(&model.Product{}).Where("id = ?", product.ID).
			Update("stock_quantity", req.Quantity)
	default:
		tx.Rollback()
		c.JSON(http.StatusBadRequest, gin.H{"error": "Type must be 'in' or 'opname'"})
		return
	}

	tx.Create(&mov)
	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to adjust stock"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Stock adjusted", "movement": mov})
}

// StockHistory returns movement history for a product (like stok_riwayat di finansial-mac)
func (h *Handler) StockHistory(c *gin.Context) {
	productID := c.Param("productId")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	from, to := parseDateRange(c)

	var movements []model.StockMovement
	h.db.Where("product_id = ? AND merchant_id = ? AND date >= ? AND date <= ?",
		productID, merchant.ID, from, to).
		Order("date DESC, created_at DESC").
		Find(&movements)

	c.JSON(http.StatusOK, gin.H{"movements": movements})
}

// ─── ACCOUNTS RECEIVABLE / PIUTANG ───────────────────────────────────────────

// ListReceivables returns all receivables for the merchant
func (h *Handler) ListReceivables(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	status := c.DefaultQuery("status", "") // unpaid, partial, paid

	q := h.db.Where("merchant_id = ?", merchant.ID)
	if status != "" {
		q = q.Where("status = ?", status)
	}

	var receivables []model.MerchantReceivable
	q.Order("created_at DESC").Find(&receivables)

	// Summary
	var totalUnpaid float64
	for _, r := range receivables {
		if r.Status != "paid" {
			totalUnpaid += r.Amount - r.PaidAmount
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"receivables":  receivables,
		"total_unpaid": totalUnpaid,
	})
}

// CreateReceivable creates a standalone receivable (piutang manual, bukan dari POS tab)
func (h *Handler) CreateReceivable(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var req struct {
		CustomerName  string  `json:"customer_name" binding:"required"`
		CustomerPhone string  `json:"customer_phone"`
		Description   string  `json:"description"`
		DueDate       *string `json:"due_date"` // "2026-06-15"
		Amount        float64 `json:"amount" binding:"required,gt=0"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var due *time.Time
	if req.DueDate != nil && *req.DueDate != "" {
		d, e := time.Parse("2006-01-02", *req.DueDate)
		if e == nil {
			due = &d
		}
	}

	rec := model.MerchantReceivable{
		MerchantID:    merchant.ID,
		CustomerName:  req.CustomerName,
		CustomerPhone: req.CustomerPhone,
		Description:   req.Description,
		DueDate:       due,
		Amount:        req.Amount,
		Status:        "unpaid",
	}
	if h.db.Create(&rec).Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create receivable"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"receivable": rec})
}

// GetReceivable returns a receivable with payment history
func (h *Handler) GetReceivable(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var rec model.MerchantReceivable
	if h.db.Where("id = ? AND merchant_id = ?", id, merchant.ID).
		Preload("Payments").First(&rec).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Receivable not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"receivable": rec})
}

// PayReceivable records a payment against a receivable (like bayar_piutang)
func (h *Handler) PayReceivable(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var req struct {
		Amount float64 `json:"amount" binding:"required,gt=0"`
		Method string  `json:"method"` // cash, transfer
		Notes  string  `json:"notes"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var rec model.MerchantReceivable
	if h.db.Where("id = ? AND merchant_id = ? AND status != ?", id, merchant.ID, "paid").
		First(&rec).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Receivable not found or already paid"})
		return
	}

	outstanding := rec.Amount - rec.PaidAmount
	if req.Amount > outstanding {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": fmt.Sprintf("Pembayaran (%.0f) melebihi sisa piutang (%.0f)", req.Amount, outstanding),
		})
		return
	}

	if req.Method == "" {
		req.Method = "cash"
	}

	payment := model.MerchantReceivablePayment{
		ReceivableID: rec.ID,
		Date:         time.Now(),
		Amount:       req.Amount,
		Method:       req.Method,
		Notes:        req.Notes,
	}
	h.db.Create(&payment)
	h.db.Model(&rec).UpdateColumn("paid_amount", gorm.Expr("paid_amount + ?", req.Amount))
	h.updateReceivableStatus(rec.ID)

	c.JSON(http.StatusOK, gin.H{"message": "Payment recorded", "payment": payment})
}

// ─── ACCOUNTS PAYABLE / HUTANG ────────────────────────────────────────────────

// ListPayables returns all payables for the merchant
func (h *Handler) ListPayables(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	status := c.DefaultQuery("status", "")

	q := h.db.Where("merchant_id = ?", merchant.ID)
	if status != "" {
		q = q.Where("status = ?", status)
	}

	var payables []model.MerchantPayable
	q.Order("created_at DESC").Find(&payables)

	var totalUnpaid float64
	for _, p := range payables {
		if p.Status != "paid" {
			totalUnpaid += p.Amount - p.PaidAmount
		}
	}

	c.JSON(http.StatusOK, gin.H{"payables": payables, "total_unpaid": totalUnpaid})
}

// CreatePayable records a purchase on credit from a supplier (like hutang baru)
func (h *Handler) CreatePayable(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var req struct {
		SupplierName  string  `json:"supplier_name" binding:"required"`
		SupplierPhone string  `json:"supplier_phone"`
		Description   string  `json:"description"`
		DueDate       *string `json:"due_date"`
		Amount        float64 `json:"amount" binding:"required,gt=0"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var due *time.Time
	if req.DueDate != nil && *req.DueDate != "" {
		d, e := time.Parse("2006-01-02", *req.DueDate)
		if e == nil {
			due = &d
		}
	}

	p := model.MerchantPayable{
		MerchantID:    merchant.ID,
		SupplierName:  req.SupplierName,
		SupplierPhone: req.SupplierPhone,
		Description:   req.Description,
		DueDate:       due,
		Amount:        req.Amount,
		Status:        "unpaid",
	}
	if h.db.Create(&p).Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create payable"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"payable": p})
}

// GetPayable returns a payable with payment history
func (h *Handler) GetPayable(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var p model.MerchantPayable
	if h.db.Where("id = ? AND merchant_id = ?", id, merchant.ID).
		Preload("Payments").First(&p).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Payable not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"payable": p})
}

// PayPayable records a payment against a payable (like bayar_hutang)
func (h *Handler) PayPayable(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var req struct {
		Amount float64 `json:"amount" binding:"required,gt=0"`
		Method string  `json:"method"`
		Notes  string  `json:"notes"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var p model.MerchantPayable
	if h.db.Where("id = ? AND merchant_id = ? AND status != ?", id, merchant.ID, "paid").
		First(&p).Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Payable not found or already paid"})
		return
	}

	outstanding := p.Amount - p.PaidAmount
	if req.Amount > outstanding {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": fmt.Sprintf("Pembayaran (%.0f) melebihi sisa hutang (%.0f)", req.Amount, outstanding),
		})
		return
	}

	if req.Method == "" {
		req.Method = "cash"
	}

	payment := model.MerchantPayablePayment{
		PayableID: p.ID,
		Date:      time.Now(),
		Amount:    req.Amount,
		Method:    req.Method,
		Notes:     req.Notes,
	}
	h.db.Create(&payment)
	h.db.Model(&p).UpdateColumn("paid_amount", gorm.Expr("paid_amount + ?", req.Amount))
	h.updatePayableStatus(p.ID)

	c.JSON(http.StatusOK, gin.H{"message": "Payment recorded", "payment": payment})
}

// ─── REPORTS ─────────────────────────────────────────────────────────────────

// ReportSummary returns a period summary: revenue, HPP, gross profit, count per day
// Mirrors dashboard + pemasukan summary di finansial-mac
func (h *Handler) ReportSummary(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	from, to := parseDateRange(c)

	type DaySummary struct {
		Date        string  `json:"date"`
		Revenue     float64 `json:"revenue"`
		TotalCost   float64 `json:"total_cost"`
		GrossProfit float64 `json:"gross_profit"`
		TxCount     int     `json:"tx_count"`
	}

	rows, _ := h.db.Model(&model.PosTransaction{}).
		Select("DATE(date) as date, SUM(grand_total) as revenue, SUM(total_cost) as total_cost, SUM(gross_profit) as gross_profit, COUNT(*) as tx_count").
		Where("merchant_id = ? AND date >= ? AND date <= ? AND status = ?", merchant.ID, from, to, "completed").
		Group("DATE(date)").
		Order("DATE(date) ASC").
		Rows()
	defer rows.Close()

	var days []DaySummary
	var totalRevenue, totalCost, totalGrossProfit float64
	var totalTx int

	for rows.Next() {
		var d DaySummary
		rows.Scan(&d.Date, &d.Revenue, &d.TotalCost, &d.GrossProfit, &d.TxCount)
		days = append(days, d)
		totalRevenue += d.Revenue
		totalCost += d.TotalCost
		totalGrossProfit += d.GrossProfit
		totalTx += d.TxCount
	}

	// Receivables & payables outstanding
	var totalReceivable float64
	h.db.Model(&model.MerchantReceivable{}).
		Select("COALESCE(SUM(amount - paid_amount), 0)").
		Where("merchant_id = ? AND status != 'paid'", merchant.ID).
		Scan(&totalReceivable)

	var totalPayable float64
	h.db.Model(&model.MerchantPayable{}).
		Select("COALESCE(SUM(amount - paid_amount), 0)").
		Where("merchant_id = ? AND status != 'paid'", merchant.ID).
		Scan(&totalPayable)

	c.JSON(http.StatusOK, gin.H{
		"period": gin.H{"from": from.Format("2006-01-02"), "to": to.Format("2006-01-02")},
		"totals": gin.H{
			"revenue":      totalRevenue,
			"total_cost":   totalCost,
			"gross_profit": totalGrossProfit,
			"gross_margin_pct": func() float64 {
				if totalRevenue == 0 {
					return 0
				}
				return totalGrossProfit / totalRevenue * 100
			}(),
			"transaction_count": totalTx,
			"receivable_unpaid": totalReceivable,
			"payable_unpaid":    totalPayable,
		},
		"daily": days,
	})
}

// ReportLabaRugi produces a Profit & Loss breakdown for the period
// Mirrors laba_rugi di finansial-mac: Pendapatan → HPP → Laba Kotor → Beban → Laba Bersih
func (h *Handler) ReportLabaRugi(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	from, to := parseDateRange(c)

	var revenue, totalCost float64
	h.db.Model(&model.PosTransaction{}).
		Select("COALESCE(SUM(grand_total), 0)").
		Where("merchant_id = ? AND date >= ? AND date <= ? AND status = ?", merchant.ID, from, to, "completed").
		Scan(&revenue)

	h.db.Model(&model.PosTransaction{}).
		Select("COALESCE(SUM(total_cost), 0)").
		Where("merchant_id = ? AND date >= ? AND date <= ? AND status = ?", merchant.ID, from, to, "completed").
		Scan(&totalCost)

	grossProfit := revenue - totalCost

	// Beban dari hutang yang dibayar pada periode ini (perkiraan beban operasional)
	var operationalExpenses float64
	h.db.Model(&model.MerchantPayablePayment{}).
		Select("COALESCE(SUM(mp.amount), 0)").
		Joins("JOIN merchant_payables mp ON mp.id = merchant_payable_payments.payable_id").
		Where("mp.merchant_id = ? AND merchant_payable_payments.date >= ? AND merchant_payable_payments.date <= ?",
			merchant.ID, from, to).
		Scan(&operationalExpenses)

	netProfit := grossProfit - operationalExpenses

	pct := func(v float64) float64 {
		if revenue == 0 {
			return 0
		}
		return v / revenue * 100
	}

	c.JSON(http.StatusOK, gin.H{
		"period": gin.H{"from": from.Format("2006-01-02"), "to": to.Format("2006-01-02")},
		"laba_rugi": gin.H{
			"pendapatan_penjualan": revenue,
			"hpp":                  totalCost,
			"laba_kotor":           grossProfit,
			"pct_laba_kotor":       pct(grossProfit),
			"beban_operasional":    operationalExpenses,
			"laba_bersih":          netProfit,
			"pct_laba_bersih":      pct(netProfit),
		},
	})
}

// ReportArusKas breaks down revenue by payment method for the period
// Mirrors arus_kas di finansial-mac
func (h *Handler) ReportArusKas(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	from, to := parseDateRange(c)

	type PaymentBreakdown struct {
		Method string  `json:"method"`
		Total  float64 `json:"total"`
		Count  int     `json:"count"`
	}

	rows, _ := h.db.Model(&model.PosTransaction{}).
		Select("payment_method as method, SUM(grand_total) as total, COUNT(*) as count").
		Where("merchant_id = ? AND date >= ? AND date <= ? AND status = ?", merchant.ID, from, to, "completed").
		Group("payment_method").
		Rows()
	defer rows.Close()

	var breakdown []PaymentBreakdown
	var totalCashIn float64

	for rows.Next() {
		var b PaymentBreakdown
		rows.Scan(&b.Method, &b.Total, &b.Count)
		breakdown = append(breakdown, b)
		if b.Method == "cash" || b.Method == "qris" || b.Method == "card" {
			totalCashIn += b.Total
		}
	}

	// Receivable payments collected in this period (cash masuk dari piutang)
	var receivableCollected float64
	h.db.Model(&model.MerchantReceivablePayment{}).
		Select("COALESCE(SUM(mrp.amount), 0)").
		Joins("JOIN merchant_receivables mr ON mr.id = merchant_receivable_payments.receivable_id").
		Where("mr.merchant_id = ? AND merchant_receivable_payments.date >= ? AND merchant_receivable_payments.date <= ?",
			merchant.ID, from, to).
		Scan(&receivableCollected)

	// Payable payments made in this period (cash keluar ke supplier)
	var payablePaid float64
	h.db.Model(&model.MerchantPayablePayment{}).
		Select("COALESCE(SUM(mpp.amount), 0)").
		Joins("JOIN merchant_payables mp ON mp.id = merchant_payable_payments.payable_id").
		Where("mp.merchant_id = ? AND merchant_payable_payments.date >= ? AND merchant_payable_payments.date <= ?",
			merchant.ID, from, to).
		Scan(&payablePaid)

	netCash := totalCashIn + receivableCollected - payablePaid

	c.JSON(http.StatusOK, gin.H{
		"period": gin.H{"from": from.Format("2006-01-02"), "to": to.Format("2006-01-02")},
		"arus_kas": gin.H{
			"masuk_penjualan":        totalCashIn,
			"masuk_piutang_terbayar": receivableCollected,
			"keluar_bayar_hutang":    payablePaid,
			"arus_kas_bersih":        netCash,
		},
		"breakdown_metode": breakdown,
	})
}

// ReportStok returns current stock status with low-stock alerts
// Mirrors halaman stok di finansial-mac
func (h *Handler) ReportStok(c *gin.Context) {
	userID := c.GetString("user_id")
	merchant, err := h.getMerchant(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Merchant not found"})
		return
	}

	var products []model.Product
	h.db.Joins("JOIN product_categories ON products.category_id = product_categories.id").
		Where("product_categories.merchant_id = ? AND products.track_stock = true", merchant.ID).
		Find(&products)

	type StockItem struct {
		ProductID     string  `json:"product_id"`
		Name          string  `json:"name"`
		SKU           string  `json:"sku"`
		StockQuantity int     `json:"stock_quantity"`
		MinStock      int     `json:"min_stock"`
		CostPrice     float64 `json:"cost_price"`
		StockValue    float64 `json:"stock_value"` // stok × harga beli
		LowStock      bool    `json:"low_stock"`
	}

	var items []StockItem
	var totalValue float64
	for _, p := range products {
		sv := float64(p.StockQuantity) * p.CostPrice
		totalValue += sv
		items = append(items, StockItem{
			ProductID:     p.ID.String(),
			Name:          p.Name,
			SKU:           p.SKU,
			StockQuantity: p.StockQuantity,
			MinStock:      p.MinStock,
			CostPrice:     p.CostPrice,
			StockValue:    sv,
			LowStock:      p.StockQuantity <= p.MinStock,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"products":          items,
		"total_stock_value": totalValue,
	})
}
