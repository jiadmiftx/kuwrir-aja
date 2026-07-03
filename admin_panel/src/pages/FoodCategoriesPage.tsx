import { useState, useEffect } from 'react'
import { Card, CardContent } from '@/components/ui/card'
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
import { UtensilsCrossed, Plus, Pencil, Trash2, Loader2 } from 'lucide-react'
import { apiFetch as api } from '@/lib/api'

interface FoodCategory {
  id: string
  name: string
  icon: string
  sort_order: number
  is_active: boolean
}

const emptyForm = { name: '', icon: '', sort_order: '0', is_active: true }

export default function FoodCategoriesPage() {
  const [categories, setCategories] = useState<FoodCategory[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState<string | null>(null)

  const [dialogOpen, setDialogOpen] = useState(false)
  const [editTarget, setEditTarget] = useState<FoodCategory | null>(null)
  const [form, setForm] = useState(emptyForm)
  const [formError, setFormError] = useState('')
  const [submitting, setSubmitting] = useState(false)

  const [deleteTarget, setDeleteTarget] = useState<FoodCategory | null>(null)

  const fetchCategories = async () => {
    setIsLoading(true)
    try {
      const res = await api('/api/v1/admin/food-categories')
      const data = await res.json()
      if (res.ok) setCategories(data.food_categories ?? [])
    } finally { setIsLoading(false) }
  }

  useEffect(() => { fetchCategories() }, [])

  const openCreate = () => {
    setEditTarget(null)
    setForm(emptyForm)
    setFormError('')
    setDialogOpen(true)
  }

  const openEdit = (c: FoodCategory) => {
    setEditTarget(c)
    setForm({
      name: c.name,
      icon: c.icon,
      sort_order: String(c.sort_order),
      is_active: c.is_active,
    })
    setFormError('')
    setDialogOpen(true)
  }

  const submitForm = async () => {
    if (!form.name.trim()) {
      setFormError('Nama kategori wajib diisi')
      return
    }
    setSubmitting(true)
    setFormError('')
    try {
      const body = {
        name: form.name.trim(),
        icon: form.icon.trim(),
        sort_order: parseInt(form.sort_order) || 0,
        is_active: form.is_active,
      }
      const url = editTarget ? `/api/v1/admin/food-categories/${editTarget.id}` : '/api/v1/admin/food-categories'
      const method = editTarget ? 'PUT' : 'POST'
      const res = await api(url, { method, body: JSON.stringify(body) })
      if (res.ok) { setDialogOpen(false); fetchCategories() }
      else { const err = await res.json(); setFormError(err.error || 'Gagal menyimpan') }
    } finally { setSubmitting(false) }
  }

  const deleteCategory = async () => {
    if (!deleteTarget) return
    setActionLoading(deleteTarget.id + '-delete')
    try {
      await api(`/api/v1/admin/food-categories/${deleteTarget.id}`, { method: 'DELETE' })
      setCategories(prev => prev.filter(c => c.id !== deleteTarget.id))
      setDeleteTarget(null)
    } finally { setActionLoading(null) }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Food Categories</h2>
          <p className="text-muted-foreground">
            Taksonomi kategori makanan lintas merchant — dipakai sebagai filter di Home customer app.
          </p>
        </div>
        <Button onClick={openCreate}>
          <Plus className="mr-2 h-4 w-4" /> Tambah Kategori
        </Button>
      </div>

      <Card>
        <CardContent className="pt-4">
          {isLoading ? (
            <div className="text-center py-8"><Loader2 className="h-5 w-5 animate-spin mx-auto" /></div>
          ) : categories.length === 0 ? (
            <div className="text-center py-12 text-muted-foreground">
              <UtensilsCrossed className="h-10 w-10 mx-auto mb-3 opacity-30" />
              <p>Belum ada kategori. Tambahkan kategori pertama, mis. "Nasi" atau "Minuman".</p>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Icon</TableHead>
                  <TableHead>Nama</TableHead>
                  <TableHead>Urutan</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {categories.map(c => (
                  <TableRow key={c.id} className={!c.is_active ? 'opacity-50' : ''}>
                    <TableCell className="text-lg">{c.icon || '🍽️'}</TableCell>
                    <TableCell className="font-medium">{c.name}</TableCell>
                    <TableCell className="text-sm text-muted-foreground">{c.sort_order}</TableCell>
                    <TableCell>
                      <Badge variant={c.is_active ? 'default' : 'secondary'}>
                        {c.is_active ? 'Aktif' : 'Nonaktif'}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-1">
                        <Button variant="ghost" size="sm" onClick={() => openEdit(c)}>
                          <Pencil className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost" size="sm"
                          className="text-red-600 hover:bg-red-50"
                          onClick={() => setDeleteTarget(c)}
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
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>{editTarget ? 'Edit Kategori' : 'Tambah Kategori Baru'}</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            <div className="grid grid-cols-[1fr_auto] gap-3">
              <div className="space-y-1">
                <Label>Nama Kategori *</Label>
                <Input
                  placeholder="Nasi, Minuman, Snack..."
                  value={form.name}
                  onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
                />
              </div>
              <div className="space-y-1 w-20">
                <Label>Icon</Label>
                <Input
                  placeholder="🍚"
                  value={form.icon}
                  onChange={e => setForm(f => ({ ...f, icon: e.target.value }))}
                  className="text-center text-lg"
                />
              </div>
            </div>
            <div className="space-y-1">
              <Label>Urutan Tampil</Label>
              <Input
                type="number"
                placeholder="0"
                value={form.sort_order}
                onChange={e => setForm(f => ({ ...f, sort_order: e.target.value }))}
              />
            </div>
            <label className="flex items-center gap-2 text-sm cursor-pointer pt-1">
              <input
                type="checkbox"
                checked={form.is_active}
                onChange={e => setForm(f => ({ ...f, is_active: e.target.checked }))}
              />
              Aktif (tampil di customer app)
            </label>
            {formError && <p className="text-sm text-red-600">{formError}</p>}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDialogOpen(false)}>Batal</Button>
            <Button disabled={submitting} onClick={submitForm}>
              {submitting && <Loader2 className="h-4 w-4 animate-spin mr-2" />}
              {editTarget ? 'Simpan Perubahan' : 'Tambah Kategori'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete confirm */}
      <Dialog open={!!deleteTarget} onOpenChange={v => { if (!v) setDeleteTarget(null) }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Hapus Kategori?</DialogTitle>
          </DialogHeader>
          <p className="text-sm text-muted-foreground">
            Kategori <strong>{deleteTarget?.name}</strong> akan dihapus permanen. Produk yang sudah ditandai
            dengan kategori ini akan kehilangan tag-nya.
          </p>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteTarget(null)}>Batal</Button>
            <Button
              variant="destructive"
              disabled={actionLoading === deleteTarget?.id + '-delete'}
              onClick={deleteCategory}
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
