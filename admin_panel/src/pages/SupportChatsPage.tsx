import { useState, useEffect, useRef } from 'react'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { MessageSquare, Send, Loader2 } from 'lucide-react'

interface SupportUser {
  user_id: string
  name: string
  phone: string
  unread_count: number
  last_message: string
}

interface SupportMessage {
  id: string
  user_id: string
  sender_role: 'customer' | 'admin'
  text: string
  is_read: boolean
  created_at: string
}

const authHeaders = () => ({
  Authorization: `Bearer ${localStorage.getItem('token')}`,
  'Content-Type': 'application/json',
})

const fmt = (d: string) =>
  new Date(d).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })

export default function SupportChatsPage() {
  const [users, setUsers] = useState<SupportUser[]>([])
  const [selectedUser, setSelectedUser] = useState<SupportUser | null>(null)
  const [messages, setMessages] = useState<SupportMessage[]>([])
  const [replyText, setReplyText] = useState('')
  const [sending, setSending] = useState(false)
  const [loadingUsers, setLoadingUsers] = useState(true)
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const messagesEndRef = useRef<HTMLDivElement>(null)

  const fetchUsers = async () => {
    try {
      const res = await fetch('/api/v1/admin/support/users', { headers: authHeaders() })
      const data = await res.json()
      setUsers(data.users ?? [])
    } catch (_) {}
    setLoadingUsers(false)
  }

  const fetchMessages = async (userId: string) => {
    try {
      const res = await fetch(`/api/v1/admin/support/users/${userId}/messages`, {
        headers: authHeaders(),
      })
      const data = await res.json()
      setMessages(data.messages ?? [])
      // Refresh unread counts in user list
      setUsers((prev) =>
        prev.map((u) => (u.user_id === userId ? { ...u, unread_count: 0 } : u))
      )
    } catch (_) {}
  }

  const handleSelectUser = (user: SupportUser) => {
    setSelectedUser(user)
    setMessages([])
    fetchMessages(user.user_id)
  }

  const handleSendReply = async () => {
    if (!replyText.trim() || !selectedUser || sending) return
    setSending(true)
    try {
      await fetch(`/api/v1/admin/support/users/${selectedUser.user_id}/messages`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ text: replyText.trim() }),
      })
      setReplyText('')
      await fetchMessages(selectedUser.user_id)
    } catch (_) {}
    setSending(false)
  }

  // Initial load + poll users every 5s
  useEffect(() => {
    fetchUsers()
    const interval = setInterval(fetchUsers, 5000)
    return () => clearInterval(interval)
  }, [])

  // Poll active chat every 3s
  useEffect(() => {
    if (pollRef.current) clearInterval(pollRef.current)
    if (!selectedUser) return
    pollRef.current = setInterval(() => fetchMessages(selectedUser.user_id), 3000)
    return () => {
      if (pollRef.current) clearInterval(pollRef.current)
    }
  }, [selectedUser?.user_id])

  // Scroll to bottom on new messages
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold">Support Chat</h1>
        <p className="text-muted-foreground text-sm mt-1">Pesan masuk dari pelanggan</p>
      </div>

      <div className="flex gap-4 h-[calc(100vh-200px)]">
        {/* User list */}
        <Card className="w-80 flex flex-col overflow-hidden shrink-0">
          <div className="p-4 border-b font-semibold text-sm flex items-center gap-2">
            <MessageSquare className="h-4 w-4" />
            Pengguna
            {loadingUsers && <Loader2 className="h-3 w-3 animate-spin ml-auto" />}
          </div>
          <div className="flex-1 overflow-y-auto">
            {users.length === 0 && !loadingUsers && (
              <div className="flex flex-col items-center justify-center h-full text-muted-foreground text-sm gap-2 p-4">
                <MessageSquare className="h-10 w-10 opacity-30" />
                <p>Belum ada pesan masuk</p>
              </div>
            )}
            {users.map((u) => (
              <button
                key={u.user_id}
                onClick={() => handleSelectUser(u)}
                className={`w-full text-left px-4 py-3 border-b hover:bg-muted/50 transition-colors ${
                  selectedUser?.user_id === u.user_id ? 'bg-muted' : ''
                }`}
              >
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="font-medium text-sm truncate">{u.name}</p>
                    <p className="text-xs text-muted-foreground">{u.phone}</p>
                    <p className="text-xs text-muted-foreground truncate mt-1">{u.last_message}</p>
                  </div>
                  {u.unread_count > 0 && (
                    <Badge variant="destructive" className="shrink-0 text-xs">
                      {u.unread_count}
                    </Badge>
                  )}
                </div>
              </button>
            ))}
          </div>
        </Card>

        {/* Chat thread */}
        <Card className="flex-1 flex flex-col overflow-hidden">
          {!selectedUser ? (
            <div className="flex-1 flex flex-col items-center justify-center text-muted-foreground gap-3">
              <MessageSquare className="h-16 w-16 opacity-20" />
              <p className="text-sm">Pilih pengguna untuk melihat percakapan</p>
            </div>
          ) : (
            <>
              {/* Header */}
              <div className="p-4 border-b">
                <p className="font-semibold">{selectedUser.name}</p>
                <p className="text-xs text-muted-foreground">{selectedUser.phone}</p>
              </div>

              {/* Messages */}
              <div className="flex-1 overflow-y-auto p-4 space-y-3">
                {messages.map((msg) => {
                  const isAdmin = msg.sender_role === 'admin'
                  return (
                    <div
                      key={msg.id}
                      className={`flex ${isAdmin ? 'justify-end' : 'justify-start'}`}
                    >
                      <div
                        className={`max-w-[72%] px-4 py-2.5 rounded-2xl ${
                          isAdmin
                            ? 'bg-primary text-primary-foreground rounded-br-none'
                            : 'bg-muted rounded-bl-none'
                        }`}
                      >
                        <p className={`text-[11px] font-semibold mb-0.5 ${
                          isAdmin ? 'text-primary-foreground/70' : 'text-muted-foreground'
                        }`}>
                          {isAdmin ? 'Admin' : selectedUser.name}
                        </p>
                        <p className="text-sm">{msg.text}</p>
                        <p className={`text-[10px] mt-1 ${
                          isAdmin ? 'text-primary-foreground/60 text-right' : 'text-muted-foreground'
                        }`}>
                          {fmt(msg.created_at)}
                        </p>
                      </div>
                    </div>
                  )
                })}
                <div ref={messagesEndRef} />
              </div>

              {/* Reply input */}
              <div className="p-4 border-t flex gap-2">
                <Input
                  placeholder="Ketik balasan..."
                  value={replyText}
                  onChange={(e) => setReplyText(e.target.value)}
                  onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) handleSendReply() }}
                  className="flex-1"
                />
                <Button onClick={handleSendReply} disabled={!replyText.trim() || sending}>
                  {sending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
                </Button>
              </div>
            </>
          )}
        </Card>
      </div>
    </div>
  )
}
