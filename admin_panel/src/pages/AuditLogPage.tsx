import { useState, useEffect, useCallback } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import { Loader2, Info } from 'lucide-react'
import { toast } from 'sonner'
import { apiFetch as api } from '@/lib/api'

interface AuditLog {
  id: string
  created_at: string
  actor_id: string
  actor_name: string
  actor_role: string
  method: string
  path: string
  fitur: string
  status_code: number
  ip_address: string
}

const ROLE_OPTIONS: { value: string; label: string }[] = [
  { value: 'all', label: 'Semua Role' },
  { value: 'customer', label: 'Customer' },
  { value: 'merchant', label: 'Merchant' },
  { value: 'driver', label: 'Driver' },
  { value: 'admin', label: 'Admin' },
]

// Mirrors the labels produced by backend middleware.DeriveFeature
// (internal/middleware/audit_feature.go) — kept in sync manually since the
// set of features changes rarely.
const FITUR_OPTIONS: { value: string; label: string }[] = [
  { value: 'all', label: 'Semua Fitur' },
  { value: 'Akun Pengguna', label: 'Akun Pengguna' },
  { value: 'Alamat', label: 'Alamat' },
  { value: 'Admin', label: 'Admin' },
  { value: 'Audit Log', label: 'Audit Log' },
  { value: 'Autentikasi', label: 'Autentikasi' },
  { value: 'Banner', label: 'Banner' },
  { value: 'Banner Toko', label: 'Banner Toko' },
  { value: 'Customer', label: 'Customer' },
  { value: 'Dashboard', label: 'Dashboard' },
  { value: 'Dashboard Toko', label: 'Dashboard Toko' },
  { value: 'Dompet', label: 'Dompet' },
  { value: 'Driver', label: 'Driver' },
  { value: 'Kasir (POS)', label: 'Kasir (POS)' },
  { value: 'Kategori Makanan', label: 'Kategori Makanan' },
  { value: 'Kategori Toko', label: 'Kategori Toko' },
  { value: 'Laporan Pendapatan', label: 'Laporan Pendapatan' },
  { value: 'Logo Toko', label: 'Logo Toko' },
  { value: 'Merchant', label: 'Merchant' },
  { value: 'Operasional Toko', label: 'Operasional Toko' },
  { value: 'Order Jasa', label: 'Order Jasa' },
  { value: 'Pembayaran', label: 'Pembayaran' },
  { value: 'Pendaftaran Driver', label: 'Pendaftaran Driver' },
  { value: 'Pengajuan Driver', label: 'Pengajuan Driver' },
  { value: 'Pengaturan', label: 'Pengaturan' },
  { value: 'Pengiriman Toko', label: 'Pengiriman Toko' },
  { value: 'Penarikan Dana', label: 'Penarikan Dana' },
  { value: 'Perjanjian Kemitraan', label: 'Perjanjian Kemitraan' },
  { value: 'Pesanan', label: 'Pesanan' },
  { value: 'Pesanan Driver', label: 'Pesanan Driver' },
  { value: 'Pesanan Toko', label: 'Pesanan Toko' },
  { value: 'Produk', label: 'Produk' },
  { value: 'Promosi', label: 'Promosi' },
  { value: 'Refund', label: 'Refund' },
  { value: 'Setoran COD', label: 'Setoran COD' },
  { value: 'Settlement', label: 'Settlement' },
  { value: 'Status Driver', label: 'Status Driver' },
  { value: 'Support / CS', label: 'Support / CS' },
  { value: 'Varian Produk', label: 'Varian Produk' },
  { value: 'WhatsApp Gateway', label: 'WhatsApp Gateway' },
  { value: 'Zona Pengiriman', label: 'Zona Pengiriman' },
]

const LIMIT = 50

function methodBadgeClass(method: string): string {
  switch (method.toUpperCase()) {
    case 'POST':
      return 'text-green-700 border-green-300 bg-green-50'
    case 'PUT':
    case 'PATCH':
      return 'text-blue-700 border-blue-300 bg-blue-50'
    case 'DELETE':
      return 'text-red-700 border-red-300 bg-red-50'
    default:
      return 'text-muted-foreground border-border'
  }
}

function statusBadgeClass(status: number): string {
  if (status >= 200 && status < 300) return 'text-green-700 border-green-300 bg-green-50'
  return 'text-red-700 border-red-300 bg-red-50'
}

