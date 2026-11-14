const pool = require('../config/db');

const obtenerProgreso = async (req, res) => {
  const { id_usuario } = req.usuario;
  const { rows } = await pool.query('SELECT * FROM vista_nivel_usuario WHERE id_usuario = $1', [id_usuario]);
  res.json(rows[0] || {});
};

const guardarSuscripcionPush = async (req, res) => {
  res.status(501).json({ mensaje: 'Endpoint RF-25 listo para implementación' });
};

module.exports = { obtenerProgreso, guardarSuscripcionPush };
