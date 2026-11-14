const pool = require('../config/db');

async function calcularRutaOptima({ origenLon, origenLat, destinoLon, destinoLat, modo = 'SEGURA' }) {
  const client = await pool.connect();

  try {
    const nodoOrigenRes = await client.query(
      `SELECT id_nodo FROM nodo_vial
       ORDER BY ubicacion <-> ST_SetSRID(ST_MakePoint($1, $2), 4326)
       LIMIT 1`,
      [origenLon, origenLat]
    );

    const nodoDestinoRes = await client.query(
      `SELECT id_nodo FROM nodo_vial
       ORDER BY ubicacion <-> ST_SetSRID(ST_MakePoint($1, $2), 4326)
       LIMIT 1`,
      [destinoLon, destinoLat]
    );

    if (!nodoOrigenRes.rows.length || !nodoDestinoRes.rows.length) {
      throw new Error('No se encontraron nodos viales cargados cerca de las coordenadas indicadas.');
    }

    const nodoInicio = nodoOrigenRes.rows[0].id_nodo;
    const nodoFin = nodoDestinoRes.rows[0].id_nodo;
    const factorRiesgo = modo === 'SEGURA' ? 5.0 : 1.0;

    const sqlEdges = `
      SELECT
        t.id_tramo::BIGINT AS id,
        t.nodo_origen::BIGINT AS source,
        t.nodo_destino::BIGINT AS target,
        (
          t.costo_base * (1 + (t.indice_riesgo * ${factorRiesgo})) +
          COALESCE((
            SELECT COUNT(*) * ${modo === 'SEGURA' ? 50.0 : 5.0}
            FROM reporte r
            WHERE r.id_estado IN (1, 3)
              AND (r.fecha_expiracion IS NULL OR r.fecha_expiracion > NOW())
              AND ST_DWithin(t.geometria::geography, r.ubicacion::geography, 50)
          ), 0)
        )::FLOAT8 AS cost,
        t.costo_reverso::FLOAT8 AS reverse_cost,
        t.x1, t.y1, t.x2, t.y2
      FROM tramo_vial t
      WHERE t.nodo_origen IS NOT NULL AND t.nodo_destino IS NOT NULL
    `;

    const rutaRes = await client.query(
      `SELECT
         COUNT(r.edge) AS total_tramos,
         ROUND((SUM(ST_Length(t.geometria::geography)) / 1000.0)::NUMERIC, 3) AS distancia_km,
         ROUND(AVG(t.indice_riesgo)::NUMERIC, 4) AS riesgo_promedio,
         ST_AsGeoJSON(ST_LineMerge(ST_Union(t.geometria)))::JSON AS geojson
       FROM pgr_astar($1, $2::BIGINT, $3::BIGINT, directed := false) AS r
       JOIN tramo_vial t ON r.edge = t.id_tramo`,
      [sqlEdges, nodoInicio, nodoFin]
    );

    return rutaRes.rows[0];
  } finally {
    client.release();
  }
}

module.exports = { calcularRutaOptima };
