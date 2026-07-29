package pricing

import (
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/kuwrir-platform/backend/internal/model"
)

// ApplyPromo validates promo against an in-progress order and returns the
// amount to subtract from the grand total. A merchant-owned promo
// (promo.MerchantID set) only ever discounts orders placed at that same
// merchant — never another merchant's, even if the code string somehow
// collides (Promotion.Code is globally unique, so this is defense in depth).
func ApplyPromo(promo model.Promotion, merchantID uuid.UUID, subtotal, deliveryFee float64) (float64, error) {
	now := time.Now()

	if !promo.IsActive {
		return 0, errors.New("kode promo tidak aktif")
	}
	if now.Before(promo.StartsAt) || now.After(promo.ExpiresAt) {
		return 0, errors.New("kode promo sudah tidak berlaku")
	}
	if promo.UsageLimit > 0 && promo.UsedCount >= promo.UsageLimit {
		return 0, errors.New("kode promo sudah mencapai batas penggunaan")
	}
	if promo.MinOrder > 0 && subtotal < promo.MinOrder {
		return 0, fmt.Errorf("minimum belanja untuk kode ini Rp%.0f", promo.MinOrder)
	}
	if promo.MerchantID != nil && *promo.MerchantID != merchantID {
		return 0, errors.New("kode promo tidak berlaku untuk toko ini")
	}

	var discount float64
	switch promo.Type {
	case "percentage":
		discount = subtotal * (promo.Value / 100.0)
	case "fixed":
		discount = promo.Value
	case "free_delivery":
		discount = deliveryFee
	default:
		return 0, errors.New("tipe kode promo tidak dikenal")
	}

	if promo.MaxDiscount > 0 && discount > promo.MaxDiscount {
		discount = promo.MaxDiscount
	}
	if max := subtotal + deliveryFee; discount > max {
		discount = max
	}
	return discount, nil
}
