import Database from 'better-sqlite3'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const db = new Database(path.join(__dirname, 'database.db'))

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL
  )
`)

// Profile fields, added after the table already existed for some users —
// add them only if they're missing so this stays safe to run every start.
const existingColumns = db.prepare('PRAGMA table_info(users)').all().map((column) => column.name)

const profileColumns = [
  { name: 'bio', definition: 'TEXT' },
  { name: 'avatar_url', definition: 'TEXT' },
  { name: 'genres', definition: 'TEXT' },
  { name: 'top_books', definition: 'TEXT' },
]

for (const column of profileColumns) {
  if (!existingColumns.includes(column.name)) {
    db.exec(`ALTER TABLE users ADD COLUMN ${column.name} ${column.definition}`)
  }
}

db.exec(`
  CREATE TABLE IF NOT EXISTS clubs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    privacy TEXT NOT NULL,
    owner_id INTEGER NOT NULL,
    current_book TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner_id) REFERENCES users(id)
  )
`)

db.exec(`
  CREATE TABLE IF NOT EXISTS club_members (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    club_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    role TEXT NOT NULL,
    joined_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (club_id, user_id),
    FOREIGN KEY (club_id) REFERENCES clubs(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
  )
`)

// SQLite won't let ALTER TABLE ADD COLUMN carry a UNIQUE constraint directly,
// so the column is added plain and uniqueness is enforced with an index
// instead (a unique index still allows any number of NULLs, which public
// clubs need since they have no invite code).
const clubColumns = db.prepare('PRAGMA table_info(clubs)').all().map((column) => column.name)

if (!clubColumns.includes('invite_code')) {
  db.exec('ALTER TABLE clubs ADD COLUMN invite_code TEXT')
}

db.exec('CREATE UNIQUE INDEX IF NOT EXISTS idx_clubs_invite_code ON clubs (invite_code)')

db.exec(`
  CREATE TABLE IF NOT EXISTS club_channels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    club_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (club_id) REFERENCES clubs(id)
  )
`)

db.exec(`
  CREATE TABLE IF NOT EXISTS club_messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (channel_id) REFERENCES club_channels(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
  )
`)

db.exec(`
  CREATE TABLE IF NOT EXISTS club_polls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id INTEGER NOT NULL UNIQUE,
    question TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (channel_id) REFERENCES club_channels(id)
  )
`)

db.exec(`
  CREATE TABLE IF NOT EXISTS club_poll_options (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    poll_id INTEGER NOT NULL,
    book_title TEXT NOT NULL,
    book_author TEXT NOT NULL,
    cover_url TEXT,
    sort_order INTEGER NOT NULL,
    FOREIGN KEY (poll_id) REFERENCES club_polls(id)
  )
`)

// One active vote per user per poll: voting again updates the existing row
// instead of stacking a second vote.
db.exec(`
  CREATE TABLE IF NOT EXISTS club_poll_votes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    poll_id INTEGER NOT NULL,
    option_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (poll_id, user_id),
    FOREIGN KEY (poll_id) REFERENCES club_polls(id),
    FOREIGN KEY (option_id) REFERENCES club_poll_options(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
  )
`)

// Last message each user has read in each channel, used for unread counts.
db.exec(`
  CREATE TABLE IF NOT EXISTS channel_reads (
    user_id INTEGER NOT NULL,
    channel_id INTEGER NOT NULL,
    last_read_message_id INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, channel_id),
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (channel_id) REFERENCES club_channels(id)
  )
`)

// Clubs created before channels existed have no General channel, so give
// every channel-less club one here.
db.exec(`
  INSERT INTO club_channels (club_id, name, type)
  SELECT clubs.id, 'General', 'general'
  FROM clubs
  WHERE NOT EXISTS (
    SELECT 1 FROM club_channels WHERE club_channels.club_id = clubs.id
  )
`)

export default db
