import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { TrendingUp, HandCoins } from 'lucide-react'

export default function SettlementsPage() {
  const [data, setData] = useState({ total_driver_cash: 0, total_platform_revenue: 0 })

  useEffect(() => {
    fetchSettlements()
  }, [])

  const fetchSettlements = async () => {
    try {
      const token = localStorage.getItem('token')
      const res = await fetch('/api/v1/admin/settlements', {
        headers: { Authorization: `Bearer ${token}` }
      })
      const body = await res.json()
      if (res.ok) setData(body)
    } catch (e) {
      console.error(e)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Settlements</h2>
          <p className="text-muted-foreground">Financial overview and payouts</p>
        </div>
        <Button onClick={fetchSettlements}>Refresh</Button>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">Platform Revenue</CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">
              Rp {data.total_platform_revenue.toLocaleString()}
            </div>
            <p className="text-xs text-muted-foreground mt-1">
              Total markup earned from all delivered orders
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">Cash Held by Drivers</CardTitle>
            <HandCoins className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-orange-600">
              Rp {data.total_driver_cash.toLocaleString()}
            </div>
            <p className="text-xs text-muted-foreground mt-1">
              Total COD cash that drivers need to deposit to Admin
            </p>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Payouts</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground mb-4">
            Merchant payout logic will be implemented here. When customers pay via non-cash methods,
            or when drivers deposit COD cash, the platform will distribute the earnings to the respective merchants.
          </p>
          <Button disabled>Process Merchant Payouts</Button>
        </CardContent>
      </Card>
    </div>
  )
}
