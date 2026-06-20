package customer

import (
	"math"
	"testing"
)

var defaultTestSettings = settingsData{
	PlatformMarkupPct:        15,
	DeliveryCommissionPct:    25,
	SelfDeliverCommissionPct: 10,
	InsideZoneFee:            15000,
	FeePerKmOutside:          10000,
	TaxPct:                   11,
	AppServiceFeePct:         5,
	MinOrderAmount:           0,
	MaxCODAmount:             500000,
}

func approxEqual(a, b, tol float64) bool {
	return math.Abs(a-b) < tol
}

// --- haversineDistance ---

func TestHaversineDistance_SamePoint(t *testing.T) {
	d := haversineDistance(-8.7185, 116.3516, -8.7185, 116.3516)
	if d != 0 {
		t.Errorf("expected 0, got %f", d)
	}
}

func TestHaversineDistance_KnownDistance(t *testing.T) {
	// Mataram to Kuta ~40km — rough check within 10km tolerance
	d := haversineDistance(-8.5833, 116.1167, -8.7185, 116.3516)
	if d < 20 || d > 60 {
		t.Errorf("expected ~30-40 km between Mataram and Kuta, got %.2f", d)
	}
}

func TestHaversineDistance_Positive(t *testing.T) {
	d := haversineDistance(0, 0, 1, 1)
	if d <= 0 {
		t.Errorf("expected positive distance, got %f", d)
	}
}

// --- calcFees: platform delivery ---

func TestCalcFees_PlatformDelivery_Basic(t *testing.T) {
	s := defaultTestSettings
	subtotal := 50000.0
	deliveryFee := 15000.0

	r := calcFees(s, subtotal, deliveryFee, false, 0)

	wantTax := subtotal * (s.TaxPct / 100) // 5500
	wantAppFee := deliveryFee * (s.AppServiceFeePct / 100) // 750
	wantDriverEarning := deliveryFee * (1 - s.DeliveryCommissionPct/100) // 11250
	wantTotal := subtotal + wantTax + deliveryFee + wantAppFee // 72250

	if !approxEqual(r.TaxAmount, wantTax, 0.01) {
		t.Errorf("TaxAmount: want %.2f, got %.2f", wantTax, r.TaxAmount)
	}
	if !approxEqual(r.AppServiceFee, wantAppFee, 0.01) {
		t.Errorf("AppServiceFee: want %.2f, got %.2f", wantAppFee, r.AppServiceFee)
	}
	if !approxEqual(r.DriverEarning, wantDriverEarning, 0.01) {
		t.Errorf("DriverEarning: want %.2f, got %.2f", wantDriverEarning, r.DriverEarning)
	}
	if !approxEqual(r.GrandTotal, wantTotal, 0.01) {
		t.Errorf("GrandTotal: want %.2f, got %.2f", wantTotal, r.GrandTotal)
	}
	if r.MerchantDeliveryEarning != 0 {
		t.Errorf("platform delivery: MerchantDeliveryEarning should be 0, got %.2f", r.MerchantDeliveryEarning)
	}
}

func TestCalcFees_PlatformDelivery_AppFeeNotDeductedFromDriver(t *testing.T) {
	s := defaultTestSettings
	r := calcFees(s, 100000, 20000, false, 0)

	// Driver earns delivery_fee * (1 - commission%), NOT minus app fee
	wantDriver := 20000 * (1 - s.DeliveryCommissionPct/100)
	if !approxEqual(r.DriverEarning, wantDriver, 0.01) {
		t.Errorf("DriverEarning: want %.2f (app fee not deducted from driver), got %.2f", wantDriver, r.DriverEarning)
	}
}

// --- calcFees: self-deliver ---

func TestCalcFees_SelfDeliver_AppFeeCharged(t *testing.T) {
	s := defaultTestSettings
	selfFee := 10000.0
	subtotal := 80000.0

	r := calcFees(s, subtotal, 15000, true, selfFee)

	// Uses merchant's self delivery fee, not the zone-based rawDeliveryFee
	if !approxEqual(r.DeliveryFee, selfFee, 0.01) {
		t.Errorf("DeliveryFee: want %.2f, got %.2f", selfFee, r.DeliveryFee)
	}

	// App service fee applies even for self-deliver
	wantAppFee := selfFee * (s.AppServiceFeePct / 100)
	if !approxEqual(r.AppServiceFee, wantAppFee, 0.01) {
		t.Errorf("AppServiceFee on self-deliver: want %.2f, got %.2f", wantAppFee, r.AppServiceFee)
	}

	// No driver earning for self-deliver
	if r.DriverEarning != 0 {
		t.Errorf("self-deliver: DriverEarning should be 0, got %.2f", r.DriverEarning)
	}

	// Merchant delivery earning = delivery_fee - self_commission
	wantMerchantDelivery := selfFee * (1 - s.SelfDeliverCommissionPct/100)
	if !approxEqual(r.MerchantDeliveryEarning, wantMerchantDelivery, 0.01) {
		t.Errorf("MerchantDeliveryEarning: want %.2f, got %.2f", wantMerchantDelivery, r.MerchantDeliveryEarning)
	}
}

func TestCalcFees_SelfDeliver_GrandTotalIncludesAppFee(t *testing.T) {
	s := defaultTestSettings
	subtotal := 60000.0
	selfFee := 8000.0

	r := calcFees(s, subtotal, 15000, true, selfFee)

	tax := subtotal * (s.TaxPct / 100)
	appFee := selfFee * (s.AppServiceFeePct / 100)
	want := subtotal + tax + selfFee + appFee

	if !approxEqual(r.GrandTotal, want, 0.01) {
		t.Errorf("GrandTotal: want %.2f, got %.2f", want, r.GrandTotal)
	}
}

// --- settingsData defaults ---

func TestSettingsData_Defaults(t *testing.T) {
	s := settingsData{
		PlatformMarkupPct:     15,
		DeliveryCommissionPct: 25,
		TaxPct:                11,
		AppServiceFeePct:      5,
	}
	if s.PlatformMarkupPct <= 0 {
		t.Error("PlatformMarkupPct should be positive")
	}
	if s.TaxPct <= 0 {
		t.Error("TaxPct should be positive")
	}
}
