import { useEffect, useState } from 'react'
import { ShoppingBag, Store, Bike, Users, DollarSign, Wallet, RefreshCw } from 'lucide-react'
import { apiFetch } from '@/lib/api'

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
  const [updatedAt, setUpdatedAt] = useState<Date | null>(null)

  const fetchStats = async () => {
    setLoading(true)
    try {
      const res = await apiFetch('/api/v1/admin/dashboard/stats')
      if (res.ok) {
        setStats(await res.json())
        setUpdatedAt(new Date())
      }
    } catch (e) {
      console.error(e)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchStats() }, [])

  const operational = stats
    ? [
        {
          label: 'Order',
          value: stats.orders.total.toLocaleString('id-ID'),
          caption: `${stats.orders.today} hari ini · ${stats.orders.active} aktif`,
          icon: ShoppingBag,
        },
        {
          label: 'Merchant aktif',
          value: stats.merchants.verified.toLocaleString('id-ID'),
          caption: `${stats.merchants.open} sedang buka`,
          icon: Store,
        },
        {
          label: 'Driver',
          value: stats.drivers.total.toLocaleString('id-ID'),
          caption: `${stats.drivers.online} online`,
          icon: Bike,
        },
        {
          label: 'Customer',
          value: stats.customers.total.toLocaleString('id-ID'),
          caption: 'terdaftar',
          icon: Users,
        },
      ]
    : []

  return (
    <div className="max-w-6xl space-y-8">
      {/* Header */}
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight text-foreground">Dashboard</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Ringkasan operasional Cocourir — Kuta, Lombok
          </p>
        </div>
        <button
          onClick={fetchStats}
          disabled={loading}
          className="flex items-center gap-2 rounded-full border border-border px-3.5 py-1.5 text-xs font-medium text-muted-foreground transition-colors hover:border-foreground/20 hover:text-foreground disabled:opacity-60"
        >
          <RefreshCw className={`h-3.5 w-3.5 ${loading ? 'animate-spin' : ''}`} />
          {updatedAt
            ? `Diperbarui ${updatedAt.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}`
            : 'Muat ulang'}
        </button>
      </div>

      {/* Attention notice — one soft line, not an alarm */}
      {stats && stats.merchants.pending > 0 && (
        <a
          href="/merchants"
          className="flex items-center gap-3 rounded-xl border border-primary/25 bg-primary/[0.07] px-4 py-3 text-sm text-foreground transition-colors hover:bg-primary/[0.11]"
        >
          <span className="h-2 w-2 shrink-0 rounded-full bg-primary" />
          <span className="flex-1">
            <strong className="font-semibold">{stats.merchants.pending} merchant</strong> menunggu verifikasi
          </span>
          <span className="font-medium text-primary">Lihat sekarang →</span>
        </a>
      )}

      {/* Operational rail — one instrument panel, not six repeated cards */}
      <div className="overflow-hidden rounded-2xl border border-border bg-card">
        {loading && !stats ? (
          <div className="grid grid-cols-2 divide-x divide-y divide-border lg:grid-cols-4 lg:divide-y-0">
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="space-y-3 p-5">
                <div className="h-3 w-20 animate-pulse rounded bg-muted" />
                <div className="h-7 w-16 animate-pulse rounded bg-muted" />
              </div>
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-2 divide-x divide-y divide-border lg:grid-cols-4 lg:divide-y-0">
            {operational.map((o) => (
              <div key={o.label} className="p-5">
                <div className="flex items-center gap-2 text-muted-foreground">
                  <o.icon className="h-3.5 w-3.5" />
                  <span className="text-xs font-medium tracking-wide">{o.label}</span>
                </div>
                <div className="mt-2 text-2xl font-semibold tracking-tight tabular-nums text-foreground">
                  {o.value}
                </div>
                <div className="mt-0.5 text-xs text-muted-foreground">{o.caption}</div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Financial summary — the money story, told once, clearly */}
      {stats && (
        <div className="rounded-2xl border border-border bg-card p-6">
          <h2 className="text-sm font-medium text-muted-foreground">Keuangan bulan ini</h2>
          <div className="mt-4 grid gap-6 sm:grid-cols-2">
            <div className="flex items-start gap-3.5">
              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
                <DollarSign className="h-4 w-4" />
              </div>
              <div>
                <div className="text-xl font-semibold tracking-tight tabular-nums text-foreground">
                  {fmt(stats.revenue.this_month)}
                </div>
                <div className="text-xs text-muted-foreground">Revenue platform (markup + komisi)</div>
              </div>
            </div>
            <div className="flex items-start gap-3.5">
              <div
                className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full ${
                  stats.pending_driver_cash > 0
                    ? 'bg-destructive/10 text-destructive'
                    : 'bg-success/10 text-success'
                }`}
              >
                <Wallet className="h-4 w-4" />
              </div>
              <div>
                <div className="text-xl font-semibold tracking-tight tabular-nums text-foreground">
                  {fmt(stats.pending_driver_cash)}
                </div>
                <div className="text-xs text-muted-foreground">
                  {stats.pending_driver_cash > 0
                    ? 'Cash COD belum disetor driver'
                    : 'Semua cash COD sudah disetor'}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
