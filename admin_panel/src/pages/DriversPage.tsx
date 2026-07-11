import { useState, useEffect, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from '@/components/ui/dialog'
import { Search, Bike, HandCoins, History, Loader2, Ban, CheckCircle, Eye } from 'lucide-react'
import { toast } from 'sonner'
import { apiFetch as api } from '@/lib/api'

interface DeliveryZone {
  id: string
  city_name: string
  parent_zone_id?: string | null
  children?: DeliveryZone[]
}

interface Driver {
  id: string
  vehicle_type: string
  vehicle_plate: string
  is_online: boolean
  is_available: boolean
  rating: number
  total_delivered: number
  cash_balance: number
  zone_id?: string | null
  zone?: DeliveryZone
  user?: { id: string; name: string; phone: string; is_active: boolean }
}

interface Deposit {
  id: string
  amount: number
  method: string
  reference: string
  notes: string
  verified_at: string
}

const fmt = (v: number | undefined) => 'Rp ' + (v ?? 0).toLocaleString('id-ID')

export default function DriversPage() {
  const navigate = useNavigate()
  const [search, setSearch] = useState('')
  const [drivers, setDrivers] = useState<Driver[]>([])
  const [zones, setZones] = useState<DeliveryZone[]>([])
  // `zones` only holds top-level (kota) zones, with kecamatan nested under
  // `children` — but a driver's zone_id may point at a kecamatan, so name
  // lookups need the flattened set or they fall back to the raw id.
  const flatZones = useMemo(() => zones.flatMap(z => [z, ...(z.children ?? [])]), [zones])
  // Base UI's <Select> only resolves the trigger's displayed label from an
  // item the popup has actually rendered at least once — before that (e.g.
  // on first page load, before anyone opens the dropdown), it falls back to
  // showing the raw zone_id (a UUID) instead of the name. Passing `items`
  // explicitly makes the label resolvable immediately regardless of
  // whether the popup was ever opened.
  const zoneItems = useMemo(() => {
    const map: Record<string, string> = { none: 'Semua Wilayah' }
    for (const z of flatZones) map[z.id] = z.city_name
    return map
  }, [flatZones])
  const [isLoading, setIsLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState<string | null>(null)

  // Deposit dialog
  const [depositDriver, setDepositDriver] = useState<Driver | null>(null)
  const [depositHistory, setDepositHistory] = useState<Deposit[]>([])
  const [depositAmount, setDepositAmount] = useState('')
  const [depositMethod, setDepositMethod] = useState('cash')
  const [depositRef, setDepositRef] = useState('')
  const [depositSubmitting, setDepositSubmitting] = useState(false)
  const [historyOpen, setHistoryOpen] = useState(false)

  const fetchDrivers = async () => {
    setIsLoading(true)
    try {
      const res = await api('/api/v1/admin/drivers')
      const data = await res.json()
      if (res.ok) setDrivers(data.drivers ?? data)
    } finally { setIsLoading(false) }
  }

  const fetchZones = async () => {
    const res = await api('/api/v1/admin/delivery-zones')
    if (res.ok) {
      const data = await res.json()
      setZones(data.zones ?? [])
    }
  }

  const assignZone = async (driverId: string, zoneId: string) => {
    const res = await api(`/api/v1/admin/drivers/${driverId}/zone`, {
      method: 'PATCH',
      body: JSON.stringify({ zone_id: zoneId === 'none' ? null : zoneId }),
    })
    if (res.ok) {
      const z = flatZones.find(z => z.id === zoneId)
      setDrivers(prev => prev.map(d =>
        d.id === driverId ? { ...d, zone_id: zoneId === 'none' ? undefined : zoneId, zone: z } : d
      ))
      toast.success('Zone updated')
    } else {
      toast.error('Failed to update zone')
    }
  }

  useEffect(() => { fetchDrivers(); fetchZones() }, [])

  const toggleActive = async (driver: Driver) => {
    if (!driver.user) return
    setActionLoading(driver.id + '-toggle')
    try {
      const res = await api(`/api/v1/admin/users/${driver.user.id}/toggle-active`, { method: 'PUT' })
      if (res.ok) {
        setDrivers(prev => prev.map(d =>
          d.id === driver.id && d.user
            ? { ...d, user: { ...d.user, is_active: !d.user.is_active } }
            : d
        ))
      }
    } finally { setActionLoading(null) }
  }

  const openDepositDialog = async (driver: Driver) => {
    setDepositDriver(driver)
    setDepositAmount('')
    setDepositMethod('cash')
    setDepositRef('')
    // fetch deposit history
    const res = await api(`/api/v1/admin/drivers/${driver.id}/deposits`)
    if (res.ok) {
      const data = await res.json()
      setDepositHistory(data.deposits ?? [])
    }
  }

  const submitDeposit = async () => {
    if (!depositDriver) return
    const amount = parseFloat(depositAmount)
    if (!amount || amount <= 0) return
    setDepositSubmitting(true)
    try {
      const res = await api(`/api/v1/admin/drivers/${depositDriver.id}/deposits`, {
        method: 'POST',
        body: JSON.stringify({ amount, method: depositMethod, reference: depositRef }),
      })
      if (res.ok) {
        // Update cash_balance in list
        setDrivers(prev => prev.map(d =>
          d.id === depositDriver.id
            ? { ...d, cash_balance: Math.max(0, d.cash_balance - amount) }
            : d
        ))
        setDepositDriver(null)
      }
    } finally { setDepositSubmitting(false) }
  }

  const filtered = drivers.filter(d =>
    d.user?.name?.toLowerCase().includes(search.toLowerCase()) ||
    d.vehicle_plate?.toLowerCase().includes(search.toLowerCase())
  )

  const totalCash = drivers.reduce((s, d) => s + (d.cash_balance ?? 0), 0)
  const onlineCount = drivers.filter(d => d.is_online).length

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Drivers</h2>
        <p className="text-muted-foreground">Manage delivery partners & COD deposits</p>
      </div>

      {/* Stats */}
      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Total Drivers</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{drivers.length}</div>
            <p className="text-xs text-muted-foreground mt-1">{onlineCount} online sekarang</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Total COD Cash Held</CardTitle>
          </CardHeader>
          <CardContent>
            <div className={`text-2xl font-bold ${totalCash > 0 ? 'text-red-600' : 'text-green-600'}`}>
              {fmt(totalCash)}
            </div>
            <p className="text-xs text-muted-foreground mt-1">belum disetor ke admin</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Driver Perlu Setor</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-orange-600">
              {drivers.filter(d => d.cash_balance > 0).length}
            </div>
            <p className="text-xs text-muted-foreground mt-1">driver dengan saldo COD</p>
          </CardContent>
        </Card>
      </div>

      {/* Table */}
      <Card>
        <CardHeader>
          <div className="relative">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder="Search by name or plate..."
              value={search}
              onChange={e => setSearch(e.target.value)}
              className="pl-9"
            />
          </div>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Driver</TableHead>
                <TableHead>Kendaraan</TableHead>
                <TableHead>Wilayah</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Deliveries</TableHead>
                <TableHead>Cash COD</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <TableRow><TableCell colSpan={7} className="text-center py-8">
                  <Loader2 className="h-5 w-5 animate-spin mx-auto" />
                </TableCell></TableRow>
              ) : filtered.length === 0 ? (
                <TableRow><TableCell colSpan={7} className="text-center text-muted-foreground py-8">No drivers found</TableCell></TableRow>
              ) : filtered.map(d => (
                <TableRow key={d.id}>
                  <TableCell>
                    <div className="font-medium">{d.user?.name ?? '-'}</div>
                    <div className="text-sm text-muted-foreground">{d.user?.phone}</div>
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-2">
                      <Bike className="h-4 w-4 text-muted-foreground" />
                      {d.vehicle_type} · {d.vehicle_plate}
                    </div>
                  </TableCell>
                  <TableCell>
                    <Select
                      items={zoneItems}
                      value={d.zone_id ?? 'none'}
                      onValueChange={val => val !== null && assignZone(d.id, val)}
                    >
                      <SelectTrigger className="h-8 w-36 text-xs">
                        <SelectValue placeholder="Pilih wilayah" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="none">Semua Wilayah</SelectItem>
                        {zones.filter(z => !z.parent_zone_id).flatMap(z => [
                          <SelectItem key={z.id} value={z.id}>{z.city_name}</SelectItem>,
                          ...(z.children ?? []).map(c => (
                            <SelectItem key={c.id} value={c.id} className="pl-6 text-muted-foreground">
                              └ {c.city_name}
                            </SelectItem>
                          )),
                        ])}
                      </SelectContent>
                    </Select>
                  </TableCell>
                  <TableCell>
                    <div className="flex flex-col gap-1">
                      <Badge variant={d.user?.is_active ? 'default' : 'secondary'}>
                        {d.user?.is_active ? 'Active' : 'Suspended'}
                      </Badge>
                      {d.is_online && (
                        <Badge variant="outline" className="text-green-600 border-green-300 text-xs w-fit">
                          Online
                        </Badge>
                      )}
                    </div>
                  </TableCell>
                  <TableCell>{d.total_delivered}</TableCell>
                  <TableCell>
                    <span className={`font-medium ${d.cash_balance > 0 ? 'text-red-600' : 'text-muted-foreground'}`}>
                      {fmt(d.cash_balance ?? 0)}
                    </span>
                  </TableCell>
                  <TableCell className="text-right">
                    <div className="flex justify-end gap-1">
                      {/* Detail lengkap */}
                      <Button variant="ghost" size="sm" title="Lihat detail lengkap" onClick={() => navigate(`/drivers/${d.id}`)}>
                        <Eye className="h-4 w-4" />
                      </Button>
                      {/* Catat setoran */}
                      {d.cash_balance > 0 && (
                        <Button
                          variant="outline" size="sm"
                          className="text-green-600 border-green-300 hover:bg-green-50"
                          onClick={() => openDepositDialog(d)}
                        >
                          <HandCoins className="h-4 w-4 mr-1" /> Setor
                        </Button>
                      )}
                      {/* Riwayat */}
                      <Button variant="ghost" size="sm"
                        onClick={async () => {
                          setDepositDriver(d)
                          const res = await api(`/api/v1/admin/drivers/${d.id}/deposits`)
                          if (res.ok) { const data = await res.json(); setDepositHistory(data.deposits ?? []) }
                          setHistoryOpen(true)
                        }}>
                        <History className="h-4 w-4" />
                      </Button>
                      {/* Suspend / Activate */}
                      <Button
                        variant="ghost" size="sm"
                        className={d.user?.is_active ? 'text-red-600 hover:bg-red-50' : 'text-green-600 hover:bg-green-50'}
                        disabled={actionLoading === d.id + '-toggle'}
                        onClick={() => toggleActive(d)}
                      >
                        {actionLoading === d.id + '-toggle'
                          ? <Loader2 className="h-4 w-4 animate-spin" />
                          : d.user?.is_active ? <Ban className="h-4 w-4" /> : <CheckCircle className="h-4 w-4" />}
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      {/* Deposit Dialog */}
      <Dialog open={!!depositDriver && !historyOpen} onOpenChange={v => { if (!v) setDepositDriver(null) }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Catat Setoran COD — {depositDriver?.user?.name}</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div className="rounded-lg bg-muted p-3 text-sm">
              <span className="text-muted-foreground">Saldo COD saat ini: </span>
              <span className="font-bold text-red-600">{fmt(depositDriver?.cash_balance ?? 0)}</span>
            </div>
            <div className="space-y-2">
              <Label>Jumlah Setoran (Rp)</Label>
              <Input
                type="number"
                placeholder="0"
                value={depositAmount}
                onChange={e => setDepositAmount(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label>Metode</Label>
              <div className="flex gap-3">
                {['cash', 'bank_transfer'].map(m => (
                  <label key={m} className="flex items-center gap-2 cursor-pointer">
                    <input type="radio" value={m} checked={depositMethod === m}
                      onChange={() => setDepositMethod(m)} />
                    <span className="text-sm capitalize">{m.replace('_', ' ')}</span>
                  </label>
                ))}
              </div>
            </div>
            <div className="space-y-2">
              <Label>Nomor Referensi / Bukti Transfer (opsional)</Label>
              <Input
                placeholder="e.g. TRF-20260601-001"
                value={depositRef}
                onChange={e => setDepositRef(e.target.value)}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDepositDriver(null)}>Batal</Button>
            <Button
              className="bg-green-600 hover:bg-green-700"
              disabled={depositSubmitting || !depositAmount}
              onClick={submitDeposit}
            >
              {depositSubmitting ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : <HandCoins className="h-4 w-4 mr-2" />}
              Konfirmasi Setoran
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* History Dialog */}
      <Dialog open={historyOpen} onOpenChange={v => { setHistoryOpen(v); if (!v) setDepositDriver(null) }}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>Riwayat Setoran — {depositDriver?.user?.name}</DialogTitle>
          </DialogHeader>
          {depositHistory.length === 0 ? (
            <p className="text-sm text-muted-foreground text-center py-4">Belum ada riwayat setoran</p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Tanggal</TableHead>
                  <TableHead>Jumlah</TableHead>
                  <TableHead>Metode</TableHead>
                  <TableHead>Ref</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {depositHistory.map(dep => (
                  <TableRow key={dep.id}>
                    <TableCell className="text-sm">
                      {new Date(dep.verified_at).toLocaleDateString('id-ID')}
                    </TableCell>
                    <TableCell className="font-medium text-green-600">{fmt(dep.amount)}</TableCell>
                    <TableCell className="capitalize text-sm">{dep.method.replace('_', ' ')}</TableCell>
                    <TableCell className="text-sm text-muted-foreground">{dep.reference || '-'}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </DialogContent>
      </Dialog>
    </div>
  )
}
