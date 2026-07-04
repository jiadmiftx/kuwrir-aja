import { useState, useEffect, useRef } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from '@/components/ui/dialog'
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select'
import { Image as ImageIcon, Plus, Pencil, Trash2, Loader2, Upload } from 'lucide-react'
import { apiFetch as api } from '@/lib/api'

interface FoodCategory {
  id: string
  name: string
  icon: string
}

interface Banner {
  id: string
  image_url: string
  title: string
  subtitle: string
  cta_text: string
  food_category_id: string | null
  sort_order: number
  is_active: boolean
}

const emptyForm = {
  title: '', subtitle: '', cta_text: 'Lihat Menu', food_category_id: '', sort_order: '0', is_active: true,
}

export default function BannersPage() {
  const [banners, setBanners] = useState<Banner[]>([])
  const [categories, setCategories] = useState<FoodCategory[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState<string | null>(null)

  const [dialogOpen, setDialogOpen] = useState(false)
  const [editTarget, setEditTarget] = useState<Banner | null>(null)
  const [form, setForm] = useState(emptyForm)
  const [formError, setFormError] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [imageFile, setImageFile] = useState<File | null>(null)
  const [imagePreview, setImagePreview] = useState<string | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const [deleteTarget, setDeleteTarget] = useState<Banner | null>(null)

  const fetchBanners = async () => {
    setIsLoading(true)
    try {
      const res = await api('/api/v1/admin/banners')
      const data = await res.json()
      if (res.ok) setBanners(data.banners ?? [])
    } finally { setIsLoading(false) }
  }

  const fetchCategories = async () => {
    const res = await api('/api/v1/admin/food-categories')
    const data = await res.json()
    if (res.ok) setCategories(data.food_categories ?? [])
  }

  useEffect(() => { fetchBanners(); fetchCategories() }, [])

  const resetImagePicker = () => {
    setImageFile(null)
    setImagePreview(null)
    if (fileInputRef.current) fileInputRef.current.value = ''
  }

  const openCreate = () => {
    setEditTarget(null)
    setForm(emptyForm)
    setFormError('')
    resetImagePicker()
    setDialogOpen(true)
  }

  const openEdit = (b: Banner) => {
    setEditTarget(b)
    setForm({
      title: b.title ?? '',
      subtitle: b.subtitle ?? '',
      cta_text: b.cta_text ?? '',
      food_category_id: b.food_category_id ?? '',
      sort_order: String(b.sort_order),
      is_active: b.is_active,
    })
    setFormError('')
    resetImagePicker()
    setDialogOpen(true)
  }

  const onPickImage = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    setImageFile(file)
    setImagePreview(URL.createObjectURL(file))
  }

  const submitForm = async () => {
    if (!form.title.trim()) {
      setFormError('Judul wajib diisi')
      return
    }
    setSubmitting(true)
    setFormError('')
    try {
      const body = {
        title: form.title.trim(),
        subtitle: form.subtitle.trim(),
        cta_text: form.cta_text.trim() || 'Lihat Menu',
        food_category_id: form.food_category_id || null,
        sort_order: parseInt(form.sort_order) || 0,
        is_active: form.is_active,
      }
      const url = editTarget ? `/api/v1/admin/banners/${editTarget.id}` : '/api/v1/admin/banners'
      const method = editTarget ? 'PUT' : 'POST'
      const res = await api(url, { method, body: JSON.stringify(body) })
      if (!res.ok) {
        const err = await res.json()
        setFormError(err.error || 'Gagal menyimpan')
        return
      }

      let bannerId = editTarget?.id
      if (!editTarget) {
        const data = await res.json()
        bannerId = data.banner?.id
      }

      if (imageFile && bannerId) {
        const imgForm = new FormData()
        imgForm.append('image', imageFile)
        const imgRes = await api(`/api/v1/admin/banners/${bannerId}/image`, { method: 'POST', body: imgForm })
        if (!imgRes.ok) {
          const err = await imgRes.json()
          setFormError(err.error || 'Banner tersimpan, tapi gagal upload gambar')
          return
        }
      }

      setDialogOpen(false)
      fetchBanners()
    } finally { setSubmitting(false) }
  }

  const deleteBanner = async () => {
    if (!deleteTarget) return
    setActionLoading(deleteTarget.id + '-delete')
    try {
      await api(`/api/v1/admin/banners/${deleteTarget.id}`, { method: 'DELETE' })
      setBanners(prev => prev.filter(b => b.id !== deleteTarget.id))
      setDeleteTarget(null)
    } finally { setActionLoading(null) }
  }

  const categoryName = (id: string | null) => categories.find(c => c.id === id)?.name

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Banners</h2>
          <p className="text-muted-foreground">
            Kelola banner promosi carousel di halaman utama customer app.
          </p>
        </div>
        <Button onClick={openCreate}>
          <Plus className="mr-2 h-4 w-4" /> Tambah Banner
        </Button>
      </div>

      <Card>
        <CardContent className="pt-4">
          {isLoading ? (
            <div className="text-center py-8"><Loader2 className="h-5 w-5 animate-spin mx-auto" /></div>
          ) : banners.length === 0 ? (
            <div className="text-center py-12 text-muted-foreground">
              <ImageIcon className="h-10 w-10 mx-auto mb-3 opacity-30" />
              <p>Belum ada banner. Tambahkan banner pertama untuk tampil di beranda customer app.</p>
            </div>
          ) : (
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              {banners.map(b => (
                <div key={b.id} className={`rounded-lg border overflow-hidden ${!b.is_active ? 'opacity-50' : ''}`}>
                  <div className="h-32 bg-muted flex items-center justify-center">
                    {b.image_url ? (
                      <img src={b.image_url} alt={b.title} className="w-full h-full object-cover" />
                    ) : (
                      <ImageIcon className="h-8 w-8 text-muted-foreground" />
                    )}
                  </div>
                  <div className="p-3 space-y-1">
                    <div className="flex items-center justify-between gap-2">
                      <span className="font-medium text-sm truncate">{b.title}</span>
                      <Badge variant={b.is_active ? 'default' : 'secondary'} className="text-xs shrink-0">
                        {b.is_active ? 'Aktif' : 'Nonaktif'}
                      </Badge>
                    </div>
                    {b.subtitle && <p className="text-xs text-muted-foreground truncate">{b.subtitle}</p>}
                    {b.food_category_id && (
                      <p className="text-xs text-muted-foreground">→ {categoryName(b.food_category_id) ?? 'Kategori'}</p>
                    )}
                    <div className="flex justify-end gap-1 pt-1">
                      <Button variant="ghost" size="sm" onClick={() => openEdit(b)}>
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="ghost" size="sm"
                        className="text-red-600 hover:bg-red-50"
                        onClick={() => setDeleteTarget(b)}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Create / Edit dialog */}
      <Dialog open={dialogOpen} onOpenChange={v => { if (!v) setDialogOpen(false) }}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>{editTarget ? 'Edit Banner' : 'Tambah Banner Baru'}</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            <div className="space-y-1">
              <Label>Gambar Banner</Label>
              <div
                className="rounded-md border border-dashed h-32 flex items-center justify-center cursor-pointer overflow-hidden hover:bg-accent/50"
                onClick={() => fileInputRef.current?.click()}
              >
                {imagePreview ? (
                  <img src={imagePreview} alt="Preview" className="w-full h-full object-cover" />
                ) : editTarget?.image_url ? (
                  <img src={editTarget.image_url} alt="Preview" className="w-full h-full object-cover" />
                ) : (
                  <div className="flex flex-col items-center text-muted-foreground text-sm">
                    <Upload className="h-6 w-6 mb-1" />
                    Klik untuk pilih gambar
                  </div>
                )}
              </div>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={onPickImage}
              />
            </div>
            <div className="space-y-1">
              <Label>Judul *</Label>
              <Input
                placeholder="Fruits: 25% Off Today!"
                value={form.title}
                onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
              />
            </div>
            <div className="space-y-1">
              <Label>Subjudul</Label>
              <Input
                placeholder="Shop & save with fresh daily deals"
                value={form.subtitle}
                onChange={e => setForm(f => ({ ...f, subtitle: e.target.value }))}
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label>Teks Tombol</Label>
                <Input
                  placeholder="Lihat Menu"
                  value={form.cta_text}
                  onChange={e => setForm(f => ({ ...f, cta_text: e.target.value }))}
                />
              </div>
              <div className="space-y-1">
                <Label>Urutan Tampil</Label>
                <Input
                  type="number"
                  value={form.sort_order}
                  onChange={e => setForm(f => ({ ...f, sort_order: e.target.value }))}
                />
              </div>
            </div>
            <div className="space-y-1">
              <Label>Tautan Kategori (opsional)</Label>
              <Select
                value={form.food_category_id || 'none'}
                onValueChange={v => setForm(f => ({ ...f, food_category_id: !v || v === 'none' ? '' : v }))}
              >
                <SelectTrigger><SelectValue placeholder="Tanpa tautan" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="none">Tanpa tautan</SelectItem>
                  {categories.map(c => (
                    <SelectItem key={c.id} value={c.id}>{c.icon} {c.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <p className="text-xs text-muted-foreground">
                Tap banner di customer app akan memfilter beranda ke kategori ini.
              </p>
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
              {editTarget ? 'Simpan Perubahan' : 'Tambah Banner'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete confirm */}
      <Dialog open={!!deleteTarget} onOpenChange={v => { if (!v) setDeleteTarget(null) }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Hapus Banner?</DialogTitle>
          </DialogHeader>
          <p className="text-sm text-muted-foreground">
            Banner <strong>{deleteTarget?.title}</strong> akan dihapus permanen.
          </p>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteTarget(null)}>Batal</Button>
            <Button
              variant="destructive"
              disabled={actionLoading === deleteTarget?.id + '-delete'}
              onClick={deleteBanner}
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
