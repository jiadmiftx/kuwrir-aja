import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogDescription,
} from '@/components/ui/dialog'
import { Loader2, Trash2 } from 'lucide-react'
import { toast } from 'sonner'
import { apiFetch as api, isRootSuperadmin } from '@/lib/api'

const CONFIRM_WORD = 'HAPUS'

/**
 * Renders nothing unless the logged-in admin is the root superadmin — see
 * lib/api.ts's isRootSuperadmin. Backend independently re-checks this on
 * DELETE /api/v1/admin/users/:id, so hiding the button here is just UX, not
 * the actual access control.
 */
export function DeleteUserAccountButton({
  userId,
  userName,
  onDeleted,
}: {
  userId: string
  userName: string
  onDeleted: () => void
}) {
  const [open, setOpen] = useState(false)
  const [confirmText, setConfirmText] = useState('')
  const [deleting, setDeleting] = useState(false)

  if (!isRootSuperadmin()) return null

  const submit = async () => {
    setDeleting(true)
    try {
      const res = await api(`/api/v1/admin/users/${userId}`, { method: 'DELETE' })
      const data = await res.json().catch(() => ({}))
      if (res.ok) {
        toast.success('Akun berhasil dihapus')
        setOpen(false)
        onDeleted()
      } else {
        toast.error(data.error ?? `Gagal menghapus akun (${res.status})`)
      }
    } catch {
      toast.error('Gagal terhubung ke server, coba lagi')
    } finally {
      setDeleting(false)
    }
  }

  return (
    <>
      <Button variant="destructive" size="sm" onClick={() => setOpen(true)}>
        <Trash2 className="h-4 w-4 mr-1" /> Hapus Akun
      </Button>
      <Dialog open={open} onOpenChange={v => { setOpen(v); if (!v) setConfirmText('') }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Hapus Akun {userName}</DialogTitle>
            <DialogDescription>
              Akun, profil, dan alamat tersimpan akan dihapus permanen dan tidak bisa dipulihkan.
              Riwayat transaksi tetap disimpan untuk keperluan pembukuan. Ditolak jika masih ada
              saldo COD atau wallet yang belum diselesaikan.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-2">
            <p className="text-sm text-muted-foreground">Ketik "{CONFIRM_WORD}" untuk konfirmasi</p>
            <Input
              value={confirmText}
              onChange={e => setConfirmText(e.target.value)}
              autoFocus
            />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>Batal</Button>
            <Button
              variant="destructive"
              disabled={confirmText.trim().toUpperCase() !== CONFIRM_WORD || deleting}
              onClick={submit}
            >
              {deleting && <Loader2 className="h-4 w-4 mr-1 animate-spin" />}
              Hapus Akun
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  )
}
