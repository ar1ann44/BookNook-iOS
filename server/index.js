import express from 'express'
import cors from 'cors'
import bcrypt from 'bcrypt'
import jwt from 'jsonwebtoken'
import multer from 'multer'
import path from 'node:path'
import fs from 'node:fs'
import { fileURLToPath } from 'node:url'
import db from './db.js'
import requireAuth from './middleware/auth.js'
import { JWT_SECRET, GOOGLE_BOOKS_API_KEY, PORT } from './config.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const uploadsDir = path.join(__dirname, 'uploads')

if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir)
}

const app = express()

app.use(cors())
app.use(express.json())
app.use('/uploads', express.static(uploadsDir))

const upload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => cb(null, uploadsDir),
    filename: (req, file, cb) => {
      const extension = path.extname(file.originalname)
      cb(null, `${req.userId}-${Date.now()}${extension}`)
    },
  }),
})

app.post('/signup', async (req, res) => {
  const { username, email, password } = req.body

  if (!username || !email || !password) {
    return res.status(400).json({ error: 'Username, email and password are required.' })
  }

  const existingUser = db
    .prepare('SELECT id FROM users WHERE username = ? OR email = ?')
    .get(username, email)

  if (existingUser) {
    return res.status(400).json({ error: 'Username or email is already registered.' })
  }

  const passwordHash = await bcrypt.hash(password, 10)

  const result = db
    .prepare('INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)')
    .run(username, email, passwordHash)

  const user = { id: result.lastInsertRowid, username, email }
  const token = jwt.sign(user, JWT_SECRET, { expiresIn: '7d' })

  res.status(201).json({ user, token })
})

app.post('/login', async (req, res) => {
  const { email, password } = req.body

  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required.' })
  }

  const row = db.prepare('SELECT * FROM users WHERE email = ?').get(email)

  if (!row) {
    return res.status(401).json({ error: 'Invalid email or password.' })
  }

  const passwordMatches = await bcrypt.compare(password, row.password_hash)

  if (!passwordMatches) {
    return res.status(401).json({ error: 'Invalid email or password.' })
  }

  const user = { id: row.id, username: row.username, email: row.email }
  const token = jwt.sign(user, JWT_SECRET, { expiresIn: '7d' })

  res.json({ user, token })
})

// Book search backed by the Google Books API. The response shape
// ({ id, title, author, coverUrl, ... }) is what the app stores in profiles,
// clubs and polls.
function toBook(item) {
  const info = item.volumeInfo || {}
  const thumbnail = info.imageLinks?.thumbnail || info.imageLinks?.smallThumbnail || null

  return {
    id: item.id,
    title: info.title || 'Untitled',
    author: info.authors?.[0] || 'Unknown author',
    coverUrl: thumbnail ? thumbnail.replace(/^http:/, 'https:') : null,
    description: info.description || '',
    categories: info.categories || [],
    publishedDate: info.publishedDate || null,
  }
}

async function searchGoogleBooks(query, limit = 10) {
  const params = new URLSearchParams({
    q: query,
    maxResults: String(Math.min(Math.max(limit, 1), 40)),
    printType: 'books',
  })

  if (GOOGLE_BOOKS_API_KEY) {
    params.set('key', GOOGLE_BOOKS_API_KEY)
  }

  const response = await fetch(`https://www.googleapis.com/books/v1/volumes?${params}`)

  if (!response.ok) {
    throw new Error(`Google Books responded with ${response.status}`)
  }

  const data = await response.json()
  return (data.items || []).map(toBook)
}

app.get('/api/books/search', async (req, res) => {
  const q = req.query.q

  if (!q) {
    return res.json([])
  }

  try {
    res.json(await searchGoogleBooks(q, Number(req.query.limit) || 10))
  } catch (err) {
    console.error('Book search failed:', err.message)
    res.status(502).json({ error: 'Could not reach Google Books.' })
  }
})

