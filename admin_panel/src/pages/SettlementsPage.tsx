import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from '@/components/ui/dialog'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { TrendingUp, HandCoins, Store, CheckCircle, Loader2, RefreshCw } from 'lucide-react'

interface Summary {
  total_driver_cash: number
  total_platform_revenue: number
  pending_merchant_payout: number
}

interface PendingPayout {
  merchant_id: string
  merchant_name: string
  total_orders: number
  total_amount: number
}

interface Settlement {
  id: string
  merchant_id: string
  period_start: string
  period_end: string
  total_orders: number
  total_base_product_amount: number
  status: string
  paid_at: string | null
  reference: string
  merchant?: { name: string }
}

const api = (path: string, opts?: RequestInit) =>
  fetch(path, {
    headers: { Authorization: `Bearer ${localStorage.getItem('token')}`, 'Content-Type': 'application/json' },
    ...opts,
  })

const fmt = (v: number | undefined) => 'Rp ' + (v ?? 0).toLocaleString('id-ID')
const fmtDate = (d: string) => new Date(d).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })

export default function SettlementsPage() {
  const [summary, setSummary] = useState<Summary>({ total_driver_cash: 0, total_platform_revenue: 0, pending_merchant_payout: 0 })
  const [pending, setPending] = useState<PendingPayout[]>([])
  const [settlements, setSettlements] = useState<Settlement[]>([])
  const [loading, setLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState<string | null>(null)

  // Process payout dialog
  const [processTarget, setProcessTarget] = useState<PendingPayout | null>(null)
  const [periodStart, setPeriodStart] = useState('')
  const [periodEnd, setPeriodEnd] = useState('')
  const [reference, setReference] = useState('')

  // Mark paid dialog
  const [markPaidTarget, setMarkPaidTarget] = useState<Settlement | null>(null)
  const [paidRef, setPaidRef] = useState('')

  const fetchAll = async () => {
    setLoading(true)
    try {
      const [s1, s2] = await Promise.all([
        api('/api/v1/admin/settlements').then(r => r.json()),
        api('/api/v1/admin/settlements/merchants').then(r => r.json()),
      ])
      setSummary({ total_driver_cash: s1.total_driver_cash ?? 0, total_platform_revenue: s1.total_platform_revenue ?? 0, pending_merchant_payout: s1.pending_merchant_payout ?? 0 })
      setPending(s2.pending_payouts ?? [])
      setSettlements(s2.settlements ?? [])
    } finally { setLoading(false) }
  }

  useEffect(() => { fetchAll() }, [])

  const processSettlement = async () => {
    if (!processTarget || !periodStart || !periodEnd) return
    setActionLoading('process')
    try {
      const res = await api(`/api/v1/admin/settlements/merchants/${processTarget.merchant_id}/process`, {
        method: 'POST',
        body: JSON.stringify({ period_start: periodStart, period_end: periodEnd, reference }),
      })
      if (res.ok) { setProcessTarget(null); fetchAll() }
      else {
        const err = await res.json()
        alert(err.error || 'Gagal membuat settlement')
      }
    } finally { setActionLoading(null) }
  }

  const markPaid = async () => {
    if (!markPaidTarget) return
    setActionLoading('mark-paid')
    try {
      const res = await api(`/api/v1/admin/settlements/${markPaidTarget.id}/mark-paid`, {
        method: 'PUT',
        body: JSON.stringify({ reference: paidRef }),
      })
      if (res.ok) {
        setSettlements(prev => prev.map(s => s.id === markPaidTarget.id ? { ...s, status: 'paid', paid_at: new Date().toISOString(), reference: paidRef } : s))
        setMarkPaidTarget(null)
      }
    } finally { setActionLoading(null) }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Settlements</h2>
          <p className="text-muted-foreground">COD cash reconciliation & merchant payouts</p>
        </div>
        <Button variant="outline" onClick={fetchAll} disabled={loading}>
          <RefreshCw className={`h-4 w-4 mr-2 ${loading ? 'animate-spin' : ''}`} /> Refresh
        </Button>
      </div>

      {/* Summary KPIs */}
      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">Platform Revenue</CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">{fmt(summary.total_platform_revenue)}</div>
            <p className="text-xs text-muted-foreground mt-1">Total markup + komisi dari semua order delivered</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">Cash Held by Drivers</CardTitle>
            <HandCoins className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className={`text-2xl font-bold ${summary.total_driver_cash > 0 ? 'text-orange-600' : 'text-green-600'}`}>
              {fmt(summary.total_driver_cash)}
            </div>
            <p className="text-xs text-muted-foreground mt-1">Perlu disetor ke admin</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">Pending Merchant Payout</CardTitle>
            <Store className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className={`text-2xl font-bold ${summary.pending_merchant_payout > 0 ? 'text-blue-600' : 'text-muted-foreground'}`}>
              {fmt(summary.pending_merchant_payout)}
            </div>
            <p className="text-xs text-muted-foreground mt-1">Belum ditransfer ke merchant</p>
          </CardContent>
        </Card>
      </div>

      <Tabs defaultValue="payouts">
        <TabsList>
          <TabsTrigger value="payouts">Payout ke Merchant</TabsTrigger>
          <TabsTrigger value="history">Riwayat Settlement</TabsTrigger>
        </TabsList>

        {/* Pending payouts */}
        <TabsContent value="payouts" className="mt-4">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Merchant Belum Dibayar</CardTitle>
              <p className="text-sm text-muted-foreground">Hitung total order yang sudah delivered dan buat settlement</p>
            </CardHeader>
            <CardContent>
              {loading ? (
                <div className="text-center py-8"><Loader2 className="h-5 w-5 animate-spin mx-auto" /></div>
              ) : pending.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-4">Semua merchant sudah lunas</p>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Merchant</TableHead>
                      <TableHead>Total Orders</TableHead>
                      <TableHead>Total Amount</TableHead>
                      <TableHead className="text-right">Action</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {pending.map(p => (
                      <TableRow key={p.merchant_id}>
                        <TableCell className="font-medium">{p.merchant_name}</TableCell>
                        <TableCell>{p.total_orders} orders</TableCell>
                        <TableCell className="font-medium text-blue-600">{fmt(p.total_amount)}</TableCell>
                        <TableCell className="text-right">
                          <Button
                            size="sm"
                            onClick={() => {
                              setProcessTarget(p)
                              const now = new Date()
                              const firstDay = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().slice(0, 10)
                              const today = now.toISOString().slice(0, 10)
                              setPeriodStart(firstDay)
                              setPeriodEnd(today)
                              setReference('')
                            }}
                          >
                            <CheckCircle className="h-4 w-4 mr-1" /> Proses Payout
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

        {/* Settlement history */}
        <TabsContent value="history" className="mt-4">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Riwayat Settlement</CardTitle>
            </CardHeader>
            <CardContent>
              {loading ? (
                <div className="text-center py-8"><Loader2 className="h-5 w-5 animate-spin mx-auto" /></div>
              ) : settlements.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-4">Belum ada settlement</p>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Merchant</TableHead>
                      <TableHead>Periode</TableHead>
                      <TableHead>Orders</TableHead>
                      <TableHead>Amount</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead className="text-right">Action</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {settlements.map(s => (
                      <TableRow key={s.id}>
                        <TableCell className="font-medium">{s.merchant?.name ?? s.merchant_id.slice(0, 8)}</TableCell>
                        <TableCell className="text-sm text-muted-foreground">
                          {fmtDate(s.period_start)} — {fmtDate(s.period_end)}
                        </TableCell>
                        <TableCell>{s.total_orders}</TableCell>
                        <TableCell className="font-medium">{fmt(s.total_base_product_amount)}</TableCell>
                        <TableCell>
                          {s.status === 'paid'
                            ? <Badge variant="secondary" className="bg-green-100 text-green-800">Paid</Badge>
                            : <Badge variant="destructive">Pending</Badge>}
                          {s.paid_at && (
                            <div className="text-xs text-muted-foreground mt-1">{fmtDate(s.paid_at)}</div>
                          )}
                        </TableCell>
                        <TableCell className="text-right">
                          {s.status === 'pending' && (
                            <Button
                              size="sm" variant="outline"
                              className="text-green-600 border-green-300 hover:bg-green-50"
                              onClick={() => { setMarkPaidTarget(s); setPaidRef('') }}
                            >
                              Mark as Paid
                            </Button>
                          )}
                          {s.reference && (
                            <div className="text-xs text-muted-foreground mt-1">Ref: {s.reference}</div>
                          )}
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

      {/* Process payout dialog */}
      <Dialog open={!!processTarget} onOpenChange={v => { if (!v) setProcessTarget(null) }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Proses Payout — {processTarget?.merchant_name}</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div className="rounded-lg bg-muted p-3 space-y-1 text-sm">
              <div className="flex justify-between">
                <span className="text-muted-foreground">Total orders</span>
                <span className="font-medium">{processTarget?.total_orders}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Total amount</span>
                <span className="font-bold text-blue-600">{fmt(processTarget?.total_amount ?? 0)}</span>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label>Periode Mulai</Label>
                <Input type="date" value={periodStart} onChange={e => setPeriodStart(e.target.value)} />
              </div>
              <div className="space-y-1">
                <Label>Periode Selesai</Label>
                <Input type="date" value={periodEnd} onChange={e => setPeriodEnd(e.target.value)} />
              </div>
            </div>
            <div className="space-y-1">
              <Label>Nomor Referensi Transfer (opsional)</Label>
              <Input placeholder="e.g. TRF-BCA-20260601" value={reference} onChange={e => setReference(e.target.value)} />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setProcessTarget(null)}>Batal</Button>
            <Button
              disabled={!periodStart || !periodEnd || actionLoading === 'process'}
              onClick={processSettlement}
            >
              {actionLoading === 'process' && <Loader2 className="h-4 w-4 animate-spin mr-2" />}
              Buat Settlement
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Mark paid dialog */}
      <Dialog open={!!markPaidTarget} onOpenChange={v => { if (!v) setMarkPaidTarget(null) }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Konfirmasi Pembayaran</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 text-sm">
            <p>Tandai settlement <strong>{markPaidTarget?.merchant?.name}</strong> sebagai sudah dibayar?</p>
            <p className="font-bold text-lg text-green-600">{fmt(markPaidTarget?.total_base_product_amount ?? 0)}</p>
            <div className="space-y-1">
              <Label>Nomor Referensi Transfer</Label>
              <Input placeholder="e.g. TRF-BCA-20260601" value={paidRef} onChange={e => setPaidRef(e.target.value)} />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setMarkPaidTarget(null)}>Batal</Button>
            <Button
              className="bg-green-600 hover:bg-green-700"
              disabled={actionLoading === 'mark-paid'}
              onClick={markPaid}
            >
              {actionLoading === 'mark-paid' && <Loader2 className="h-4 w-4 animate-spin mr-2" />}
              Konfirmasi Lunas
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
