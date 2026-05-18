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
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog'
import { Search, CheckCircle, XCircle, Eye, MapPin, Star } from 'lucide-react'

interface Merchant {
  id: string
  name: string
  phone: string
  address: string
  rating: number
  total_reviews: number
  is_active: boolean
  is_verified: boolean
  is_open: boolean
  created_at: string
}

export default function MerchantsPage() {
  const [search, setSearch] = useState('')
  const [merchants, setMerchants] = useState<Merchant[]>([])
  const [selectedMerchant, setSelectedMerchant] = useState<Merchant | null>(null)
  const [detailOpen, setDetailOpen] = useState(false)
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    fetchMerchants()
  }, [])

  const fetchMerchants = async () => {
    try {
      const token = localStorage.getItem('token')
      const res = await fetch('/api/v1/admin/merchants', {
        headers: { Authorization: `Bearer ${token}` }
      })
      const data = await res.json()
      if (res.ok) setMerchants(data)
    } catch (e) {
      console.error(e)
    } finally {
      setIsLoading(false)
    }
  }

  const filtered = merchants.filter((r) =>
    r.name.toLowerCase().includes(search.toLowerCase())
  )

  const pendingCount = merchants.filter((r) => !r.is_verified).length

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Merchants</h2>
          <p className="text-muted-foreground">
            Manage merchant partners and verification
          </p>
        </div>
        {pendingCount > 0 && (
          <Badge variant="destructive" className="text-sm px-3 py-1">
            {pendingCount} Pending Verification
          </Badge>
        )}
      </div>

      {/* Stats */}
      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Total Merchants
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{merchants.length}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Verified & Active
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">
              {merchants.filter((r) => r.is_verified && r.is_active).length}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Currently Open
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-600">
              {merchants.filter((r) => r.is_open).length}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Search + Table */}
      <Card>
        <CardHeader>
          <div className="flex items-center gap-4">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search merchants..."
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
                <TableHead>Merchant</TableHead>
                <TableHead>Location</TableHead>
                <TableHead>Rating</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Open</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <TableRow><TableCell colSpan={6} className="text-center">Loading...</TableCell></TableRow>
              ) : filtered.length === 0 ? (
                <TableRow><TableCell colSpan={6} className="text-center">No merchants found</TableCell></TableRow>
              ) : filtered.map((r) => (
                <TableRow key={r.id}>
                  <TableCell>
                    <div>
                      <div className="font-medium">{r.name}</div>
                      <div className="text-sm text-muted-foreground">{r.phone}</div>
                    </div>
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-1 text-sm text-muted-foreground">
                      <MapPin className="h-3 w-3" />
                      {r.address}
                    </div>
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-1">
                      <Star className="h-3 w-3 fill-yellow-400 text-yellow-400" />
                      <span className="text-sm">{r.rating > 0 ? r.rating : '-'}</span>
                      <span className="text-xs text-muted-foreground">({r.total_reviews})</span>
                    </div>
                  </TableCell>
                  <TableCell>
                    {r.is_verified ? (
                      <Badge variant="secondary" className="bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">
                        Verified
                      </Badge>
                    ) : (
                      <Badge variant="destructive">Pending</Badge>
                    )}
                  </TableCell>
                  <TableCell>
                    <Badge variant={r.is_open ? 'default' : 'secondary'}>
                      {r.is_open ? 'Open' : 'Closed'}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-right">
                    <div className="flex justify-end gap-2">
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => {
                          setSelectedMerchant(r)
                          setDetailOpen(true)
                        }}
                      >
                        <Eye className="h-4 w-4" />
                      </Button>
                      {!r.is_verified && (
                        <>
                          <Button variant="ghost" size="sm" className="text-green-600 hover:text-green-700">
                            <CheckCircle className="h-4 w-4" />
                          </Button>
                          <Button variant="ghost" size="sm" className="text-red-600 hover:text-red-700">
                            <XCircle className="h-4 w-4" />
                          </Button>
                        </>
                      )}
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      {/* Detail Dialog */}
      <Dialog open={detailOpen} onOpenChange={setDetailOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{selectedMerchant?.name}</DialogTitle>
          </DialogHeader>
          {selectedMerchant && (
            <div className="space-y-3 text-sm">
              <div className="flex justify-between">
                <span className="text-muted-foreground">Phone</span>
                <span>{selectedMerchant.phone}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Address</span>
                <span>{selectedMerchant.address}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Rating</span>
                <span>{selectedMerchant.rating} ({selectedMerchant.total_reviews} reviews)</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Registered</span>
                <span>{selectedMerchant.created_at}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Status</span>
                <Badge variant={selectedMerchant.is_verified ? 'secondary' : 'destructive'}>
                  {selectedMerchant.is_verified ? 'Verified' : 'Pending Verification'}
                </Badge>
              </div>
            </div>
          )}
          <DialogFooter>
            {selectedMerchant && !selectedMerchant.is_verified && (
              <div className="flex gap-2">
                <Button className="bg-green-600 hover:bg-green-700">
                  <CheckCircle className="mr-2 h-4 w-4" /> Approve
                </Button>
                <Button variant="destructive">
                  <XCircle className="mr-2 h-4 w-4" /> Reject
                </Button>
              </div>
            )}
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