// Avatars are stored as a path ("/uploads/..."), so any device can build the
// full URL from the server address it is using. Older rows saved a
// localhost URL, which is trimmed here.
function toPublicPath(url) {
  return url ? url.replace(/^https?:\/\/[^/]+/, '') : null
}

function toProfileResponse(row) {
  return {
    username: row.username,
    email: row.email,
    bio: row.bio || '',
    avatarUrl: toPublicPath(row.avatar_url),
    genres: row.genres ? JSON.parse(row.genres) : [],
    topBooks: row.top_books ? JSON.parse(row.top_books) : [],
  }
}

app.get('/profile', requireAuth, (req, res) => {
  const row = db.prepare('SELECT * FROM users WHERE id = ?').get(req.userId)

  if (!row) {
    return res.status(404).json({ error: 'User not found.' })
  }

  res.json(toProfileResponse(row))
})

app.put('/profile', requireAuth, (req, res) => {
  const { bio, genres, topBooks } = req.body

  if (!Array.isArray(genres)) {
    return res.status(400).json({ error: 'genres must be an array.' })
  }

  if (!Array.isArray(topBooks) || topBooks.length > 4) {
    return res.status(400).json({ error: 'topBooks must be an array of at most 4 books.' })
  }

  db.prepare('UPDATE users SET bio = ?, genres = ?, top_books = ? WHERE id = ?').run(
    bio || '',
    JSON.stringify(genres),
    JSON.stringify(topBooks),
    req.userId,
  )

  const row = db.prepare('SELECT * FROM users WHERE id = ?').get(req.userId)
  res.json(toProfileResponse(row))
})

app.post('/profile/avatar', requireAuth, upload.single('avatar'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No image file was uploaded.' })
  }

  const avatarUrl = `/uploads/${req.file.filename}`

  db.prepare('UPDATE users SET avatar_url = ? WHERE id = ?').run(avatarUrl, req.userId)

  res.json({ avatarUrl })
})

const INVITE_CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
const INVITE_CODE_LENGTH = 6

function generateInviteCode() {
  let code = ''
  for (let i = 0; i < INVITE_CODE_LENGTH; i++) {
    code += INVITE_CODE_CHARS[Math.floor(Math.random() * INVITE_CODE_CHARS.length)]
  }
  return code
}

function generateUniqueInviteCode() {
  let code = generateInviteCode()
  while (db.prepare('SELECT id FROM clubs WHERE invite_code = ?').get(code)) {
    code = generateInviteCode()
  }
  return code
}

function toClubResponse(row, extra = {}) {
  return {
    id: row.id,
    name: row.name,
    description: row.description || '',
    privacy: row.privacy,
    ownerId: row.owner_id,
    currentBook: row.current_book ? JSON.parse(row.current_book) : null,
    createdAt: row.created_at,
    ...extra,
  }
}

app.post('/clubs', requireAuth, (req, res) => {
  const { name, description, privacy, currentBook } = req.body

  if (!name || !name.trim()) {
    return res.status(400).json({ error: 'Club name is required.' })
  }

  if (privacy !== 'private' && privacy !== 'public') {
    return res.status(400).json({ error: 'privacy must be "private" or "public".' })
  }

  const inviteCode = privacy === 'private' ? generateUniqueInviteCode() : null

  const result = db
    .prepare(
      'INSERT INTO clubs (name, description, privacy, owner_id, current_book, invite_code) VALUES (?, ?, ?, ?, ?, ?)',
    )
    .run(
      name.trim(),
      description ? description.trim() : null,
      privacy,
      req.userId,
      currentBook ? JSON.stringify(currentBook) : null,
      inviteCode,
    )

  db.prepare('INSERT INTO club_members (club_id, user_id, role) VALUES (?, ?, ?)').run(
    result.lastInsertRowid,
    req.userId,
    'admin',
  )

  // Every club starts with a General chat channel.
  db.prepare('INSERT INTO club_channels (club_id, name, type) VALUES (?, ?, ?)').run(
    result.lastInsertRowid,
    'General',
    'general',
  )

  const row = db.prepare('SELECT * FROM clubs WHERE id = ?').get(result.lastInsertRowid)
  res.status(201).json(toClubResponse(row, { role: 'admin', memberCount: 1 }))
})

