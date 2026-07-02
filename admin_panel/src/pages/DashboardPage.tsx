import { useEffect, useState } from 'react'
import { type VariantProps } from 'class-variance-authority'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { badgeVariants } from '@/components/ui/badge-variants'
import {
  ShoppingBag, Store, Bike, Users, TrendingUp, DollarSign,
  Clock, AlertCircle,
} from 'lucide-react'
import { apiFetch } from '@/lib/api'

type BadgeVariant = VariantProps<typeof badgeVariants>['variant']

interface Stats {
  orders: { total: number; today: number; active: number }
  merchants: { total: number; verified: number; open: number; pending: number }
  drivers: { total: number; online: number }
  customers: { total: number }
  revenue: { this_month: number }
  pending_driver_cash: number
}

function fmt(v: number | undefined) {
  return 'Rp ' + (v ?? 0).toLocaleString('id-ID')
}

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats | null>(null)
  const [loading, setLoading] = useState(true)

  const fetchStats = async () => {
    try {
      const res = await apiFetch('/api/v1/admin/dashboard/stats')
      if (res.ok) setStats(await res.json())
    } catch (e) {
      console.error(e)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchStats() }, [])

  const kpis = stats
    ? [
        {
          title: 'Total Orders',
          value: stats.orders.total.toLocaleString(),
          sub: `${stats.orders.today} hari ini`,
          badge: `${stats.orders.active} aktif`,
          icon: ShoppingBag,
          color: 'text-blue-600',
        },
        {
          title: 'Active Merchants',
          value: stats.merchants.verified.toString(),
          sub: `${stats.merchants.open} sedang buka`,
          badge: stats.merchants.pending > 0 ? `${stats.merchants.pending} pending` : 'Semua terverifikasi',
          badgeVariant: stats.merchants.pending > 0 ? 'destructive' : 'secondary',
          icon: Store,
          color: 'text-green-600',
        },
        {
          title: 'Active Drivers',
          value: stats.drivers.total.toString(),
          sub: 'terdaftar',
          badge: `${stats.drivers.online} online`,
          icon: Bike,
          color: 'text-purple-600',
        },
        {
          title: 'Customers',
          value: stats.customers.total.toLocaleString(),
          sub: 'registered',
          badge: '+0',
          icon: Users,
          color: 'text-orange-600',
        },
        {
          title: 'Platform Revenue',
          value: fmt(stats.revenue.this_month),
          sub: 'bulan ini',
          badge: 'markup + komisi',
          icon: DollarSign,
          color: 'text-emerald-600',
        },
        {
          title: 'Cash Held by Drivers',
          value: fmt(stats.pending_driver_cash),
          sub: 'belum disetor ke admin',
          badge: 'COD pending',
          badgeVariant: stats.pending_driver_cash > 0 ? 'destructive' : 'secondary',
          icon: TrendingUp,
          color: stats.pending_driver_cash > 0 ? 'text-red-600' : 'text-gray-400',
        },
      ]
    : []

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Dashboard</h2>
          <p className="text-muted-foreground">Cocourir Admin — Lombok</p>
        </div>
        <button
          onClick={fetchStats}
          className="text-sm text-muted-foreground hover:text-foreground transition-colors"
        >
          Refresh
        </button>
      </div>

      {/* Pending merchant alert */}
      {stats && stats.merchants.pending > 0 && (
        <div className="flex items-center gap-3 rounded-lg border border-orange-200 bg-orange-50 px-4 py-3 text-orange-800 dark:border-orange-800 dark:bg-orange-950 dark:text-orange-200">
          <AlertCircle className="h-4 w-4 shrink-0" />
          <span className="text-sm">
            <strong>{stats.merchants.pending} merchant</strong> menunggu verifikasi.{' '}
            <a href="/merchants" className="underline font-medium">Lihat sekarang →</a>
          </span>
        </div>
      )}

      {/* KPI Cards */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {loading
          ? Array.from({ length: 6 }).map((_, i) => (
              <Card key={i} className="animate-pulse">
                <CardHeader className="pb-2">
                  <div className="h-4 w-24 rounded bg-muted" />
                </CardHeader>
                <CardContent>
                  <div className="h-8 w-32 rounded bg-muted" />
                </CardContent>
              </Card>
            ))
          : kpis.map((k) => (
              <Card key={k.title}>
                <CardHeader className="flex flex-row items-center justify-between pb-2">
                  <CardTitle className="text-sm font-medium text-muted-foreground">
                    {k.title}
                  </CardTitle>
                  <k.icon className={`h-4 w-4 ${k.color}`} />
                </CardHeader>
                <CardContent>
                  <div className={`text-2xl font-bold ${k.color}`}>{k.value}</div>
                  <div className="flex items-center gap-2 pt-1">
                    <Badge
                      variant={(k.badgeVariant as BadgeVariant | undefined) ?? 'secondary'}
                      className="text-xs"
                    >
                      {k.badge}
                    </Badge>
                    <span className="text-xs text-muted-foreground">{k.sub}</span>
                  </div>
                </CardContent>
              </Card>
            ))}
      </div>

      {/* Quick info row */}
      {stats && (
        <div className="grid gap-4 md:grid-cols-2">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="flex items-center gap-2 text-base">
                <Clock className="h-4 w-4" /> Order Status Aktif
              </CardTitle>
            </CardHeader>
            <CardContent className="text-sm text-muted-foreground">
              {stats.orders.active > 0
                ? `${stats.orders.active} order sedang dalam proses (pending → delivering)`
                : 'Tidak ada order aktif saat ini.'}
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="flex items-center gap-2 text-base">
                <DollarSign className="h-4 w-4" /> COD Summary
              </CardTitle>
            </CardHeader>
            <CardContent className="text-sm space-y-1">
              <div className="flex justify-between">
                <span className="text-muted-foreground">Cash di driver</span>
                <span className={`font-medium ${stats.pending_driver_cash > 0 ? 'text-red-600' : 'text-green-600'}`}>
                  {fmt(stats.pending_driver_cash)}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Revenue platform</span>
                <span className="font-medium text-emerald-600">{fmt(stats.revenue.this_month)}</span>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  )
}
