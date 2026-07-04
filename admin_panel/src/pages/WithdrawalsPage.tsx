import { useState, useEffect } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import { Loader2, Wallet } from 'lucide-react'
import { apiFetch as api } from '@/lib/api'

interface Withdrawal {
  id: string
  amount: number
  bank_code: string
  bank_account_number: string
  bank_account_name: string
  status: string
  disbursement_ref?: string
  failed_reason?: string
  created_at: string
  wallet?: { user?: { name: string; role: string } }
}

const fmt = (v: number) => 'Rp ' + v.toLocaleString('id-ID')
const fmtDate = (d: string) => new Date(d).toLocaleString('id-ID', { dateStyle: 'medium', timeStyle: 'short' })

const statusVariant = (s: string): 'default' | 'secondary' | 'destructive' => {
  if (s === 'success') return 'default'
  if (s === 'failed') return 'destructive'
  return 'secondary'
}

export default function WithdrawalsPage() {
  const [withdrawals, setWithdrawals] = useState<Withdrawal[]>([])
  const [status, setStatus] = useState('all')
  const [isLoading, setIsLoading] = useState(true)

  const fetchWithdrawals = async (s: string) => {
    setIsLoading(true)
    try {
      const query = s === 'all' ? '' : `?status=${s}`
      const res = await api(`/api/v1/admin/withdrawals${query}`)
      const data = await res.json()
      if (res.ok) setWithdrawals(data.withdrawals ?? [])
    } finally { setIsLoading(false) }
  }

  useEffect(() => { fetchWithdrawals(status) }, [status])

  const totalProcessing = withdrawals.filter(w => w.status === 'processing').reduce((sum, w) => sum + w.amount, 0)

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Withdrawals</h2>
        <p className="text-muted-foreground">
          Riwayat penarikan dana merchant &amp; driver (real-time via Duitku disbursement).
        </p>
      </div>

      <Card>
        <CardContent className="pt-4">
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <Wallet className="h-4 w-4" />
            Total sedang diproses: <span className="font-semibold text-foreground">{fmt(totalProcessing)}</span>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardContent className="pt-4 space-y-4">
          <div className="flex justify-end">
            <Select value={status} onValueChange={v => v && setStatus(v)}>
              <SelectTrigger className="w-48"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Semua Status</SelectItem>
                <SelectItem value="processing">Processing</SelectItem>
                <SelectItem value="success">Success</SelectItem>
                <SelectItem value="failed">Failed</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {isLoading ? (
            <div className="text-center py-8"><Loader2 className="h-5 w-5 animate-spin mx-auto" /></div>
          ) : withdrawals.length === 0 ? (
            <div className="text-center py-12 text-muted-foreground">
              <Wallet className="h-10 w-10 mx-auto mb-3 opacity-30" />
              <p>Belum ada penarikan dana.</p>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Tanggal</TableHead>
                  <TableHead>User</TableHead>
                  <TableHead>Jumlah</TableHead>
                  <TableHead>Bank</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Referensi</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {withdrawals.map(w => (
                  <TableRow key={w.id}>
                    <TableCell className="text-sm text-muted-foreground">{fmtDate(w.created_at)}</TableCell>
                    <TableCell>
                      <div className="font-medium">{w.wallet?.user?.name ?? '-'}</div>
                      <div className="text-xs text-muted-foreground capitalize">{w.wallet?.user?.role ?? ''}</div>
                    </TableCell>
                    <TableCell className="font-medium">{fmt(w.amount)}</TableCell>
                    <TableCell className="text-sm">
                      {w.bank_code} — {w.bank_account_number}
                      <div className="text-xs text-muted-foreground">{w.bank_account_name}</div>
                    </TableCell>
                    <TableCell>
                      <Badge variant={statusVariant(w.status)} className="capitalize">{w.status}</Badge>
                      {w.status === 'failed' && w.failed_reason && (
                        <div className="text-xs text-red-500 mt-0.5">{w.failed_reason}</div>
                      )}
                    </TableCell>
                    <TableCell className="text-xs text-muted-foreground font-mono">{w.disbursement_ref ?? '-'}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
