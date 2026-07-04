import express from 'express'
import QRCode from 'qrcode'
import pino from 'pino'
import {
  makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  fetchLatestBaileysVersion,
} from '@whiskeysockets/baileys'

const PORT = process.env.PORT || 3000
const API_KEY = process.env.WHATSAPP_API_KEY || ''
const AUTH_DIR = process.env.AUTH_DIR || './auth_session'

const logger = pino({ level: process.env.LOG_LEVEL || 'info' })

let sock = null
let latestQrPng = null
let isPaired = false

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
      logger.info('New pairing QR generated — fetch it from GET /qr and scan with WhatsApp')
    }

    if (connection === 'open') {
      isPaired = true
      latestQrPng = null
      logger.info('WhatsApp session paired and connected')
    }

    if (connection === 'close') {
      isPaired = false
      const statusCode = lastDisconnect?.error?.output?.statusCode
      const loggedOut = statusCode === DisconnectReason.loggedOut
      logger.warn({ statusCode, loggedOut }, 'WhatsApp connection closed')
      if (!loggedOut) {
        startSocket()
      } else {
        logger.error('Session logged out from the phone — delete AUTH_DIR and re-scan a fresh QR')
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
  res.json({ paired: isPaired })
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
    res.json({ message: 'sent' })
  } catch (err) {
    logger.error({ err }, 'Failed to send OTP')
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
