import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from '@/components/ui/dialog'
import { Loader2, Ban, CheckCircle, ShieldAlert, Plus, Pencil, Eye, EyeOff, Lock } from 'lucide-react'
import { toast } from 'sonner'
import { apiFetch as api } from '@/lib/api'

interface Admin {
  id: string
  name: string
  phone: string
  admin_tier: 'superadmin' | 'admin' | 'cs' | 'developer' | ''
  is_active: boolean
  created_at: string
  // Backend-computed: this is the platform's protected owner account —
  // only that account itself can edit/deactivate it, even other
  // superadmins are blocked (see UpdateAdmin's rootSuperadminPhone check).
  is_root?: boolean
}

const TIERS = ['superadmin', 'admin', 'cs', 'developer'] as const

const TIER_LABEL: Record<string, string> = {
  superadmin: 'Superadmin',
  admin: 'Admin',
  cs: 'CS',
  developer: 'Developer',
  '': 'Superadmin (legacy)',
}

const TIER_DESC: Record<string, string> = {
  superadmin: 'Akses penuh termasuk kelola admin lain',
  admin: 'Operasional penuh tanpa kelola admin lain',
  cs: 'Hanya lihat data + balas support chat',
  developer: 'Hanya lihat data + audit log',
}

function tierBadgeVariant(tier: string): 'default' | 'secondary' | 'destructive' | 'outline' {
  switch (tier) {
    case 'superadmin':
    case '':
      return 'destructive'
    case 'admin':
      return 'default'
    case 'cs':
      return 'secondary'
    case 'developer':
      return 'outline'
    default:
      return 'outline'
  }
}

function currentAdminTier(): string {
  try {
    const raw = localStorage.getItem('user')
    if (!raw) return ''
    return JSON.parse(raw).admin_tier ?? ''
  } catch {
    return ''
  }
}

function currentAdminId(): string {
  try {
    const raw = localStorage.getItem('user')
    if (!raw) return ''
    return JSON.parse(raw).id ?? ''
  } catch {
    return ''
  }
}

