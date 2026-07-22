import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  ShoppingBag, Store, Bike, Users, DollarSign, Wallet, RefreshCw, ClipboardList, RotateCcw,
  CreditCard, Banknote, Trophy, Utensils,
} from 'lucide-react'
import { apiFetch } from '@/lib/api'

interface RecentOrder {
  id: string
  order_number: string
  status: string
  total: number
  created_at: string
  merchant?: { name: string }
}

interface TopMerchant {
  merchant_id: string
  name: string
  order_count: number
}

interface TopProduct {
  item_name: string
  quantity: number
}

interface Stats {
  orders: { total: number; today: number; active: number }
  merchants: { total: number; verified: number; open: number; pending: number }
  drivers: { total: number; online: number }
  customers: { total: number }
  revenue: { this_month: number; this_month_gateway: number; this_month_cash: number }
  pending_driver_cash: number
  driver_applications_pending: number
  refunds_pending: number
  recent_orders: RecentOrder[]
  top_merchants: TopMerchant[]
  top_products: TopProduct[]
}

function fmt(v: number | undefined) {
  return 'Rp ' + (v ?? 0).toLocaleString('id-ID')
}

function timeAgo(iso: string): string {
  const diffMs = Date.now() - new Date(iso).getTime()
  const min = Math.floor(diffMs / 60000)
  if (min < 1) return 'baru saja'
  if (min < 60) return `${min} menit lalu`
  const hr = Math.floor(min / 60)
  if (hr < 24) return `${hr} jam lalu`
  return `${Math.floor(hr / 24)} hari lalu`
}

