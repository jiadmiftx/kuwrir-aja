import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Search, Clock, CheckCircle, Truck, Package, XCircle } from 'lucide-react'


const statusConfig: Record<string, { label: string; color: string; icon: typeof Clock }> = {
  pending: { label: 'Pending', color: 'bg-yellow-100 text-yellow-800', icon: Clock },
  confirmed: { label: 'Confirmed', color: 'bg-blue-100 text-blue-800', icon: CheckCircle },
  preparing: { label: 'Preparing', color: 'bg-purple-100 text-purple-800', icon: Package },
  ready: { label: 'Ready', color: 'bg-indigo-100 text-indigo-800', icon: Package },
  picked_up: { label: 'Picked Up', color: 'bg-cyan-100 text-cyan-800', icon: Truck },
  delivered: { label: 'Delivered', color: 'bg-green-100 text-green-800', icon: CheckCircle },
  cancelled: { label: 'Cancelled', color: 'bg-red-100 text-red-800', icon: XCircle },
}

export default function OrdersPage() {
  const [search, setSearch] = useState('')
  const [tab, setTab] = useState('all')
  const [orders, setOrders] = useState<any[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    fetchOrders()
  }, [])

  const fetchOrders = async () => {
    try {
      const token = localStorage.getItem('token')
      const res = await fetch('/api/v1/admin/orders', {
        headers: { Authorization: `Bearer ${token}` }
      })
      const data = await res.json()
      if (res.ok) setOrders(data)
    } catch (e) {
      console.error(e)
    } finally {
      setIsLoading(false)
    }
  }

  const filtered = orders.filter((o) => {
    const matchSearch =
      o.order_number.toLowerCase().includes(search.toLowerCase()) ||
      o.customer_name.toLowerCase().includes(search.toLowerCase())
    const matchTab = tab === 'all' || o.status === tab
    return matchSearch && matchTab
  })

  const totalRevenue = orders
    .filter((o) => o.status === 'delivered')
    .reduce((sum, o) => sum + (o.platform_markup || 0) + (o.delivery_commission || 0), 0)

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Orders</h2>
        <p className="text-muted-foreground">Monitor all platform orders and revenue</p>
      </div>

      {/* Stats */}
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
            <CardTitle className="text-sm font-medium text-muted-foreground">Delivered</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">
              {orders.filter((o) => o.status === 'delivered').length}
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

      {/* Filters + Table */}
      <Card>
        <CardHeader>
          <div className="flex items-center gap-4">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search by order number or customer..."
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
                    <TableHead>Total (Cash)</TableHead>
                    <TableHead>KUWRIR Cut</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Time</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {isLoading ? (
                    <TableRow><TableCell colSpan={8} className="text-center">Loading...</TableCell></TableRow>
                  ) : filtered.length === 0 ? (
                    <TableRow><TableCell colSpan={8} className="text-center">No orders found</TableCell></TableRow>
                  ) : filtered.map((order) => {
                    const cfg = statusConfig[order.status] || { label: order.status, color: 'bg-gray-100', icon: Clock }
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
                        <TableCell className="font-medium">
                          IDR {order.total.toLocaleString('id-ID')}
                        </TableCell>
                        <TableCell className="text-primary font-medium">
                          IDR {((order.platform_markup || 0) + (order.delivery_commission || 0)).toLocaleString('id-ID')}
                        </TableCell>
                        <TableCell>
                          <Badge className={cfg.color}>{cfg.label}</Badge>
                        </TableCell>
                        <TableCell className="text-muted-foreground text-sm">{new Date(order.created_at).toLocaleString()}</TableCell>
                      </TableRow>
                    )
                  })}
                </TableBody>
              </Table>
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>
    </div>
  )
}
