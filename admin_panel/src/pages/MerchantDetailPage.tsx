import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { ArrowLeft, MapPin, Star, Loader2, Wallet, Package } from 'lucide-react'

import { apiFetch as api } from '@/lib/api'

const fmt = (v: number | undefined) => 'Rp ' + (v ?? 0).toLocaleString('id-ID')
const fmtDate = (d?: string | null) => d ? new Date(d).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' }) : '-'
const fmtDateTime = (d?: string | null) => d ? new Date(d).toLocaleString('id-ID', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '-'

// Shows a document image or a "no file" placeholder — mirrors MerchantsPage's
// DocImage so verification docs look consistent across both admin flows.
function DocImage({ url, label }: { url?: string; label: string }) {
  if (!url) return (
    <div className="space-y-1">
      <p className="text-xs font-medium text-muted-foreground">{label}</p>
      <div className="flex h-32 w-full items-center justify-center rounded border-2 border-dashed text-muted-foreground text-xs">
        tidak ada file
      </div>
    </div>
  )
  return (
    <div className="space-y-1">
      <p className="text-xs font-medium text-muted-foreground">{label}</p>
      <a href={url} target="_blank" rel="noreferrer">
        <img
          src={url}
          alt={label}
          className="h-32 w-full rounded border object-cover cursor-pointer hover:opacity-90 transition-opacity"
          onError={e => { (e.target as HTMLImageElement).style.display = 'none' }}
        />
      </a>
    </div>
  )
}

const orderStatusColor: Record<string, string> = {
  pending: 'bg-yellow-100 text-yellow-800',
  confirmed: 'bg-blue-100 text-blue-800',
  preparing: 'bg-purple-100 text-purple-800',
  ready: 'bg-indigo-100 text-indigo-800',
  picked_up: 'bg-cyan-100 text-cyan-800',
  delivered: 'bg-green-100 text-green-800',
  cancelled: 'bg-red-100 text-red-800',
}

interface Merchant {
  id: string
  name: string
  slug?: string
  description?: string
  phone: string
  logo_url?: string
  banner_url?: string
  address: string
  latitude?: number
  longitude?: number
  rating: number
  total_reviews: number
  is_active: boolean
  is_verified: boolean
  is_open: boolean
  tax_enabled?: boolean
  tax_rate?: number | null
  zone?: { city_name: string } | null
  user?: { name: string; phone: string; email?: string }
  owner_ktp_url?: string
  business_license_url?: string
  store_photo_url?: string
}

interface WalletTransaction {
  id: string
  created_at: string
  type: 'credit' | 'debit'
  category: string
  amount: number
  balance_after: number
  order_id?: string
}

interface MerchantSettlement {
  id: string
  period_start: string
  period_end: string
  total_orders: number
  total_base_product_amount: number
  status: 'pending' | 'paid'
  paid_at?: string | null
  reference?: string
}

interface MerchantReceivable {
  id: string
  amount: number
  paid_amount: number
  status: 'unpaid' | 'partial' | 'paid'
  customer_name?: string
  created_at?: string
}

interface MerchantPayable {
  id: string
  supplier_name: string
  amount: number
  paid_amount: number
  status: 'unpaid' | 'partial' | 'paid'
  created_at?: string
}

interface Order {
  id: string
  order_number: string
  status: string
  total: number
  subtotal: number
  created_at: string
  delivered_at?: string | null
  customer_id?: string
  driver_id?: string | null
}

interface MerchantDetail {
  merchant: Merchant
  wallet: { balance: number; total_earned: number; transactions: WalletTransaction[] }
  pending_payout: { total_orders: number; total_amount: number }
  settlements: MerchantSettlement[]
  receivables: MerchantReceivable[]
  payables: MerchantPayable[]
  orders: Order[]
  total_orders: number
}

const categoryLabel: Record<string, string> = {
  order_earning: 'Pendapatan Order',
  withdrawal: 'Penarikan',
  refund: 'Refund',
  adjustment: 'Penyesuaian',
  cod_deposit: 'Setoran COD',
}

const receivablePayableStatusBadge = (status: string) => {
  if (status === 'paid') return <Badge variant="secondary" className="bg-green-100 text-green-800">Lunas</Badge>
  if (status === 'partial') return <Badge variant="secondary" className="bg-yellow-100 text-yellow-800">Sebagian</Badge>
  return <Badge variant="destructive">Belum Bayar</Badge>
}

export default function MerchantDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [data, setData] = useState<MerchantDetail | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!id) return
    setIsLoading(true)
    api(`/api/v1/admin/merchants/${id}`)
      .then(async res => {
        const body = await res.json()
        if (res.ok) setData(body)
        else setError(body.error || 'Gagal memuat detail merchant')
      })
      .catch(() => setError('Gagal memuat detail merchant'))
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
        <p className="text-sm text-red-600">{error || 'Merchant tidak ditemukan'}</p>
      </div>
    )
  }

  const { merchant: m, wallet, pending_payout, settlements, receivables, payables, orders, total_orders } = data

  return (
    <div className="space-y-6">
      <Button variant="ghost" size="sm" onClick={() => navigate(-1)}>
        <ArrowLeft className="h-4 w-4 mr-1" /> Kembali
      </Button>

      {/* Header card */}
      <Card>
        <CardContent className="pt-6">
          <div className="flex flex-col md:flex-row gap-4 md:items-start">
            <img
              src={m.logo_url || '/placeholder-store.png'}
              alt={m.name}
              className="h-20 w-20 rounded-lg object-cover border shrink-0"
              onError={e => { (e.target as HTMLImageElement).style.visibility = 'hidden' }}
            />
            <div className="flex-1 space-y-2">
              <div className="flex flex-wrap items-center gap-2">
                <h2 className="text-2xl font-bold tracking-tight">{m.name}</h2>
                {m.is_verified
                  ? <Badge variant="secondary" className="bg-green-100 text-green-800">Verified</Badge>
                  : <Badge variant="destructive">Pending Verifikasi</Badge>}
                <Badge variant={m.is_active ? 'default' : 'secondary'}>{m.is_active ? 'Active' : 'Nonaktif'}</Badge>
                <Badge variant={m.is_open ? 'default' : 'secondary'}>{m.is_open ? 'Open' : 'Closed'}</Badge>
                {m.tax_enabled && (
                  <Badge variant="secondary" className="bg-blue-100 text-blue-800">
                    PKP {m.tax_rate != null ? `${m.tax_rate}%` : '(default)'}
                  </Badge>
                )}
              </div>
              <div className="flex items-center gap-1 text-sm text-muted-foreground">
                <MapPin className="h-3.5 w-3.5 shrink-0" /> {m.address}
                {m.zone?.city_name && <span className="ml-1">· {m.zone.city_name}</span>}
              </div>
              <div className="flex items-center gap-4 text-sm">
                <span className="flex items-center gap-1">
                  <Star className="h-3.5 w-3.5 fill-yellow-400 text-yellow-400" />
                  {m.rating > 0 ? m.rating.toFixed(1) : '-'}
                  <span className="text-muted-foreground">({m.total_reviews})</span>
                </span>
                <span className="text-muted-foreground">{m.phone}</span>
                {m.user?.email && <span className="text-muted-foreground">{m.user.email}</span>}
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mt-6">
            <DocImage url={m.owner_ktp_url} label="KTP Pemilik" />
            <DocImage url={m.store_photo_url} label="Foto Toko" />
            <DocImage url={m.business_license_url} label="Izin Usaha" />
          </div>
        </CardContent>
      </Card>

      <Tabs defaultValue="ringkasan">
        <TabsList>
          <TabsTrigger value="ringkasan">Ringkasan</TabsTrigger>
          <TabsTrigger value="wallet">Wallet</TabsTrigger>
          <TabsTrigger value="settlement">Settlement</TabsTrigger>
          <TabsTrigger value="hutang-piutang">Piutang/Hutang</TabsTrigger>
          <TabsTrigger value="pesanan">Pesanan</TabsTrigger>
        </TabsList>

        {/* Ringkasan */}
        <TabsContent value="ringkasan" className="mt-4 space-y-4">
          <div className="grid gap-4 md:grid-cols-2">
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">Belum Dibayar Platform</CardTitle>
              </CardHeader>
              <CardContent>
                <div className={`text-3xl font-bold ${pending_payout.total_amount > 0 ? 'text-blue-600' : 'text-muted-foreground'}`}>
                  {fmt(pending_payout.total_amount)}
                </div>
                <p className="text-xs text-muted-foreground mt-1">
                  {pending_payout.total_orders} order delivered belum di-settle
                </p>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">Total Pesanan</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">{total_orders}</div>
                <p className="text-xs text-muted-foreground mt-1">sepanjang waktu</p>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Wallet */}
        <TabsContent value="wallet" className="mt-4 space-y-4">
          <div className="grid gap-4 md:grid-cols-2">
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground flex items-center gap-2">
                  <Wallet className="h-4 w-4" /> Saldo Wallet
                </CardTitle>
              </CardHeader>
              <CardContent><div className="text-2xl font-bold">{fmt(wallet.balance)}</div></CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">Total Pendapatan</CardTitle>
              </CardHeader>
              <CardContent><div className="text-2xl font-bold text-green-600">{fmt(wallet.total_earned)}</div></CardContent>
            </Card>
          </div>
          <Card>
            <CardHeader><CardTitle className="text-base">Riwayat Transaksi Wallet</CardTitle></CardHeader>
            <CardContent>
              {wallet.transactions.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-4">Belum ada transaksi</p>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Tanggal</TableHead>
                      <TableHead>Kategori</TableHead>
                      <TableHead>Jumlah</TableHead>
                      <TableHead>Saldo Setelah</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {wallet.transactions.map(t => (
                      <TableRow key={t.id}>
                        <TableCell className="text-sm text-muted-foreground">{fmtDateTime(t.created_at)}</TableCell>
                        <TableCell className="text-sm">{categoryLabel[t.category] ?? t.category}</TableCell>
                        <TableCell className={`font-medium ${t.type === 'credit' ? 'text-green-600' : 'text-red-600'}`}>
                          {t.type === 'credit' ? '+' : '-'}{fmt(t.amount)}
                        </TableCell>
                        <TableCell className="text-sm">{fmt(t.balance_after)}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Settlement */}
        <TabsContent value="settlement" className="mt-4">
          <Card>
            <CardHeader><CardTitle className="text-base">Riwayat Settlement</CardTitle></CardHeader>
            <CardContent>
              {settlements.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-4">Belum ada settlement</p>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Periode</TableHead>
                      <TableHead>Orders</TableHead>
                      <TableHead>Jumlah</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Referensi</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {settlements.map(s => (
                      <TableRow key={s.id}>
                        <TableCell className="text-sm text-muted-foreground">
                          {fmtDate(s.period_start)} — {fmtDate(s.period_end)}
                        </TableCell>
                        <TableCell>{s.total_orders}</TableCell>
                        <TableCell className="font-medium">{fmt(s.total_base_product_amount)}</TableCell>
                        <TableCell>
                          {s.status === 'paid'
                            ? <Badge variant="secondary" className="bg-green-100 text-green-800">Paid</Badge>
                            : <Badge variant="destructive">Pending</Badge>}
                          {s.paid_at && <div className="text-xs text-muted-foreground mt-1">{fmtDate(s.paid_at)}</div>}
                        </TableCell>
                        <TableCell className="text-sm text-muted-foreground">{s.reference || '-'}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Piutang / Hutang */}
        <TabsContent value="hutang-piutang" className="mt-4 space-y-4">
          <p className="text-sm text-muted-foreground">
            Pembukuan pribadi merchant (POS) — bukan uang platform. Piutang = pelanggan yang berutang ke
            merchant (tab/bon), Hutang = merchant berutang ke supplier.
          </p>
          <Card>
            <CardHeader><CardTitle className="text-base">Piutang (Pelanggan Berutang ke Merchant)</CardTitle></CardHeader>
            <CardContent>
              {receivables.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-4">Tidak ada piutang</p>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Pelanggan</TableHead>
                      <TableHead>Jumlah</TableHead>
                      <TableHead>Dibayar</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Tanggal</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {receivables.map(r => (
                      <TableRow key={r.id}>
                        <TableCell>{r.customer_name || '-'}</TableCell>
                        <TableCell className="font-medium">{fmt(r.amount)}</TableCell>
                        <TableCell>{fmt(r.paid_amount)}</TableCell>
                        <TableCell>{receivablePayableStatusBadge(r.status)}</TableCell>
                        <TableCell className="text-sm text-muted-foreground">{fmtDate(r.created_at)}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle className="text-base">Hutang (Merchant Berutang ke Supplier)</CardTitle></CardHeader>
            <CardContent>
              {payables.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-4">Tidak ada hutang</p>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Supplier</TableHead>
                      <TableHead>Jumlah</TableHead>
                      <TableHead>Dibayar</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Tanggal</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {payables.map(p => (
                      <TableRow key={p.id}>
                        <TableCell>{p.supplier_name}</TableCell>
                        <TableCell className="font-medium">{fmt(p.amount)}</TableCell>
                        <TableCell>{fmt(p.paid_amount)}</TableCell>
                        <TableCell>{receivablePayableStatusBadge(p.status)}</TableCell>
                        <TableCell className="text-sm text-muted-foreground">{fmtDate(p.created_at)}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
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
      </Tabs>
    </div>
  )
}
