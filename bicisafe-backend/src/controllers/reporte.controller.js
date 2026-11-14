const pool = require('../config/db');

const verificarHurtoMarco = async (req, res) => {
  const { marco } = req.params;
  const { rows } = await pool.query(
    'SELECT * FROM vista_consulta_hurto_bicicleta WHERE UPPER(TRIM(numero_marco)) = UPPER(TRIM($1))',
    [marco]
  );
  res.json(rows[0] || { mensaje: 'Bicicleta sin registros o sin alerta activa' });
};

const listarReportes = async (req, res) => {
  const { rows } = await pool.query('SELECT * FROM vista_reporte_votos ORDER BY fecha_reporte DESC LIMIT 100');
  res.json(rows);
};

module.exports = { verificarHurtoMarco, listarReportes };
