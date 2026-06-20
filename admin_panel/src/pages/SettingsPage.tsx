import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Separator } from '@/components/ui/separator'
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs'
import { Badge } from '@/components/ui/badge'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '@/components/ui/dialog'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Save, Plus, Pencil, Trash2 } from 'lucide-react'
import { toast } from 'sonner'

const token = () => localStorage.getItem('token')
const apiFetch = (path: string, opts?: RequestInit) =>
  fetch(path, {
    headers: { Authorization: `Bearer ${token()}`, 'Content-Type': 'application/json' },
    ...opts,
  })

interface Setting {
  key: string
  value: string
  label: string
}

interface DeliveryZone {
  id: string
  city_name: string
  latitude: number
  longitude: number
  radius_km: number
  base_fee: number
  per_km_fee: number
  is_default: boolean
  is_active: boolean
}

const defaultSettings: Setting[] = [
  { key: 'platform_markup_percentage', value: '15', label: 'Platform Markup (%)' },
  { key: 'delivery_commission_percentage', value: '25', label: 'Delivery Commission (%)' },
  { key: 'app_service_fee_percentage', value: '5', label: 'App Service Fee on Delivery (%)' },
  { key: 'tax_percentage', value: '11', label: 'Tax / PPN (%)' },
  { key: 'delivery_base_fee_inside_zone', value: '15000', label: 'Default Inside Zone Delivery Fee (IDR)' },
  { key: 'delivery_fee_per_km_outside', value: '10000', label: 'Default Outside Zone Fee Per KM (IDR)' },
]

const emptyZone = (): Partial<DeliveryZone> => ({
  city_name: '',
  latitude: 0,
  longitude: 0,
  radius_km: 5,
  base_fee: 15000,
  per_km_fee: 10000,
  is_default: false,
  is_active: true,
})

