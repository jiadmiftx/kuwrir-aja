import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { ArrowLeft, Loader2, Package, MapPin, ShieldCheck, RotateCcw } from 'lucide-react'

import { apiFetch as api } from '@/lib/api'

const fmt = (v: number | undefined) => 'Rp ' + (v ?? 0).toLocaleString('id-ID')
const fmtDate = (d?: string | null) => d ? new Date(d).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' }) : '-'
const fmtDateTime = (d?: string | null) => d ? new Date(d).toLocaleString('id-ID', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '-'

const orderStatusColor: Record<string, string> = {
  pending: 'bg-yellow-100 text-yellow-800',
  confirmed: 'bg-blue-100 text-blue-800',
  preparing: 'bg-purple-100 text-purple-800',
  ready: 'bg-indigo-100 text-indigo-800',
  picked_up: 'bg-cyan-100 text-cyan-800',
  delivered: 'bg-green-100 text-green-800',
  cancelled: 'bg-red-100 text-red-800',
}

const refundStatusBadge = (status: string) => {
  if (status === 'approved') return <Badge variant="secondary" className="bg-green-100 text-green-800">Disetujui</Badge>
  if (status === 'rejected') return <Badge variant="destructive">Ditolak</Badge>
  return <Badge variant="secondary" className="bg-yellow-100 text-yellow-800">Pending</Badge>
}

interface Customer {
  id: string
  name: string
  phone: string
  email?: string
  avatar_url?: string
  is_active: boolean
  phone_verified_at?: string | null
  created_at: string
}

interface SavedAddress {
  id: string
  label: string
  address: string
  detail?: string
  latitude?: number
  longitude?: number
  is_default?: boolean
}

interface Order {
  id: string
  order_number: string
  status: string
  total: number
  subtotal: number
  created_at: string
  delivered_at?: string | null
  driver_id?: string | null
}

interface RefundRequest {
  id: string
  order_id: string
  reason: string
  amount: number
  status: 'pending' | 'approved' | 'rejected'
  created_at: string
}

interface CustomerDetail {
  customer: Customer
  addresses: SavedAddress[]
  orders: Order[]
  total_orders: number
  total_spent: number
  refunds: RefundRequest[]
}

export default function CustomerDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [data, setData] = useState<CustomerDetail | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!id) return
    setIsLoading(true)
    api(`/api/v1/admin/customers/${id}`)
      .then(async res => {
        const body = await res.json()
        if (res.ok) setData(body)
        else setError(body.error || 'Gagal memuat detail customer')
      })
      .catch(() => setError('Gagal memuat detail customer'))
      .finally(() => setIsLoading(false))
  }, [id])

  if (isLoading) {
    return <div className="flex justify-center py-16"><Loader2 className="h-6 w-6 animate-spin" /></div>
  }
  if (error || !data) {
    return (
      <div className="space-y-4">
        <Button variant="ghost" size="sm" onClick={() => navigate(-1)}>
          <ArrowLeft className="h-4 w-4 mr-1" /> Kembali
        </Button>
        <p className="text-sm text-red-600">{error || 'Customer tidak ditemukan'}</p>
      </div>
    )
  }

  const { customer: c, total_orders, total_spent } = data
  const addresses = data.addresses ?? []
  const orders = data.orders ?? []
  const refunds = data.refunds ?? []

  return (
    <div className="space-y-6">
      <Button variant="ghost" size="sm" onClick={() => navigate(-1)}>
        <ArrowLeft className="h-4 w-4 mr-1" /> Kembali
      </Button>

      {/* Header card */}
      <Card>
        <CardContent className="pt-6">
          <div className="flex items-start gap-4">
            <img
              src={c.avatar_url || '/placeholder-avatar.png'}
              alt={c.name}
              className="h-16 w-16 rounded-full object-cover border shrink-0"
              onError={e => { (e.target as HTMLImageElement).style.visibility = 'hidden' }}
            />
            <div className="flex-1 space-y-2">
              <div className="flex flex-wrap items-center gap-2">
                <h2 className="text-2xl font-bold tracking-tight">{c.name}</h2>
                <Badge variant={c.is_active ? 'default' : 'secondary'}>{c.is_active ? 'Active' : 'Suspended'}</Badge>
                {c.phone_verified_at && (
                  <Badge variant="outline" className="text-green-600 border-green-300">
                    <ShieldCheck className="h-3 w-3 mr-1" /> Terverifikasi
                  </Badge>
                )}
              </div>
              <div className="flex items-center gap-4 text-sm text-muted-foreground">
                <span>{c.phone}</span>
                {c.email && <span>{c.email}</span>}
                <span>Bergabung {fmtDate(c.created_at)}</span>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      <Tabs defaultValue="ringkasan">
        <TabsList>
          <TabsTrigger value="ringkasan">Ringkasan</TabsTrigger>
          <TabsTrigger value="alamat">Alamat Tersimpan</TabsTrigger>
          <TabsTrigger value="pesanan">Pesanan</TabsTrigger>
          <TabsTrigger value="refund">Refund</TabsTrigger>
        </TabsList>

        {/* Ringkasan */}
        <TabsContent value="ringkasan" className="mt-4 space-y-4">
          <div className="grid gap-4 md:grid-cols-2">
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">Total Pesanan</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">{total_orders}</div>
                <p className="text-xs text-muted-foreground mt-1">sepanjang waktu</p>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">Total Belanja</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold text-green-600">{fmt(total_spent)}</div>
                <p className="text-xs text-muted-foreground mt-1">dari order delivered</p>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Alamat */}
        <TabsContent value="alamat" className="mt-4">
          <Card>
            <CardHeader><CardTitle className="text-base flex items-center gap-2"><MapPin className="h-4 w-4" /> Alamat Tersimpan</CardTitle></CardHeader>
            <CardContent>
              {addresses.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-4">Belum ada alamat tersimpan</p>
              ) : (
                <div className="space-y-3">
                  {addresses.map(a => (
                    <div key={a.id} className="rounded-lg border p-3">
                      <div className="flex items-center gap-2">
                        <span className="font-medium">{a.label}</span>
                        {a.is_default && <Badge variant="secondary" className="bg-blue-100 text-blue-800">Default</Badge>}
                      </div>
                      <p className="text-sm text-muted-foreground mt-1">{a.address}</p>
                      {a.detail && <p className="text-xs text-muted-foreground mt-0.5">{a.detail}</p>}
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Pesanan */}
        <TabsContent value="pesanan" className="mt-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between">
              <CardTitle className="text-base flex items-center gap-2"><Package className="h-4 w-4" /> Pesanan Terbaru</CardTitle>
              <span className="text-xs text-muted-foreground">Menampilkan {orders.length} dari {total_orders} pesanan</span>
            </CardHeader>
            <CardContent>
              {orders.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-4">Belum ada pesanan</p>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Order</TableHead>
                      <TableHead>Total</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Tanggal</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {orders.map(o => (
                      <TableRow key={o.id}>
                        <TableCell className="font-mono text-sm">{o.order_number}</TableCell>
                        <TableCell className="font-medium">{fmt(o.total)}</TableCell>
                        <TableCell>
                          <Badge className={orderStatusColor[o.status] ?? 'bg-gray-100 text-gray-800'}>{o.status}</Badge>
                        </TableCell>
                        <TableCell className="text-sm text-muted-foreground">{fmtDateTime(o.created_at)}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Refund */}
        <TabsContent value="refund" className="mt-4">
          <Card>
            <CardHeader><CardTitle className="text-base flex items-center gap-2"><RotateCcw className="h-4 w-4" /> Riwayat Refund</CardTitle></CardHeader>
            <CardContent>
              {refunds.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-4">Belum ada permintaan refund</p>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Order</TableHead>
                      <TableHead>Alasan</TableHead>
                      <TableHead>Jumlah</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Tanggal</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {refunds.map(r => (
                      <TableRow key={r.id}>
                        <TableCell className="font-mono text-sm">{r.order_id.slice(0, 8)}</TableCell>
                        <TableCell className="text-sm">{r.reason}</TableCell>
                        <TableCell className="font-medium">{fmt(r.amount)}</TableCell>
                        <TableCell>{refundStatusBadge(r.status)}</TableCell>
                        <TableCell className="text-sm text-muted-foreground">{fmtDate(r.created_at)}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}
