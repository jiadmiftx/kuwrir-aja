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
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import {
  CheckCircle, XCircle, Eye, Loader2, Bike, FileText, RefreshCw, Clock,
} from 'lucide-react'
import { apiFetch as api } from '@/lib/api'

interface Application {
  id: string
  user_id: string
  status: string // pending | approved | rejected
  vehicle_type: string
  vehicle_plate: string
  vehicle_year: number
  vehicle_color: string
  vehicle_brand: string
  ktp_url: string
  sim_url: string
  stnk_url: string
  selfie_url: string
  vehicle_photo_url: string
  review_note: string
  reviewed_at: string | null
  created_at: string
  user?: {
    name: string
    phone: string
    email: string
  }
}

type DocKey = 'ktp_url' | 'sim_url' | 'stnk_url' | 'selfie_url' | 'vehicle_photo_url'

const fmtDate = (d: string) =>
  new Date(d).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })

// Shows a document image or a "no file" placeholder
function DocImage({ url, label }: { url: string; label: string }) {
  if (!url) return (
    <div className="flex h-32 w-full items-center justify-center rounded border-2 border-dashed text-muted-foreground text-xs">
      {label} — tidak ada file
    </div>
  )
  return (
    <div className="space-y-1">
      <p className="text-xs font-medium text-muted-foreground">{label}</p>
      <a href={url} target="_blank" rel="noreferrer">
        <img
          src={url}
          alt={label}
          className="h-32 w-full rounded border object-cover cursor-pointer hover:opacity-90 transition-opacity"
          onError={e => { (e.target as HTMLImageElement).style.display = 'none' }}
        />
      </a>
    </div>
  )
}

