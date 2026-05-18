import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import {
  ShoppingBag,
  Store,
  Bike,
  Users,
  TrendingUp,
  DollarSign,
} from 'lucide-react'

const stats = [
  {
    title: 'Total Orders',
    value: '0',
    description: 'Today',
    icon: ShoppingBag,
    trend: '+0%',
  },
  {
    title: 'Active Merchants',
    value: '0',
    description: 'Verified',
    icon: Store,
    trend: '+0',
  },
  {
    title: 'Active Drivers',
    value: '0',
    description: 'Online now',
    icon: Bike,
    trend: '0 online',
  },
  {
    title: 'Customers',
    value: '0',
    description: 'Registered',
    icon: Users,
    trend: '+0',
  },
  {
    title: 'Revenue (KUWRIR)',
    value: 'IDR 0',
    description: 'This month',
    icon: DollarSign,
    trend: '+0%',
  },
  {
    title: 'Pending Deposits',
    value: 'IDR 0',
    description: 'From drivers',
    icon: TrendingUp,
    trend: '0 drivers',
  },
]

export default function DashboardPage() {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Dashboard</h2>
        <p className="text-muted-foreground">
          Welcome to KUWRIR Admin Panel — Kuta, Lombok
        </p>
      </div>

      {/* KPI Cards */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {stats.map((stat) => (
          <Card key={stat.title}>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                {stat.title}
              </CardTitle>
              <stat.icon className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stat.value}</div>
              <div className="flex items-center gap-2 pt-1">
                <Badge variant="secondary" className="text-xs">
                  {stat.trend}
                </Badge>
                <span className="text-xs text-muted-foreground">
                  {stat.description}
                </span>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Recent Orders placeholder */}
      <Card>
        <CardHeader>
          <CardTitle>Recent Orders</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground text-sm">
            No orders yet. Orders will appear here once the platform is live.
          </p>
        </CardContent>
      </Card>
    </div>
  )
}