export default function UsersPage() {
  const isSuperadmin = currentAdminTier() === '' || currentAdminTier() === 'superadmin'
  const myId = currentAdminId()

  const [admins, setAdmins] = useState<Admin[]>([])
  const [isLoading, setIsLoading] = useState(true)

  // Create dialog
  const [createOpen, setCreateOpen] = useState(false)
  const [newName, setNewName] = useState('')
  const [newPhone, setNewPhone] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [newShowPassword, setNewShowPassword] = useState(false)
  const [newTier, setNewTier] = useState<string>('admin')
  const [creating, setCreating] = useState(false)

  // Edit admin dialog (name, phone, tier + optional password change)
  const [tierTarget, setTierTarget] = useState<Admin | null>(null)
  const [tierName, setTierName] = useState('')
  const [tierPhone, setTierPhone] = useState('')
  const [tierValue, setTierValue] = useState<string>('admin')
  const [tierNewPassword, setTierNewPassword] = useState('')
  const [tierShowPassword, setTierShowPassword] = useState(false)
  const [tierSubmitting, setTierSubmitting] = useState(false)

  // Deactivate confirm dialog
  const [toggleTarget, setToggleTarget] = useState<Admin | null>(null)
  const [toggleSubmitting, setToggleSubmitting] = useState(false)

  const fetchAdmins = async () => {
    setIsLoading(true)
    try {
      const res = await api('/api/v1/admin/admins')
      const data = await res.json()
      if (res.ok) setAdmins(data.admins ?? [])
      else toast.error(data.error ?? 'Gagal memuat daftar admin')
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    if (isSuperadmin) fetchAdmins()
    else setIsLoading(false)
  }, [isSuperadmin])

  const submitCreate = async () => {
    if (!newName || !newPhone || !newPassword || !newTier) return
    setCreating(true)
    try {
      const res = await api('/api/v1/admin/admins', {
        method: 'POST',
        body: JSON.stringify({ name: newName, phone: newPhone, password: newPassword, admin_tier: newTier }),
      })
      const data = await res.json().catch(() => ({}))
      if (res.ok) {
        setAdmins(prev => [data.admin, ...prev])
        toast.success('Admin baru berhasil dibuat')
        setCreateOpen(false)
        setNewName(''); setNewPhone(''); setNewPassword(''); setNewTier('admin'); setNewShowPassword(false)
      } else {
        toast.error(data.error ?? `Gagal membuat admin (${res.status})`)
      }
    } catch {
      toast.error('Gagal terhubung ke server, coba lagi')
    } finally {
      setCreating(false)
    }
  }

  const openTierDialog = (admin: Admin) => {
    setTierTarget(admin)
    setTierName(admin.name)
    setTierPhone(admin.phone)
    setTierValue(admin.admin_tier || 'superadmin')
    setTierNewPassword('')
    setTierShowPassword(false)
  }

  const submitTierChange = async () => {
    if (!tierTarget) return
    if (!tierName || !tierPhone) {
      toast.error('Nama dan telepon wajib diisi')
      return
    }
    if (tierNewPassword && tierNewPassword.length < 6) {
      toast.error('Password baru minimal 6 karakter')
      return
    }
    setTierSubmitting(true)
    try {
      const body: Record<string, string> = { name: tierName, phone: tierPhone, admin_tier: tierValue }
      if (tierNewPassword) body.password = tierNewPassword
      const res = await api(`/api/v1/admin/admins/${tierTarget.id}`, {
        method: 'PUT',
        body: JSON.stringify(body),
      })
      const data = await res.json().catch(() => ({}))
      if (res.ok) {
        setAdmins(prev => prev.map(a => a.id === tierTarget.id ? data.admin : a))
        toast.success(tierNewPassword ? 'Data & password admin diperbarui' : 'Data admin diperbarui')
        setTierTarget(null)
      } else {
        toast.error(data.error ?? `Gagal memperbarui admin (${res.status})`)
      }
    } catch {
      toast.error('Gagal terhubung ke server, coba lagi')
    } finally {
      setTierSubmitting(false)
    }
  }

  const submitToggleActive = async () => {
    if (!toggleTarget) return
    setToggleSubmitting(true)
    try {
      const res = await api(`/api/v1/admin/admins/${toggleTarget.id}`, {
        method: 'PUT',
        body: JSON.stringify({ is_active: !toggleTarget.is_active }),
      })
      const data = await res.json().catch(() => ({}))
      if (res.ok) {
        setAdmins(prev => prev.map(a => a.id === toggleTarget.id ? data.admin : a))
        toast.success(data.admin.is_active ? 'Admin diaktifkan' : 'Admin dinonaktifkan')
        setToggleTarget(null)
      } else {
        toast.error(data.error ?? `Gagal mengubah status admin (${res.status})`)
      }
    } catch {
      toast.error('Gagal terhubung ke server, coba lagi')
    } finally {
      setToggleSubmitting(false)
    }
  }

  if (!isSuperadmin) {
    return (
      <div className="space-y-6">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Admin Users</h2>
          <p className="text-muted-foreground">Kelola akun admin</p>
        </div>
        <Card>
          <CardContent className="flex flex-col items-center justify-center gap-3 py-16 text-center">
            <ShieldAlert className="h-10 w-10 text-destructive" />
            <div className="text-lg font-semibold">Akses Ditolak</div>
            <p className="max-w-sm text-sm text-muted-foreground">
              Hanya superadmin yang bisa mengelola akun admin. Hubungi superadmin jika Anda membutuhkan akses ini.
            </p>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Admin Users</h2>
          <p className="text-muted-foreground">Kelola akun admin & hak aksesnya</p>
        </div>
        <Button onClick={() => setCreateOpen(true)}>
          <Plus className="h-4 w-4 mr-1" /> Tambah Admin
        </Button>
      </div>

      {/* Tier legend */}
      <Card>
        <CardContent className="grid gap-3 py-4 sm:grid-cols-2 lg:grid-cols-4">
          {TIERS.map(tier => (
            <div key={tier} className="flex items-start gap-2">
              <Badge variant={tierBadgeVariant(tier)} className="mt-0.5 shrink-0">{TIER_LABEL[tier]}</Badge>
              <p className="text-xs text-muted-foreground">{TIER_DESC[tier]}</p>
            </div>
          ))}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Daftar Admin</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Nama</TableHead>
                <TableHead>Telepon</TableHead>
                <TableHead>Tier</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Dibuat</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <TableRow><TableCell colSpan={6} className="text-center py-8">
                  <Loader2 className="h-5 w-5 animate-spin mx-auto" />
                </TableCell></TableRow>
              ) : admins.length === 0 ? (
                <TableRow><TableCell colSpan={6} className="text-center text-muted-foreground py-8">Belum ada admin</TableCell></TableRow>
              ) : admins.map(a => {
                const isSelf = a.id === myId
                const lockedForMe = !!a.is_root && !isSelf
                return (
                  <TableRow key={a.id}>
                    <TableCell className="font-medium">
                      <span className="inline-flex items-center gap-1.5">
                        {a.name}
                        {a.is_root && (
                          <span title="Akun superadmin utama — hanya bisa diubah oleh pemiliknya sendiri">
                            <Lock className="h-3.5 w-3.5 text-muted-foreground" />
                          </span>
                        )}
                      </span>
                    </TableCell>
                    <TableCell>{a.phone}</TableCell>
                    <TableCell>
                      <Badge variant={tierBadgeVariant(a.admin_tier)}>{TIER_LABEL[a.admin_tier] ?? a.admin_tier}</Badge>
                    </TableCell>
                    <TableCell>
                      <Badge variant={a.is_active ? 'default' : 'secondary'}>
                        {a.is_active ? 'Active' : 'Inactive'}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {a.created_at ? new Date(a.created_at).toLocaleDateString('id-ID') : '-'}
                    </TableCell>
                    <TableCell className="text-right">
                      {lockedForMe ? (
                        <span className="text-xs text-muted-foreground">Dilindungi</span>
                      ) : (
                        <div className="flex justify-end gap-1">
                          <Button variant="outline" size="sm" onClick={() => openTierDialog(a)}>
                            <Pencil className="h-4 w-4 mr-1" /> Edit Admin
                          </Button>
                          {!isSelf && (
                            <Button
                              variant="ghost" size="sm"
                              className={a.is_active ? 'text-red-600 hover:bg-red-50' : 'text-green-600 hover:bg-green-50'}
                              onClick={() => setToggleTarget(a)}
                            >
                              {a.is_active ? <><Ban className="h-4 w-4 mr-1" /> Nonaktifkan</> : <><CheckCircle className="h-4 w-4 mr-1" /> Aktifkan</>}
                            </Button>
                          )}
                        </div>
                      )}
                    </TableCell>
                  </TableRow>
                )
              })}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      {/* Create Admin Dialog */}
      <Dialog open={createOpen} onOpenChange={setCreateOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Tambah Admin Baru</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label>Nama</Label>
              <Input value={newName} onChange={e => setNewName(e.target.value)} placeholder="Nama lengkap" />
            </div>
            <div className="space-y-2">
              <Label>Telepon</Label>
              <Input value={newPhone} onChange={e => setNewPhone(e.target.value)} placeholder="08xxxxxxxxxx" />
            </div>
            <div className="space-y-2">
              <Label>Password</Label>
              <div className="relative">
                <Input
                  type={newShowPassword ? 'text' : 'password'}
                  value={newPassword}
                  onChange={e => setNewPassword(e.target.value)}
                  placeholder="Minimal 6 karakter"
                  className="pr-10"
                />
                <button
                  type="button"
                  className="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                  onClick={() => setNewShowPassword(v => !v)}
                  tabIndex={-1}
                >
                  {newShowPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
            </div>
            <div className="space-y-2">
              <Label>Tier</Label>
              <Select value={newTier} onValueChange={val => val !== null && setNewTier(val)}>
                <SelectTrigger className="w-full">
                  <SelectValue placeholder="Pilih tier" />
                </SelectTrigger>
                <SelectContent>
                  {TIERS.map(t => (
                    <SelectItem key={t} value={t}>{TIER_LABEL[t]}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <p className="text-xs text-muted-foreground">{TIER_DESC[newTier]}</p>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCreateOpen(false)}>Batal</Button>
            <Button
              disabled={creating || !newName || !newPhone || !newPassword}
              onClick={submitCreate}
            >
              {creating ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : <Plus className="h-4 w-4 mr-2" />}
              Buat Admin
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit Admin Dialog: name, phone (login username), tier + optional password change */}
      <Dialog open={!!tierTarget} onOpenChange={v => { if (!v) setTierTarget(null) }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Edit Admin — {tierTarget?.name}</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label>Nama</Label>
              <Input value={tierName} onChange={e => setTierName(e.target.value)} placeholder="Nama lengkap" />
            </div>
            <div className="space-y-2">
              <Label>Telepon (username login)</Label>
              <Input value={tierPhone} onChange={e => setTierPhone(e.target.value)} placeholder="08xxxxxxxxxx" />
            </div>
            <div className="space-y-2">
              <Label>Tier</Label>
              <Select value={tierValue} onValueChange={val => val !== null && setTierValue(val)}>
                <SelectTrigger className="w-full">
                  <SelectValue placeholder="Pilih tier" />
                </SelectTrigger>
                <SelectContent>
                  {TIERS.map(t => (
                    <SelectItem key={t} value={t}>{TIER_LABEL[t]}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <p className="text-xs text-muted-foreground">{TIER_DESC[tierValue]}</p>
            </div>
            <div className="space-y-2">
              <Label>Password Baru (opsional)</Label>
              <div className="relative">
                <Input
                  type={tierShowPassword ? 'text' : 'password'}
                  value={tierNewPassword}
                  onChange={e => setTierNewPassword(e.target.value)}
                  placeholder="Kosongkan jika tidak ingin mengganti password"
                  className="pr-10"
                />
                <button
                  type="button"
                  className="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                  onClick={() => setTierShowPassword(v => !v)}
                  tabIndex={-1}
                >
                  {tierShowPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
              <p className="text-xs text-muted-foreground">Minimal 6 karakter jika diisi.</p>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setTierTarget(null)}>Batal</Button>
            <Button disabled={tierSubmitting || !tierName || !tierPhone} onClick={submitTierChange}>
              {tierSubmitting ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : <Pencil className="h-4 w-4 mr-2" />}
              Simpan
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Deactivate/Activate Confirm Dialog */}
      <Dialog open={!!toggleTarget} onOpenChange={v => { if (!v) setToggleTarget(null) }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {toggleTarget?.is_active ? 'Nonaktifkan Admin?' : 'Aktifkan Admin?'}
            </DialogTitle>
          </DialogHeader>
          <p className="text-sm text-muted-foreground">
            {toggleTarget?.is_active
              ? `${toggleTarget?.name} tidak akan bisa login ke admin panel setelah dinonaktifkan.`
              : `${toggleTarget?.name} akan bisa login kembali ke admin panel.`}
          </p>
          <DialogFooter>
            <Button variant="outline" onClick={() => setToggleTarget(null)}>Batal</Button>
            <Button
              className={toggleTarget?.is_active ? 'bg-red-600 hover:bg-red-700' : 'bg-green-600 hover:bg-green-700'}
              disabled={toggleSubmitting}
              onClick={submitToggleActive}
            >
              {toggleSubmitting ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : null}
              {toggleTarget?.is_active ? 'Nonaktifkan' : 'Aktifkan'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
