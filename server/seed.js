// Demo data in Spanish: readers with profile pictures, public and private
// clubs, chat history, extra channels and book polls.
//
// Run it with `npm run seed` from the server folder. It is safe to run again:
// it first removes the previous demo data (and the old English demo users
// mariana, diego and sam) and leaves every other account untouched.
//
// Book covers come from Google Books, so GOOGLE_BOOKS_API_KEY should be set in
// .env. Books it can't find keep working, the app draws a cover for them.
import bcrypt from 'bcrypt'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import db from './db.js'
import { GOOGLE_BOOKS_API_KEY } from './config.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const AVATAR_SOURCE_DIR = path.join(__dirname, 'seed-assets', 'avatars')
const UPLOADS_DIR = path.join(__dirname, 'uploads')

const DEMO_PASSWORD = 'lectura123'
const DEMO_EMAIL_DOMAIN = '@booknook.mx'
const LEGACY_DEMO_EMAILS = ['mariana@test.com', 'diego@test.com', 'sam@test.com']

/* ==========================================================================
   Data
   ========================================================================== */

const book = (title, author) => ({ title, author })

const USERS = [
  {
    username: 'valeria',
    bio: 'Bibliotecaria de día, lectora de realismo mágico de noche. Siempre con un lápiz para subrayar.',
    genres: ['Magical Realism', 'Classics', 'Poetry'],
    topBooks: [
      book('Cien años de soledad', 'Gabriel García Márquez'),
      book('Pedro Páramo', 'Juan Rulfo'),
      book('La casa de los espíritus', 'Isabel Allende'),
      book('Rayuela', 'Julio Cortázar'),
    ],
  },
  {
    username: 'mateo',
    bio: 'Leo de madrugada con café. Me encantan los libros que no te dejan dormir.',
    genres: ['Mystery', 'Thriller', 'Historical Fiction'],
    topBooks: [
      book('La sombra del viento', 'Carlos Ruiz Zafón'),
      book('El nombre de la rosa', 'Umberto Eco'),
      book('Los pilares de la Tierra', 'Ken Follett'),
      book('El código Da Vinci', 'Dan Brown'),
    ],
  },
  {
    username: 'camila',
    bio: 'Estudiante de Letras. Colecciono separadores y opiniones fuertes sobre finales abiertos.',
    genres: ['Contemporary Fiction', 'Young Adult', 'Romance'],
    topBooks: [
      book('Orgullo y prejuicio', 'Jane Austen'),
      book('Mujercitas', 'Louisa May Alcott'),
      book('Como agua para chocolate', 'Laura Esquivel'),
      book('Los siete maridos de Evelyn Hugo', 'Taylor Jenkins Reid'),
    ],
  },
  {
    username: 'sofia',
    bio: 'Poesía en el transporte público y novelas largas los domingos.',
    genres: ['Poetry', 'Literary Fiction', 'Memoir'],
    topBooks: [
      book('Veinte poemas de amor y una canción desesperada', 'Pablo Neruda'),
      book('La casa en Mango Street', 'Sandra Cisneros'),
      book('Persépolis', 'Marjane Satrapi'),
      book('Ficciones', 'Jorge Luis Borges'),
    ],
  },
  {
    username: 'emiliano',
    bio: 'Ingeniero que lee ciencia ficción para imaginar el futuro (y quejarse de él).',
    genres: ['Science Fiction', 'Dystopian', 'Adventure'],
    topBooks: [
      book('Dune', 'Frank Herbert'),
      book('Fundación', 'Isaac Asimov'),
      book('1984', 'George Orwell'),
      book('Proyecto Hail Mary', 'Andy Weir'),
    ],
  },
  {
    username: 'renata',
    bio: 'Si hay un crimen sin resolver, ya estoy tomando notas.',
    genres: ['Crime', 'Mystery', 'Noir'],
    topBooks: [
      book('Diez negritos', 'Agatha Christie'),
      book('El silencio de los corderos', 'Thomas Harris'),
      book('La chica del tren', 'Paula Hawkins'),
      book('El paciente silencioso', 'Alex Michaelides'),
    ],
  },
  {
    username: 'joaquin',
    bio: 'Profesor de historia. Leo clásicos despacio y sin culpa.',
    genres: ['Classics', 'Philosophy', 'Historical Fiction'],
    topBooks: [
      book('Don Quijote de la Mancha', 'Miguel de Cervantes'),
      book('Crimen y castigo', 'Fiódor Dostoievski'),
      book('Moby Dick', 'Herman Melville'),
      book('La Odisea', 'Homero'),
    ],
  },
  {
    username: 'ximena',
    bio: 'Fantasía, dragones y sagas de mil páginas. Hago reseñas cortas en mi tiempo libre.',
    genres: ['Fantasy', 'Romance', 'Young Adult'],
    topBooks: [
      book('Alas de sangre', 'Rebecca Yarros'),
      book('Una corte de rosas y espinas', 'Sarah J. Maas'),
      book('El nombre del viento', 'Patrick Rothfuss'),
      book('Harry Potter y la piedra filosofal', 'J. K. Rowling'),
    ],
  },
  {
    username: 'andres',
    bio: 'Jubilado y lector de tiempo completo. Me gustan las novelas de misterio y los libros de viajes.',
    genres: ['Mystery', 'Travel', 'Biography'],
    topBooks: [
      book('Asesinato en el Orient Express', 'Agatha Christie'),
      book('Viajes con Charley', 'John Steinbeck'),
      book('El viejo y el mar', 'Ernest Hemingway'),
      book('Steve Jobs', 'Walter Isaacson'),
    ],
  },
  {
    username: 'lucia',
    bio: 'Escribo poemas cortos y leo poemarios largos. Mi lugar favorito es una librería de viejo.',
    genres: ['Poetry', 'Essay', 'Short Stories'],
    topBooks: [
      book('Poesía completa', 'Alejandra Pizarnik'),
      book('El llano en llamas', 'Juan Rulfo'),
      book('Una habitación propia', 'Virginia Woolf'),
      book('Bestiario', 'Julio Cortázar'),
    ],
  },
]

