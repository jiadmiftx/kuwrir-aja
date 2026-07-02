import { describe, it, expect } from 'vitest'
import { calcPreviewFees, calcSelfDeliverFees, type FeeSettings } from '../lib/fee-calc'

const defaultSettings: FeeSettings = {
  platformMarkupPct: 15,
  deliveryCommissionPct: 25,
  selfDeliverCommissionPct: 10,
  appServiceFeePct: 5,
  taxPct: 11,
  insideZoneFee: 15000,
}

describe('calcPreviewFees', () => {
  it('applies platform markup correctly', () => {
    const r = calcPreviewFees(100000, defaultSettings)
    expect(r.platformUjrah).toBeCloseTo(15000)
    expect(r.foodWithMarkup).toBeCloseTo(115000)
  })

  it('calculates tax on food subtotal with markup', () => {
    const r = calcPreviewFees(100000, defaultSettings)
    expect(r.taxAmount).toBeCloseTo(115000 * 0.11) // 12650
  })

  it('charges app service fee to customer (in total)', () => {
    const r = calcPreviewFees(100000, defaultSettings)
    const expectedAppFee = 15000 * 0.05 // 750
    expect(r.appServiceFeeAmt).toBeCloseTo(expectedAppFee)
    expect(r.total).toBeCloseTo(r.foodWithMarkup + r.taxAmount + defaultSettings.insideZoneFee + expectedAppFee)
  })

  it('driver earning does not include app service fee deduction', () => {
    const r = calcPreviewFees(100000, defaultSettings)
    const expectedDriver = defaultSettings.insideZoneFee * (1 - defaultSettings.deliveryCommissionPct / 100)
    expect(r.driverEarning).toBeCloseTo(expectedDriver) // 11250
  })

  it('platform revenue = markup + tax + delivery commission + app fee', () => {
    const r = calcPreviewFees(100000, defaultSettings)
    const expected = r.platformUjrah + r.taxAmount + r.deliveryCommissionAmt + r.appServiceFeeAmt
    expect(r.platformRevenue).toBeCloseTo(expected)
  })

  it('total = food_with_markup + tax + delivery + app_fee', () => {
    const r = calcPreviewFees(50000, defaultSettings)
    const expected = r.foodWithMarkup + r.taxAmount + defaultSettings.insideZoneFee + r.appServiceFeeAmt
    expect(r.total).toBeCloseTo(expected)
  })

  it('zero food: only delivery and fees apply', () => {
    const r = calcPreviewFees(0, defaultSettings)
    expect(r.foodWithMarkup).toBe(0)
    expect(r.taxAmount).toBe(0)
    expect(r.appServiceFeeAmt).toBeCloseTo(15000 * 0.05)
  })
})

describe('calcSelfDeliverFees', () => {
  it('charges app service fee to customer even for self-deliver', () => {
    const r = calcSelfDeliverFees(80000, 8800, 10000, defaultSettings)
    expect(r.appServiceFeeAmt).toBeCloseTo(10000 * 0.05) // 500
  })

  it('merchant keeps delivery fee minus commission', () => {
    const r = calcSelfDeliverFees(80000, 8800, 10000, defaultSettings)
    expect(r.selfCommissionAmt).toBeCloseTo(10000 * 0.10) // 1000
    expect(r.merchantDeliveryEarning).toBeCloseTo(9000) // 10000 - 1000
  })

  it('grand total includes app fee', () => {
    const subtotal = 80000
    const tax = 8800
    const selfFee = 10000
    const r = calcSelfDeliverFees(subtotal, tax, selfFee, defaultSettings)
    const appFee = selfFee * 0.05
    expect(r.total).toBeCloseTo(subtotal + tax + selfFee + appFee)
  })
})