app.get('/clubs/mine', requireAuth, (req, res) => {
  const rows = db
    .prepare(
      `SELECT clubs.*,
              club_members.role AS member_role,
              (SELECT COUNT(*) FROM club_members cm WHERE cm.club_id = clubs.id) AS member_count
       FROM clubs
       JOIN club_members ON club_members.club_id = clubs.id
       WHERE club_members.user_id = ?
       ORDER BY clubs.created_at DESC`,
    )
    .all(req.userId)

  res.json(
    rows.map((row) =>
      toClubResponse(row, { role: row.member_role, memberCount: row.member_count }),
    ),
  )
})

app.get('/clubs/public', requireAuth, (req, res) => {
  const rows = db
    .prepare(
      `SELECT clubs.*,
              COUNT(club_members.id) AS member_count,
              EXISTS(
                SELECT 1 FROM club_members cm
                WHERE cm.club_id = clubs.id AND cm.user_id = ?
              ) AS is_member
       FROM clubs
       LEFT JOIN club_members ON club_members.club_id = clubs.id
       WHERE clubs.privacy = 'public'
       GROUP BY clubs.id
       ORDER BY clubs.created_at DESC`,
    )
    .all(req.userId)

  res.json(
    rows.map((row) =>
      toClubResponse(row, { memberCount: row.member_count, isMember: !!row.is_member }),
    ),
  )
})

app.get('/clubs/:id', requireAuth, (req, res) => {
  const club = db.prepare('SELECT * FROM clubs WHERE id = ?').get(req.params.id)

  if (!club) {
    return res.status(404).json({ error: 'Club not found.' })
  }

  const membership = db
    .prepare('SELECT * FROM club_members WHERE club_id = ? AND user_id = ?')
    .get(club.id, req.userId)

  if (club.privacy === 'private' && !membership) {
    return res.status(403).json({ error: 'This club is private.' })
  }

  const members = db
    .prepare(
      `SELECT users.id, users.username, club_members.role
       FROM club_members
       JOIN users ON users.id = club_members.user_id
       WHERE club_members.club_id = ?`,
    )
    .all(club.id)

  const extra = { members, role: membership ? membership.role : null }

  // The invite code is an admin-only detail: plain members should not be able
  // to hand out access to a private club.
  if (membership && membership.role === 'admin') {
    extra.inviteCode = club.invite_code
  }

  res.json(toClubResponse(club, extra))
})

app.post('/clubs/:id/join', requireAuth, (req, res) => {
  const club = db.prepare('SELECT * FROM clubs WHERE id = ?').get(req.params.id)

  if (!club) {
    return res.status(404).json({ error: 'Club not found.' })
  }

  if (club.privacy !== 'public') {
    return res.status(403).json({ error: 'This club is private.' })
  }

  const existingMembership = db
    .prepare('SELECT id FROM club_members WHERE club_id = ? AND user_id = ?')
    .get(club.id, req.userId)

  if (existingMembership) {
    return res.status(400).json({ error: 'You are already a member of this club.' })
  }

  db.prepare('INSERT INTO club_members (club_id, user_id, role) VALUES (?, ?, ?)').run(
    club.id,
    req.userId,
    'member',
  )

  res.status(201).json({ joined: true })
})

app.post('/clubs/join-by-code', requireAuth, (req, res) => {
  const { code } = req.body

  if (!code || !code.trim()) {
    return res.status(400).json({ error: 'An invite code is required.' })
  }

  const club = db
    .prepare('SELECT * FROM clubs WHERE UPPER(invite_code) = UPPER(?)')
    .get(code.trim())

  if (!club) {
    return res.status(404).json({ error: 'No club found with that code. Double check and try again.' })
  }

  const existingMembership = db
    .prepare('SELECT id FROM club_members WHERE club_id = ? AND user_id = ?')
    .get(club.id, req.userId)

  if (existingMembership) {
    return res.json({ id: club.id, message: 'You are already a member of this club.' })
  }

  db.prepare('INSERT INTO club_members (club_id, user_id, role) VALUES (?, ?, ?)').run(
    club.id,
    req.userId,
    'member',
  )

  res.status(201).json({ id: club.id })
})

