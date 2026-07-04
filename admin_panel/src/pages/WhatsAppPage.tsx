import { useState, useEffect, useRef, useCallback } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Badge } from '@/components/ui/badge'
import { MessageCircle, Loader2, Send, CheckCircle2 } from 'lucide-react'
import { apiFetch as api } from '@/lib/api'

interface WhatsAppStatus {
  paired: boolean
  number: string | null
}

interface WhatsAppLogEntry {
  timestamp: string
  type: string
  message: string
}

const fmt = (d: string) =>
  new Date(d).toLocaleString('id-ID', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })

export default function WhatsAppPage() {
  const [status, setStatus] = useState<WhatsAppStatus | null>(null)
  const [logs, setLogs] = useState<WhatsAppLogEntry[]>([])
  const [qrUrl, setQrUrl] = useState<string | null>(null)
  const [qrError, setQrError] = useState('')

  const [phone, setPhone] = useState('')
  const [message, setMessage] = useState('')
  const [sending, setSending] = useState(false)
  const [sendError, setSendError] = useState('')
  const [sendSuccess, setSendSuccess] = useState(false)

  const qrUrlRef = useRef<string | null>(null)

  const fetchStatus = useCallback(async () => {
    try {
      const res = await api('/api/v1/admin/whatsapp/status')
      if (res.ok) setStatus(await res.json())
    } catch {
      // ignore, next poll retries
    }
  }, [])

  const fetchLogs = useCallback(async () => {
    try {
      const res = await api('/api/v1/admin/whatsapp/logs')
      if (res.ok) {
        const data = await res.json()
        setLogs(data.logs ?? [])
      }
    } catch {
      // ignore
    }
  }, [])

  const fetchQr = useCallback(async () => {
    try {
      const res = await api('/api/v1/admin/whatsapp/qr')
      if (!res.ok) {
        setQrError('Belum ada QR — menunggu gateway siap...')
        return
      }
      const blob = await res.blob()
      const url = URL.createObjectURL(blob)
      if (qrUrlRef.current) URL.revokeObjectURL(qrUrlRef.current)
      qrUrlRef.current = url
      setQrUrl(url)
      setQrError('')
    } catch {
      setQrError('Gagal memuat QR')
    }
  }, [])

  useEffect(() => {
    fetchStatus()
    const interval = setInterval(fetchStatus, 5000)
    return () => clearInterval(interval)
  }, [fetchStatus])

  useEffect(() => {
    if (!status) return
    if (status.paired) {
      fetchLogs()
      const interval = setInterval(fetchLogs, 5000)
      return () => clearInterval(interval)
    } else {
      fetchQr()
    }
  }, [status, fetchLogs, fetchQr])

  useEffect(() => {
    return () => {
      if (qrUrlRef.current) URL.revokeObjectURL(qrUrlRef.current)
    }
  }, [])

  const sendMessage = async () => {
    if (!phone.trim() || !message.trim()) return
    setSending(true)
    setSendError('')
    setSendSuccess(false)
    try {
      const res = await api('/api/v1/admin/whatsapp/send-message', {
        method: 'POST',
        body: JSON.stringify({ phone: phone.trim(), message: message.trim() }),
      })
      if (res.ok) {
        setSendSuccess(true)
        setMessage('')
        fetchLogs()
      } else {
        const err = await res.json()
        setSendError(err.error || 'Gagal mengirim pesan')
      }
    } catch {
      setSendError('Gagal mengirim pesan')
    } finally {
      setSending(false)
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">WhatsApp Gateway</h2>
        <p className="text-muted-foreground">
          Status koneksi WhatsApp OTP, aktivitas terakhir, dan kirim pesan manual.
        </p>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        {/* Status / QR card */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2">
              <MessageCircle className="h-5 w-5" /> Status Koneksi
            </CardTitle>
          </CardHeader>
          <CardContent>
            {!status ? (
              <div className="py-8 text-center"><Loader2 className="h-5 w-5 animate-spin mx-auto" /></div>
            ) : status.paired ? (
              <div className="flex items-center gap-3 py-4">
                <CheckCircle2 className="h-8 w-8 text-green-600" />
                <div>
                  <Badge variant="default">Terhubung</Badge>
                  <p className="text-sm text-muted-foreground mt-1">
                    Nomor: {status.number ?? '-'}
                  </p>
                </div>
              </div>
            ) : (
              <div className="flex flex-col items-center gap-3 py-4">
                <Badge variant="secondary">Belum Terhubung</Badge>
                {qrUrl ? (
                  <img src={qrUrl} alt="WhatsApp pairing QR" className="w-56 h-56 border rounded-md" />
                ) : (
                  <p className="text-sm text-muted-foreground">{qrError || 'Memuat QR...'}</p>
                )}
                <p className="text-xs text-muted-foreground text-center max-w-xs">
                  Scan pakai WhatsApp di HP: Perangkat Tertaut → Tautkan Perangkat.
                  QR akan otomatis refresh tiap beberapa detik.
                </p>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Send message card */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Kirim Pesan Manual</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <p className="text-xs text-muted-foreground">
              Untuk tes pengiriman atau kontak manual satu nomor — bukan untuk broadcast massal.
            </p>
            <div className="space-y-1">
              <Label>Nomor HP</Label>
              <Input
                placeholder="08xxxxxxxxxx"
                value={phone}
                onChange={e => setPhone(e.target.value)}
                disabled={!status?.paired}
              />
            </div>
            <div className="space-y-1">
              <Label>Pesan</Label>
              <textarea
                className="w-full rounded-md border px-3 py-2 text-sm min-h-24"
                value={message}
                onChange={e => setMessage(e.target.value)}
                disabled={!status?.paired}
                placeholder="Isi pesan..."
              />
            </div>
            {sendError && <p className="text-sm text-red-600">{sendError}</p>}
            {sendSuccess && <p className="text-sm text-green-600">Pesan terkirim</p>}
            <Button
              onClick={sendMessage}
              disabled={!status?.paired || sending || !phone.trim() || !message.trim()}
              className="w-full"
            >
              {sending ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : <Send className="h-4 w-4 mr-2" />}
              Kirim
            </Button>
            {!status?.paired && (
              <p className="text-xs text-muted-foreground text-center">
                Sambungkan WhatsApp dulu (scan QR di kiri) sebelum bisa kirim pesan.
              </p>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Activity log */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Aktivitas Terakhir</CardTitle>
        </CardHeader>
        <CardContent>
          {logs.length === 0 ? (
            <p className="text-sm text-muted-foreground text-center py-6">Belum ada aktivitas.</p>
          ) : (
            <div className="space-y-2 max-h-96 overflow-y-auto">
              {logs.map((log, i) => (
                <div key={i} className="flex items-start justify-between gap-3 text-sm border-b pb-2 last:border-0">
                  <span className="flex-1">{log.message}</span>
                  <span className="text-xs text-muted-foreground shrink-0">{fmt(log.timestamp)}</span>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