export default function AuditLogPage() {
  const [logs, setLogs] = useState<AuditLog[]>([])
  const [role, setRole] = useState('all')
  const [fitur, setFitur] = useState('all')
  const [page, setPage] = useState(1)
  const [total, setTotal] = useState(0)
  const [isLoading, setIsLoading] = useState(true)
  const [isLoadingMore, setIsLoadingMore] = useState(false)

  const fetchLogs = useCallback(async (targetPage: number, roleFilter: string, fiturFilter: string, append: boolean) => {
    if (append) setIsLoadingMore(true)
    else setIsLoading(true)
    try {
      const params = new URLSearchParams({ page: String(targetPage), limit: String(LIMIT) })
      if (roleFilter !== 'all') params.set('role', roleFilter)
      if (fiturFilter !== 'all') params.set('fitur', fiturFilter)
      const res = await api(`/api/v1/admin/audit-logs?${params.toString()}`)
      const data = await res.json()
      if (res.ok) {
        setLogs(prev => append ? [...prev, ...(data.logs ?? [])] : (data.logs ?? []))
        setTotal(data.total ?? 0)
        setPage(data.page ?? targetPage)
      } else {
        toast.error(data.error ?? 'Gagal memuat audit log')
      }
    } finally {
      if (append) setIsLoadingMore(false)
      else setIsLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchLogs(1, role, fitur, false)
  }, [role, fitur, fetchLogs])

  const handleRoleChange = (val: string | null) => {
    if (val === null) return
    setRole(val)
  }

  const handleFiturChange = (val: string | null) => {
    if (val === null) return
    setFitur(val)
  }

  const loadMore = () => {
    fetchLogs(page + 1, role, fitur, true)
  }

  const hasMore = logs.length < total

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Audit Log</h2>
        <p className="text-muted-foreground">Riwayat aktivitas mutasi data oleh pengguna</p>
      </div>

      <div className="flex items-start gap-2 rounded-lg border border-blue-200 bg-blue-50 p-3 text-sm text-blue-800">
        <Info className="h-4 w-4 mt-0.5 shrink-0" />
        <span>
          Hanya menyimpan 30 hari terakhir. Backup lengkap tersimpan otomatis tiap bulan ke penyimpanan terpisah.
        </span>
      </div>

      <Card>
        <CardHeader>
          <div className="flex items-center justify-between gap-4">
            <CardTitle>Riwayat Aktivitas</CardTitle>
            <div className="flex items-center gap-2">
              <Select items={Object.fromEntries(FITUR_OPTIONS.map(o => [o.value, o.label]))} value={fitur} onValueChange={handleFiturChange}>
                <SelectTrigger className="w-48">
                  <SelectValue placeholder="Filter fitur" />
                </SelectTrigger>
                <SelectContent>
                  {FITUR_OPTIONS.map(o => (
                    <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <Select items={Object.fromEntries(ROLE_OPTIONS.map(o => [o.value, o.label]))} value={role} onValueChange={handleRoleChange}>
                <SelectTrigger className="w-44">
                  <SelectValue placeholder="Filter role" />
                </SelectTrigger>
                <SelectContent>
                  {ROLE_OPTIONS.map(o => (
                    <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Waktu</TableHead>
                <TableHead>Actor</TableHead>
                <TableHead>Fitur</TableHead>
                <TableHead>Method</TableHead>
                <TableHead>Path</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>IP</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <TableRow><TableCell colSpan={7} className="text-center py-8">
                  <Loader2 className="h-5 w-5 animate-spin mx-auto" />
                </TableCell></TableRow>
              ) : logs.length === 0 ? (
                <TableRow><TableCell colSpan={7} className="text-center text-muted-foreground py-8">Belum ada aktivitas tercatat</TableCell></TableRow>
              ) : logs.map(log => (
                <TableRow key={log.id}>
                  <TableCell className="text-sm whitespace-nowrap">
                    {new Date(log.created_at).toLocaleString('id-ID')}
                  </TableCell>
                  <TableCell>
                    <div className="font-medium">{log.actor_name || '-'}</div>
                    <Badge variant="outline" className="text-xs mt-0.5">{log.actor_role}</Badge>
                  </TableCell>
                  <TableCell>
                    <Badge variant="outline" className="text-xs">{log.fitur || '-'}</Badge>
                  </TableCell>
                  <TableCell>
                    <Badge variant="outline" className={methodBadgeClass(log.method)}>{log.method}</Badge>
                  </TableCell>
                  <TableCell className="text-sm font-mono max-w-xs truncate" title={log.path}>{log.path}</TableCell>
                  <TableCell>
                    <Badge variant="outline" className={statusBadgeClass(log.status_code)}>{log.status_code}</Badge>
                  </TableCell>
                  <TableCell className="text-sm text-muted-foreground">{log.ip_address || '-'}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>

          {hasMore && !isLoading && (
            <div className="flex justify-center pt-4">
              <Button variant="outline" disabled={isLoadingMore} onClick={loadMore}>
                {isLoadingMore ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : null}
                Muat lebih banyak
              </Button>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
