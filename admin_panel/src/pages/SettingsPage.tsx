import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Label } from '@/components/ui/label'
import { Separator } from '@/components/ui/separator'
import { Save } from 'lucide-react'
import { toast } from 'sonner'
import { calcPreviewFees, calcSelfDeliverFees } from '@/lib/fee-calc'
import { apiFetch } from '@/lib/api'

interface Setting {
  key: string
  value: string
  label: string
}

const MARKUP_MODE_KEY = 'product_markup_mode'

const defaultSettings: Setting[] = [
  // Product margin — Wakalah/Ujrah (disclosed platform service fee on products)
  { key: MARKUP_MODE_KEY, value: 'percentage', label: 'Product Markup Mode' },
  { key: 'platform_markup_percentage', value: '15', label: 'Platform Ujrah / Service Fee on Products (%) — used when mode = percentage' },
  { key: 'product_markup_fixed_amount', value: '1000', label: 'Fixed Markup per Product (IDR) — used when mode = fixed' },
  // Delivery split
  { key: 'delivery_commission_percentage', value: '25', label: 'Platform Commission from Delivery Fee (%)' },
  { key: 'app_service_fee_percentage', value: '5', label: 'Platform Tech Fee from Delivery Fee (%)' },
  // Self-deliver merchant: platform takes small ujrah on their delivery fee too
  { key: 'self_deliver_commission_percentage', value: '10', label: 'Self-Deliver Merchant Commission (%)' },
  // Tax
  { key: 'tax_percentage', value: '11', label: 'Tax / PPN (%)' },
  // Zone fallback
  { key: 'delivery_base_fee_inside_zone', value: '15000', label: 'Default Inside Zone Delivery Fee (IDR)' },
  { key: 'delivery_fee_per_km_outside', value: '10000', label: 'Default Outside Zone Fee Per KM (IDR)' },
  // Order guardrails
  { key: 'min_order_amount', value: '0', label: 'Minimum Order Amount (IDR, 0 = no minimum)' },
  { key: 'max_cod_amount', value: '500000', label: 'Maximum COD Order Amount (IDR)' },
]