// Messages are [username, text, minutesAgo]; channels other than General are
// listed in `extraChannels`.
const CLUBS = [
  {
    name: 'Realismo Mágico',
    description: 'Leemos a los grandes del boom latinoamericano y a quienes vinieron después.',
    privacy: 'public',
    admin: 'valeria',
    members: ['mateo', 'camila', 'sofia', 'joaquin', 'lucia'],
    currentBook: book('Cien años de soledad', 'Gabriel García Márquez'),
    messages: [
      ['valeria', '¡Bienvenidos! Este mes leemos Cien años de soledad. La idea es llegar al capítulo 10 para el domingo.', 4 * 1440 + 30],
      ['joaquin', 'Perfecto. Les recomiendo tener a mano el árbol genealógico de los Buendía, ayuda muchísimo.', 4 * 1440 + 10],
      ['camila', 'Yo ya me perdí entre tantos Aurelianos 😅', 3 * 1440 + 300],
      ['sofia', 'Es parte de la experiencia. Los nombres se repiten igual que la historia de la familia.', 3 * 1440 + 280],
      ['lucia', 'La escena de la lluvia de flores amarillas me pareció preciosa.', 2 * 1440 + 90],
      ['mateo', 'Voy en el capítulo 7. Macondo cada vez se siente más real.', 1440 + 200],
      ['valeria', 'Recuerden que el jueves abrimos la encuesta para elegir el libro de diciembre.', 1440 + 60],
      ['camila', '¿Alguien más siente que Úrsula es el verdadero centro de la novela?', 180],
      ['joaquin', 'Totalmente. Ella sostiene a la familia durante casi cien años.', 150],
      ['sofia', 'Úrsula es la memoria de Macondo.', 40],
    ],
    extraChannels: [
      {
        name: 'spoilers',
        messages: [
          ['mateo', 'Aviso: aquí sí se vale hablar del final.', 2 * 1440 + 30],
          ['sofia', 'Ese último párrafo me dejó sin aire. Todo cierra de forma perfecta.', 1440 + 20],
          ['lucia', 'Lo releí tres veces. Es de los mejores finales que he leído.', 300],
        ],
      },
    ],
    poll: {
      question: '¿Qué leemos en diciembre?',
      options: [
        book('Pedro Páramo', 'Juan Rulfo'),
        book('La casa de los espíritus', 'Isabel Allende'),
        book('Como agua para chocolate', 'Laura Esquivel'),
      ],
      votes: { valeria: 0, joaquin: 0, lucia: 0, camila: 2, sofia: 1 },
    },
  },
  {
    name: 'Lectores Nocturnos',
    description: 'Un club privado para quienes leen cuando todos duermen. Misterio, suspenso y mucho café.',
    privacy: 'private',
    inviteCode: 'LUNA27',
    admin: 'mateo',
    members: ['renata', 'emiliano', 'ximena'],
    currentBook: book('La sombra del viento', 'Carlos Ruiz Zafón'),
    messages: [
      ['mateo', 'Arrancamos con La sombra del viento. Barcelona de posguerra y un libro maldito, ¿qué más se puede pedir?', 3 * 1440 + 120],
      ['renata', 'El Cementerio de los Libros Olvidados es el lugar más bonito de la literatura.', 3 * 1440 + 60],
      ['ximena', 'Fermín es mi personaje favorito, cada frase suya es oro.', 2 * 1440 + 400],
      ['emiliano', 'Me quedé leyendo hasta las 3 a.m. otra vez. Este club es peligroso.', 1440 + 15],
      ['renata', 'Ya tengo una teoría sobre Laín Coubert. No digo nada hasta el viernes.', 260],
      ['mateo', 'Las teorías se comparten en la llamada del viernes 🔦', 75],
    ],
    extraChannels: [],
  },
  {
    name: 'Ciencia Ficción y Café',
    description: 'Naves, futuros posibles y discusiones largas sobre viajes en el tiempo.',
    privacy: 'public',
    admin: 'emiliano',
    members: ['andres', 'camila', 'joaquin'],
    currentBook: book('Dune', 'Frank Herbert'),
    messages: [
      ['emiliano', 'Este mes toca Dune. Paciencia con las primeras 100 páginas, después no se puede soltar.', 5 * 1440],
      ['andres', 'Lo leí hace 40 años y lo estoy disfrutando como la primera vez.', 4 * 1440 + 200],
      ['camila', 'El glosario del final me salvó la vida.', 3 * 1440 + 30],
      ['joaquin', 'Me impresiona lo actual que se siente el tema del agua y los recursos.', 2 * 1440 + 100],
      ['emiliano', '¿Vieron las películas? Quiero saber si las comparamos cuando terminemos.', 600],
      ['andres', 'Yo voto por comparar. Pero primero el libro, ¡que no se vale hacer trampa!', 120],
    ],
    extraChannels: [
      {
        name: 'recomendaciones',
        messages: [
          ['camila', 'Si les gustó Dune, prueben Proyecto Hail Mary. Es mucho más ligero y divertido.', 2 * 1440],
          ['emiliano', 'Y Fundación de Asimov para los que quieren algo más clásico.', 1440 + 300],
        ],
      },
    ],
    poll: {
      question: '¿Cuál sigue después de Dune?',
      options: [
        book('Fundación', 'Isaac Asimov'),
        book('Proyecto Hail Mary', 'Andy Weir'),
        book('Fahrenheit 451', 'Ray Bradbury'),
        book('La mano izquierda de la oscuridad', 'Ursula K. Le Guin'),
      ],
      votes: { emiliano: 0, andres: 2, camila: 1, joaquin: 1 },
    },
  },
  {
    name: 'Club de Poesía',
    description: 'Un poema a la vez. Compartimos lecturas en voz alta y nuestros versos favoritos.',
    privacy: 'public',
    admin: 'lucia',
    members: ['sofia', 'ximena', 'valeria'],
    currentBook: book('Veinte poemas de amor y una canción desesperada', 'Pablo Neruda'),
    messages: [
      ['lucia', 'Esta semana leemos los primeros diez poemas de Neruda. Elijan su verso favorito.', 2 * 1440 + 500],
      ['sofia', '"Es tan corto el amor, y es tan largo el olvido." No hay manera de superarlo.', 2 * 1440 + 420],
      ['valeria', 'Yo me quedo con el Poema 15: "Me gustas cuando callas porque estás como ausente".', 1440 + 500],
      ['ximena', 'Nunca había leído poesía en grupo y me está encantando.', 1440 + 100],
      ['lucia', 'El sábado hacemos lectura en voz alta en la librería de la esquina. ¡Están invitadas!', 90],
    ],
    extraChannels: [],
  },
  {
    name: 'Clásicos sin Prisa',
    description: 'Los libros que siempre dijimos que íbamos a leer, a un ritmo tranquilo.',
    privacy: 'public',
    admin: 'joaquin',
    members: ['andres', 'valeria', 'emiliano', 'mateo'],
    currentBook: book('Don Quijote de la Mancha', 'Miguel de Cervantes'),
    messages: [
      ['joaquin', 'Empezamos el Quijote: diez capítulos por semana, sin presiones.', 6 * 1440],
      ['andres', 'Lo empecé tres veces en mi vida. Esta vez lo termino.', 5 * 1440 + 300],
      ['valeria', 'Los molinos de viento siempre me hacen reír, por más veces que lo lea.', 3 * 1440 + 200],
      ['mateo', 'Sancho Panza es el mejor personaje, no acepto otra opinión.', 2 * 1440 + 30],
      ['emiliano', 'Me sorprende lo moderno que es el humor.', 1440 + 400],
      ['joaquin', 'Ya pueden votar el siguiente clásico en la encuesta 📚', 220],
    ],
    extraChannels: [],
    poll: {
      question: '¿Qué clásico leemos después?',
      options: [
        book('Orgullo y prejuicio', 'Jane Austen'),
        book('Crimen y castigo', 'Fiódor Dostoievski'),
        book('Madame Bovary', 'Gustave Flaubert'),
      ],
      votes: { joaquin: 1, andres: 1, valeria: 0, mateo: 1 },
    },
  },
  {
    name: 'Misterio en la Biblioteca',
    description: 'Club privado de novela negra y policiaca. Prohibido revelar al culpable.',
    privacy: 'private',
    inviteCode: 'CLAVE8',
    admin: 'renata',
    members: ['camila', 'sofia', 'andres'],
    currentBook: book('El nombre de la rosa', 'Umberto Eco'),
    messages: [
      ['renata', 'Nuevo caso: El nombre de la rosa. Una abadía, un laberinto y muertes misteriosas.', 3 * 1440 + 50],
      ['andres', 'Guillermo de Baskerville es básicamente Sherlock Holmes con hábito.', 2 * 1440 + 700],
      ['camila', 'Las partes en latín me están costando, pero la trama me tiene atrapada.', 2 * 1440 + 60],
      ['sofia', 'Dibujé un mapa de la biblioteca para no perderme 🗺️', 1440 + 30],
      ['renata', '¡Compártelo! Lo ponemos en el canal de pistas.', 1440 + 10],
      ['andres', 'Tengo un sospechoso, pero me lo guardo hasta el final.', 35],
    ],
    extraChannels: [
      {
        name: 'pistas',
        messages: [
          ['sofia', 'Aquí va mi mapa de la biblioteca (versión 2, ahora con pasadizos).', 1440 + 5],
          ['renata', 'Ojo con el capítulo del tercer día, hay una pista muy importante.', 400],
        ],
      },
    ],
  },
  {
    name: 'Fantasía Juvenil',
    description: 'Sagas, dragones y romances épicos. Para quienes leen con el corazón.',
    privacy: 'public',
    admin: 'ximena',
    members: ['lucia', 'camila', 'mateo'],
    currentBook: book('Alas de sangre', 'Rebecca Yarros'),
    messages: [
      ['ximena', '¡Llegaron los dragones! Este mes leemos Alas de sangre.', 2 * 1440 + 200],
      ['camila', 'Lo terminé en dos días, no me arrepiento de nada.', 1440 + 600],
      ['mateo', 'No suelo leer fantasía, pero me están convenciendo.', 1440 + 90],
      ['lucia', 'Los dragones con personalidad son lo mejor del libro.', 500],
      ['ximena', 'Ya salió el segundo, por si alguien quiere seguir 🐉', 20],
    ],
    extraChannels: [],
  },
]