/* ==========================================================================
   Club channels, messages and polls
   ========================================================================== */

// Shared guard for every chat route: the club has to exist and the caller has
// to be a member of it. Returns the membership row, or null after it has
// already answered the request with the right error.
function requireMembership(req, res) {
  const club = db.prepare('SELECT * FROM clubs WHERE id = ?').get(req.params.id)

  if (!club) {
    res.status(404).json({ error: 'Club not found.' })
    return null
  }

  const membership = db
    .prepare('SELECT * FROM club_members WHERE club_id = ? AND user_id = ?')
    .get(club.id, req.userId)

  if (!membership) {
    res.status(403).json({ error: 'You are not a member of this club.' })
    return null
  }

  return { club, membership }
}

function toChannelResponse(row, extra = {}) {
  return {
    id: row.id,
    clubId: row.club_id,
    name: row.name,
    type: row.type,
    createdAt: row.created_at,
    ...extra,
  }
}

function getChannelForClub(clubId, channelId) {
  return db
    .prepare('SELECT * FROM club_channels WHERE id = ? AND club_id = ?')
    .get(channelId, clubId)
}

// Options plus their vote counts, and which one this user picked.
function readPoll(poll, userId) {
  const options = db
    .prepare(
      `SELECT club_poll_options.*,
              (SELECT COUNT(*) FROM club_poll_votes
               WHERE club_poll_votes.option_id = club_poll_options.id) AS vote_count
       FROM club_poll_options
       WHERE poll_id = ?
       ORDER BY sort_order ASC`,
    )
    .all(poll.id)

  const myVote = db
    .prepare('SELECT option_id FROM club_poll_votes WHERE poll_id = ? AND user_id = ?')
    .get(poll.id, userId)

  return {
    id: poll.id,
    channelId: poll.channel_id,
    question: poll.question,
    createdAt: poll.created_at,
    myVoteOptionId: myVote ? myVote.option_id : null,
    options: options.map((option) => ({
      id: option.id,
      title: option.book_title,
      author: option.book_author,
      coverUrl: option.cover_url,
      votes: option.vote_count,
    })),
  }
}

// Latest chatter across every club the user belongs to, newest first.
app.get('/me/activity', requireAuth, (req, res) => {
  const rows = db
    .prepare(
      `SELECT club_messages.id,
              club_messages.content,
              club_messages.created_at,
              users.username,
              clubs.id AS club_id,
              clubs.name AS club_name
       FROM club_messages
       JOIN club_channels ON club_channels.id = club_messages.channel_id
       JOIN clubs ON clubs.id = club_channels.club_id
       JOIN club_members ON club_members.club_id = clubs.id AND club_members.user_id = ?
       JOIN users ON users.id = club_messages.user_id
       WHERE club_channels.type = 'general'
       ORDER BY club_messages.created_at DESC, club_messages.id DESC
       LIMIT 3`,
    )
    .all(req.userId)

  res.json(
    rows.map((row) => ({
      id: row.id,
      content: row.content,
      createdAt: row.created_at,
      username: row.username,
      clubId: row.club_id,
      clubName: row.club_name,
    })),
  )
})

app.get('/clubs/:id/channels', requireAuth, (req, res) => {
  const access = requireMembership(req, res)
  if (!access) return

  const rows = db
    .prepare('SELECT * FROM club_channels WHERE club_id = ? ORDER BY created_at ASC, id ASC')
    .all(access.club.id)

  // Poll channels carry their poll id so the frontend can load it directly.
  res.json(
    rows.map((row) => {
      if (row.type !== 'poll') return toChannelResponse(row)

      const poll = db.prepare('SELECT id FROM club_polls WHERE channel_id = ?').get(row.id)
      return toChannelResponse(row, { pollId: poll ? poll.id : null })
    }),
  )
})

