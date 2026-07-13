import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { ArrowLeft, Bike, Star, Loader2, Wallet, Package, HandCoins } from 'lucide-react'

import { apiFetch as api } from '@/lib/api'
import { DeleteUserAccountButton } from '@/components/DeleteUserAccountButton'

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

const categoryLabel: Record<string, string> = {
  order_earning: 'Pendapatan Order',
  withdrawal: 'Penarikan',
  refund: 'Refund',
  adjustment: 'Penyesuaian',
  cod_deposit: 'Setoran COD',
}

interface Driver {
  id: string
  vehicle_type: string
  vehicle_plate: string
  license_number?: string
  is_online: boolean
  is_available: boolean
  rating: number
  total_delivered: number
  cod_holding: number
  zone?: { city_name: string } | null
  user?: { id: string; name: string; phone: string; is_active?: boolean }
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

interface DriverDeposit {
  id: string
  amount: number
  method: 'cash' | 'bank_transfer'
  reference?: string
  verified_at: string
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
}

interface DriverDetail {
  driver: Driver
  wallet: { balance: number; total_earned: number; transactions: WalletTransaction[] }
  cod_holding: number
  deposits: DriverDeposit[]
  orders: Order[]
  total_delivered: number
}

export default function DriverDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [data, setData] = useState<DriverDetail | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!id) return
    setIsLoading(true)
    api(`/api/v1/admin/drivers/${id}`)
      .then(async res => {
        const body = await res.json()
        if (res.ok) setData(body)
        else setError(body.error || 'Gagal memuat detail driver')
      })
      .catch(() => setError('Gagal memuat detail driver'))
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
        <p className="text-sm text-red-600">{error || 'Driver tidak ditemukan'}</p>
      </div>
    )
  }

  const { driver: d, cod_holding, total_delivered } = data
  const wallet = data.wallet ?? { balance: 0, total_earned: 0, transactions: [] }
  const walletTxns = wallet.transactions ?? []
  const deposits = data.deposits ?? []
  const orders = data.orders ?? []

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <Button variant="ghost" size="sm" onClick={() => navigate(-1)}>
          <ArrowLeft className="h-4 w-4 mr-1" /> Kembali
        </Button>
        {d.user?.id && (
          <DeleteUserAccountButton userId={d.user.id} userName={d.user.name} onDeleted={() => navigate('/drivers')} />
        )}
      </div>

      {/* Header card */}
      <Card>
        <CardContent className="pt-6 space-y-2">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="text-2xl font-bold tracking-tight">{d.user?.name ?? '-'}</h2>
            <Badge variant={d.user?.is_active ? 'default' : 'secondary'}>
              {d.user?.is_active ? 'Active' : 'Suspended'}
            </Badge>
            {d.is_online && (
              <Badge variant="outline" className="text-green-600 border-green-300">Online</Badge>
            )}
            {d.is_available && d.is_online && (
              <Badge variant="outline" className="text-blue-600 border-blue-300">Available</Badge>
            )}
          </div>
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <Bike className="h-3.5 w-3.5" /> {d.vehicle_type} · {d.vehicle_plate}
            {d.license_number && <span>· SIM {d.license_number}</span>}
          </div>
          <div className="flex items-center gap-4 text-sm">
            <span className="flex items-center gap-1">
              <Star className="h-3.5 w-3.5 fill-yellow-400 text-yellow-400" />
              {d.rating > 0 ? d.rating.toFixed(1) : '-'}
            </span>
            <span className="text-muted-foreground">{d.user?.phone}</span>
            {d.zone?.city_name && <span className="text-muted-foreground">Wilayah: {d.zone.city_name}</span>}
          </div>
        </CardContent>
      </Card>

      <Tabs defaultValue="ringkasan">
        <TabsList>
          <TabsTrigger value="ringkasan">Ringkasan</TabsTrigger>
          <TabsTrigger value="wallet">Wallet</TabsTrigger>
          <TabsTrigger value="setoran">Setoran COD</TabsTrigger>
          <TabsTrigger value="pesanan">Pesanan</TabsTrigger>
        </TabsList>

        {/* Ringkasan */}
        <TabsContent value="ringkasan" className="mt-4 space-y-4">
          <div className="grid gap-4 md:grid-cols-2">
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">Cash COD Dipegang</CardTitle>
              </CardHeader>
              <CardContent>
                <div className={`text-3xl font-bold ${cod_holding > 0 ? 'text-red-600' : 'text-green-600'}`}>
                  {fmt(cod_holding)}
                </div>
                <p className="text-xs text-muted-foreground mt-1">belum disetor ke platform</p>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">Total Delivered</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">{total_delivered}</div>
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
              {walletTxns.length === 0 ? (
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
                    {walletTxns.map(t => (
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

        {/* Setoran COD */}
        <TabsContent value="setoran" className="mt-4">
          <Card>
            <CardHeader><CardTitle className="text-base flex items-center gap-2"><HandCoins className="h-4 w-4" /> Riwayat Setoran COD</CardTitle></CardHeader>
            <CardContent>
              {deposits.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-4">Belum ada setoran</p>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Tanggal</TableHead>
                      <TableHead>Jumlah</TableHead>
                      <TableHead>Metode</TableHead>
                      <TableHead>Referensi</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {deposits.map(dep => (
                      <TableRow key={dep.id}>
                        <TableCell className="text-sm text-muted-foreground">{fmtDate(dep.verified_at)}</TableCell>
                        <TableCell className="font-medium text-green-600">{fmt(dep.amount)}</TableCell>
                        <TableCell className="capitalize text-sm">{dep.method.replace('_', ' ')}</TableCell>
                        <TableCell className="text-sm text-muted-foreground">{dep.reference || '-'}</TableCell>
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
              <CardTitle className="text-base flex items-center gap-2"><Package className="h-4 w-4" /> Pengantaran Terbaru</CardTitle>
              <span className="text-xs text-muted-foreground">Menampilkan {orders.length} dari {total_delivered} pengantaran</span>
            </CardHeader>
            <CardContent>
              {orders.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-4">Belum ada pengantaran</p>
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