/* ==========================================================================
   Google Books covers
   ========================================================================== */

const coverCache = new Map()

async function findCover({ title, author }) {
  const key = `${title}|${author}`
  if (coverCache.has(key)) return coverCache.get(key)

  let cover = null
  try {
    const params = new URLSearchParams({
      q: `intitle:${title} inauthor:${author.split(' ').pop()}`,
      maxResults: '5',
      printType: 'books',
    })
    if (GOOGLE_BOOKS_API_KEY) params.set('key', GOOGLE_BOOKS_API_KEY)

    const response = await fetch(`https://www.googleapis.com/books/v1/volumes?${params}`)
    if (response.ok) {
      const data = await response.json()
      const withCover = (data.items || []).find((item) => item.volumeInfo?.imageLinks?.thumbnail)
      if (withCover) {
        cover = withCover.volumeInfo.imageLinks.thumbnail.replace(/^http:/, 'https:')
      }
    }
  } catch (err) {
    // No cover; the app draws one from the title.
  }

  coverCache.set(key, cover)
  return cover
}

async function withCover(entry) {
  return { ...entry, coverUrl: await findCover(entry) }
}

/* ==========================================================================
   Cleanup of earlier demo data
   ========================================================================== */

function deleteClub(clubId) {
  const channelIds = db
    .prepare('SELECT id FROM club_channels WHERE club_id = ?')
    .all(clubId)
    .map((row) => row.id)

  for (const channelId of channelIds) {
    const poll = db.prepare('SELECT id FROM club_polls WHERE channel_id = ?').get(channelId)
    if (poll) {
      db.prepare('DELETE FROM club_poll_votes WHERE poll_id = ?').run(poll.id)
      db.prepare('DELETE FROM club_poll_options WHERE poll_id = ?').run(poll.id)
      db.prepare('DELETE FROM club_polls WHERE id = ?').run(poll.id)
    }
    db.prepare('DELETE FROM club_messages WHERE channel_id = ?').run(channelId)
    db.prepare('DELETE FROM channel_reads WHERE channel_id = ?').run(channelId)
  }

  db.prepare('DELETE FROM club_channels WHERE club_id = ?').run(clubId)
  db.prepare('DELETE FROM club_members WHERE club_id = ?').run(clubId)
  db.prepare('DELETE FROM clubs WHERE id = ?').run(clubId)
}

