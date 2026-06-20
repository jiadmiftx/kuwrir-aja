import { useState, useEffect, useCallback } from 'react'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Separator } from '@/components/ui/separator'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { TrendingUp, ShoppingBag, Truck, Smartphone, RefreshCw } from 'lucide-react'

const token = () => localStorage.getItem('token')
const apiFetch = (path: string) =>
  fetch(path, { headers: { Authorization: `Bearer ${token()}` } })

const fmt = (n: number) => 'IDR ' + Math.round(n).toLocaleString('id-ID')

interface RevenueSummary {
  total_orders: number
  total_gmv: number
  platform_markup_total: number
  delivery_commission: number
  app_service_fee: number
  tax_collected: number
  total_platform_revenue: number
  merchant_payout_total: number
  driver_earning_total: number
}

interface DayRow {
  day: string
  orders: number
  revenue: number
  gmv: number
}

interface RefundRequest {
  id: string
  order_id: string
  reason: string
  amount: number
  status: string
  created_at: string
  Order?: { order_number: string; payment_type: string }
}

const periods = [
  { key: 'today', label: 'Hari Ini' },
  { key: 'week', label: '7 Hari' },
  { key: 'month', label: 'Bulan Ini' },
  { key: 'all', label: 'All Time' },
]

export default function RevenuePage() {
  const [period, setPeriod] = useState('month')
  const [summary, setSummary] = useState<RevenueSummary | null>(null)
  const [daily, setDaily] = useState<DayRow[]>([])
  const [refunds, setRefunds] = useState<RefundRequest[]>([])
  const [loading, setLoading] = useState(true)
  const [processingRefund, setProcessingRefund] = useState('')

  const fetchRevenue = useCallback(async () => {
    setLoading(true)
    try {
      const [revRes, refundRes] = await Promise.all([
        apiFetch(`/api/v1/admin/revenue?period=${period}`),
        apiFetch('/api/v1/admin/refunds?status=pending'),
      ])
      const revData = await revRes.json()
      const refundData = await refundRes.json()
      setSummary(revData.summary)
      setDaily(revData.daily || [])
      setRefunds(refundData.refunds || [])
    } catch (e) {
      console.error(e)
    } finally {
      setLoading(false)
    }
  }, [period])

  useEffect(() => { fetchRevenue() }, [fetchRevenue])

  const processRefund = async (id: string, approve: boolean) => {
    setProcessingRefund(id)
    try {
      const res = await fetch(`/api/v1/admin/refunds/${id}/process`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token()}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ approve, admin_note: approve ? 'Approved by admin' : 'Rejected by admin' }),
      })
      const data = await res.json()
      if (res.ok) {
        alert(data.message)
        fetchRevenue()
      } else {
        alert(data.error)
      }
    } catch {
      alert('Network error')
    } finally {
      setProcessingRefund('')
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Revenue</h2>
          <p className="text-muted-foreground">Platform earnings breakdown & refund management</p>
        </div>
        <Button variant="outline" size="sm" onClick={fetchRevenue} disabled={loading}>
          <RefreshCw className={`mr-2 h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>

      {/* Period Filter */}
      <div className="flex gap-2">
        {periods.map((p) => (
          <Button
            key={p.key}
            variant={period === p.key ? 'default' : 'outline'}
            size="sm"
            onClick={() => setPeriod(p.key)}
          >
            {p.label}
          </Button>
        ))}
      </div>

      {/* Summary Cards */}
      {summary && (
        <>
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            <Card>
              <CardHeader className="pb-2 flex flex-row items-center justify-between space-y-0">
                <CardTitle className="text-sm font-medium text-muted-foreground">Total GMV</CardTitle>
                <ShoppingBag className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-xl font-bold">{fmt(summary.total_gmv)}</div>
                <p className="text-xs text-muted-foreground">{summary.total_orders} orders</p>
              </CardContent>
            </Card>

            <Card className="border-primary/30">
              <CardHeader className="pb-2 flex flex-row items-center justify-between space-y-0">
                <CardTitle className="text-sm font-medium">KUWRIR Revenue</CardTitle>
                <TrendingUp className="h-4 w-4 text-primary" />
              </CardHeader>
              <CardContent>
                <div className="text-xl font-bold text-primary">{fmt(summary.total_platform_revenue)}</div>
                <p className="text-xs text-muted-foreground">
                  {summary.total_gmv > 0
                    ? ((summary.total_platform_revenue / summary.total_gmv) * 100).toFixed(1)
                    : 0}% dari GMV
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2 flex flex-row items-center justify-between space-y-0">
                <CardTitle className="text-sm font-medium text-muted-foreground">Merchant Payout</CardTitle>
                <ShoppingBag className="h-4 w-4 text-green-600" />
              </CardHeader>
              <CardContent>
                <div className="text-xl font-bold text-green-700">{fmt(summary.merchant_payout_total)}</div>
                <p className="text-xs text-muted-foreground">Harga asli produk ke merchant</p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2 flex flex-row items-center justify-between space-y-0">
                <CardTitle className="text-sm font-medium text-muted-foreground">Driver Earnings</CardTitle>
                <Truck className="h-4 w-4 text-blue-600" />
              </CardHeader>
              <CardContent>
                <div className="text-xl font-bold text-blue-700">{fmt(summary.driver_earning_total)}</div>
                <p className="text-xs text-muted-foreground">Driver share of delivery fee</p>
              </CardContent>
            </Card>
          </div>

          {/* Revenue Breakdown */}
          <Card>
            <CardHeader>
              <CardTitle>Revenue Breakdown</CardTitle>
              <CardDescription>Sumber pendapatan platform per komponen</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-3">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <ShoppingBag className="h-4 w-4 text-primary" />
                      <span className="text-sm">Ujrah Produk (markup %)</span>
                    </div>
                    <span className="font-bold">{fmt(summary.platform_markup_total)}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Truck className="h-4 w-4 text-orange-500" />
                      <span className="text-sm">Komisi Delivery</span>
                    </div>
                    <span className="font-bold">{fmt(summary.delivery_commission)}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Smartphone className="h-4 w-4 text-blue-500" />
                      <span className="text-sm">App Tech Fee</span>
                    </div>
                    <span className="font-bold">{fmt(summary.app_service_fee)}</span>
                  </div>
                  <Separator />
                  <div className="flex items-center justify-between font-bold text-primary">
                    <span>Total Platform Revenue</span>
                    <span>{fmt(summary.total_platform_revenue)}</span>
                  </div>
                </div>

                <div className="space-y-3">
                  <p className="text-sm font-medium text-muted-foreground">Distribusi Dana Customer</p>
                  {[
                    { label: 'Merchant (harga asli)', value: summary.merchant_payout_total, color: 'bg-green-500' },
                    { label: 'Driver Earnings', value: summary.driver_earning_total, color: 'bg-blue-500' },
                    { label: 'Platform Revenue', value: summary.total_platform_revenue, color: 'bg-primary' },
                  ].map((item) => {
                    const pct = summary.total_gmv > 0 ? (item.value / summary.total_gmv) * 100 : 0
                    return (
                      <div key={item.label} className="space-y-1">
                        <div className="flex justify-between text-sm">
                          <span>{item.label}</span>
                          <span>{pct.toFixed(1)}%</span>
                        </div>
                        <div className="h-2 rounded-full bg-muted overflow-hidden">
                          <div className={`h-full ${item.color} rounded-full`} style={{ width: `${pct}%` }} />
                        </div>
                      </div>
                    )
                  })}
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Daily Breakdown */}
          {daily.length > 0 && (
            <Card>
              <CardHeader>
                <CardTitle>Daily Revenue</CardTitle>
              </CardHeader>
              <CardContent>
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Tanggal</TableHead>
                      <TableHead className="text-right">Orders</TableHead>
                      <TableHead className="text-right">GMV</TableHead>
                      <TableHead className="text-right">Platform Revenue</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {daily.map((row) => (
                      <TableRow key={row.day}>
                        <TableCell>{row.day}</TableCell>
                        <TableCell className="text-right">{row.orders}</TableCell>
                        <TableCell className="text-right">{fmt(row.gmv)}</TableCell>
                        <TableCell className="text-right font-medium text-primary">{fmt(row.revenue)}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </CardContent>
            </Card>
          )}
        </>
      )}

      {/* Pending Refunds */}
      <Card>
        <CardHeader>
          <CardTitle>Pending Refund Requests</CardTitle>
          <CardDescription>Customer yang mengajukan refund — approve akan reverse wallet merchant</CardDescription>
        </CardHeader>
        <CardContent>
          {refunds.length === 0 ? (
            <p className="text-sm text-muted-foreground py-4 text-center">Tidak ada refund request pending.</p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Order</TableHead>
                  <TableHead>Alasan</TableHead>
                  <TableHead>Jumlah</TableHead>
                  <TableHead>Pembayaran</TableHead>
                  <TableHead>Tanggal</TableHead>
                  <TableHead>Aksi</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {refunds.map((r) => (
                  <TableRow key={r.id}>
                    <TableCell className="font-mono text-sm">{r.Order?.order_number || r.order_id.slice(0, 8)}</TableCell>
                    <TableCell className="max-w-48 truncate text-sm">{r.reason}</TableCell>
                    <TableCell className="font-medium">{fmt(r.amount)}</TableCell>
                    <TableCell>
                      <Badge variant={r.Order?.payment_type === 'cash' ? 'secondary' : 'default'}>
                        {r.Order?.payment_type === 'cash' ? 'COD (manual)' : 'Online'}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {new Date(r.created_at).toLocaleDateString('id-ID')}
                    </TableCell>
                    <TableCell>
                      <div className="flex gap-2">
                        <Button
                          size="sm"
                          variant="default"
                          disabled={processingRefund === r.id}
                          onClick={() => processRefund(r.id, true)}
                        >
                          Approve
                        </Button>
                        <Button
                          size="sm"
                          variant="outline"
                          disabled={processingRefund === r.id}
                          onClick={() => processRefund(r.id, false)}
                        >
                          Reject
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