export default function SettingsPage() {
  const [settings, setSettings] = useState<Setting[]>(defaultSettings)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    apiFetch('/api/v1/admin/settings')
      .then((r) => r.json())
      .then((data: { settings: Setting[] }) => {
        if (data.settings) {
          setSettings((prev) =>
            prev.map((s) => {
              const remote = data.settings.find((r) => r.key === s.key)
              return remote ? { ...s, value: remote.value } : s
            })
          )
        }
      })
      .catch(() => {})
  }, [])

  const updateValue = (key: string, value: string) => {
    setSettings((prev) => prev.map((s) => (s.key === key ? { ...s, value } : s)))
  }

  const handleSave = async () => {
    setSaving(true)
    try {
      const results = await Promise.all(
        settings.map(async (s) => {
          const res = await apiFetch(`/api/v1/admin/settings/${s.key}`, {
            method: 'PUT',
            body: JSON.stringify({ value: s.value }),
          })
          return { key: s.key, ok: res.ok }
        })
      )
      const failed = results.filter((r) => !r.ok)
      if (failed.length > 0) {
        toast.error(`Gagal menyimpan: ${failed.map((f) => f.key).join(', ')}`)
      } else {
        toast.success('Settings saved')
      }
    } catch {
      toast.error('Failed to save settings')
    } finally {
      setSaving(false)
    }
  }

  // Live calculation preview (Wakalah/Ujrah model)
  const markup = parseFloat(settings.find((s) => s.key === 'platform_markup_percentage')?.value || '15')
  const commission = parseFloat(settings.find((s) => s.key === 'delivery_commission_percentage')?.value || '25')
  const serviceFee = parseFloat(settings.find((s) => s.key === 'app_service_fee_percentage')?.value || '5')
  const selfDeliverComm = parseFloat(settings.find((s) => s.key === 'self_deliver_commission_percentage')?.value || '10')
  const tax = parseFloat(settings.find((s) => s.key === 'tax_percentage')?.value || '11')
  const insideFee = parseFloat(settings.find((s) => s.key === 'delivery_base_fee_inside_zone')?.value || '15000')
  const markupMode = (settings.find((s) => s.key === MARKUP_MODE_KEY)?.value || 'percentage') as 'percentage' | 'fixed'
  const markupFixedAmount = parseFloat(settings.find((s) => s.key === 'product_markup_fixed_amount')?.value || '1000')

  const baseFood = 50000
  const feeSettings = {
    platformMarkupPct: markup,
    deliveryCommissionPct: commission,
    selfDeliverCommissionPct: selfDeliverComm,
    appServiceFeePct: serviceFee,
    taxPct: tax,
    insideZoneFee: insideFee,
    markupMode,
    markupFixedAmount,
  }
  const preview = calcPreviewFees(baseFood, feeSettings)
  const { platformUjrah, foodWithMarkup, taxAmount, appServiceFeeAmt, deliveryCommissionAmt, driverEarning, total, platformRevenue } = preview
  const merchantReceives = baseFood

  const selfDeliverFee = 10000
  const selfPreview = calcSelfDeliverFees(foodWithMarkup, taxAmount, selfDeliverFee, feeSettings)
  const selfDeliverCommAmt = selfPreview.selfCommissionAmt
  const merchantDeliveryEarning = selfPreview.merchantDeliveryEarning

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Settings</h2>
        <p className="text-muted-foreground">Configure platform fees and taxes.</p>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle>Financial Configuration</CardTitle>
                <CardDescription>Changes apply to all new orders immediately.</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                {settings.map((setting) => {
                  const isPctInput = setting.key === 'platform_markup_percentage'
                  const isFixedInput = setting.key === 'product_markup_fixed_amount'
                  const isInactive =
                    (isPctInput && markupMode === 'fixed') ||
                    (isFixedInput && markupMode === 'percentage')

                  return (
                    <div key={setting.key} className={`space-y-2 transition-opacity ${isInactive ? 'opacity-40' : ''}`}>
                      <Label htmlFor={setting.key}>{setting.label}</Label>
                      {setting.key === MARKUP_MODE_KEY ? (
                        <Select value={setting.value} onValueChange={(v) => v && updateValue(setting.key, v)}>
                          <SelectTrigger id={setting.key}>
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent>
                            <SelectItem value="percentage">Percentage (% dari harga produk)</SelectItem>
                            <SelectItem value="fixed">Fixed (nominal tetap per produk)</SelectItem>
                          </SelectContent>
                        </Select>
                      ) : (
                        <Input
                          id={setting.key}
                          type="number"
                          value={setting.value}
                          onChange={(e) => updateValue(setting.key, e.target.value)}
                          disabled={isInactive}
                        />
                      )}
                      {isInactive && (
                        <p className="text-xs text-muted-foreground">
                          Tidak berlaku saat mode = {markupMode}
                        </p>
                      )}
                    </div>
                  )
                })}
                <Separator />
                <Button onClick={handleSave} disabled={saving} className="w-full">
                  <Save className="mr-2 h-4 w-4" />
                  {saving ? 'Saving...' : 'Save Settings'}
                </Button>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Live Calculation Preview</CardTitle>
                <CardDescription>Example: food base IDR 50,000 inside zone</CardDescription>
              </CardHeader>
              <CardContent className="space-y-3 text-sm">
                <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">Platform Delivery (food Rp 50.000)</p>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Merchant harga asli</span>
                  <span>IDR {baseFood.toLocaleString('id-ID')}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">
                    + Platform Ujrah ({markupMode === 'fixed' ? `flat IDR ${markupFixedAmount.toLocaleString('id-ID')}` : `${markup}%, dibulatkan ke atas kelipatan 500`})
                  </span>
                  <span className="text-primary">IDR {platformUjrah.toLocaleString('id-ID')}</span>
                </div>
                <div className="flex justify-between text-xs">
                  <span className="text-muted-foreground">→ Harga produk yang dilihat customer di katalog</span>
                  <span className="font-medium">IDR {foodWithMarkup.toLocaleString('id-ID')}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">+ Tax/PPN ({tax}%)</span>
                  <span className="text-orange-500">IDR {taxAmount.toLocaleString('id-ID')}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">+ Ongkir (inside zone)</span>
                  <span>IDR {insideFee.toLocaleString('id-ID')}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">+ Biaya Aplikasi ({serviceFee}%)</span>
                  <span className="text-orange-500">IDR {appServiceFeeAmt.toLocaleString('id-ID')}</span>
                </div>
                <Separator />
                <div className="flex justify-between font-bold text-base">
                  <span>Customer Bayar</span>
                  <span>IDR {total.toLocaleString('id-ID')}</span>
                </div>
                <Separator />
                <div className="flex justify-between text-green-700 font-medium">
                  <span>→ Merchant Terima (harga asli)</span>
                  <span>IDR {merchantReceives.toLocaleString('id-ID')}</span>
                </div>
                <div className="flex justify-between text-blue-600 font-medium">
                  <span>→ Driver Terima</span>
                  <span>IDR {driverEarning.toLocaleString('id-ID')}</span>
                </div>
                <div className="flex justify-between text-primary font-bold">
                  <span>→ Platform Revenue</span>
                  <span>IDR {platformRevenue.toLocaleString('id-ID')}</span>
                </div>
                <div className="text-xs text-muted-foreground pt-1 space-y-0.5">
                  <div>Ujrah produk: IDR {platformUjrah.toLocaleString('id-ID')} | PPN: IDR {taxAmount.toLocaleString('id-ID')}</div>
                  <div>Komisi delivery: IDR {deliveryCommissionAmt.toLocaleString('id-ID')} | Tech fee: IDR {appServiceFeeAmt.toLocaleString('id-ID')}</div>
                </div>
                <Separator />
                <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">Self-Deliver Merchant (ongkir Rp 10.000)</p>
                <div className="flex justify-between text-green-700">
                  <span>→ Merchant Terima (product + delivery)</span>
                  <span>IDR {(merchantReceives + merchantDeliveryEarning).toLocaleString('id-ID')}+</span>
                </div>
                <div className="flex justify-between text-primary">
                  <span>→ Platform Ujrah Delivery ({selfDeliverComm}%)</span>
                  <span>IDR {selfDeliverCommAmt.toLocaleString('id-ID')}</span>
                </div>
              </CardContent>
            </Card>
          </div>
    </div>
  )
}
