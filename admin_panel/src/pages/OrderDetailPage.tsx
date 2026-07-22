import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { ArrowLeft, Store, User, Bike, MapPin, CreditCard, Loader2, Clock } from 'lucide-react'
import { apiFetch } from '@/lib/api'

interface OrderItem {
  id: string
  item_name: string
  quantity: number
  unit_price: number
  total_price: number
  notes?: string
}

interface Order {
  id: string
  order_number: string
  status: string
  payment_type: string
  payment_status: string
  subtotal: number
  delivery_fee: number
  tax_amount: number
  app_service_fee: number
  total: number
  pickup_address?: string
  dropoff_address?: string
  distance_km: number
  notes?: string
  created_at: string
  placed_at?: string
  confirmed_at?: string
  ready_at?: string
  picked_up_at?: string
  delivered_at?: string
  cancelled_at?: string
  merchant?: { id: string; name: string; phone: string; address: string }
  customer?: { id: string; name: string; phone: string }
  driver?: { id: string; user?: { name: string; phone: string } }
  items?: OrderItem[]
}

const fmt = (v: number | undefined) => 'Rp ' + (v ?? 0).toLocaleString('id-ID')
const fmtDateTime = (d?: string) =>
  d
    ? new Date(d).toLocaleString('id-ID', {
        day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
      })
    : '-'

const statusMeta: Record<string, { label: string; className: string }> = {
  pending: { label: 'Menunggu', className: 'bg-primary/10 text-primary' },
  confirmed: { label: 'Dikonfirmasi', className: 'bg-primary/10 text-primary' },
  preparing: { label: 'Disiapkan', className: 'bg-primary/10 text-primary' },
  ready: { label: 'Siap diambil', className: 'bg-primary/10 text-primary' },
  picked_up: { label: 'Diantar', className: 'bg-primary/10 text-primary' },
  delivered: { label: 'Selesai', className: 'bg-success/10 text-success' },
  cancelled: { label: 'Dibatalkan', className: 'bg-destructive/10 text-destructive' },
}

// Only the milestones that actually happened, in order — a partial
// timeline (still "confirmed") is more honest than showing every possible
// stage grayed out.
function timeline(order: Order) {
  return [
    { label: 'Dibuat', at: order.placed_at ?? order.created_at },
    { label: 'Dikonfirmasi merchant', at: order.confirmed_at },
    { label: 'Siap diambil', at: order.ready_at },
    { label: 'Diambil driver', at: order.picked_up_at },
    { label: 'Selesai diantar', at: order.delivered_at },
    { label: 'Dibatalkan', at: order.cancelled_at },
  ].filter((t) => t.at)
}

function Section({ title, icon: Icon, children }: { title: string; icon: typeof Store; children: React.ReactNode }) {
  return (
    <div className="rounded-2xl border border-border bg-card p-6">
      <div className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
        <Icon className="h-4 w-4" />
        {title}
      </div>
      <div className="mt-4">{children}</div>
    </div>
  )
}

