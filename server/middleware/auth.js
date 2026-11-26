import jwt from 'jsonwebtoken'
import { JWT_SECRET } from '../config.js'

function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Necesitas iniciar sesión.' })
  }

  const token = authHeader.slice('Bearer '.length)

  try {
    const payload = jwt.verify(token, JWT_SECRET)
    req.userId = payload.id
    next()
  } catch (err) {
    res.status(401).json({ error: 'Tu sesión expiró. Vuelve a iniciar sesión.' })
  }
}

export default requireAuth
