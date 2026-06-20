import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '@/components/ui/dialog'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Search, Clock, CheckCircle, Truck, Package, XCircle, UserCheck } from 'lucide-react'
import { toast } from 'sonner'

const token = () => localStorage.getItem('token')
const apiFetch = (path: string, opts?: RequestInit) =>
  fetch(path, { headers: { Authorization: `Bearer ${token()}`, 'Content-Type': 'application/json' }, ...opts })

const statusConfig: Record<string, { label: string; color: string; icon: typeof Clock }> = {
  pending:   { label: 'Pending',   color: 'bg-yellow-100 text-yellow-800', icon: Clock },
  confirmed: { label: 'Confirmed', color: 'bg-blue-100 text-blue-800',     icon: CheckCircle },
  preparing: { label: 'Preparing', color: 'bg-purple-100 text-purple-800', icon: Package },
  ready:     { label: 'Ready',     color: 'bg-indigo-100 text-indigo-800', icon: Package },
  picked_up: { label: 'Picked Up', color: 'bg-cyan-100 text-cyan-800',     icon: Truck },
  delivered: { label: 'Delivered', color: 'bg-green-100 text-green-800',   icon: CheckCircle },
  cancelled: { label: 'Cancelled', color: 'bg-red-100 text-red-800',       icon: XCircle },
}

interface Order {
  id: string
  order_number: string
  status: string
  delivery_type: string
  total: number
  platform_markup?: number
  delivery_commission?: number
  app_service_fee?: number
  created_at: string
  driver_id?: string | null
  Customer?: { name: string }
  Merchant?: { name: string }
  Driver?: { User?: { name: string } }
}

interface NearbyDriver {
  id: string
  distance_km: number
  User?: { name: string; phone: string }
  vehicle_type: string
  vehicle_plate: string
  rating: number
  total_delivered: number
}