export default function SettingsPage() {
  const [settings, setSettings] = useState<Setting[]>(defaultSettings)
  const [saving, setSaving] = useState(false)

  const [zones, setZones] = useState<DeliveryZone[]>([])
  const [zonesLoading, setZonesLoading] = useState(true)
  const [zoneDialog, setZoneDialog] = useState(false)
  const [editZone, setEditZone] = useState<DeliveryZone | null>(null)
  const [zoneForm, setZoneForm] = useState<Partial<DeliveryZone>>(emptyZone())
  const [zoneSaving, setZoneSaving] = useState(false)

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

  const fetchZones = () => {
    setZonesLoading(true)
    apiFetch('/api/v1/admin/delivery-zones')
      .then((r) => r.json())
      .then((data) => setZones(data.zones || []))
      .catch(() => {})
      .finally(() => setZonesLoading(false))
  }

  useEffect(() => {
    fetchZones()
  }, [])

  const updateValue = (key: string, value: string) => {
    setSettings((prev) => prev.map((s) => (s.key === key ? { ...s, value } : s)))
  }

  const handleSave = async () => {
    setSaving(true)
    try {
      await Promise.all(
        settings.map((s) =>
          apiFetch(`/api/v1/admin/settings/${s.key}`, {
            method: 'PUT',
            body: JSON.stringify({ value: s.value }),
          })
        )
      )
      toast.success('Settings saved')
    } catch {
      toast.error('Failed to save settings')
    } finally {
      setSaving(false)
    }
  }

  const openAddZone = () => {
    setEditZone(null)
    setZoneForm(emptyZone())
    setZoneDialog(true)
  }

  const openEditZone = (zone: DeliveryZone) => {
    setEditZone(zone)
    setZoneForm({ ...zone })
    setZoneDialog(true)
  }

  const handleDeleteZone = async (id: string) => {
    if (!confirm('Delete this zone?')) return
    await apiFetch(`/api/v1/admin/delivery-zones/${id}`, { method: 'DELETE' })
    fetchZones()
    toast.success('Zone deleted')
  }

  const handleSaveZone = async () => {
    setZoneSaving(true)
    try {
      if (editZone) {
        await apiFetch(`/api/v1/admin/delivery-zones/${editZone.id}`, {
          method: 'PUT',
          body: JSON.stringify(zoneForm),
        })
        toast.success('Zone updated')
      } else {
        await apiFetch('/api/v1/admin/delivery-zones', {
          method: 'POST',
          body: JSON.stringify(zoneForm),
        })
        toast.success('Zone created')
      }
      setZoneDialog(false)
      fetchZones()
    } catch {
      toast.error('Failed to save zone')
    } finally {
      setZoneSaving(false)
    }
  }

  // Live calculation preview
  const markup = parseFloat(settings.find((s) => s.key === 'platform_markup_percentage')?.value || '15')
  const commission = parseFloat(settings.find((s) => s.key === 'delivery_commission_percentage')?.value || '25')
  const serviceFee = parseFloat(settings.find((s) => s.key === 'app_service_fee_percentage')?.value || '5')
  const tax = parseFloat(settings.find((s) => s.key === 'tax_percentage')?.value || '11')
  const insideFee = parseFloat(settings.find((s) => s.key === 'delivery_base_fee_inside_zone')?.value || '15000')

  const baseFood = 50000
  const foodWithMarkup = baseFood + baseFood * (markup / 100)
  const taxAmount = foodWithMarkup * (tax / 100)
  const appServiceFeeAmt = insideFee * (serviceFee / 100)
  const deliveryCommissionAmt = insideFee * (commission / 100)
  const driverEarning = insideFee - deliveryCommissionAmt - appServiceFeeAmt
  const total = foodWithMarkup + taxAmount + insideFee
  const kuwrirRevenue = baseFood * (markup / 100) + taxAmount + deliveryCommissionAmt + appServiceFeeAmt

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Settings</h2>
        <p className="text-muted-foreground">Configure platform fees, taxes, and delivery zones.</p>
      </div>

      <Tabs defaultValue="fees">
        <TabsList>
          <TabsTrigger value="fees">Fee Settings</TabsTrigger>
          <TabsTrigger value="zones">Delivery Zones</TabsTrigger>
        </TabsList>

        {/* ── Fee Settings Tab ── */}
        <TabsContent value="fees" className="mt-4">
          <div className="grid gap-6 lg:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle>Financial Configuration</CardTitle>
                <CardDescription>Changes apply to all new orders immediately.</CardDescription>
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

            <Card>
              <CardHeader>
                <CardTitle>Live Calculation Preview</CardTitle>
                <CardDescription>Example: food base IDR 50,000 inside zone</CardDescription>
              </CardHeader>
              <CardContent className="space-y-3 text-sm">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Food Base (merchant price)</span>
                  <span>IDR {baseFood.toLocaleString('id-ID')}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">+ Markup ({markup}%)</span>
                  <span className="text-primary">IDR {(baseFood * markup / 100).toLocaleString('id-ID')}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">+ Tax/PPN ({tax}%)</span>
                  <span className="text-orange-500">IDR {taxAmount.toLocaleString('id-ID')}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Delivery Fee (inside zone)</span>
                  <span>IDR {insideFee.toLocaleString('id-ID')}</span>
                </div>
                <Separator />
                <div className="flex justify-between font-bold text-base">
                  <span>Total Customer Pays</span>
                  <span>IDR {total.toLocaleString('id-ID')}</span>
                </div>
                <Separator />
                <div className="flex justify-between text-green-600">
                  <span>→ Merchant Receives</span>
                  <span>IDR {baseFood.toLocaleString('id-ID')}</span>
                </div>
                <div className="flex justify-between text-blue-600">
                  <span>→ Driver Receives</span>
                  <span>IDR {driverEarning.toLocaleString('id-ID')}</span>
                </div>
                <div className="flex justify-between text-primary font-bold">
                  <span>→ KUWRIR Revenue</span>
                  <span>IDR {kuwrirRevenue.toLocaleString('id-ID')}</span>
                </div>
                <div className="text-xs text-muted-foreground pt-2 space-y-1">
                  <div>App service fee: IDR {appServiceFeeAmt.toLocaleString('id-ID')} ({serviceFee}% of delivery)</div>
                  <div>Delivery commission: IDR {deliveryCommissionAmt.toLocaleString('id-ID')} ({commission}% of delivery)</div>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* ── Delivery Zones Tab ── */}
        <TabsContent value="zones" className="mt-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between">
              <div>
                <CardTitle>Delivery Zones</CardTitle>
                <CardDescription>
                  City reference points used to calculate delivery fees. The nearest active zone to
                  the merchant is selected per order.
                </CardDescription>
              </div>
              <Button onClick={openAddZone}>
                <Plus className="mr-2 h-4 w-4" /> Add Zone
              </Button>
            </CardHeader>
            <CardContent>
              {zonesLoading ? (
                <p className="text-muted-foreground text-sm">Loading zones...</p>
              ) : zones.length === 0 ? (
                <p className="text-muted-foreground text-sm">No zones configured yet.</p>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>City</TableHead>
                      <TableHead>Lat / Lng</TableHead>
                      <TableHead>Radius (km)</TableHead>
                      <TableHead>Base Fee</TableHead>
                      <TableHead>Per KM Fee</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead></TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {zones.map((zone) => (
                      <TableRow key={zone.id}>
                        <TableCell className="font-medium">
                          {zone.city_name}
                          {zone.is_default && (
                            <Badge className="ml-2" variant="secondary">default</Badge>
                          )}
                        </TableCell>
                        <TableCell className="text-xs text-muted-foreground">
                          {zone.latitude.toFixed(4)}, {zone.longitude.toFixed(4)}
                        </TableCell>
                        <TableCell>{zone.radius_km} km</TableCell>
                        <TableCell>IDR {zone.base_fee.toLocaleString('id-ID')}</TableCell>
                        <TableCell>IDR {zone.per_km_fee.toLocaleString('id-ID')}/km</TableCell>
                        <TableCell>
                          <Badge variant={zone.is_active ? 'default' : 'secondary'}>
                            {zone.is_active ? 'Active' : 'Inactive'}
                          </Badge>
                        </TableCell>
                        <TableCell className="flex gap-2">
                          <Button variant="ghost" size="icon" onClick={() => openEditZone(zone)}>
                            <Pencil className="h-4 w-4" />
                          </Button>
                          <Button variant="ghost" size="icon" onClick={() => handleDeleteZone(zone.id)}>
                            <Trash2 className="h-4 w-4 text-destructive" />
                          </Button>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      {/* Zone Dialog */}
      <Dialog open={zoneDialog} onOpenChange={setZoneDialog}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>{editZone ? 'Edit Delivery Zone' : 'Add Delivery Zone'}</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-2">
              <Label>City Name</Label>
              <Input
                value={zoneForm.city_name || ''}
                onChange={(e) => setZoneForm((f) => ({ ...f, city_name: e.target.value }))}
                placeholder="e.g. Kuta, Lombok"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>Latitude</Label>
                <Input
                  type="number"
                  step="0.0001"
                  value={zoneForm.latitude || 0}
                  onChange={(e) => setZoneForm((f) => ({ ...f, latitude: parseFloat(e.target.value) }))}
                />
              </div>
              <div className="space-y-2">
                <Label>Longitude</Label>
                <Input
                  type="number"
                  step="0.0001"
                  value={zoneForm.longitude || 0}
                  onChange={(e) => setZoneForm((f) => ({ ...f, longitude: parseFloat(e.target.value) }))}
                />
              </div>
            </div>
            <div className="grid grid-cols-3 gap-3">
              <div className="space-y-2">
                <Label>Radius (km)</Label>
                <Input
                  type="number"
                  value={zoneForm.radius_km || 5}
                  onChange={(e) => setZoneForm((f) => ({ ...f, radius_km: parseFloat(e.target.value) }))}
                />
              </div>
              <div className="space-y-2">
                <Label>Base Fee (IDR)</Label>
                <Input
                  type="number"
                  value={zoneForm.base_fee || 15000}
                  onChange={(e) => setZoneForm((f) => ({ ...f, base_fee: parseFloat(e.target.value) }))}
                />
              </div>
              <div className="space-y-2">
                <Label>Per KM (IDR)</Label>
                <Input
                  type="number"
                  value={zoneForm.per_km_fee || 10000}
                  onChange={(e) => setZoneForm((f) => ({ ...f, per_km_fee: parseFloat(e.target.value) }))}
                />
              </div>
            </div>
            <div className="flex items-center gap-6">
              <label className="flex items-center gap-2 text-sm cursor-pointer">
                <input
                  type="checkbox"
                  checked={zoneForm.is_default || false}
                  onChange={(e) => setZoneForm((f) => ({ ...f, is_default: e.target.checked }))}
                />
                Set as default zone
              </label>
              <label className="flex items-center gap-2 text-sm cursor-pointer">
                <input
                  type="checkbox"
                  checked={zoneForm.is_active !== false}
                  onChange={(e) => setZoneForm((f) => ({ ...f, is_active: e.target.checked }))}
                />
                Active
              </label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setZoneDialog(false)}>Cancel</Button>
            <Button onClick={handleSaveZone} disabled={zoneSaving}>
              {zoneSaving ? 'Saving...' : 'Save Zone'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
