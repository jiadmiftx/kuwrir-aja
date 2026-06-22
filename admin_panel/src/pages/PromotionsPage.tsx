import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from '@/components/ui/dialog'
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select'
import { Tag, Plus, Pencil, Trash2, Power, Loader2 } from 'lucide-react'
import { apiFetch as api } from '@/lib/api'

interface Promo {
  id: string
  code: string
  title: string
  type: string       // percentage, fixed, free_delivery
  value: number
  min_order: number
  max_discount: number
  usage_limit: number
  used_count: number
  is_active: boolean
  starts_at: string
  expires_at: string
}

const fmt = (v: number) => 'Rp ' + v.toLocaleString('id-ID')
const fmtDate = (d: string) => new Date(d).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })
const toInputDate = (d: string) => d ? d.slice(0, 10) : ''

const emptyForm = {
  code: '', title: '', type: 'percentage', value: '', min_order: '', max_discount: '', usage_limit: '',
  starts_at: new Date().toISOString().slice(0, 10),
  expires_at: new Date(Date.now() + 30 * 86400000).toISOString().slice(0, 10),
}

export default function PromotionsPage() {
  const [promos, setPromos] = useState<Promo[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState<string | null>(null)

  const [dialogOpen, setDialogOpen] = useState(false)
  const [editTarget, setEditTarget] = useState<Promo | null>(null)
  const [form, setForm] = useState(emptyForm)
  const [formError, setFormError] = useState('')
  const [submitting, setSubmitting] = useState(false)

  const [deleteTarget, setDeleteTarget] = useState<Promo | null>(null)

  const fetchPromos = async () => {
    setIsLoading(true)
    try {
      const res = await api('/api/v1/admin/promotions')
      const data = await res.json()
      if (res.ok) setPromos(data.promotions ?? data)
    } finally { setIsLoading(false) }
  }

  useEffect(() => { fetchPromos() }, [])

  const openCreate = () => {
    setEditTarget(null)
    setForm(emptyForm)
    setFormError('')
    setDialogOpen(true)
  }

  const openEdit = (p: Promo) => {
    setEditTarget(p)
    setForm({
      code: p.code,
      title: p.title,
      type: p.type,
      value: String(p.value),
      min_order: String(p.min_order),
      max_discount: String(p.max_discount),
      usage_limit: String(p.usage_limit),
      starts_at: toInputDate(p.starts_at),
      expires_at: toInputDate(p.expires_at),
    })
    setFormError('')
    setDialogOpen(true)
  }

  const submitForm = async () => {
    if (!form.code || !form.title || !form.value) {
      setFormError('Kode, judul, dan nilai wajib diisi')
      return
    }
    setSubmitting(true)
    setFormError('')
    try {
      const body = {
        code: form.code.toUpperCase(),
        title: form.title,
        type: form.type,
        value: parseFloat(form.value) || 0,
        min_order: parseFloat(form.min_order) || 0,
        max_discount: parseFloat(form.max_discount) || 0,
        usage_limit: parseInt(form.usage_limit) || 0,
        starts_at: form.starts_at,
        expires_at: form.expires_at,
      }
      const url = editTarget ? `/api/v1/admin/promotions/${editTarget.id}` : '/api/v1/admin/promotions'
      const method = editTarget ? 'PUT' : 'POST'
      const res = await api(url, { method, body: JSON.stringify(body) })
      if (res.ok) { setDialogOpen(false); fetchPromos() }
      else { const err = await res.json(); setFormError(err.error || 'Gagal menyimpan') }
    } finally { setSubmitting(false) }
  }

  const toggleActive = async (p: Promo) => {
    setActionLoading(p.id + '-toggle')
    try {
      const res = await api(`/api/v1/admin/promotions/${p.id}/toggle`, { method: 'PUT' })
      if (res.ok) {
        const { is_active } = await res.json()
        setPromos(prev => prev.map(x => x.id === p.id ? { ...x, is_active } : x))
      }
    } finally { setActionLoading(null) }
  }

  const deletePromo = async () => {
    if (!deleteTarget) return
    setActionLoading(deleteTarget.id + '-delete')
    try {
      await api(`/api/v1/admin/promotions/${deleteTarget.id}`, { method: 'DELETE' })
      setPromos(prev => prev.filter(p => p.id !== deleteTarget.id))
      setDeleteTarget(null)
    } finally { setActionLoading(null) }
  }

  const isExpired = (p: Promo) => new Date(p.expires_at) < new Date()

  const typeLabel = (t: string) => ({ percentage: 'Persentase %', fixed: 'Nominal Rp', free_delivery: 'Gratis Ongkir' }[t] ?? t)
  const valueDisplay = (p: Promo) => {
    if (p.type === 'percentage') return `${p.value}%`
    if (p.type === 'fixed') return fmt(p.value)
    return 'Gratis Ongkir'
  }

  const activeCount = promos.filter(p => p.is_active && !isExpired(p)).length

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Promotions</h2>
          <p className="text-muted-foreground">Manage discount vouchers and promo codes</p>
        </div>
        <Button onClick={openCreate}>
          <Plus className="mr-2 h-4 w-4" /> Create Promo
        </Button>
      </div>

      {/* Stats */}
      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground flex items-center gap-2">
              <Tag className="h-4 w-4" /> Total Promos
            </CardTitle>
          </CardHeader>
          <CardContent><div className="text-2xl font-bold">{promos.length}</div></CardContent>
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
            <CardTitle className="text-sm font-medium text-muted-foreground">Expired / Inactive</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-muted-foreground">{promos.length - activeCount}</div>
          </CardContent>
        </Card>
      </div>

      {/* Table */}
      <Card>
        <CardContent className="pt-4">
          {isLoading ? (
            <div className="text-center py-8"><Loader2 className="h-5 w-5 animate-spin mx-auto" /></div>
          ) : promos.length === 0 ? (
            <div className="text-center py-12 text-muted-foreground">
              <Tag className="h-10 w-10 mx-auto mb-3 opacity-30" />
              <p>Belum ada promo. Buat promo pertama!</p>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Kode</TableHead>
                  <TableHead>Judul</TableHead>
                  <TableHead>Tipe</TableHead>
                  <TableHead>Nilai</TableHead>
                  <TableHead>Min Order</TableHead>
                  <TableHead>Usage</TableHead>
                  <TableHead>Berlaku</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {promos.map(p => (
                  <TableRow key={p.id} className={(!p.is_active || isExpired(p)) ? 'opacity-50' : ''}>
                    <TableCell>
                      <code className="rounded bg-muted px-1.5 py-0.5 text-sm font-mono">{p.code}</code>
                    </TableCell>
                    <TableCell className="font-medium">{p.title}</TableCell>
                    <TableCell className="text-sm text-muted-foreground">{typeLabel(p.type)}</TableCell>
                    <TableCell className="font-medium text-green-600">{valueDisplay(p)}</TableCell>
                    <TableCell className="text-sm">{p.min_order > 0 ? fmt(p.min_order) : '-'}</TableCell>
                    <TableCell className="text-sm">
                      {p.used_count}/{p.usage_limit > 0 ? p.usage_limit : '∞'}
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {fmtDate(p.starts_at)} — {fmtDate(p.expires_at)}
                      {isExpired(p) && <div className="text-xs text-red-500">Expired</div>}
                    </TableCell>
                    <TableCell>
                      <Badge variant={p.is_active && !isExpired(p) ? 'default' : 'secondary'}>
                        {isExpired(p) ? 'Expired' : p.is_active ? 'Active' : 'Inactive'}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-1">
                        <Button variant="ghost" size="sm" onClick={() => openEdit(p)}>
                          <Pencil className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost" size="sm"
                          className={p.is_active ? 'text-orange-500 hover:bg-orange-50' : 'text-green-600 hover:bg-green-50'}
                          disabled={actionLoading === p.id + '-toggle'}
                          onClick={() => toggleActive(p)}
                          title={p.is_active ? 'Nonaktifkan' : 'Aktifkan'}
                        >
                          {actionLoading === p.id + '-toggle'
                            ? <Loader2 className="h-4 w-4 animate-spin" />
                            : <Power className="h-4 w-4" />}
                        </Button>
                        <Button
                          variant="ghost" size="sm"
                          className="text-red-600 hover:bg-red-50"
                          onClick={() => setDeleteTarget(p)}
                        >
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Create / Edit dialog */}
      <Dialog open={dialogOpen} onOpenChange={v => { if (!v) setDialogOpen(false) }}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>{editTarget ? 'Edit Promo' : 'Buat Promo Baru'}</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label>Kode Promo *</Label>
                <Input
                  placeholder="SUMMER10"
                  value={form.code}
                  onChange={e => setForm(f => ({ ...f, code: e.target.value.toUpperCase() }))}
                />
              </div>
              <div className="space-y-1">
                <Label>Tipe Diskon *</Label>
                <Select value={form.type} onValueChange={v => v && setForm(f => ({ ...f, type: v }))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="percentage">Persentase (%)</SelectItem>
                    <SelectItem value="fixed">Nominal (Rp)</SelectItem>
                    <SelectItem value="free_delivery">Gratis Ongkir</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div className="space-y-1">
              <Label>Judul / Deskripsi *</Label>
              <Input placeholder="Diskon 10% untuk semua menu" value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label>{form.type === 'percentage' ? 'Nilai (%)' : form.type === 'fixed' ? 'Nilai (Rp)' : 'Nilai'} *</Label>
                <Input
                  type="number"
                  placeholder={form.type === 'percentage' ? '10' : '15000'}
                  value={form.value}
                  onChange={e => setForm(f => ({ ...f, value: e.target.value }))}
                  disabled={form.type === 'free_delivery'}
                />
              </div>
              <div className="space-y-1">
                <Label>Max Diskon (Rp)</Label>
                <Input type="number" placeholder="50000" value={form.max_discount} onChange={e => setForm(f => ({ ...f, max_discount: e.target.value }))} />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label>Min Order (Rp)</Label>
                <Input type="number" placeholder="50000" value={form.min_order} onChange={e => setForm(f => ({ ...f, min_order: e.target.value }))} />
              </div>
              <div className="space-y-1">
                <Label>Batas Pemakaian (0 = ∞)</Label>
                <Input type="number" placeholder="100" value={form.usage_limit} onChange={e => setForm(f => ({ ...f, usage_limit: e.target.value }))} />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label>Mulai Berlaku</Label>
                <Input type="date" value={form.starts_at} onChange={e => setForm(f => ({ ...f, starts_at: e.target.value }))} />
              </div>
              <div className="space-y-1">
                <Label>Berakhir</Label>
                <Input type="date" value={form.expires_at} onChange={e => setForm(f => ({ ...f, expires_at: e.target.value }))} />
              </div>
            </div>
            {formError && <p className="text-sm text-red-600">{formError}</p>}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDialogOpen(false)}>Batal</Button>
            <Button disabled={submitting} onClick={submitForm}>
              {submitting && <Loader2 className="h-4 w-4 animate-spin mr-2" />}
              {editTarget ? 'Simpan Perubahan' : 'Buat Promo'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete confirm */}
      <Dialog open={!!deleteTarget} onOpenChange={v => { if (!v) setDeleteTarget(null) }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Hapus Promo?</DialogTitle>
          </DialogHeader>
          <p className="text-sm text-muted-foreground">
            Promo <strong>{deleteTarget?.code}</strong> — {deleteTarget?.title} akan dihapus permanen.
          </p>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteTarget(null)}>Batal</Button>
            <Button
              variant="destructive"
              disabled={actionLoading === deleteTarget?.id + '-delete'}
              onClick={deletePromo}
            >
              {actionLoading === deleteTarget?.id + '-delete' && <Loader2 className="h-4 w-4 animate-spin mr-2" />}
              Hapus
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