export default function OrdersPage() {
  const [search, setSearch] = useState('')
  const [tab, setTab] = useState('all')
  const [orders, setOrders] = useState<Order[]>([])
  const [isLoading, setIsLoading] = useState(true)

  // Assign driver dialog
  const [assignOrder, setAssignOrder] = useState<Order | null>(null)
  const [nearbyDrivers, setNearbyDrivers] = useState<NearbyDriver[]>([])
  const [driversLoading, setDriversLoading] = useState(false)
  const [selectedDriver, setSelectedDriver] = useState('')
  const [assigning, setAssigning] = useState(false)

  const fetchOrders = async () => {
    try {
      const res = await apiFetch('/api/v1/admin/orders')
      const data = await res.json()
      if (res.ok) setOrders(data.orders ?? [])
    } catch (e) {
      console.error(e)
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => { fetchOrders() }, [])

  const openAssignDialog = async (order: Order) => {
    setAssignOrder(order)
    setSelectedDriver(order.driver_id || '')
    setNearbyDrivers([])
    setDriversLoading(true)
    try {
      const res = await apiFetch(`/api/v1/admin/orders/${order.id}/nearby-drivers`)
      const data = await res.json()
      setNearbyDrivers(data.drivers || [])
    } catch {
      toast.error('Failed to load nearby drivers')
    } finally {
      setDriversLoading(false)
    }
  }

  const handleAssign = async () => {
    if (!assignOrder || !selectedDriver) return
    setAssigning(true)
    try {
      const res = await apiFetch(`/api/v1/admin/orders/${assignOrder.id}/assign-driver`, {
        method: 'POST',
        body: JSON.stringify({ driver_id: selectedDriver }),
      })
      const data = await res.json()
      if (res.ok) {
        toast.success(`Driver assigned: ${data.driver_name}`)
        setAssignOrder(null)
        fetchOrders()
      } else {
        toast.error(data.error || 'Failed to assign driver')
      }
    } catch {
      toast.error('Network error')
    } finally {
      setAssigning(false)
    }
  }

  const filtered = orders.filter((o) => {
    const matchSearch =
      o.order_number.toLowerCase().includes(search.toLowerCase()) ||
      (o.Customer?.name || '').toLowerCase().includes(search.toLowerCase())
    const matchTab = tab === 'all' || o.status === tab
    return matchSearch && matchTab
  })

  const totalRevenue = orders
    .filter((o) => o.status === 'delivered')
    .reduce((sum, o) => sum + (o.platform_markup || 0) + (o.delivery_commission || 0) + (o.app_service_fee || 0), 0)

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Orders</h2>
        <p className="text-muted-foreground">Monitor all platform orders, assign drivers, and track revenue</p>
      </div>

      <div className="grid gap-4 md:grid-cols-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Total Orders</CardTitle>
          </CardHeader>
          <CardContent><div className="text-2xl font-bold">{orders.length}</div></CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Active</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-600">
              {orders.filter((o) => !['delivered', 'cancelled'].includes(o.status)).length}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Awaiting Driver</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-orange-500">
              {orders.filter((o) => o.status === 'ready' && !o.driver_id).length}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">KUWRIR Revenue</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-primary">
              IDR {totalRevenue.toLocaleString('id-ID')}
            </div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <div className="flex items-center gap-4">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search order number or customer..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="pl-9"
              />
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <Tabs value={tab} onValueChange={setTab}>
            <TabsList>
              <TabsTrigger value="all">All</TabsTrigger>
              <TabsTrigger value="pending">Pending</TabsTrigger>
              <TabsTrigger value="preparing">Preparing</TabsTrigger>
              <TabsTrigger value="ready">Ready</TabsTrigger>
              <TabsTrigger value="delivered">Delivered</TabsTrigger>
              <TabsTrigger value="cancelled">Cancelled</TabsTrigger>
            </TabsList>
            <TabsContent value={tab} className="mt-4">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Order</TableHead>
                    <TableHead>Customer</TableHead>
                    <TableHead>Merchant</TableHead>
                    <TableHead>Delivery</TableHead>
                    <TableHead>Driver</TableHead>
                    <TableHead>Total</TableHead>
                    <TableHead>Platform Cut</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Aksi</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {isLoading ? (
                    <TableRow><TableCell colSpan={9} className="text-center">Loading...</TableCell></TableRow>
                  ) : filtered.length === 0 ? (
                    <TableRow><TableCell colSpan={9} className="text-center">No orders found</TableCell></TableRow>
                  ) : filtered.map((order) => {
                    const cfg = statusConfig[order.status] || { label: order.status, color: 'bg-gray-100', icon: Clock }
                    const platformCut = (order.platform_markup || 0) + (order.delivery_commission || 0) + (order.app_service_fee || 0)
                    return (
                      <TableRow key={order.id}>
                        <TableCell className="font-mono text-sm">{order.order_number}</TableCell>
                        <TableCell>{order.Customer?.name || 'Walk-in'}</TableCell>
                        <TableCell>{order.Merchant?.name}</TableCell>
                        <TableCell>
                          <Badge className={order.delivery_type === 'self' ? 'bg-purple-100 text-purple-800' : 'bg-sky-100 text-sky-800'}>
                            {order.delivery_type === 'self' ? 'Self' : 'Platform'}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-sm">
                          {order.Driver?.User?.name
                            ? <span className="text-green-700 font-medium">{order.Driver.User.name}</span>
                            : order.status === 'ready'
                            ? <span className="text-orange-500">Unassigned</span>
                            : <span className="text-muted-foreground">—</span>
                          }
                        </TableCell>
                        <TableCell className="font-medium">
                          IDR {(order.total ?? 0).toLocaleString('id-ID')}
                        </TableCell>
                        <TableCell className="text-primary font-medium">
                          IDR {platformCut.toLocaleString('id-ID')}
                        </TableCell>
                        <TableCell>
                          <Badge className={cfg.color}>{cfg.label}</Badge>
                        </TableCell>
                        <TableCell>
                          {order.status === 'ready' && (
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => openAssignDialog(order)}
                              className="text-xs"
                            >
                              <UserCheck className="mr-1 h-3 w-3" />
                              {order.driver_id ? 'Ganti Driver' : 'Assign Driver'}
                            </Button>
                          )}
                        </TableCell>
                      </TableRow>
                    )
                  })}
                </TableBody>
              </Table>
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>

      {/* Assign Driver Dialog */}
      <Dialog open={!!assignOrder} onOpenChange={(open) => !open && setAssignOrder(null)}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>Assign Driver — {assignOrder?.order_number}</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            {driversLoading ? (
              <p className="text-muted-foreground text-sm text-center py-4">Memuat driver terdekat...</p>
            ) : nearbyDrivers.length === 0 ? (
              <p className="text-muted-foreground text-sm text-center py-4">Tidak ada driver online saat ini.</p>
            ) : (
              <div className="space-y-2 max-h-80 overflow-y-auto">
                {nearbyDrivers.map((d) => (
                  <div
                    key={d.id}
                    onClick={() => setSelectedDriver(d.id)}
                    className={`flex items-center justify-between p-3 rounded-lg border cursor-pointer transition-colors ${
                      selectedDriver === d.id ? 'border-primary bg-primary/5' : 'hover:bg-muted/50'
                    }`}
                  >
                    <div>
                      <div className="font-medium">{d.User?.name}</div>
                      <div className="text-xs text-muted-foreground">
                        {d.vehicle_type} · {d.vehicle_plate} · ⭐ {d.rating.toFixed(1)} · {d.total_delivered} antar
                      </div>
                    </div>
                    <div className="text-right text-sm">
                      <div className="font-bold text-primary">{d.distance_km.toFixed(1)} km</div>
                      <div className="text-xs text-muted-foreground">dari merchant</div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAssignOrder(null)}>Batal</Button>
            <Button onClick={handleAssign} disabled={!selectedDriver || assigning}>
              {assigning ? 'Menyimpan...' : 'Assign Driver Ini'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