function removePreviousDemoData() {
  const demoUsers = db
    .prepare(
      `SELECT id FROM users
       WHERE email LIKE ? OR email IN (${LEGACY_DEMO_EMAILS.map(() => '?').join(', ')})`,
    )
    .all(`%${DEMO_EMAIL_DOMAIN}`, ...LEGACY_DEMO_EMAILS)
    .map((row) => row.id)

  if (demoUsers.length === 0) return 0

  const placeholders = demoUsers.map(() => '?').join(', ')

  // Clubs created by demo users go away completely, members included.
  const demoClubs = db
    .prepare(`SELECT id FROM clubs WHERE owner_id IN (${placeholders})`)
    .all(...demoUsers)
  for (const club of demoClubs) deleteClub(club.id)

  // Anything demo users left in other people's clubs.
  db.prepare(`DELETE FROM club_poll_votes WHERE user_id IN (${placeholders})`).run(...demoUsers)
  db.prepare(`DELETE FROM club_messages WHERE user_id IN (${placeholders})`).run(...demoUsers)
  db.prepare(`DELETE FROM channel_reads WHERE user_id IN (${placeholders})`).run(...demoUsers)
  db.prepare(`DELETE FROM club_members WHERE user_id IN (${placeholders})`).run(...demoUsers)
  db.prepare(`DELETE FROM users WHERE id IN (${placeholders})`).run(...demoUsers)

  return demoUsers.length
}

