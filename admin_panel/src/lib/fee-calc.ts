export interface FeeSettings {
  platformMarkupPct: number
  deliveryCommissionPct: number
  selfDeliverCommissionPct: number
  appServiceFeePct: number
  taxPct: number
  insideZoneFee: number
  markupMode?: 'percentage' | 'fixed'
  markupFixedAmount?: number
}

export interface FeeBreakdown {
  foodWithMarkup: number
  platformUjrah: number
  taxAmount: number
  appServiceFeeAmt: number
  deliveryCommissionAmt: number
  driverEarning: number
  total: number
  platformRevenue: number
}

// Mirrors backend internal/pricing.ApplyMarkup — same formula/rounding so
// this preview matches what the customer catalog actually shows.
export function applyProductMarkup(price: number, s: Pick<FeeSettings, 'platformMarkupPct' | 'markupMode' | 'markupFixedAmount'>): number {
  if (s.markupMode === 'fixed') {
    return price + (s.markupFixedAmount ?? 0)
  }
  const marked = price * (1 + s.platformMarkupPct / 100)
  return Math.ceil(marked / 500) * 500
}

export function calcPreviewFees(baseFood: number, s: FeeSettings): FeeBreakdown {
  const foodWithMarkup = applyProductMarkup(baseFood, s)
  const platformUjrah = foodWithMarkup - baseFood
  const taxAmount = foodWithMarkup * (s.taxPct / 100)
  const appServiceFeeAmt = s.insideZoneFee * (s.appServiceFeePct / 100)
  const deliveryCommissionAmt = s.insideZoneFee * (s.deliveryCommissionPct / 100)
  const driverEarning = s.insideZoneFee - deliveryCommissionAmt
  const total = foodWithMarkup + taxAmount + s.insideZoneFee + appServiceFeeAmt
  const platformRevenue = platformUjrah + taxAmount + deliveryCommissionAmt + appServiceFeeAmt

  return {
    foodWithMarkup,
    platformUjrah,
    taxAmount,
    appServiceFeeAmt,
    deliveryCommissionAmt,
    driverEarning,
    total,
    platformRevenue,
  }
}

export interface SelfDeliverFeeBreakdown {
  appServiceFeeAmt: number
  selfCommissionAmt: number
  merchantDeliveryEarning: number
  total: number
}

export function calcSelfDeliverFees(
  subtotalWithMarkup: number,
  taxAmount: number,
  selfDeliveryFee: number,
  s: Pick<FeeSettings, 'selfDeliverCommissionPct' | 'appServiceFeePct'>,
): SelfDeliverFeeBreakdown {
  const appServiceFeeAmt = selfDeliveryFee * (s.appServiceFeePct / 100)
  const selfCommissionAmt = selfDeliveryFee * (s.selfDeliverCommissionPct / 100)
  const merchantDeliveryEarning = selfDeliveryFee - selfCommissionAmt
  const total = subtotalWithMarkup + taxAmount + selfDeliveryFee + appServiceFeeAmt

  return { appServiceFeeAmt, selfCommissionAmt, merchantDeliveryEarning, total }
}
