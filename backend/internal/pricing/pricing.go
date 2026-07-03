// Package pricing computes the customer-facing product price (platform
// markup baked in) shared by the customer, merchant, and service handlers,
// so the price shown in the catalog always matches what PlaceOrder charges.
package pricing

import (
	"math"
	"strconv"

	"gorm.io/gorm"

	"github.com/kuwrir-platform/backend/internal/model"
)

type Settings struct {
	MarkupMode        string // "percentage" | "fixed"
	MarkupPct         float64
	MarkupFixedAmount float64
}

func LoadSettings(db *gorm.DB) Settings {
	s := Settings{
		MarkupMode:        "percentage",
		MarkupPct:         15,
		MarkupFixedAmount: 1000,
	}

	var settings []model.SystemSetting
	db.Find(&settings)

	for _, setting := range settings {
		switch setting.Key {
		case "product_markup_mode":
			if setting.Value == "fixed" || setting.Value == "percentage" {
				s.MarkupMode = setting.Value
			}
		case "platform_markup_percentage":
			if val, err := strconv.ParseFloat(setting.Value, 64); err == nil {
				s.MarkupPct = val
			}
		case "product_markup_fixed_amount":
			if val, err := strconv.ParseFloat(setting.Value, 64); err == nil {
				s.MarkupFixedAmount = val
			}
		}
	}
	return s
}

// ApplyMarkup returns the customer-facing price for a raw merchant price.
// In "fixed" mode a flat nominal is added. In "percentage" mode the
// percentage markup is applied and rounded UP to the nearest Rp 500 so the
// displayed price is always a clean number.
func ApplyMarkup(price float64, s Settings) float64 {
	if s.MarkupMode == "fixed" {
		return price + s.MarkupFixedAmount
	}
	marked := price * (1 + s.MarkupPct/100.0)
	return math.Ceil(marked/500) * 500
}

// EffectivePrice returns the price a customer actually pays before markup:
// the product's DiscountPrice when set, otherwise its regular Price. This is
// the single place discount logic lives — both catalog display and
// PlaceOrder feed this into ApplyMarkup so the two never drift apart.
func EffectivePrice(p model.Product) float64 {
	if p.DiscountPrice != nil && *p.DiscountPrice > 0 {
		return *p.DiscountPrice
	}
	return p.Price
}

// ApplyMarkupToCategories overwrites product/variant prices in-memory with
// the markup-inclusive customer price. It never writes back to the DB — the
// merchant's raw price stays untouched in storage. Price and DiscountPrice
// (when set) are marked up independently, so the customer app can still show
// the original price struck through next to the marked-up discount price.
func ApplyMarkupToCategories(db *gorm.DB, categories []model.ProductCategory) {
	ps := LoadSettings(db)
	for i := range categories {
		for j := range categories[i].Products {
			product := &categories[i].Products[j]
			product.Price = ApplyMarkup(product.Price, ps)
			if product.DiscountPrice != nil && *product.DiscountPrice > 0 {
				marked := ApplyMarkup(*product.DiscountPrice, ps)
				product.DiscountPrice = &marked
			}
			for k := range product.Variants {
				product.Variants[k].Price = ApplyMarkup(product.Variants[k].Price, ps)
			}
		}
	}
}