/* ==========================================================================
   Seed
   ========================================================================== */

function timestamp(minutesAgo) {
  return new Date(Date.now() - minutesAgo * 60 * 1000).toISOString().replace('T', ' ').slice(0, 19)
}

function copyAvatar(username) {
  const source = path.join(AVATAR_SOURCE_DIR, `${username}.png`)
  if (!fs.existsSync(source)) return null

  if (!fs.existsSync(UPLOADS_DIR)) fs.mkdirSync(UPLOADS_DIR)
  const fileName = `seed-${username}.png`
  fs.copyFileSync(source, path.join(UPLOADS_DIR, fileName))
  return `/uploads/${fileName}`
}

function insertMessages(channelId, messages, userIds) {
  const insert = db.prepare(
    'INSERT INTO club_messages (channel_id, user_id, content, created_at) VALUES (?, ?, ?, ?)',
  )
  return [...messages]
    .sort((a, b) => b[2] - a[2])
    .map(([username, content, minutesAgo]) =>
      Number(insert.run(channelId, userIds[username], content, timestamp(minutesAgo)).lastInsertRowid),
    )
}

// Everyone has read the channel except its last couple of messages, so the
// app shows a few unread messages per club.
function markMostlyRead(channelId, messageIds, memberIds) {
  const lastReadIndex = Math.max(0, messageIds.length - 3)
  const lastRead = messageIds[lastReadIndex] ?? 0
  const insert = db.prepare(
    'INSERT OR REPLACE INTO channel_reads (user_id, channel_id, last_read_message_id) VALUES (?, ?, ?)',
  )
  for (const userId of memberIds) insert.run(userId, channelId, lastRead)
}