app.post('/clubs/:id/channels', requireAuth, (req, res) => {
  const access = requireMembership(req, res)
  if (!access) return

  if (access.membership.role !== 'admin') {
    return res.status(403).json({ error: 'Only club admins can create a channel.' })
  }

  const { name } = req.body

  if (!name || !name.trim()) {
    return res.status(400).json({ error: 'A channel name is required.' })
  }

  const result = db
    .prepare('INSERT INTO club_channels (club_id, name, type) VALUES (?, ?, ?)')
    .run(access.club.id, name.trim(), 'general')

  const row = db.prepare('SELECT * FROM club_channels WHERE id = ?').get(result.lastInsertRowid)

  res.status(201).json(toChannelResponse(row))
})

app.delete('/clubs/:id/members/:userId', requireAuth, (req, res) => {
  const access = requireMembership(req, res)
  if (!access) return

  if (access.membership.role !== 'admin') {
    return res.status(403).json({ error: 'Only club admins can remove members.' })
  }

  const targetUserId = Number(req.params.userId)

  // Removing yourself would leave the club without the admin who owns it;
  // that needs a role-transfer flow we have not built yet.
  if (targetUserId === req.userId) {
    return res.status(400).json({ error: 'You cannot remove yourself from a club you admin.' })
  }

  const targetMembership = db
    .prepare('SELECT * FROM club_members WHERE club_id = ? AND user_id = ?')
    .get(access.club.id, targetUserId)

  if (!targetMembership) {
    return res.status(404).json({ error: 'That user is not a member of this club.' })
  }

  db.prepare('DELETE FROM club_members WHERE club_id = ? AND user_id = ?').run(
    access.club.id,
    targetUserId,
  )

  res.json({ removed: true })
})

app.get('/clubs/:id/channels/:channelId/messages', requireAuth, (req, res) => {
  const access = requireMembership(req, res)
  if (!access) return

  const channel = getChannelForClub(access.club.id, req.params.channelId)

  if (!channel) {
    return res.status(404).json({ error: 'Channel not found.' })
  }

  if (channel.type !== 'general') {
    return res.status(400).json({ error: 'This channel does not hold messages.' })
  }

  const rows = db
    .prepare(
      `SELECT club_messages.id, club_messages.content, club_messages.created_at,
              club_messages.user_id, users.username
       FROM club_messages
       JOIN users ON users.id = club_messages.user_id
       WHERE club_messages.channel_id = ? AND club_messages.id > ?
       ORDER BY club_messages.created_at ASC, club_messages.id ASC`,
    )
    // ?after=<message id> returns only newer messages, so clients that poll
    // for new chat don't download the whole history every time.
    .all(channel.id, Number(req.query.after) || 0)

  res.json(
    rows.map((row) => ({
      id: row.id,
      content: row.content,
      createdAt: row.created_at,
      userId: row.user_id,
      username: row.username,
    })),
  )
})

app.post('/clubs/:id/channels/:channelId/messages', requireAuth, (req, res) => {
  const access = requireMembership(req, res)
  if (!access) return

  const channel = getChannelForClub(access.club.id, req.params.channelId)

  if (!channel) {
    return res.status(404).json({ error: 'Channel not found.' })
  }

  if (channel.type !== 'general') {
    return res.status(400).json({ error: 'This channel does not hold messages.' })
  }

  const { content } = req.body

  if (!content || !content.trim()) {
    return res.status(400).json({ error: 'Message content is required.' })
  }

  const result = db
    .prepare('INSERT INTO club_messages (channel_id, user_id, content) VALUES (?, ?, ?)')
    .run(channel.id, req.userId, content.trim())

  const row = db
    .prepare(
      `SELECT club_messages.id, club_messages.content, club_messages.created_at,
              club_messages.user_id, users.username
       FROM club_messages
       JOIN users ON users.id = club_messages.user_id
       WHERE club_messages.id = ?`,
    )
    .get(result.lastInsertRowid)

  res.status(201).json({
    id: row.id,
    content: row.content,
    createdAt: row.created_at,
    userId: row.user_id,
    username: row.username,
  })
})

