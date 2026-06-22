import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import { Search, ShieldAlert, ShieldCheck, Loader2, Users } from 'lucide-react'
import { apiFetch as api } from '@/lib/api'

interface Customer {
  id: string
  name: string
  phone: string
  email: string
  is_active: boolean
  created_at: string
}

const fmt = (d: string) => new Date(d).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })

export default function CustomersPage() {
  const [search, setSearch] = useState('')
  const [customers, setCustomers] = useState<Customer[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState<string | null>(null)

  const fetchCustomers = async () => {
    setIsLoading(true)
    try {
      const res = await api('/api/v1/admin/customers')
      const data = await res.json()
      if (res.ok) setCustomers(data.customers ?? data)
    } finally { setIsLoading(false) }
  }

  useEffect(() => { fetchCustomers() }, [])

  const toggleActive = async (customer: Customer) => {
    setActionLoading(customer.id)
    try {
      const res = await api(`/api/v1/admin/users/${customer.id}/toggle-active`, { method: 'PUT' })
      if (res.ok) {
        setCustomers(prev =>
          prev.map(c => c.id === customer.id ? { ...c, is_active: !c.is_active } : c)
        )
      }
    } finally { setActionLoading(null) }
  }

  const filtered = customers.filter(c =>
    c.name?.toLowerCase().includes(search.toLowerCase()) ||
    c.phone?.includes(search) ||
    c.email?.toLowerCase().includes(search.toLowerCase())
  )

  const activeCount = customers.filter(c => c.is_active).length
  const suspendedCount = customers.length - activeCount

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Customers</h2>
        <p className="text-muted-foreground">Manage platform users</p>
      </div>

      {/* Stats */}
      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground flex items-center gap-2">
              <Users className="h-4 w-4" /> Total Customers
            </CardTitle>
          </CardHeader>
          <CardContent><div className="text-2xl font-bold">{customers.length}</div></CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Active</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">{activeCount}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Suspended</CardTitle>
          </CardHeader>
          <CardContent>
            <div className={`text-2xl font-bold ${suspendedCount > 0 ? 'text-red-600' : 'text-muted-foreground'}`}>
              {suspendedCount}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Table */}
      <Card>
        <CardHeader>
          <div className="relative">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder="Search by name, phone, or email..."
              value={search}
              onChange={e => setSearch(e.target.value)}
              className="pl-9"
            />
          </div>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Customer</TableHead>
                <TableHead>Phone</TableHead>
                <TableHead>Email</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Joined</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <TableRow><TableCell colSpan={6} className="text-center py-8">
                  <Loader2 className="h-5 w-5 animate-spin mx-auto" />
                </TableCell></TableRow>
              ) : filtered.length === 0 ? (
                <TableRow><TableCell colSpan={6} className="text-center text-muted-foreground py-8">
                  No customers found
                </TableCell></TableRow>
              ) : filtered.map(c => (
                <TableRow key={c.id} className={!c.is_active ? 'opacity-60' : ''}>
                  <TableCell className="font-medium">{c.name}</TableCell>
                  <TableCell>{c.phone}</TableCell>
                  <TableCell className="text-muted-foreground">{c.email || '-'}</TableCell>
                  <TableCell>
                    <Badge variant={c.is_active ? 'default' : 'secondary'}>
                      {c.is_active ? 'Active' : 'Suspended'}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-sm text-muted-foreground">{fmt(c.created_at)}</TableCell>
                  <TableCell className="text-right">
                    <Button
                      variant="ghost"
                      size="sm"
                      className={c.is_active
                        ? 'text-orange-600 hover:text-orange-700 hover:bg-orange-50'
                        : 'text-green-600 hover:text-green-700 hover:bg-green-50'}
                      disabled={actionLoading === c.id}
                      onClick={() => toggleActive(c)}
                      title={c.is_active ? 'Suspend user' : 'Activate user'}
                    >
                      {actionLoading === c.id
                        ? <Loader2 className="h-4 w-4 animate-spin" />
                        : c.is_active
                          ? <ShieldAlert className="h-4 w-4" />
                          : <ShieldCheck className="h-4 w-4" />}
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  )
}