export default function OrderDetailPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [order, setOrder] = useState<Order | null>(null)
  const [loading, setLoading] = useState(true)
  const [notFound, setNotFound] = useState(false)

  useEffect(() => {
    let cancelled = false
    ;(async () => {
      try {
        const res = await apiFetch(`/api/v1/admin/orders/${id}`)
        if (cancelled) return
        if (res.ok) {
          const data = await res.json()
          setOrder(data.order)
        } else {
          setNotFound(true)
        }
      } catch {
        if (!cancelled) setNotFound(true)
      } finally {
        if (!cancelled) setLoading(false)
      }
    })()
    return () => { cancelled = true }
  }, [id])

  if (loading) {
    return (
      <div className="flex items-center justify-center py-24">
        <Loader2 className="h-5 w-5 animate-spin text-muted-foreground" />
      </div>
    )
  }

  if (notFound || !order) {
    return (
      <div className="max-w-3xl space-y-4">
        <button
          onClick={() => navigate('/orders')}
          className="flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" /> Kembali ke Orders
        </button>
        <p className="text-sm text-muted-foreground">Order tidak ditemukan.</p>
      </div>
    )
  }

  const meta = statusMeta[order.status] ?? { label: order.status, className: 'bg-muted text-muted-foreground' }

  return (
    <div className="max-w-4xl space-y-6">
      <button
        onClick={() => navigate('/orders')}
        className="flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
      >
        <ArrowLeft className="h-4 w-4" /> Kembali ke Orders
      </button>

      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight text-foreground">#{order.order_number}</h1>
          <p className="mt-1 text-sm text-muted-foreground">{fmtDateTime(order.created_at)}</p>
        </div>
        <span className={`rounded-full px-3 py-1.5 text-sm font-medium ${meta.className}`}>{meta.label}</span>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <Section title="Merchant" icon={Store}>
          {order.merchant ? (
            <div className="space-y-1">
              <p className="text-sm font-semibold text-foreground">{order.merchant.name}</p>
              <p className="text-xs text-muted-foreground">{order.merchant.phone}</p>
              <p className="text-xs text-muted-foreground">{order.merchant.address}</p>
            </div>
          ) : (
            <p className="text-sm text-muted-foreground">-</p>
          )}
        </Section>

        <Section title="Customer" icon={User}>
          {order.customer ? (
            <div className="space-y-1">
              <p className="text-sm font-semibold text-foreground">{order.customer.name || 'Tanpa nama'}</p>
              <p className="text-xs text-muted-foreground">{order.customer.phone}</p>
            </div>
          ) : (
            <p className="text-sm text-muted-foreground">-</p>
          )}
        </Section>

        <Section title="Driver" icon={Bike}>
          {order.driver?.user ? (
            <div className="space-y-1">
              <p className="text-sm font-semibold text-foreground">{order.driver.user.name}</p>
              <p className="text-xs text-muted-foreground">{order.driver.user.phone}</p>
            </div>
          ) : (
            <p className="text-sm text-muted-foreground">Belum ada driver</p>
          )}
        </Section>
      </div>

      {(order.pickup_address || order.dropoff_address) && (
        <Section title="Rute" icon={MapPin}>
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <p className="text-xs font-medium text-muted-foreground">Ambil</p>
              <p className="mt-0.5 text-sm text-foreground">{order.pickup_address || '-'}</p>
            </div>
            <div>
              <p className="text-xs font-medium text-muted-foreground">Antar</p>
              <p className="mt-0.5 text-sm text-foreground">{order.dropoff_address || '-'}</p>
            </div>
          </div>
          {order.distance_km > 0 && (
            <p className="mt-3 text-xs text-muted-foreground">{order.distance_km.toFixed(1)} km</p>
          )}
        </Section>
      )}

      {order.items && order.items.length > 0 && (
        <Section title="Item" icon={Store}>
          <div className="divide-y divide-border">
            {order.items.map((it) => (
              <div key={it.id} className="flex items-center gap-3 py-2.5 first:pt-0 last:pb-0">
                <span className="w-8 shrink-0 text-sm text-muted-foreground">{it.quantity}×</span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm text-foreground">{it.item_name}</p>
                  {it.notes && <p className="text-xs text-muted-foreground">{it.notes}</p>}
                </div>
                <span className="shrink-0 text-sm tabular-nums text-foreground">{fmt(it.total_price)}</span>
              </div>
            ))}
          </div>
        </Section>
      )}

      <div className="grid gap-6 lg:grid-cols-2">
        <Section title="Pembayaran" icon={CreditCard}>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-muted-foreground">Metode</span>
              <span className="text-foreground">{order.payment_type === 'cash' ? 'COD (tunai)' : order.payment_type.toUpperCase()}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Subtotal</span>
              <span className="tabular-nums text-foreground">{fmt(order.subtotal)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Ongkir</span>
              <span className="tabular-nums text-foreground">{fmt(order.delivery_fee)}</span>
            </div>
            {order.tax_amount > 0 && (
              <div className="flex justify-between">
                <span className="text-muted-foreground">Pajak</span>
                <span className="tabular-nums text-foreground">{fmt(order.tax_amount)}</span>
              </div>
            )}
            {order.app_service_fee > 0 && (
              <div className="flex justify-between">
                <span className="text-muted-foreground">Biaya layanan</span>
                <span className="tabular-nums text-foreground">{fmt(order.app_service_fee)}</span>
              </div>
            )}
            <div className="flex justify-between border-t border-border pt-2 font-semibold">
              <span className="text-foreground">Total</span>
              <span className="tabular-nums text-foreground">{fmt(order.total)}</span>
            </div>
          </div>
        </Section>

        <Section title="Riwayat" icon={Clock}>
          <div className="space-y-3">
            {timeline(order).map((t, i) => (
              <div key={i} className="flex items-center gap-3">
                <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
                <span className="flex-1 text-sm text-foreground">{t.label}</span>
                <span className="text-xs text-muted-foreground">{fmtDateTime(t.at)}</span>
              </div>
            ))}
          </div>
        </Section>
      </div>
    </div>
  )
}
