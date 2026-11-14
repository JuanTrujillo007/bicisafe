const pool = require('../config/db');
const { calcularRutaOptima } = require('../services/routing.service');

const obtenerRuta = async (req, res) => {
  try {
    const { origenLon, origenLat, destinoLon, destinoLat, modo } = req.body;
    const ruta = await calcularRutaOptima({ origenLon, origenLat, destinoLon, destinoLat, modo });
    res.json(ruta);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

const listarCapas = async (req, res) => {
  const { rows } = await pool.query('SELECT * FROM capa_geografica WHERE esta_activo = TRUE');
  res.json(rows);
};

module.exports = { obtenerRuta, listarCapas };