export default function DriverApplicationsPage() {
  const [applications, setApplications] = useState<Application[]>([])
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState('pending')
  const [selected, setSelected] = useState<Application | null>(null)
  const [reviewNote, setReviewNote] = useState('')
  const [actionLoading, setActionLoading] = useState<string | null>(null)

  const fetchApplications = async (status: string) => {
    setLoading(true)
    try {
      const res = await api(`/api/v1/admin/driver-applications?status=${status}`)
      const data = await res.json()
      if (res.ok) setApplications(data.applications ?? [])
    } finally { setLoading(false) }
  }

  useEffect(() => { fetchApplications(activeTab) }, [activeTab])

  const review = async (id: string, action: 'approve' | 'reject') => {
    setActionLoading(id + '-' + action)
    try {
      const res = await api(`/api/v1/admin/driver-applications/${id}/review`, {
        method: 'PUT',
        body: JSON.stringify({ action, note: reviewNote }),
      })
      if (res.ok) {
        setApplications(prev => prev.filter(a => a.id !== id))
        setSelected(null)
        setReviewNote('')
      }
    } finally { setActionLoading(null) }
  }

  const pendingCount = applications.length

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Driver Applications</h2>
          <p className="text-muted-foreground">Review & verifikasi pendaftaran driver baru</p>
        </div>
        <Button variant="outline" onClick={() => fetchApplications(activeTab)} disabled={loading}>
          <RefreshCw className={`h-4 w-4 mr-2 ${loading ? 'animate-spin' : ''}`} /> Refresh
        </Button>
      </div>

      {/* Alert for pending */}
      {activeTab === 'pending' && pendingCount > 0 && (
        <div className="flex items-center gap-3 rounded-lg border border-orange-200 bg-orange-50 px-4 py-3 text-orange-800">
          <Clock className="h-4 w-4 shrink-0" />
          <span className="text-sm"><strong>{pendingCount} pendaftaran</strong> menunggu review</span>
        </div>
      )}

      <Tabs value={activeTab} onValueChange={v => setActiveTab(v)}>
        <TabsList>
          <TabsTrigger value="pending">Menunggu Review</TabsTrigger>
          <TabsTrigger value="approved">Disetujui</TabsTrigger>
          <TabsTrigger value="rejected">Ditolak</TabsTrigger>
        </TabsList>

        {['pending', 'approved', 'rejected'].map(tab => (
          <TabsContent key={tab} value={tab} className="mt-4">
            <Card>
              <CardContent className="pt-4">
                {loading ? (
                  <div className="text-center py-8"><Loader2 className="h-5 w-5 animate-spin mx-auto" /></div>
                ) : applications.length === 0 ? (
                  <div className="text-center py-12 text-muted-foreground">
                    <FileText className="h-10 w-10 mx-auto mb-3 opacity-30" />
                    <p>Tidak ada pendaftaran {tab === 'pending' ? 'yang menunggu' : tab === 'approved' ? 'yang disetujui' : 'yang ditolak'}</p>
                  </div>
                ) : (
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Pemohon</TableHead>
                        <TableHead>Kendaraan</TableHead>
                        <TableHead>Dokumen</TableHead>
                        <TableHead>Dikirim</TableHead>
                        {tab !== 'pending' && <TableHead>Catatan</TableHead>}
                        <TableHead className="text-right">Aksi</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {applications.map(app => (
                        <TableRow key={app.id}>
                          <TableCell>
                            <div className="font-medium">{app.user?.name ?? '-'}</div>
                            <div className="text-sm text-muted-foreground">{app.user?.phone}</div>
                          </TableCell>
                          <TableCell>
                            <div className="flex items-center gap-2">
                              <Bike className="h-4 w-4 text-muted-foreground" />
                              <div>
                                <div className="font-medium">{app.vehicle_plate}</div>
                                <div className="text-sm text-muted-foreground capitalize">
                                  {app.vehicle_type} · {app.vehicle_brand} {app.vehicle_color} {app.vehicle_year > 0 ? app.vehicle_year : ''}
                                </div>
                              </div>
                            </div>
                          </TableCell>
                          <TableCell>
                            <div className="flex gap-1 flex-wrap">
                              {([
                                { key: 'ktp_url', label: 'KTP' },
                                { key: 'sim_url', label: 'SIM' },
                                { key: 'stnk_url', label: 'STNK' },
                                { key: 'selfie_url', label: 'Selfie' },
                                { key: 'vehicle_photo_url', label: 'Kendaraan' },
                              ] as { key: DocKey; label: string }[]).map(doc => (
                                <Badge
                                  key={doc.key}
                                  variant={app[doc.key] ? 'secondary' : 'outline'}
                                  className={`text-xs ${app[doc.key] ? 'bg-green-100 text-green-800' : 'text-red-500'}`}
                                >
                                  {doc.label} {app[doc.key] ? '✓' : '✗'}
                                </Badge>
                              ))}
                            </div>
                          </TableCell>
                          <TableCell className="text-sm text-muted-foreground">
                            {fmtDate(app.created_at)}
                          </TableCell>
                          {tab !== 'pending' && (
                            <TableCell className="text-sm text-muted-foreground max-w-xs truncate">
                              {app.review_note || '-'}
                            </TableCell>
                          )}
                          <TableCell className="text-right">
                            <div className="flex justify-end gap-1">
                              <Button variant="ghost" size="sm" onClick={() => { setSelected(app); setReviewNote('') }}>
                                <Eye className="h-4 w-4" />
                              </Button>
                              {tab === 'pending' && (
                                <>
                                  <Button
                                    variant="ghost" size="sm"
                                    className="text-green-600 hover:bg-green-50"
                                    disabled={!!actionLoading}
                                    onClick={() => { setSelected(app); setReviewNote('') }}
                                  >
                                    <CheckCircle className="h-4 w-4" />
                                  </Button>
                                  <Button
                                    variant="ghost" size="sm"
                                    className="text-red-600 hover:bg-red-50"
                                    disabled={!!actionLoading}
                                    onClick={() => { setSelected(app); setReviewNote('') }}
                                  >
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
                )}
              </CardContent>
            </Card>
          </TabsContent>
        ))}
      </Tabs>

      {/* Review Detail Dialog */}
      <Dialog open={!!selected} onOpenChange={v => { if (!v) setSelected(null) }}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Review Pendaftaran Driver — {selected?.user?.name}</DialogTitle>
          </DialogHeader>

          {selected && (
            <div className="space-y-4">
              {/* Driver info */}
              <div className="grid grid-cols-2 gap-3 text-sm">
                <div><span className="text-muted-foreground">Nama: </span><strong>{selected.user?.name}</strong></div>
                <div><span className="text-muted-foreground">HP: </span>{selected.user?.phone}</div>
                <div><span className="text-muted-foreground">Email: </span>{selected.user?.email}</div>
                <div><span className="text-muted-foreground">Plat: </span><strong>{selected.vehicle_plate}</strong></div>
                <div><span className="text-muted-foreground">Jenis: </span><span className="capitalize">{selected.vehicle_type}</span></div>
                <div><span className="text-muted-foreground">Kendaraan: </span>{selected.vehicle_brand} {selected.vehicle_color} {selected.vehicle_year > 0 ? selected.vehicle_year : ''}</div>
              </div>

              {/* Documents */}
              <div>
                <p className="text-sm font-semibold mb-3">Dokumen</p>
                <div className="grid grid-cols-2 gap-3">
                  <DocImage url={selected.ktp_url} label="KTP" />
                  <DocImage url={selected.sim_url} label="SIM" />
                  <DocImage url={selected.stnk_url} label="STNK" />
                  <DocImage url={selected.selfie_url} label="Selfie + KTP" />
                  <DocImage url={selected.vehicle_photo_url} label="Foto Kendaraan" />
                </div>
              </div>

              {/* Review note */}
              {selected.status === 'pending' && (
                <div className="space-y-1">
                  <Label>Catatan untuk Pemohon (opsional)</Label>
                  <Input
                    placeholder="e.g. Foto SIM kurang jelas, mohon upload ulang"
                    value={reviewNote}
                    onChange={e => setReviewNote(e.target.value)}
                  />
                </div>
              )}

              {selected.status !== 'pending' && selected.review_note && (
                <div className="rounded bg-muted p-3 text-sm">
                  <span className="font-medium">Catatan admin: </span>{selected.review_note}
                </div>
              )}
            </div>
          )}

          <DialogFooter>
            <Button variant="outline" onClick={() => setSelected(null)}>Tutup</Button>
            {selected?.status === 'pending' && (
              <>
                <Button
                  variant="destructive"
                  disabled={!!actionLoading}
                  onClick={() => review(selected.id, 'reject')}
                >
                  {actionLoading === selected.id + '-reject'
                    ? <Loader2 className="h-4 w-4 animate-spin mr-2" />
                    : <XCircle className="h-4 w-4 mr-2" />}
                  Tolak
                </Button>
                <Button
                  className="bg-green-600 hover:bg-green-700"
                  disabled={!!actionLoading}
                  onClick={() => review(selected.id, 'approve')}
                >
                  {actionLoading === selected.id + '-approve'
                    ? <Loader2 className="h-4 w-4 animate-spin mr-2" />
                    : <CheckCircle className="h-4 w-4 mr-2" />}
                  Setujui
                </Button>
              </>
            )}
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
