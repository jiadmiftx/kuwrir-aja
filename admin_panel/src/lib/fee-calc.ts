export interface FeeSettings {
  platformMarkupPct: number
  deliveryCommissionPct: number
  selfDeliverCommissionPct: number
  appServiceFeePct: number
  taxPct: number
  insideZoneFee: number
}

export interface FeeBreakdown {
  foodWithMarkup: number
  platformUjrah: number
  taxAmount: number
  appServiceFeeAmt: number
  deliveryCommissionAmt: number
  driverEarning: number
  total: number
  kuwrirRevenue: number
}

export function calcPreviewFees(baseFood: number, s: FeeSettings): FeeBreakdown {
  const platformUjrah = baseFood * (s.platformMarkupPct / 100)
  const foodWithMarkup = baseFood + platformUjrah
  const taxAmount = foodWithMarkup * (s.taxPct / 100)
  const appServiceFeeAmt = s.insideZoneFee * (s.appServiceFeePct / 100)
  const deliveryCommissionAmt = s.insideZoneFee * (s.deliveryCommissionPct / 100)
  const driverEarning = s.insideZoneFee - deliveryCommissionAmt
  const total = foodWithMarkup + taxAmount + s.insideZoneFee + appServiceFeeAmt
  const kuwrirRevenue = platformUjrah + taxAmount + deliveryCommissionAmt + appServiceFeeAmt

  return {
    foodWithMarkup,
    platformUjrah,
    taxAmount,
    appServiceFeeAmt,
    deliveryCommissionAmt,
    driverEarning,
    total,
    kuwrirRevenue,
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
