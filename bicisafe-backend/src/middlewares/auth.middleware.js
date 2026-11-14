const jwt = require('jsonwebtoken');

function verificarSesion(req, res, next) {
  const token = req.cookies?.bicisafe_token;
  if (!token) {
    return res.status(401).json({ error: 'Acceso no autorizado. Sesión no encontrada.' });
  }
  try {
    req.usuario = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Token inválido o expirado.' });
  }
}

module.exports = { verificarSesion };
