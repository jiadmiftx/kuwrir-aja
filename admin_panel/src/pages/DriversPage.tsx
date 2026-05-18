import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { Search, Bike, Ban } from 'lucide-react'

export default function DriversPage() {
  const [search, setSearch] = useState('')
  const [drivers, setDrivers] = useState<any[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    fetchDrivers()
  }, [])

  const fetchDrivers = async () => {
    try {
      const token = localStorage.getItem('token')
      const res = await fetch('/api/v1/admin/drivers', {
        headers: { Authorization: `Bearer ${token}` }
      })
      const data = await res.json()
      if (res.ok) setDrivers(data)
    } catch (e) {
      console.error(e)
    } finally {
      setIsLoading(false)
    }
  }

  const filtered = drivers.filter(d => 
    d.User?.name?.toLowerCase().includes(search.toLowerCase()) || 
    d.vehicle_plate?.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Drivers</h2>
          <p className="text-muted-foreground">Manage delivery partners</p>
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Total Drivers</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{drivers.length}</div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <div className="flex items-center gap-4">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search drivers..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="pl-9"
              />
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Driver</TableHead>
                <TableHead>Vehicle</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Deliveries</TableHead>
                <TableHead>Cash Balance (COD)</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <TableRow><TableCell colSpan={6} className="text-center">Loading...</TableCell></TableRow>
              ) : filtered.length === 0 ? (
                <TableRow><TableCell colSpan={6} className="text-center">No drivers found</TableCell></TableRow>
              ) : (
                filtered.map(d => (
                  <TableRow key={d.id}>
                    <TableCell>
                      <div className="font-medium">{d.User?.name}</div>
                      <div className="text-sm text-muted-foreground">{d.User?.phone}</div>
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <Bike className="h-4 w-4 text-muted-foreground" />
                        {d.vehicle_type} - {d.vehicle_plate}
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge variant={d.is_active ? 'default' : 'secondary'}>
                        {d.is_active ? 'Active' : 'Inactive'}
                      </Badge>
                    </TableCell>
                    <TableCell>{d.total_delivered}</TableCell>
                    <TableCell className="text-red-600 font-medium">Rp {d.cash_balance?.toLocaleString() || 0}</TableCell>
                    <TableCell className="text-right">
                      <Button variant="ghost" size="sm" className="text-red-600">
                        <Ban className="h-4 w-4" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  )
}
