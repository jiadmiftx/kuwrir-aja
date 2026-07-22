import express from 'express'
import QRCode from 'qrcode'
import pino from 'pino'
import { rm } from 'fs/promises'
import {
  makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  fetchLatestBaileysVersion,
} from '@whiskeysockets/baileys'

const PORT = process.env.PORT || 3000
const API_KEY = process.env.WHATSAPP_API_KEY || ''
const AUTH_DIR = process.env.AUTH_DIR || './auth_session'
const MAX_LOGS = 100

const logger = pino({ level: process.env.LOG_LEVEL || 'info' })

let sock = null
let latestQrPng = null
let isPaired = false
let pairedNumber = null
const logs = []

// Operational activity log (pairing/connection/send events), most-recent
// first — purely for admin-panel visibility, not a business record, so an
// in-memory ring buffer is enough; no persistence needed.
function pushLog(type, message) {
  logs.unshift({ timestamp: new Date().toISOString(), type, message })
  if (logs.length > MAX_LOGS) logs.pop()
}

// Normalizes Indonesian phone numbers (08xx, +628xx, 628xx) into the
// country-code-first digit string Baileys/WhatsApp JIDs expect.
function toWhatsAppJid(phone) {
  let digits = phone.replace(/\D/g, '')
  if (digits.startsWith('0')) digits = '62' + digits.slice(1)
  if (!digits.startsWith('62')) digits = '62' + digits
  return `${digits}@s.whatsapp.net`
}

async function startSocket() {
  const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR)
  const { version } = await fetchLatestBaileysVersion()

  sock = makeWASocket({
    version,
    auth: state,
    logger,
    printQRInTerminal: false,
  })

  sock.ev.on('creds.update', saveCreds)

  sock.ev.on('connection.update', async (update) => {
    const { connection, lastDisconnect, qr } = update

    if (qr) {
      latestQrPng = await QRCode.toBuffer(qr, { type: 'png', width: 320 })
      isPaired = false
      pairedNumber = null
      logger.info('New pairing QR generated — fetch it from GET /qr and scan with WhatsApp')
      pushLog('qr', 'Pairing QR generated, waiting to be scanned')
    }

    if (connection === 'open') {
      isPaired = true
      latestQrPng = null
      pairedNumber = sock?.user?.id ? sock.user.id.split(':')[0] : null
      logger.info('WhatsApp session paired and connected')
      pushLog('connected', `Paired and connected as ${pairedNumber ?? 'unknown number'}`)
    }

    if (connection === 'close') {
      isPaired = false
      pairedNumber = null
      const statusCode = lastDisconnect?.error?.output?.statusCode
      const loggedOut = statusCode === DisconnectReason.loggedOut
      logger.warn({ statusCode, loggedOut }, 'WhatsApp connection closed')
      pushLog('disconnected', loggedOut
        ? 'Session logged out from the phone, needs a fresh QR scan'
        : 'Connection closed, reconnecting')
      if (!loggedOut) {
        startSocket()
      } else {
        // A real logout (device removed from the phone, etc.) leaves stale
        // creds in AUTH_DIR that useMultiFileAuthState would otherwise keep
        // trying to resume with — Baileys never falls back to a fresh QR on
        // its own. Clear them and restart so a new QR is generated
        // automatically instead of the gateway going silent until someone
        // manually restarts the container.
        logger.warn('Session logged out from the phone — clearing stale auth and generating a fresh QR')
        rm(AUTH_DIR, { recursive: true, force: true })
          .then(() => startSocket())
          .catch((err) => logger.error({ err }, 'Failed to clear stale AUTH_DIR after logout'))
      }
    }
  })
}

function requireApiKey(req, res, next) {
  if (!API_KEY) {
    res.status(500).json({ error: 'WHATSAPP_API_KEY not configured on the gateway' })
    return
  }
  if (req.header('X-API-Key') !== API_KEY) {
    res.status(401).json({ error: 'Invalid API key' })
    return
  }
  next()
}

const app = express()
app.use(express.json())

app.get('/status', requireApiKey, (req, res) => {
  res.json({ paired: isPaired, number: pairedNumber })
})

app.get('/logs', requireApiKey, (req, res) => {
  res.json({ logs })
})

app.get('/qr', requireApiKey, (req, res) => {
  if (isPaired) {
    res.status(404).json({ error: 'Already paired — no QR to show' })
    return
  }
  if (!latestQrPng) {
    res.status(404).json({ error: 'No QR generated yet, try again shortly' })
    return
  }
  res.set('Content-Type', 'image/png')
  res.send(latestQrPng)
})

app.post('/send-otp', requireApiKey, async (req, res) => {
  const { phone, code } = req.body || {}
  if (!phone || !code) {
    res.status(400).json({ error: 'phone and code are required' })
    return
  }
  if (!isPaired || !sock) {
    res.status(503).json({ error: 'WhatsApp session not paired yet' })
    return
  }
  try {
    const jid = toWhatsAppJid(phone)
    await sock.sendMessage(jid, {
      text: `Kode OTP Cocourir kamu: *${code}*\n\nJangan bagikan kode ini ke siapa pun, termasuk pihak yang mengaku dari Cocourir.`,
    })
    pushLog('otp-sent', `OTP sent to ${phone}`)
    res.json({ message: 'sent' })
  } catch (err) {
    logger.error({ err }, 'Failed to send OTP')
    pushLog('otp-failed', `Failed to send OTP to ${phone}: ${err.message}`)
    res.status(502).json({ error: 'Failed to send WhatsApp message' })
  }
})

// Freeform message send, separate from /send-otp's fixed template — for
// one-off manual sends from the admin panel (testing delivery, quick
// support outreach). Not the bulk WA-blast/marketing feature, which is
// intentionally out of scope here.
app.post('/send-message', requireApiKey, async (req, res) => {
  const { phone, message } = req.body || {}
  if (!phone || !message) {
    res.status(400).json({ error: 'phone and message are required' })
    return
  }
  if (!isPaired || !sock) {
    res.status(503).json({ error: 'WhatsApp session not paired yet' })
    return
  }
  try {
    const jid = toWhatsAppJid(phone)
    await sock.sendMessage(jid, { text: message })
    pushLog('message-sent', `Message sent to ${phone}`)
    res.json({ message: 'sent' })
  } catch (err) {
    logger.error({ err }, 'Failed to send message')
    pushLog('message-failed', `Failed to send message to ${phone}: ${err.message}`)
    res.status(502).json({ error: 'Failed to send WhatsApp message' })
  }
})

app.listen(PORT, () => {
  logger.info(`whatsapp-gateway listening on :${PORT}`)
})

startSocket().catch((err) => {
  logger.error({ err }, 'Failed to start WhatsApp socket')
  process.exit(1)
})