const statusMeta: Record<string, { label: string; className: string }> = {
  pending: { label: 'Menunggu', className: 'bg-primary/10 text-primary' },
  confirmed: { label: 'Dikonfirmasi', className: 'bg-primary/10 text-primary' },
  preparing: { label: 'Disiapkan', className: 'bg-primary/10 text-primary' },
  ready: { label: 'Siap diambil', className: 'bg-primary/10 text-primary' },
  picked_up: { label: 'Diantar', className: 'bg-primary/10 text-primary' },
  delivered: { label: 'Selesai', className: 'bg-success/10 text-success' },
  cancelled: { label: 'Dibatalkan', className: 'bg-destructive/10 text-destructive' },
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
        const data = await res.json()
        // Defaults for fields a not-yet-redeployed backend won't have yet,
        // so this never hard-crashes the page mid-rollout.
        setStats({
          ...data,
          driver_applications_pending: data.driver_applications_pending ?? 0,
          refunds_pending: data.refunds_pending ?? 0,
          recent_orders: data.recent_orders ?? [],
          top_merchants: data.top_merchants ?? [],
          top_products: data.top_products ?? [],
          revenue: {
            this_month: data.revenue?.this_month ?? 0,
            this_month_gateway: data.revenue?.this_month_gateway ?? 0,
            this_month_cash: data.revenue?.this_month_cash ?? 0,
          },
        })
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

  const actionItems = stats
    ? [
        {
          key: 'merchants',
          count: stats.merchants.pending,
          label: 'merchant menunggu verifikasi',
          href: '/merchants',
        },
        {
          key: 'drivers',
          count: stats.driver_applications_pending,
          label: 'aplikasi driver menunggu review',
          href: '/driver-applications',
        },
        {
          key: 'refunds',
          count: stats.refunds_pending,
          label: 'refund menunggu diproses',
          href: '/revenue',
        },
      ].filter((a) => a.count > 0)
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

      {/* Attention list — everything that needs a decision, one soft panel */}
      {actionItems.length > 0 && (
        <div className="divide-y divide-border overflow-hidden rounded-xl border border-primary/25 bg-primary/[0.05]">
          {actionItems.map((a) => (
            <Link
              key={a.key}
              to={a.href}
              className="flex items-center gap-3 px-4 py-3 text-sm text-foreground transition-colors hover:bg-primary/[0.08]"
            >
              <span className="h-2 w-2 shrink-0 rounded-full bg-primary" />
              <span className="flex-1">
                <strong className="font-semibold">{a.count}</strong> {a.label}
              </span>
              <span className="font-medium text-primary">Lihat →</span>
            </Link>
          ))}
        </div>
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

      <div className="grid gap-8 lg:grid-cols-5">
        {/* Financial summary — the money story, told once, clearly */}
        {stats && (
          <div className="rounded-2xl border border-border bg-card p-6 lg:col-span-2">
            <h2 className="text-sm font-medium text-muted-foreground">Keuangan bulan ini</h2>
            <div className="mt-4 space-y-5">
              <div className="flex items-start gap-3.5">
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
                  <DollarSign className="h-4 w-4" />
                </div>
                <div className="flex-1">
                  <div className="text-xl font-semibold tracking-tight tabular-nums text-foreground">
                    {fmt(stats.revenue.this_month)}
                  </div>
                  <div className="text-xs text-muted-foreground">Revenue platform (markup + komisi)</div>
                  <div className="mt-2 flex gap-4 text-xs">
                    <span className="flex items-center gap-1.5 text-muted-foreground">
                      <CreditCard className="h-3 w-3" /> Gateway {fmt(stats.revenue.this_month_gateway)}
                    </span>
                    <span className="flex items-center gap-1.5 text-muted-foreground">
                      <Banknote className="h-3 w-3" /> Tunai {fmt(stats.revenue.this_month_cash)}
                    </span>
                  </div>
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
              <div className="flex items-start gap-3.5">
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-muted text-muted-foreground">
                  <RotateCcw className="h-4 w-4" />
                </div>
                <div>
                  <div className="text-xl font-semibold tracking-tight tabular-nums text-foreground">
                    {stats.refunds_pending}
                  </div>
                  <div className="text-xs text-muted-foreground">Refund menunggu diproses</div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Recent orders — a live feed, not a full table (that's the Orders page) */}
        {stats && (
          <div className="rounded-2xl border border-border bg-card p-6 lg:col-span-3">
            <div className="flex items-center justify-between">
              <h2 className="text-sm font-medium text-muted-foreground">Order terbaru</h2>
              <Link to="/orders" className="text-xs font-medium text-primary hover:underline">
                Lihat semua →
              </Link>
            </div>
            {stats.recent_orders.length === 0 ? (
              <div className="mt-6 flex flex-col items-center gap-2 py-4 text-center">
                <ClipboardList className="h-5 w-5 text-muted-foreground" />
                <p className="text-sm text-muted-foreground">Belum ada order masuk.</p>
              </div>
            ) : (
              <div className="mt-3 divide-y divide-border">
                {stats.recent_orders.map((o) => {
                  const meta = statusMeta[o.status] ?? { label: o.status, className: 'bg-muted text-muted-foreground' }
                  return (
                    <Link
                      key={o.id}
                      to={`/orders/${o.id}`}
                      className="flex items-center gap-3 py-3 first:pt-2 transition-colors hover:opacity-70"
                    >
                      <div className="min-w-0 flex-1">
                        <div className="truncate text-sm font-medium text-foreground">
                          {o.merchant?.name ?? 'Order'}
                        </div>
                        <div className="text-xs text-muted-foreground">
                          #{o.order_number} · {timeAgo(o.created_at)}
                        </div>
                      </div>
                      <span className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-medium ${meta.className}`}>
                        {meta.label}
                      </span>
                      <span className="w-24 shrink-0 text-right text-sm font-medium tabular-nums text-foreground">
                        {fmt(o.total)}
                      </span>
                    </Link>
                  )
                })}
              </div>
            )}
          </div>
        )}
      </div>

      {/* Performance — who's driving this month's volume */}
      {stats && (stats.top_merchants.length > 0 || stats.top_products.length > 0) && (
        <div className="grid gap-6 sm:grid-cols-2">
          <div className="rounded-2xl border border-border bg-card p-6">
            <div className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
              <Trophy className="h-4 w-4" /> Merchant teratas bulan ini
            </div>
            {stats.top_merchants.length === 0 ? (
              <p className="mt-4 text-sm text-muted-foreground">Belum ada order bulan ini.</p>
            ) : (
              <div className="mt-4 space-y-3">
                {stats.top_merchants.map((m, i) => (
                  <Link
                    key={m.merchant_id}
                    to={`/merchants/${m.merchant_id}`}
                    className="flex items-center gap-3 transition-colors hover:opacity-70"
                  >
                    <span className="w-4 shrink-0 text-xs font-medium text-muted-foreground">{i + 1}</span>
                    <span className="min-w-0 flex-1 truncate text-sm text-foreground">{m.name}</span>
                    <span className="shrink-0 text-sm font-medium tabular-nums text-foreground">
                      {m.order_count} order
                    </span>
                  </Link>
                ))}
              </div>
            )}
          </div>

          <div className="rounded-2xl border border-border bg-card p-6">
            <div className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
              <Utensils className="h-4 w-4" /> Produk terlaris bulan ini
            </div>
            {stats.top_products.length === 0 ? (
              <p className="mt-4 text-sm text-muted-foreground">Belum ada order bulan ini.</p>
            ) : (
              <div className="mt-4 space-y-3">
                {stats.top_products.map((p, i) => (
                  <div key={p.item_name} className="flex items-center gap-3">
                    <span className="w-4 shrink-0 text-xs font-medium text-muted-foreground">{i + 1}</span>
                    <span className="min-w-0 flex-1 truncate text-sm text-foreground">{p.item_name}</span>
                    <span className="shrink-0 text-sm font-medium tabular-nums text-foreground">
                      {p.quantity} terjual
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
