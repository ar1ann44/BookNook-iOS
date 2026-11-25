// Standalone test-data script. Run it by hand with `node seed.js` from the
// server folder — it is never imported by index.js.
import bcrypt from 'bcrypt'
import db from './db.js'

const TEST_PASSWORD = 'test1234'

const USERS = [
  { username: 'mariana', email: 'mariana@test.com' },
  { username: 'diego', email: 'diego@test.com' },
  { username: 'sam', email: 'sam@test.com' },
]

const CLUBS = [
  {
    name: 'The Slow Readers',
    description: 'A public club for people who like to take their time with a book.',
    privacy: 'public',
    inviteCode: null,
    currentBook: {
      title: 'The Little Prince',
      author: 'Antoine de Saint-Exupéry',
      coverUrl: 'https://covers.openlibrary.org/b/id/10173413-M.jpg',
    },
    adminUsername: 'mariana',
    messages: [
      ['mariana', 'Welcome everyone! We are starting The Little Prince this week.'],
      ['diego', 'I had never read it as an adult. The fox chapter completely got me.'],
      ['sam', 'Same here. It reads like a letter more than a novel.'],
      ['mariana', 'That is exactly it. Take it slow, there is no rush.'],
      ['diego', 'Anyone else underlining half the book, or just me?'],
    ],
  },
  {
    name: 'Midnight Pages',
    description: 'A private club for late night readers and long conversations.',
    privacy: 'private',
    inviteCode: 'MIDNGT',
    currentBook: {
      title: 'Pedro Páramo',
      author: 'Juan Rulfo',
      coverUrl: 'https://covers.openlibrary.org/b/id/8231990-M.jpg',
    },
    adminUsername: 'diego',
    messages: [
      ['diego', 'Pedro Páramo it is. Fair warning: the timeline jumps around a lot.'],
      ['sam', 'I noticed. I had to reread the first ten pages twice.'],
      ['mariana', 'Worth it though. The atmosphere is unlike anything else.'],
      ['sam', 'Comala feels like a character of its own.'],
    ],
  },
]

const POLL = {
  clubName: 'The Slow Readers',
  question: 'What should we read next?',
  options: [
    {
      title: 'Mrs Dalloway',
      author: 'Virginia Woolf',
      coverUrl: 'https://covers.openlibrary.org/b/id/12645114-M.jpg',
    },
    {
      title: 'The Aleph',
      author: 'Jorge Luis Borges',
      coverUrl: 'https://covers.openlibrary.org/b/id/8231856-M.jpg',
    },
    {
      title: 'Never Let Me Go',
      author: 'Kazuo Ishiguro',
      coverUrl: 'https://covers.openlibrary.org/b/id/8231432-M.jpg',
    },
  ],
  // Two votes for the first book, one for the second: enough of a gap that the
  // winning-option highlight is visible.
  votes: [
    { username: 'mariana', optionIndex: 0 },
    { username: 'sam', optionIndex: 0 },
    { username: 'diego', optionIndex: 1 },
  ],
}

function findOrCreateUser({ username, email }, passwordHash) {
  const existing = db.prepare('SELECT * FROM users WHERE username = ?').get(username)
  if (existing) return existing

  const result = db
    .prepare('INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)')
    .run(username, email, passwordHash)

  return db.prepare('SELECT * FROM users WHERE id = ?').get(result.lastInsertRowid)
}

async function seed() {
  const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10)

  const usersByName = {}
  for (const user of USERS) {
    usersByName[user.username] = findOrCreateUser(user, passwordHash)
  }

  const summary = []

  for (const clubSpec of CLUBS) {
    const admin = usersByName[clubSpec.adminUsername]

    const clubResult = db
      .prepare(
        'INSERT INTO clubs (name, description, privacy, owner_id, current_book, invite_code) VALUES (?, ?, ?, ?, ?, ?)',
      )
      .run(
        clubSpec.name,
        clubSpec.description,
        clubSpec.privacy,
        admin.id,
        JSON.stringify(clubSpec.currentBook),
        clubSpec.inviteCode,
      )

    const clubId = clubResult.lastInsertRowid

    for (const user of USERS) {
      db.prepare('INSERT INTO club_members (club_id, user_id, role) VALUES (?, ?, ?)').run(
        clubId,
        usersByName[user.username].id,
        user.username === clubSpec.adminUsername ? 'admin' : 'member',
      )
    }

    const channelResult = db
      .prepare('INSERT INTO club_channels (club_id, name, type) VALUES (?, ?, ?)')
      .run(clubId, 'General', 'general')

    const generalChannelId = channelResult.lastInsertRowid

    clubSpec.messages.forEach(([username, content], index) => {
      // Space the messages out so the chat has a believable timeline.
      const createdAt = new Date(Date.now() - (clubSpec.messages.length - index) * 45 * 60 * 1000)
        .toISOString()
        .replace('T', ' ')
        .slice(0, 19)

      db.prepare(
        'INSERT INTO club_messages (channel_id, user_id, content, created_at) VALUES (?, ?, ?, ?)',
      ).run(generalChannelId, usersByName[username].id, content, createdAt)
    })

    summary.push({
      club: clubSpec.name,
      id: clubId,
      privacy: clubSpec.privacy,
      inviteCode: clubSpec.inviteCode,
      admin: clubSpec.adminUsername,
      generalChannelId,
    })
  }

  // Poll channel on the public club.
  const pollClub = summary.find((entry) => entry.club === POLL.clubName)

  const pollChannelResult = db
    .prepare('INSERT INTO club_channels (club_id, name, type) VALUES (?, ?, ?)')
    .run(pollClub.id, POLL.question, 'poll')

  const pollResult = db
    .prepare('INSERT INTO club_polls (channel_id, question) VALUES (?, ?)')
    .run(pollChannelResult.lastInsertRowid, POLL.question)

  const optionIds = POLL.options.map((option, index) => {
    const result = db
      .prepare(
        'INSERT INTO club_poll_options (poll_id, book_title, book_author, cover_url, sort_order) VALUES (?, ?, ?, ?, ?)',
      )
      .run(pollResult.lastInsertRowid, option.title, option.author, option.coverUrl, index)

    return result.lastInsertRowid
  })

  for (const vote of POLL.votes) {
    db.prepare(
      'INSERT INTO club_poll_votes (poll_id, option_id, user_id) VALUES (?, ?, ?)',
    ).run(pollResult.lastInsertRowid, optionIds[vote.optionIndex], usersByName[vote.username].id)
  }

  console.log('\nSeed complete.\n')

  console.log('Users (password for all of them: %s)', TEST_PASSWORD)
  for (const user of USERS) {
    const row = usersByName[user.username]
    console.log('  #%d  %s  <%s>', row.id, row.username, row.email)
  }

  console.log('\nClubs')
  for (const entry of summary) {
    console.log(
      '  #%d  %s  (%s%s)  admin: %s  general channel: #%d',
      entry.id,
      entry.club,
      entry.privacy,
      entry.inviteCode ? `, invite code ${entry.inviteCode}` : '',
      entry.admin,
      entry.generalChannelId,
    )
  }

  console.log(
    '\nPoll  #%d  "%s"  on club #%d  (channel #%d, %d options, %d votes)\n',
    pollResult.lastInsertRowid,
    POLL.question,
    pollClub.id,
    pollChannelResult.lastInsertRowid,
    optionIds.length,
    POLL.votes.length,
  )
}

seed().catch((err) => {
  console.error('Seed failed:', err)
  process.exit(1)
})
