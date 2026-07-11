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
import { Loader2, Ban, CheckCircle, ShieldAlert, Plus, Pencil } from 'lucide-react'
import { toast } from 'sonner'
import { apiFetch as api } from '@/lib/api'

interface Admin {
  id: string
  name: string
  phone: string
  admin_tier: 'superadmin' | 'admin' | 'cs' | 'developer' | ''
  is_active: boolean
  created_at: string
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
  const [newTier, setNewTier] = useState<string>('admin')
  const [creating, setCreating] = useState(false)

  // Change tier dialog
  const [tierTarget, setTierTarget] = useState<Admin | null>(null)
  const [tierValue, setTierValue] = useState<string>('admin')
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
  }, [])

  const submitCreate = async () => {
    if (!newName || !newPhone || !newPassword || !newTier) return
    setCreating(true)
    try {
      const res = await api('/api/v1/admin/admins', {
        method: 'POST',
        body: JSON.stringify({ name: newName, phone: newPhone, password: newPassword, admin_tier: newTier }),
      })
      const data = await res.json()
      if (res.ok) {
        setAdmins(prev => [data.admin, ...prev])
        toast.success('Admin baru berhasil dibuat')
        setCreateOpen(false)
        setNewName(''); setNewPhone(''); setNewPassword(''); setNewTier('admin')
      } else {
        toast.error(data.error ?? 'Gagal membuat admin')
      }
    } finally {
      setCreating(false)
    }
  }

  const openTierDialog = (admin: Admin) => {
    setTierTarget(admin)
    setTierValue(admin.admin_tier || 'superadmin')
  }

  const submitTierChange = async () => {
    if (!tierTarget) return
    setTierSubmitting(true)
    try {
      const res = await api(`/api/v1/admin/admins/${tierTarget.id}`, {
        method: 'PUT',
        body: JSON.stringify({ admin_tier: tierValue }),
      })
      const data = await res.json()
      if (res.ok) {
        setAdmins(prev => prev.map(a => a.id === tierTarget.id ? data.admin : a))
        toast.success('Tier admin diperbarui')
        setTierTarget(null)
      } else {
        toast.error(data.error ?? 'Gagal memperbarui tier')
      }
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
      const data = await res.json()
      if (res.ok) {
        setAdmins(prev => prev.map(a => a.id === toggleTarget.id ? data.admin : a))
        toast.success(data.admin.is_active ? 'Admin diaktifkan' : 'Admin dinonaktifkan')
        setToggleTarget(null)
      } else {
        toast.error(data.error ?? 'Gagal mengubah status admin')
      }
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
                return (
                  <TableRow key={a.id}>
                    <TableCell className="font-medium">{a.name}</TableCell>
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
                      <div className="flex justify-end gap-1">
                        <Button variant="outline" size="sm" onClick={() => openTierDialog(a)}>
                          <Pencil className="h-4 w-4 mr-1" /> Ubah Tier
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
              <Input type="password" value={newPassword} onChange={e => setNewPassword(e.target.value)} placeholder="Minimal 8 karakter" />
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

      {/* Change Tier Dialog */}
      <Dialog open={!!tierTarget} onOpenChange={v => { if (!v) setTierTarget(null) }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Ubah Tier — {tierTarget?.name}</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
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
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setTierTarget(null)}>Batal</Button>
            <Button disabled={tierSubmitting} onClick={submitTierChange}>
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