async function seed() {
  console.log('Buscando portadas en Google Books…')

  const users = await Promise.all(
    USERS.map(async (user) => ({ ...user, topBooks: await Promise.all(user.topBooks.map(withCover)) })),
  )
  const clubs = await Promise.all(
    CLUBS.map(async (club) => ({
      ...club,
      currentBook: await withCover(club.currentBook),
      poll: club.poll
        ? { ...club.poll, options: await Promise.all(club.poll.options.map(withCover)) }
        : undefined,
    })),
  )

  const passwordHash = await bcrypt.hash(DEMO_PASSWORD, 10)

  const run = db.transaction(() => {
    const removed = removePreviousDemoData()

    const userIds = {}
    for (const user of users) {
      const result = db
        .prepare(
          `INSERT INTO users (username, email, password_hash, bio, avatar_url, genres, top_books)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
        )
        .run(
          user.username,
          `${user.username}${DEMO_EMAIL_DOMAIN}`,
          passwordHash,
          user.bio,
          copyAvatar(user.username),
          JSON.stringify(user.genres),
          JSON.stringify(user.topBooks),
        )
      userIds[user.username] = Number(result.lastInsertRowid)
    }

    const summary = []

    for (const club of clubs) {
      const clubId = Number(
        db
          .prepare(
            `INSERT INTO clubs (name, description, privacy, owner_id, current_book, invite_code, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
          )
          .run(
            club.name,
            club.description,
            club.privacy,
            userIds[club.admin],
            JSON.stringify(club.currentBook),
            club.inviteCode || null,
            timestamp(30 * 1440),
          ).lastInsertRowid,
      )

      const memberNames = [club.admin, ...club.members]
      const memberIds = memberNames.map((name) => userIds[name])
      for (const name of memberNames) {
        db.prepare('INSERT INTO club_members (club_id, user_id, role) VALUES (?, ?, ?)').run(
          clubId,
          userIds[name],
          name === club.admin ? 'admin' : 'member',
        )
      }

      const addChannel = (name, type) =>
        Number(
          db
            .prepare('INSERT INTO club_channels (club_id, name, type) VALUES (?, ?, ?)')
            .run(clubId, name, type).lastInsertRowid,
        )

      const generalId = addChannel('General', 'general')
      markMostlyRead(generalId, insertMessages(generalId, club.messages, userIds), memberIds)

      for (const channel of club.extraChannels) {
        const channelId = addChannel(channel.name, 'general')
        markMostlyRead(channelId, insertMessages(channelId, channel.messages, userIds), memberIds)
      }

      if (club.poll) {
        const pollChannelId = addChannel(club.poll.question, 'poll')
        const pollId = Number(
          db
            .prepare('INSERT INTO club_polls (channel_id, question) VALUES (?, ?)')
            .run(pollChannelId, club.poll.question).lastInsertRowid,
        )
        const optionIds = club.poll.options.map((option, index) =>
          Number(
            db
              .prepare(
                `INSERT INTO club_poll_options (poll_id, book_title, book_author, cover_url, sort_order)
                 VALUES (?, ?, ?, ?, ?)`,
              )
              .run(pollId, option.title, option.author, option.coverUrl, index).lastInsertRowid,
          ),
        )
        for (const [username, optionIndex] of Object.entries(club.poll.votes)) {
          db.prepare('INSERT INTO club_poll_votes (poll_id, option_id, user_id) VALUES (?, ?, ?)').run(
            pollId,
            optionIds[optionIndex],
            userIds[username],
          )
        }
      }

      summary.push({ ...club, id: clubId, memberCount: memberNames.length })
    }

    return { removed, userIds, summary }
  })

  const { removed, userIds, summary } = run()
  const coversFound = [...coverCache.values()].filter(Boolean).length

  console.log('\nListo.')
  if (removed > 0) console.log(`Se quitaron ${removed} usuarios de prueba anteriores y sus clubes.`)
  console.log(`Portadas encontradas: ${coversFound} de ${coverCache.size}.\n`)

  console.log(`Usuarios (contraseña para todos: ${DEMO_PASSWORD})`)
  for (const user of users) {
    console.log(`  #${userIds[user.username]}  ${user.username}${DEMO_EMAIL_DOMAIN}`)
  }

  console.log('\nClubes')
  for (const club of summary) {
    const privacy = club.privacy === 'private' ? `privado, código ${club.inviteCode}` : 'público'
    console.log(`  #${club.id}  ${club.name}  (${privacy})  admin: ${club.admin}  miembros: ${club.memberCount}`)
  }
}

seed().catch((err) => {
  console.error(err)
  process.exit(1)
})