app.post('/clubs/:id/polls', requireAuth, (req, res) => {
  const access = requireMembership(req, res)
  if (!access) return

  if (access.membership.role !== 'admin') {
    return res.status(403).json({ error: 'Only club admins can create a poll.' })
  }

  const { question, options } = req.body

  if (!question || !question.trim()) {
    return res.status(400).json({ error: 'A poll question is required.' })
  }

  if (!Array.isArray(options) || options.length < 2 || options.length > 4) {
    return res.status(400).json({ error: 'A poll needs between 2 and 4 books.' })
  }

  if (options.some((option) => !option || !option.title || !option.author)) {
    return res.status(400).json({ error: 'Every poll option needs a title and an author.' })
  }

  const createPoll = db.transaction(() => {
    const channelResult = db
      .prepare('INSERT INTO club_channels (club_id, name, type) VALUES (?, ?, ?)')
      .run(access.club.id, question.trim(), 'poll')

    const pollResult = db
      .prepare('INSERT INTO club_polls (channel_id, question) VALUES (?, ?)')
      .run(channelResult.lastInsertRowid, question.trim())

    const insertOption = db.prepare(
      'INSERT INTO club_poll_options (poll_id, book_title, book_author, cover_url, sort_order) VALUES (?, ?, ?, ?, ?)',
    )

    options.forEach((option, index) => {
      insertOption.run(
        pollResult.lastInsertRowid,
        option.title,
        option.author,
        option.coverUrl || null,
        index,
      )
    })

    return { channelId: channelResult.lastInsertRowid, pollId: pollResult.lastInsertRowid }
  })

  const { channelId, pollId } = createPoll()

  const channelRow = db.prepare('SELECT * FROM club_channels WHERE id = ?').get(channelId)
  const pollRow = db.prepare('SELECT * FROM club_polls WHERE id = ?').get(pollId)

  res.status(201).json({
    channel: toChannelResponse(channelRow, { pollId }),
    poll: readPoll(pollRow, req.userId),
  })
})

app.get('/clubs/:id/polls/:pollId', requireAuth, (req, res) => {
  const access = requireMembership(req, res)
  if (!access) return

  const poll = db
    .prepare(
      `SELECT club_polls.*
       FROM club_polls
       JOIN club_channels ON club_channels.id = club_polls.channel_id
       WHERE club_polls.id = ? AND club_channels.club_id = ?`,
    )
    .get(req.params.pollId, access.club.id)

  if (!poll) {
    return res.status(404).json({ error: 'Poll not found.' })
  }

  res.json(readPoll(poll, req.userId))
})

app.post('/clubs/:id/polls/:pollId/vote', requireAuth, (req, res) => {
  const access = requireMembership(req, res)
  if (!access) return

  const poll = db
    .prepare(
      `SELECT club_polls.*
       FROM club_polls
       JOIN club_channels ON club_channels.id = club_polls.channel_id
       WHERE club_polls.id = ? AND club_channels.club_id = ?`,
    )
    .get(req.params.pollId, access.club.id)

  if (!poll) {
    return res.status(404).json({ error: 'Poll not found.' })
  }

  const { optionId } = req.body

  const option = db
    .prepare('SELECT id FROM club_poll_options WHERE id = ? AND poll_id = ?')
    .get(optionId, poll.id)

  if (!option) {
    return res.status(400).json({ error: 'That option does not belong to this poll.' })
  }

  // One vote per user per poll — voting again moves the existing vote.
  db.prepare(
    `INSERT INTO club_poll_votes (poll_id, option_id, user_id) VALUES (?, ?, ?)
     ON CONFLICT (poll_id, user_id) DO UPDATE SET option_id = excluded.option_id`,
  ).run(poll.id, option.id, req.userId)

  res.json(readPoll(poll, req.userId))
})

app.listen(PORT, () => {
  console.log(`BookNook server listening on http://localhost:${PORT}`)
})
