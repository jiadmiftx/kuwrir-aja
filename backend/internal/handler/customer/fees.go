package customer

// feeResult holds computed fee breakdown for an order.
type feeResult struct {
	AppServiceFee    float64
	DeliveryFee      float64
	DeliveryCommission float64
	DriverEarning    float64
	MerchantDeliveryEarning float64
	TaxAmount        float64
	GrandTotal       float64
}

// calcFees computes order fees from pure inputs — no DB dependency.
// subtotalWithMarkup is the product subtotal after platform markup.
// rawDeliveryFee is the zone-based delivery fee (used for platform delivery).
// For self-deliver, merchantSelfDeliveryFee overrides the delivery fee.
func calcFees(s settingsData, subtotalWithMarkup, rawDeliveryFee float64, isSelfDeliver bool, merchantSelfDeliveryFee float64) feeResult {
	var r feeResult

	if isSelfDeliver {
		r.DeliveryFee = merchantSelfDeliveryFee
		selfComm := r.DeliveryFee * (s.SelfDeliverCommissionPct / 100.0)
		r.MerchantDeliveryEarning = r.DeliveryFee - selfComm
		r.DeliveryCommission = selfComm
		r.DriverEarning = 0
	} else {
		r.DeliveryFee = rawDeliveryFee
		r.DeliveryCommission = r.DeliveryFee * (s.DeliveryCommissionPct / 100.0)
		r.DriverEarning = r.DeliveryFee - r.DeliveryCommission
		if r.DriverEarning < 0 {
			r.DriverEarning = 0
		}
	}

	// App service fee charged to customer for all delivery types.
	r.AppServiceFee = r.DeliveryFee * (s.AppServiceFeePct / 100.0)
	r.TaxAmount = subtotalWithMarkup * (s.TaxPct / 100.0)
	r.GrandTotal = subtotalWithMarkup + r.TaxAmount + r.DeliveryFee + r.AppServiceFee

	return r
}
