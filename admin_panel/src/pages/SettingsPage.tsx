import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Separator } from '@/components/ui/separator'
import { Save } from 'lucide-react'

interface Setting {
  key: string
  value: string
  label: string
}

const defaultSettings: Setting[] = [
  { key: 'platform_markup_percentage', value: '15', label: 'Platform Markup Percentage (%)' },
  { key: 'delivery_commission_percentage', value: '25', label: 'Delivery Commission Percentage (%)' },
  { key: 'delivery_base_fee_inside_zone', value: '15000', label: 'Inside Zone Delivery Fee (IDR)' },
  { key: 'delivery_fee_per_km_outside', value: '10000', label: 'Outside Zone Fee Per KM (IDR)' },
]

export default function SettingsPage() {
  const [settings, setSettings] = useState<Setting[]>(defaultSettings)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    // TODO: Fetch from API GET /api/v1/admin/settings
  }, [])

  const updateValue = (key: string, value: string) => {
    setSettings((prev) =>
      prev.map((s) => (s.key === key ? { ...s, value } : s))
    )
  }

  const handleSave = async () => {
    setSaving(true)
    // TODO: Call API PUT /api/v1/admin/settings/:key for each changed setting
    setTimeout(() => setSaving(false), 500)
  }

  // Live calculation preview
  const foodMarkup = parseFloat(settings.find((s) => s.key === 'platform_markup_percentage')?.value || '15')
  const deliveryCommission = parseFloat(settings.find((s) => s.key === 'delivery_commission_percentage')?.value || '25')
  const insideFee = parseFloat(settings.find((s) => s.key === 'delivery_base_fee_inside_zone')?.value || '15000')

  const exampleFoodBase = 50000
  const exampleFoodCustomer = exampleFoodBase + (exampleFoodBase * foodMarkup / 100)
  const exampleTotal = exampleFoodCustomer + insideFee
  const exampleDriverEarning = insideFee * (1 - deliveryCommission / 100)
  const exampleKuwrirRevenue = (exampleFoodBase * foodMarkup / 100) + (insideFee * deliveryCommission / 100)

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Settings</h2>
        <p className="text-muted-foreground">
          Configure platform fees and delivery pricing. Changes take effect immediately.
        </p>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        {/* Settings Form */}
        <Card>
          <CardHeader>
            <CardTitle>Financial Configuration</CardTitle>
            <CardDescription>
              These values are applied to all new orders in real-time.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {settings.map((setting) => (
              <div key={setting.key} className="space-y-2">
                <Label htmlFor={setting.key}>{setting.label}</Label>
                <Input
                  id={setting.key}
                  type="number"
                  value={setting.value}
                  onChange={(e) => updateValue(setting.key, e.target.value)}
                />
              </div>
            ))}
            <Separator />
            <Button onClick={handleSave} disabled={saving} className="w-full">
              <Save className="mr-2 h-4 w-4" />
              {saving ? 'Saving...' : 'Save Settings'}
            </Button>
          </CardContent>
        </Card>

        {/* Live Preview */}
        <Card>
          <CardHeader>
            <CardTitle>Live Calculation Preview</CardTitle>
            <CardDescription>
              Example: Customer orders food (base IDR 50,000) inside zone
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            <div className="flex justify-between">
              <span className="text-muted-foreground">Food Base Price</span>
              <span>IDR {exampleFoodBase.toLocaleString('id-ID')}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">+ Platform Markup ({foodMarkup}%)</span>
              <span className="text-primary">IDR {(exampleFoodBase * foodMarkup / 100).toLocaleString('id-ID')}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Food Price (Customer Sees)</span>
              <span className="font-medium">IDR {exampleFoodCustomer.toLocaleString('id-ID')}</span>
            </div>
            <Separator />
            <div className="flex justify-between">
              <span className="text-muted-foreground">Delivery Fee (Inside Zone)</span>
              <span>IDR {insideFee.toLocaleString('id-ID')}</span>
            </div>
            <Separator />
            <div className="flex justify-between font-bold text-base">
              <span>Total Customer Pays (Cash)</span>
              <span>IDR {exampleTotal.toLocaleString('id-ID')}</span>
            </div>
            <Separator />
            <div className="flex justify-between text-green-600">
              <span>→ Merchant Receives</span>
              <span>IDR {exampleFoodBase.toLocaleString('id-ID')}</span>
            </div>
            <div className="flex justify-between text-blue-600">
              <span>→ Driver Receives</span>
              <span>IDR {exampleDriverEarning.toLocaleString('id-ID')}</span>
            </div>
            <div className="flex justify-between text-primary font-bold">
              <span>→ KUWRIR Revenue</span>
              <span>IDR {exampleKuwrirRevenue.toLocaleString('id-ID')}</span>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
