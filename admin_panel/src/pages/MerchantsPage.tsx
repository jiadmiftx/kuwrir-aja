import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from '@/components/ui/dialog'
import { Search, CheckCircle, XCircle, Eye, MapPin, Star, Loader2 } from 'lucide-react'
import { toast } from 'sonner'
import { apiFetch as api } from '@/lib/api'

interface DeliveryZone {
  id: string
  city_name: string
}

interface Merchant {
  id: string
  name: string
  phone: string
  address: string
  rating: number
  total_reviews: number
  is_active: boolean
  is_verified: boolean
  is_open: boolean
  created_at: string
  zone_id?: string | null
  zone?: DeliveryZone
  tax_enabled?: boolean
  tax_rate?: number | null
}

export default function MerchantsPage() {
  const [search, setSearch] = useState('')
  const [merchants, setMerchants] = useState<Merchant[]>([])
  const [zones, setZones] = useState<DeliveryZone[]>([])
  const [selected, setSelected] = useState<Merchant | null>(null)
  const [detailOpen, setDetailOpen] = useState(false)
  const [isLoading, setIsLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState<string | null>(null)

  const fetchMerchants = async () => {
    setIsLoading(true)
    try {
      const res = await api('/api/v1/admin/merchants')
      const data = await res.json()
      if (res.ok) setMerchants(data.merchants ?? data)
    } catch (e) { console.error(e) }
    finally { setIsLoading(false) }
  }

  const fetchZones = async () => {
    const res = await api('/api/v1/admin/delivery-zones')
    if (res.ok) {
      const data = await res.json()
      setZones(data.zones ?? [])
    }
  }

  const assignZone = async (merchantId: string, zoneId: string) => {
    const res = await api(`/api/v1/admin/merchants/${merchantId}/zone`, {
      method: 'PATCH',
      body: JSON.stringify({ zone_id: zoneId === 'none' ? null : zoneId }),
    })
    if (res.ok) {
      const z = zones.find(z => z.id === zoneId)
      setMerchants(prev => prev.map(m =>
        m.id === merchantId ? { ...m, zone_id: zoneId === 'none' ? undefined : zoneId, zone: z } : m
      ))
      toast.success('Zone updated')
    } else {
      toast.error('Failed to update zone')
    }
  }

  useEffect(() => { fetchMerchants(); fetchZones() }, [])

  const verify = async (id: string, verified: boolean) => {
    setActionLoading(id + (verified ? '-approve' : '-reject'))
    try {
      const res = await api(`/api/v1/admin/merchants/${id}/verify`, {
        method: 'PUT',
        body: JSON.stringify({ verified }),
      })
      if (res.ok) {
        setMerchants(prev =>
          prev.map(m => m.id === id ? { ...m, is_verified: verified, is_active: verified } : m)
        )
        if (selected?.id === id) setSelected(s => s ? { ...s, is_verified: verified } : s)
      }
    } finally { setActionLoading(null) }
  }

  const filtered = merchants.filter(m =>
    m.name.toLowerCase().includes(search.toLowerCase()) ||
    m.phone.includes(search)
  )

  const pendingCount = merchants.filter(m => !m.is_verified).length

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Merchants</h2>
          <p className="text-muted-foreground">Manage merchant partners and verification</p>
        </div>
        {pendingCount > 0 && (
          <Badge variant="destructive" className="text-sm px-3 py-1">
            {pendingCount} Pending Verification
          </Badge>
        )}
      </div>

      {/* Stats */}
      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Total Merchants</CardTitle>
          </CardHeader>
          <CardContent><div className="text-2xl font-bold">{merchants.length}</div></CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Verified & Active</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">
              {merchants.filter(m => m.is_verified && m.is_active).length}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Currently Open</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-600">
              {merchants.filter(m => m.is_open).length}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Table */}
      <Card>
        <CardHeader>
          <div className="relative">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder="Search merchants..."
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
                <TableHead>Merchant</TableHead>
                <TableHead>Location</TableHead>
                <TableHead>Wilayah</TableHead>
                <TableHead>Rating</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Open</TableHead>
                <TableHead>Pajak</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <TableRow><TableCell colSpan={7} className="text-center py-8">
                  <Loader2 className="h-5 w-5 animate-spin mx-auto" />
                </TableCell></TableRow>
              ) : filtered.length === 0 ? (
                <TableRow><TableCell colSpan={7} className="text-center text-muted-foreground py-8">No merchants found</TableCell></TableRow>
              ) : filtered.map(m => (
                <TableRow key={m.id}>
                  <TableCell>
                    <div className="font-medium">{m.name}</div>
                    <div className="text-sm text-muted-foreground">{m.phone}</div>
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-1 text-sm text-muted-foreground">
                      <MapPin className="h-3 w-3 shrink-0" />{m.address}
                    </div>
                  </TableCell>
                  <TableCell>
                    <Select
                      value={m.zone_id ?? 'none'}
                      onValueChange={val => val !== null && assignZone(m.id, val)}
                    >
                      <SelectTrigger className="h-8 w-36 text-xs">
                        <SelectValue placeholder="Pilih wilayah" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="none">Unassigned</SelectItem>
                        {zones.map(z => (
                          <SelectItem key={z.id} value={z.id}>{z.city_name}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-1">
                      <Star className="h-3 w-3 fill-yellow-400 text-yellow-400" />
                      <span className="text-sm">{m.rating > 0 ? m.rating.toFixed(1) : '-'}</span>
                      <span className="text-xs text-muted-foreground">({m.total_reviews})</span>
                    </div>
                  </TableCell>
                  <TableCell>
                    {m.is_verified
                      ? <Badge variant="secondary" className="bg-green-100 text-green-800">Verified</Badge>
                      : <Badge variant="destructive">Pending</Badge>}
                  </TableCell>
                  <TableCell>
                    <Badge variant={m.is_open ? 'default' : 'secondary'}>
                      {m.is_open ? 'Open' : 'Closed'}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    {m.tax_enabled
                      ? <Badge variant="secondary" className="bg-blue-100 text-blue-800">
                          PKP {m.tax_rate != null ? `${m.tax_rate}%` : '(default)'}
                        </Badge>
                      : <Badge variant="outline" className="text-muted-foreground">Non-PKP</Badge>}
                  </TableCell>
                  <TableCell className="text-right">
                    <div className="flex justify-end gap-1">
                      <Button variant="ghost" size="sm" onClick={() => { setSelected(m); setDetailOpen(true) }}>
                        <Eye className="h-4 w-4" />
                      </Button>
                      {!m.is_verified && (
                        <>
                          <Button
                            variant="ghost" size="sm"
                            className="text-green-600 hover:text-green-700 hover:bg-green-50"
                            disabled={actionLoading === m.id + '-approve'}
                            onClick={() => verify(m.id, true)}
                          >
                            {actionLoading === m.id + '-approve'
                              ? <Loader2 className="h-4 w-4 animate-spin" />
                              : <CheckCircle className="h-4 w-4" />}
                          </Button>
                          <Button
                            variant="ghost" size="sm"
                            className="text-red-600 hover:text-red-700 hover:bg-red-50"
                            disabled={actionLoading === m.id + '-reject'}
                            onClick={() => verify(m.id, false)}
                          >
                            {actionLoading === m.id + '-reject'
                              ? <Loader2 className="h-4 w-4 animate-spin" />
                              : <XCircle className="h-4 w-4" />}
                          </Button>
                        </>
                      )}
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      {/* Detail Dialog */}
      <Dialog open={detailOpen} onOpenChange={setDetailOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{selected?.name}</DialogTitle>
          </DialogHeader>
          {selected && (
            <div className="space-y-3 text-sm">
              {[
                ['Phone', selected.phone],
                ['Address', selected.address],
                ['Rating', `${selected.rating} (${selected.total_reviews} reviews)`],
                ['Joined', new Date(selected.created_at).toLocaleDateString('id-ID')],
              ].map(([label, value]) => (
                <div key={label} className="flex justify-between">
                  <span className="text-muted-foreground">{label}</span>
                  <span>{value}</span>
                </div>
              ))}
              <div className="flex justify-between items-center">
                <span className="text-muted-foreground">Status</span>
                <Badge variant={selected.is_verified ? 'secondary' : 'destructive'}>
                  {selected.is_verified ? 'Verified' : 'Pending Verification'}
                </Badge>
              </div>
            </div>
          )}
          <DialogFooter>
            {selected && !selected.is_verified && (
              <div className="flex gap-2">
                <Button
                  className="bg-green-600 hover:bg-green-700"
                  disabled={!!actionLoading}
                  onClick={async () => { await verify(selected.id, true); setDetailOpen(false) }}
                >
                  <CheckCircle className="mr-2 h-4 w-4" /> Approve
                </Button>
                <Button
                  variant="destructive"
                  disabled={!!actionLoading}
                  onClick={async () => { await verify(selected.id, false); setDetailOpen(false) }}
                >
                  <XCircle className="mr-2 h-4 w-4" /> Reject
                </Button>
              </div>
            )}
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
