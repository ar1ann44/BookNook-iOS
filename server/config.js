// Values come from server/.env (see .env.example). The fallbacks are only
// meant for local development.
export const JWT_SECRET = process.env.JWT_SECRET || 'dev-only-secret-change-me'
export const GOOGLE_BOOKS_API_KEY = process.env.GOOGLE_BOOKS_API_KEY || ''
export const PORT = Number(process.env.PORT) || 4000
