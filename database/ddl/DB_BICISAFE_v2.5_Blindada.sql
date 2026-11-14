-- ============================================================================
-- BICISAFE — DDL v2.5 CORREGIDO Y AUDITADO (PostgreSQL 18 + PostGIS 3.7 + pgRouting)
-- Equipo: Luengas · Romero · Pinzón · Trujillo — SENA CEET ADSO
-- Estándar: Tercera Forma Normal (3FN) + Trazabilidad SyRS / SRS v2.0 (IEEE 29148)
-- Fecha de Corrección: 14/11/2026
-- ============================================================================

-- ============================================================================
-- FASE 0: LIMPIEZA INTEGRAL E IDEMPOTENTE (VISTAS Y TABLAS EN CASCADA)
-- ============================================================================

DROP VIEW IF EXISTS
    vista_consulta_hurto_bicicleta,
    vista_trayecto_completo,
    vista_reporte_votos,
    vista_nivel_usuario CASCADE;

DROP TABLE IF EXISTS
    log_auditoria,
    voto_reporte,
    reporte,
    capa_geografica,
    tramo_vial,
    punto_paso,
    trayecto,
    lugar_favorito,
    suscripcion_push,
    otp_usuario,
    bicicleta,
    usuario_medalla,
    medalla,
    gamificacion,
    preferencia_mapa,
    usuario,
    nivel,
    nodo_vial,
    barrio,
    severidad_reporte,
    marca_bicicleta,
    tipo_voto,
    tipo_accion_log,
    tipo_capa,
    tipo_via,
    estado_reporte,
    categoria_reporte,
    estado_trayecto,
    tipo_ruta,
    estilo_mapa,
    localidad,
    tipo_via_nomenclatura,
    estado_usuario,
    rol CASCADE;

DROP FUNCTION IF EXISTS fn_calcular_extremos_tramo() CASCADE;

-- ============================================================================
-- FASE 1: EXTENSIONES ESPACIALES Y DE ENRUTAMIENTO (PostGIS + pgRouting)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgrouting;

-- ============================================================================
-- BLOQUE 1: TABLAS DE DOMINIO Y CATÁLOGOS NORMALIZADOS (3FN)
-- ============================================================================

CREATE TABLE rol (
    id_rol      INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(30)  NOT NULL,
    descripcion VARCHAR(200),
    CONSTRAINT uq_rol_nombre UNIQUE (nombre)
);

CREATE TABLE estado_usuario (
    id_estado   INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(30)  NOT NULL,
    descripcion VARCHAR(200),
    CONSTRAINT uq_estado_usuario_nombre UNIQUE (nombre)
);

CREATE TABLE tipo_via_nomenclatura (
    id_tipo     INTEGER     NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(30) NOT NULL,
    abreviacion VARCHAR(5)  NOT NULL,
    CONSTRAINT uq_tipo_via_nomenclatura_nombre      UNIQUE (nombre),
    CONSTRAINT uq_tipo_via_nomenclatura_abreviacion UNIQUE (abreviacion)
);

CREATE TABLE localidad (
    id_localidad INTEGER     NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(80) NOT NULL,
    codigo_dane  CHAR(5),
    CONSTRAINT uq_localidad_nombre      UNIQUE (nombre),
    CONSTRAINT uq_localidad_codigo_dane UNIQUE (codigo_dane)
);

-- 3FN: barrio depende de id_localidad, evitando dependencia transitiva en lugar_favorito
CREATE TABLE barrio (
    id_barrio    INTEGER     NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(80) NOT NULL,
    id_localidad INTEGER     NOT NULL,
    CONSTRAINT uq_barrio_nombre_localidad UNIQUE (nombre, id_localidad),
    CONSTRAINT fk_barrio_localidad
        FOREIGN KEY (id_localidad) REFERENCES localidad(id_localidad)
);

CREATE TABLE estilo_mapa (
    id_estilo   INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(30)  NOT NULL,
    descripcion VARCHAR(200),
    CONSTRAINT uq_estilo_mapa_nombre UNIQUE (nombre)
);

CREATE TABLE tipo_ruta (
    id_tipo_ruta INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(30)  NOT NULL,
    descripcion  VARCHAR(200),
    CONSTRAINT uq_tipo_ruta_nombre UNIQUE (nombre)
);

CREATE TABLE estado_trayecto (
    id_estado   INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(30)  NOT NULL,
    descripcion VARCHAR(200),
    CONSTRAINT uq_estado_trayecto_nombre UNIQUE (nombre)
);

CREATE TABLE categoria_reporte (
    id_categoria INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(50)  NOT NULL,
    url_icono    VARCHAR(500),
    descripcion  VARCHAR(200),
    CONSTRAINT uq_categoria_reporte_nombre UNIQUE (nombre)
);

CREATE TABLE estado_reporte (
    id_estado   INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(30)  NOT NULL,
    descripcion VARCHAR(200),
    CONSTRAINT uq_estado_reporte_nombre UNIQUE (nombre)
);

-- Checklist #2 (RF-16 y RF-23): Catálogo normalizado de severidad del reporte
CREATE TABLE severidad_reporte (
    id_severidad INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(20)  NOT NULL,
    nivel_orden  SMALLINT     NOT NULL,
    descripcion  VARCHAR(200),
    CONSTRAINT uq_severidad_reporte_nombre UNIQUE (nombre),
    CONSTRAINT uq_severidad_reporte_orden  UNIQUE (nivel_orden),
    CONSTRAINT chk_severidad_reporte_orden CHECK (nivel_orden BETWEEN 1 AND 3)
);

-- Checklist #4 (RF-03): Catálogo normalizado de marcas de bicicleta (3FN estricta)
CREATE TABLE marca_bicicleta (
    id_marca INTEGER     NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre   VARCHAR(80) NOT NULL,
    CONSTRAINT uq_marca_bicicleta_nombre UNIQUE (nombre)
);

CREATE TABLE tipo_via (
    id_tipo_via INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(50)  NOT NULL,
    descripcion VARCHAR(200),
    CONSTRAINT uq_tipo_via_nombre UNIQUE (nombre)
);

CREATE TABLE tipo_capa (
    id_tipo_capa INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(50)  NOT NULL,
    descripcion  VARCHAR(200),
    CONSTRAINT uq_tipo_capa_nombre UNIQUE (nombre)
);

CREATE TABLE tipo_accion_log (
    id_accion   INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(20)  NOT NULL,
    descripcion VARCHAR(200),
    CONSTRAINT uq_tipo_accion_log_nombre UNIQUE (nombre)
);

CREATE TABLE tipo_voto (
    id_tipo_voto INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(20)  NOT NULL,
    descripcion  VARCHAR(200),
    CONSTRAINT uq_tipo_voto_nombre UNIQUE (nombre)
);

-- Nodos del grafo vial — requeridos por tramo_vial y pgRouting
CREATE TABLE nodo_vial (
    id_nodo   INTEGER               NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ubicacion GEOMETRY(POINT, 4326) NOT NULL
);

-- ============================================================================
-- BLOQUE 2: CATÁLOGO DE GAMIFICACIÓN
-- ============================================================================

CREATE TABLE nivel (
    id_nivel       INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre         VARCHAR(80)  NOT NULL,
    descripcion    TEXT,
    puntos_minimos INTEGER      NOT NULL DEFAULT 0,
    puntos_maximos INTEGER,
    url_icono      VARCHAR(500),
    CONSTRAINT uq_nivel_nombre UNIQUE (nombre),
    CONSTRAINT chk_nivel_puntos
        CHECK (puntos_minimos >= 0
           AND (puntos_maximos IS NULL
                OR puntos_maximos > puntos_minimos))
);

-- ============================================================================
-- BLOQUE 3: ENTIDADES PRINCIPALES Y TRANSACCIONALES
-- ============================================================================

CREATE TABLE usuario (
    id_usuario          INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    primer_nombre       VARCHAR(50)  NOT NULL,
    segundo_nombre      VARCHAR(50),
    primer_apellido     VARCHAR(50)  NOT NULL,
    segundo_apellido    VARCHAR(50),
    telefono            VARCHAR(20),
    correo              VARCHAR(150),
    contrasena_hash     VARCHAR(255) NOT NULL,
    id_rol              INTEGER      NOT NULL DEFAULT 1,
    id_estado           INTEGER      NOT NULL DEFAULT 1,
    esta_verificado     BOOLEAN      NOT NULL DEFAULT FALSE,
    fecha_registro      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_ultimo_acceso TIMESTAMP,
    CONSTRAINT uq_usuario_telefono  UNIQUE (telefono),
    CONSTRAINT uq_usuario_correo    UNIQUE (correo),
    CONSTRAINT chk_usuario_contacto CHECK (telefono IS NOT NULL OR correo IS NOT NULL),
    CONSTRAINT fk_usuario_rol       FOREIGN KEY (id_rol)    REFERENCES rol(id_rol),
    CONSTRAINT fk_usuario_estado    FOREIGN KEY (id_estado) REFERENCES estado_usuario(id_estado)
);

-- 3FN + PK subrogada id_otp para evitar colisiones históricas de códigos OTP (RF-01)
CREATE TABLE otp_usuario (
    id_otp           INTEGER     NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario       INTEGER     NOT NULL,
    codigo_otp       VARCHAR(10) NOT NULL,
    fecha_expiracion TIMESTAMP   NOT NULL,
    esta_usado       BOOLEAN     NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_otp_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE CASCADE
);

CREATE TABLE preferencia_mapa (
    id_usuario           INTEGER NOT NULL PRIMARY KEY,
    id_estilo_mapa       INTEGER NOT NULL DEFAULT 1,
    modo_nocturno_auto   BOOLEAN NOT NULL DEFAULT TRUE,
    mostrar_huecos       BOOLEAN NOT NULL DEFAULT TRUE,
    mostrar_inseguridad  BOOLEAN NOT NULL DEFAULT TRUE,
    mostrar_parqueaderos BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_preferencia_mapa_usuario
        FOREIGN KEY (id_usuario)     REFERENCES usuario(id_usuario)   ON DELETE CASCADE,
    CONSTRAINT fk_preferencia_mapa_estilo
        FOREIGN KEY (id_estilo_mapa) REFERENCES estilo_mapa(id_estilo)
);

-- 3FN: id_nivel omitido para evitar dependencia transitiva; se calcula en vista_nivel_usuario
CREATE TABLE gamificacion (
    id_usuario             INTEGER       NOT NULL PRIMARY KEY,
    puntos_totales         INTEGER       NOT NULL DEFAULT 0,
    racha_dias_actual      INTEGER       NOT NULL DEFAULT 0,
    racha_dias_maxima      INTEGER       NOT NULL DEFAULT 0,
    kilometros_totales     DECIMAL(12,3) NOT NULL DEFAULT 0,
    riesgo_evitado_total   DECIMAL(12,4) NOT NULL DEFAULT 0,
    fecha_ultima_actividad TIMESTAMP,
    CONSTRAINT fk_gamificacion_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    CONSTRAINT chk_gamificacion_puntos CHECK (puntos_totales     >= 0),
    CONSTRAINT chk_gamificacion_racha  CHECK (racha_dias_actual  >= 0 AND racha_dias_maxima >= 0),
    CONSTRAINT chk_gamificacion_km     CHECK (kilometros_totales >= 0)
);

CREATE TABLE medalla (
    id_medalla  INTEGER     NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(80) NOT NULL,
    descripcion TEXT,
    url_icono   VARCHAR(500),
    criterio    TEXT,
    esta_activa BOOLEAN     NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_medalla_nombre UNIQUE (nombre)
);

CREATE TABLE usuario_medalla (
    id_usuario     INTEGER   NOT NULL,
    id_medalla     INTEGER   NOT NULL,
    fecha_obtenida TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_usuario, id_medalla),
    CONSTRAINT fk_usuario_medalla_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_usuario_medalla_medalla FOREIGN KEY (id_medalla) REFERENCES medalla(id_medalla) ON DELETE CASCADE
);

-- Checklist #5 (RF-25): Suscripciones Web Push (PushManager) para alertas preventivas de racha (48h)
CREATE TABLE suscripcion_push (
    id_suscripcion INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario     INTEGER      NOT NULL,
    endpoint       TEXT         NOT NULL,
    llave_p256dh   VARCHAR(255) NOT NULL,
    llave_auth     VARCHAR(255) NOT NULL,
    user_agent     VARCHAR(255),
    esta_activa    BOOLEAN      NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_suscripcion_push_endpoint UNIQUE (endpoint),
    CONSTRAINT fk_suscripcion_push_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE CASCADE
);

-- Checklist #1 y #4 (RF-03, RF-14, RF-15): Maestro de bicicletas en 3FN con FK a marca_bicicleta y UNIQUE en numero_marco
CREATE TABLE bicicleta (
    id_bicicleta   INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario     INTEGER      NOT NULL,
    id_marca       INTEGER      NOT NULL,
    modelo         VARCHAR(80),
    color          VARCHAR(50),
    numero_marco   VARCHAR(100),
    url_fotografia VARCHAR(500),
    fecha_registro TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_bicicleta_usuario      FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_bicicleta_marca        FOREIGN KEY (id_marca)   REFERENCES marca_bicicleta(id_marca)
);

-- 3FN: id_barrio normaliza barrio + localidad sin restricción geográfica a Suba (RF-04)
CREATE TABLE lugar_favorito (
    id_lugar        INTEGER               NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario      INTEGER               NOT NULL,
    alias           VARCHAR(50)           NOT NULL,
    id_tipo_via_dir INTEGER,
    numero_via      VARCHAR(10),
    es_bis          BOOLEAN               NOT NULL DEFAULT FALSE,
    letra_via       VARCHAR(3),
    numero_cruce    VARCHAR(10),
    letra_cruce     VARCHAR(3),
    numero_placa    VARCHAR(10),
    complemento     VARCHAR(100),
    id_barrio       INTEGER,
    ubicacion       GEOMETRY(POINT, 4326) NOT NULL,
    fecha_creacion  TIMESTAMP             NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_lugar_favorito_usuario  FOREIGN KEY (id_usuario)      REFERENCES usuario(id_usuario)            ON DELETE CASCADE,
    CONSTRAINT fk_lugar_favorito_tipo_via FOREIGN KEY (id_tipo_via_dir) REFERENCES tipo_via_nomenclatura(id_tipo),
    CONSTRAINT fk_lugar_favorito_barrio   FOREIGN KEY (id_barrio)       REFERENCES barrio(id_barrio),
    CONSTRAINT uq_lugar_favorito_alias    UNIQUE (id_usuario, alias)
);

-- Checklist #6 (RF-09, RF-21, RF-26, RF-30): Incluye ruta_geometria LINESTRING para trazado GeoJSON y modo offline
CREATE TABLE trayecto (
    id_trayecto           INTEGER                    NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario            INTEGER                    NOT NULL,
    id_tipo_ruta          INTEGER                    NOT NULL DEFAULT 1,
    distancia_kilometros  DECIMAL(10,3),
    duracion_minutos      DECIMAL(10,2),
    indice_riesgo_evitado DECIMAL(10,4)              DEFAULT 0,
    punto_origen          GEOMETRY(POINT, 4326),
    punto_destino         GEOMETRY(POINT, 4326),
    ruta_geometria        GEOMETRY(LINESTRING, 4326),
    fecha_inicio          TIMESTAMP                  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin             TIMESTAMP,
    id_estado             INTEGER                    NOT NULL DEFAULT 1,
    valoracion            SMALLINT,
    nota_valoracion       VARCHAR(500),
    CONSTRAINT chk_trayecto_valoracion CHECK (valoracion BETWEEN 1 AND 5),
    CONSTRAINT chk_trayecto_fechas     CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
    CONSTRAINT fk_trayecto_usuario     FOREIGN KEY (id_usuario)   REFERENCES usuario(id_usuario),
    CONSTRAINT fk_trayecto_tipo_ruta   FOREIGN KEY (id_tipo_ruta) REFERENCES tipo_ruta(id_tipo_ruta),
    CONSTRAINT fk_trayecto_estado      FOREIGN KEY (id_estado)    REFERENCES estado_trayecto(id_estado)
);

-- Checklist #6 (RF-36): Estandarizado a PostGIS GEOMETRY(POINT, 4326)
CREATE TABLE punto_paso (
    id_punto    INTEGER               NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_trayecto INTEGER               NOT NULL,
    orden       SMALLINT              NOT NULL,
    ubicacion   GEOMETRY(POINT, 4326) NOT NULL,
    alias       VARCHAR(80),
    CONSTRAINT chk_punto_paso_orden   CHECK (orden BETWEEN 1 AND 3),
    CONSTRAINT fk_punto_paso_trayecto FOREIGN KEY (id_trayecto) REFERENCES trayecto(id_trayecto) ON DELETE CASCADE,
    CONSTRAINT uq_punto_paso_orden    UNIQUE (id_trayecto, orden)
);

-- Checklist #6 (RF-09, RF-10, RF-39, SYS-PE-003): Topología pgRouting con coordenadas (x1, y1, x2, y2) para pgr_astar
CREATE TABLE tramo_vial (
    id_tramo              INTEGER                   NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_via            VARCHAR(200),
    id_tipo_via           INTEGER                   NOT NULL DEFAULT 1,
    iluminacion           BOOLEAN                   NOT NULL DEFAULT FALSE,
    indice_riesgo         DECIMAL(5,4)              NOT NULL DEFAULT 0.5,
    altitud_inicio_metros DECIMAL(8,2),
    altitud_fin_metros    DECIMAL(8,2),
    geometria             GEOMETRY(LINESTRING, 4326),
    nodo_origen           INTEGER,
    nodo_destino          INTEGER,
    x1                    DOUBLE PRECISION,
    y1                    DOUBLE PRECISION,
    x2                    DOUBLE PRECISION,
    y2                    DOUBLE PRECISION,
    costo_base            FLOAT                     NOT NULL DEFAULT 1.0,
    costo_reverso         FLOAT                     NOT NULL DEFAULT 1.0,
    CONSTRAINT chk_tramo_vial_riesgo      CHECK (indice_riesgo BETWEEN 0 AND 1),
    CONSTRAINT fk_tramo_vial_tipo_via     FOREIGN KEY (id_tipo_via)  REFERENCES tipo_via(id_tipo_via),
    CONSTRAINT fk_tramo_vial_nodo_origen  FOREIGN KEY (nodo_origen)  REFERENCES nodo_vial(id_nodo),
    CONSTRAINT fk_tramo_vial_nodo_destino FOREIGN KEY (nodo_destino) REFERENCES nodo_vial(id_nodo)
);

CREATE TABLE capa_geografica (
    id_capa      INTEGER      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(150) NOT NULL,
    id_tipo_capa INTEGER      NOT NULL DEFAULT 1,
    fuente       VARCHAR(200),
    url_geojson  VARCHAR(500),
    descripcion  TEXT,
    esta_activo  BOOLEAN      NOT NULL DEFAULT TRUE,
    id_admin     INTEGER      NOT NULL,
    fecha_carga  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_capa_geografica_admin     FOREIGN KEY (id_admin)     REFERENCES usuario(id_usuario),
    CONSTRAINT fk_capa_geografica_tipo_capa FOREIGN KEY (id_tipo_capa) REFERENCES tipo_capa(id_tipo_capa)
);

-- Checklist #1, #2 y #3 (RF-14, RF-15, RF-16, RF-20, RF-23): Vínculo bicicleta, severidad, fotografía y TTL
CREATE TABLE reporte (
    id_reporte       INTEGER               NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario       INTEGER               NOT NULL,
    id_categoria     INTEGER               NOT NULL DEFAULT 1,
    id_severidad     INTEGER               NOT NULL DEFAULT 1,
    id_bicicleta     INTEGER               NULL,
    descripcion      VARCHAR(500),
    url_fotografia   VARCHAR(500),
    ubicacion        GEOMETRY(POINT, 4326) NOT NULL,
    id_estado        INTEGER               NOT NULL DEFAULT 1,
    fecha_reporte    TIMESTAMP             NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion TIMESTAMP,
    fecha_moderacion TIMESTAMP,
    id_moderador     INTEGER,
    CONSTRAINT chk_reporte_fechas    CHECK (fecha_expiracion IS NULL OR fecha_expiracion > fecha_reporte),
    CONSTRAINT fk_reporte_usuario    FOREIGN KEY (id_usuario)   REFERENCES usuario(id_usuario),
    CONSTRAINT fk_reporte_categoria  FOREIGN KEY (id_categoria) REFERENCES categoria_reporte(id_categoria),
    CONSTRAINT fk_reporte_severidad  FOREIGN KEY (id_severidad) REFERENCES severidad_reporte(id_severidad),
    CONSTRAINT fk_reporte_bicicleta  FOREIGN KEY (id_bicicleta) REFERENCES bicicleta(id_bicicleta) ON DELETE SET NULL,
    CONSTRAINT fk_reporte_estado     FOREIGN KEY (id_estado)    REFERENCES estado_reporte(id_estado),
    CONSTRAINT fk_reporte_moderador  FOREIGN KEY (id_moderador) REFERENCES usuario(id_usuario)
);

CREATE TABLE voto_reporte (
    id_voto      INTEGER   NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_reporte   INTEGER   NOT NULL,
    id_usuario   INTEGER   NOT NULL,
    id_tipo_voto INTEGER   NOT NULL DEFAULT 1,
    fecha_voto   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_voto_reporte_reporte   FOREIGN KEY (id_reporte)   REFERENCES reporte(id_reporte)   ON DELETE CASCADE,
    CONSTRAINT fk_voto_reporte_usuario   FOREIGN KEY (id_usuario)   REFERENCES usuario(id_usuario),
    CONSTRAINT fk_voto_reporte_tipo_voto FOREIGN KEY (id_tipo_voto) REFERENCES tipo_voto(id_tipo_voto),
    CONSTRAINT uq_voto_reporte_unico     UNIQUE (id_reporte, id_usuario)
);

CREATE TABLE log_auditoria (
    id_log              BIGINT      NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario          INTEGER,
    tabla_afectada      VARCHAR(60) NOT NULL,
    id_tipo_accion      INTEGER     NOT NULL DEFAULT 1,
    detalle_cambio      JSONB,
    direccion_ip_origen VARCHAR(45),
    fecha               TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_log_auditoria_usuario     FOREIGN KEY (id_usuario)     REFERENCES usuario(id_usuario)        ON DELETE SET NULL,
    CONSTRAINT fk_log_auditoria_tipo_accion FOREIGN KEY (id_tipo_accion) REFERENCES tipo_accion_log(id_accion)
);

-- ============================================================================
-- BLOQUE 4: ÍNDICES DE RENDIMIENTO (B-TREE Y GIST ESPACIALES)
-- ============================================================================

-- Índices B-Tree (Claves foráneas, consultas de historial, TTL y topología pgRouting)
CREATE INDEX idx_otp_usuario_activo       ON otp_usuario      (id_usuario, esta_usado);
CREATE INDEX idx_suscripcion_push_usuario ON suscripcion_push (id_usuario) WHERE esta_activa = TRUE;
CREATE INDEX idx_bicicleta_usuario        ON bicicleta        (id_usuario);
CREATE INDEX idx_bicicleta_marca          ON bicicleta        (id_marca);
CREATE UNIQUE INDEX uq_bicicleta_numero_marco_norm
    ON bicicleta (UPPER(TRIM(numero_marco)))
    WHERE numero_marco IS NOT NULL;
CREATE INDEX idx_lugar_favorito_usuario   ON lugar_favorito   (id_usuario);
CREATE INDEX idx_lugar_favorito_barrio    ON lugar_favorito   (id_barrio);
CREATE INDEX idx_barrio_localidad         ON barrio           (id_localidad);
CREATE INDEX idx_trayecto_usuario         ON trayecto         (id_usuario);
CREATE INDEX idx_trayecto_estado          ON trayecto         (id_estado);
CREATE INDEX idx_trayecto_fecha_inicio    ON trayecto         (fecha_inicio DESC);
CREATE INDEX idx_tramo_vial_nodo_origen   ON tramo_vial       (nodo_origen);
CREATE INDEX idx_tramo_vial_nodo_destino  ON tramo_vial       (nodo_destino);
CREATE INDEX idx_reporte_usuario          ON reporte          (id_usuario);
CREATE INDEX idx_reporte_estado           ON reporte          (id_estado);
CREATE INDEX idx_reporte_categoria        ON reporte          (id_categoria);
CREATE INDEX idx_reporte_severidad        ON reporte          (id_severidad);
CREATE INDEX idx_reporte_fecha            ON reporte          (fecha_reporte DESC);
CREATE INDEX idx_reporte_bicicleta        ON reporte          (id_bicicleta) WHERE id_bicicleta IS NOT NULL;
CREATE INDEX idx_reporte_expiracion       ON reporte          (fecha_expiracion) WHERE id_estado = 1;
CREATE INDEX idx_voto_reporte_id_reporte  ON voto_reporte     (id_reporte);
CREATE INDEX idx_log_auditoria_usuario    ON log_auditoria    (id_usuario);
CREATE INDEX idx_log_auditoria_fecha      ON log_auditoria    (fecha DESC);

-- Índices GiST (Obligatorios para ST_DWithin, ST_Distance y pgr_astar < 500 ms)
CREATE INDEX idx_reporte_ubicacion        ON reporte          USING GIST (ubicacion);
CREATE INDEX idx_lugar_fav_ubicacion      ON lugar_favorito   USING GIST (ubicacion);
CREATE INDEX idx_trayecto_punto_origen    ON trayecto         USING GIST (punto_origen);
CREATE INDEX idx_trayecto_punto_destino   ON trayecto         USING GIST (punto_destino);
CREATE INDEX idx_trayecto_ruta_geometria  ON trayecto         USING GIST (ruta_geometria);
CREATE INDEX idx_punto_paso_ubicacion     ON punto_paso       USING GIST (ubicacion);
CREATE INDEX idx_tramo_vial_geometria     ON tramo_vial       USING GIST (geometria);
CREATE INDEX idx_nodo_vial_ubicacion      ON nodo_vial        USING GIST (ubicacion);

-- ============================================================================
-- BLOQUE 4.5: TRIGGERS DE INTEGRIDAD ESPACIAL (pgRouting)
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_calcular_extremos_tramo()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.geometria IS NOT NULL THEN
        NEW.x1 := ST_X(ST_StartPoint(NEW.geometria));
        NEW.y1 := ST_Y(ST_StartPoint(NEW.geometria));
        NEW.x2 := ST_X(ST_EndPoint(NEW.geometria));
        NEW.y2 := ST_Y(ST_EndPoint(NEW.geometria));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tramo_vial_extremos
BEFORE INSERT OR UPDATE OF geometria ON tramo_vial
FOR EACH ROW EXECUTE FUNCTION fn_calcular_extremos_tramo();

-- ============================================================================
-- BLOQUE 5: VISTAS DE CONSULTA Y CÁLCULO DERIVADO (3FN)
-- ============================================================================

CREATE VIEW vista_trayecto_completo AS
SELECT
    trayecto.id_trayecto,
    trayecto.id_usuario,
    trayecto.id_tipo_ruta,
    trayecto.distancia_kilometros,
    trayecto.duracion_minutos,
    trayecto.indice_riesgo_evitado,
    ST_Y(trayecto.punto_origen)    AS origen_latitud,
    ST_X(trayecto.punto_origen)    AS origen_longitud,
    ST_Y(trayecto.punto_destino)   AS destino_latitud,
    ST_X(trayecto.punto_destino)   AS destino_longitud,
    ST_AsGeoJSON(trayecto.ruta_geometria) AS ruta_geojson,
    trayecto.fecha_inicio,
    trayecto.fecha_fin,
    trayecto.id_estado,
    trayecto.valoracion,
    trayecto.nota_valoracion,
    CASE
        WHEN trayecto.duracion_minutos > 0
        THEN ROUND((trayecto.distancia_kilometros / (trayecto.duracion_minutos / 60.0))::NUMERIC, 2)
        ELSE 0
    END                            AS velocidad_promedio_kmh,
    tipo_ruta.nombre               AS nombre_tipo_ruta,
    estado_trayecto.nombre         AS nombre_estado_trayecto,
    CONCAT(usuario.primer_nombre, ' ', usuario.primer_apellido) AS nombre_completo_usuario
FROM trayecto
JOIN usuario         ON usuario.id_usuario       = trayecto.id_usuario
JOIN tipo_ruta       ON tipo_ruta.id_tipo_ruta   = trayecto.id_tipo_ruta
JOIN estado_trayecto ON estado_trayecto.id_estado = trayecto.id_estado;


CREATE VIEW vista_reporte_votos AS
SELECT
    reporte.id_reporte,
    reporte.id_usuario,
    reporte.id_categoria,
    reporte.id_severidad,
    reporte.id_bicicleta,
    reporte.descripcion,
    reporte.url_fotografia,
    ST_Y(reporte.ubicacion)       AS latitud,
    ST_X(reporte.ubicacion)       AS longitud,
    reporte.id_estado,
    reporte.fecha_reporte,
    reporte.fecha_expiracion,
    reporte.fecha_moderacion,
    reporte.id_moderador,
    categoria_reporte.nombre      AS nombre_categoria,
    categoria_reporte.url_icono   AS url_icono_categoria,
    severidad_reporte.nombre      AS nombre_severidad,
    severidad_reporte.nivel_orden AS orden_severidad,
    estado_reporte.nombre         AS nombre_estado_reporte,
    SUM(CASE WHEN tipo_voto.nombre = 'CONFIRMAR' THEN 1 ELSE 0 END) AS votos_confirmar,
    SUM(CASE WHEN tipo_voto.nombre = 'DESMENTIR' THEN 1 ELSE 0 END) AS votos_desmentir,
    CONCAT(usuario.primer_nombre, ' ', usuario.primer_apellido)      AS nombre_completo_reportero
FROM reporte
JOIN usuario             ON usuario.id_usuario               = reporte.id_usuario
JOIN categoria_reporte   ON categoria_reporte.id_categoria   = reporte.id_categoria
JOIN severidad_reporte   ON severidad_reporte.id_severidad   = reporte.id_severidad
JOIN estado_reporte      ON estado_reporte.id_estado          = reporte.id_estado
LEFT JOIN voto_reporte   ON voto_reporte.id_reporte           = reporte.id_reporte
LEFT JOIN tipo_voto      ON tipo_voto.id_tipo_voto             = voto_reporte.id_tipo_voto
GROUP BY
    reporte.id_reporte, reporte.id_usuario, reporte.id_categoria,
    reporte.id_severidad, reporte.id_bicicleta, reporte.descripcion,
    reporte.url_fotografia, reporte.ubicacion, reporte.id_estado,
    reporte.fecha_reporte, reporte.fecha_expiracion,
    reporte.fecha_moderacion, reporte.id_moderador,
    categoria_reporte.nombre, categoria_reporte.url_icono,
    severidad_reporte.nombre, severidad_reporte.nivel_orden,
    estado_reporte.nombre, usuario.primer_nombre, usuario.primer_apellido;


-- 3FN: Calcula dinámicamente el nivel desde puntos_totales sin almacenar redundancia
CREATE VIEW vista_nivel_usuario AS
SELECT
    gamificacion.id_usuario,
    gamificacion.puntos_totales,
    nivel.id_nivel,
    nivel.nombre    AS nombre_nivel,
    nivel.url_icono
FROM gamificacion
JOIN nivel
    ON gamificacion.puntos_totales
       BETWEEN nivel.puntos_minimos
       AND COALESCE(nivel.puntos_maximos, 2147483647);


-- RF-15: Vista pública de consulta de estado de hurto por número de marco (sin exponer PII)
CREATE VIEW vista_consulta_hurto_bicicleta AS
SELECT
    bicicleta.id_bicicleta,
    bicicleta.numero_marco,
    marca_bicicleta.nombre AS marca,
    bicicleta.modelo,
    bicicleta.color,
    bicicleta.url_fotografia AS foto_bicicleta,
    CASE
        WHEN reporte.id_reporte IS NOT NULL THEN TRUE
        ELSE FALSE
    END                    AS tiene_alerta_hurto_activa,
    reporte.id_reporte     AS id_reporte_hurto,
    reporte.fecha_reporte  AS fecha_alerta_hurto,
    ST_Y(reporte.ubicacion) AS latitud_incidente,
    ST_X(reporte.ubicacion) AS longitud_incidente,
    reporte.descripcion    AS detalle_incidente
FROM bicicleta
JOIN marca_bicicleta
    ON marca_bicicleta.id_marca = bicicleta.id_marca
LEFT JOIN reporte
    ON reporte.id_bicicleta = bicicleta.id_bicicleta
   AND reporte.id_categoria = (SELECT id_categoria FROM categoria_reporte WHERE nombre = 'ROBO')
   AND reporte.id_estado    IN (SELECT id_estado FROM estado_reporte WHERE nombre IN ('ACTIVO', 'MODERADO'));

-- ============================================================================
-- BLOQUE 6: SEED ORDENADO DE DATOS DE DOMINIO (CATÁLOGOS MAESTROS)
-- ============================================================================

INSERT INTO rol (nombre, descripcion) VALUES
    ('ROLE_CYCLIST', 'Ciclista urbano — usuario final de la PWA'),
    ('ROLE_ADMIN',   'Administrador del sistema con acceso al panel');

INSERT INTO estado_usuario (nombre, descripcion) VALUES
    ('ACTIVO',     'Cuenta habilitada para iniciar sesión'),
    ('SUSPENDIDO', 'Cuenta suspendida temporalmente por el administrador'),
    ('INACTIVO',   'Cuenta inactiva por solicitud del usuario');

INSERT INTO tipo_via_nomenclatura (nombre, abreviacion) VALUES
    ('Calle', 'Cl'), ('Carrera', 'Kr'), ('Avenida', 'Av'),
    ('Avenida Calle', 'AC'), ('Avenida Carrera', 'AK'),
    ('Diagonal', 'Dg'), ('Transversal', 'Tv'), ('Circular', 'Cir');

INSERT INTO localidad (nombre, codigo_dane) VALUES
    ('Usaquén', '11001'),        ('Chapinero', '11002'),
    ('Santafé', '11003'),        ('San Cristóbal', '11004'),
    ('Usme', '11005'),           ('Tunjuelito', '11006'),
    ('Bosa', '11007'),           ('Kennedy', '11008'),
    ('Fontibón', '11009'),       ('Engativá', '11010'),
    ('Suba', '11011'),           ('Barrios Unidos', '11012'),
    ('Teusaquillo', '11013'),    ('Los Mártires', '11014'),
    ('Antonio Nariño', '11015'), ('Puente Aranda', '11016'),
    ('La Candelaria', '11017'),  ('Rafael Uribe Uribe', '11018'),
    ('Ciudad Bolívar', '11019'), ('Sumapaz', '11020');

INSERT INTO estilo_mapa (nombre, descripcion) VALUES
    ('CLARO',     'Mapa en tonos claros para uso diurno'),
    ('NOCTURNO',  'Mapa oscuro — reduce el encandilamiento nocturno'),
    ('SATELITAL', 'Vista satelital de Bogotá'),
    ('CICLOVIA',  'Resalta ciclorrutas y ciclovías dominicales');

INSERT INTO tipo_ruta (nombre, descripcion) VALUES
    ('SEGURA', 'Prioriza iluminación y ciclorrutas (riesgo mínimo)'),
    ('RAPIDA', 'Prioriza la menor distancia y tiempo de recorrido');

INSERT INTO estado_trayecto (nombre, descripcion) VALUES
    ('EN_CURSO',   'Recorrido activo — ciclista en movimiento'),
    ('FINALIZADO', 'Recorrido completado en el destino'),
    ('CANCELADO',  'Recorrido cancelado antes de llegar al destino');

INSERT INTO categoria_reporte (nombre, descripcion) VALUES
    ('HUECO',       'Daño grave en la vía que afecta al ciclista'),
    ('ZONA_OSCURA', 'Tramo con deficiencia de iluminación pública'),
    ('ROBO',        'Punto de hurto de bicicletas o agresión'),
    ('BLOQUEO',     'Obstáculo que cierra la ciclorruta total o parcialmente');

INSERT INTO estado_reporte (nombre, descripcion) VALUES
    ('ACTIVO',    'Reporte publicado y visible en el mapa'),
    ('INACTIVO',  'Desactivado por votos de desmentido de la comunidad'),
    ('MODERADO',  'Revisado y aprobado por el administrador'),
    ('ELIMINADO', 'Eliminado por spam o información falsa');

INSERT INTO severidad_reporte (nombre, nivel_orden, descripcion) VALUES
    ('BAJA',  1, 'Incidente leve que requiere precaución moderada sin bloquear el paso'),
    ('MEDIA', 2, 'Incidente relevante que exige desvío parcial o reducción de velocidad'),
    ('ALTA',  3, 'Incidente crítico de alto riesgo vial o de seguridad personal');

INSERT INTO marca_bicicleta (nombre) VALUES
    ('GW'), ('Trek'), ('Specialized'), ('Scott'), ('Giant'),
    ('Cannondale'), ('Bianchi'), ('Orbea'), ('Cliff'), ('Optimus'), ('Otra');

INSERT INTO tipo_via (nombre, descripcion) VALUES
    ('CICLORRUTA',         'Vía exclusiva para bicicletas con señalización oficial'),
    ('CARRIL_MIXTO',       'Carril compartido con vehículos motorizados'),
    ('CICLOVIA_DOMINICAL', 'Habilitada para ciclistas domingos y festivos'),
    ('VIA_NORMAL',         'Vía vehicular sin infraestructura ciclista');

INSERT INTO tipo_capa (nombre, descripcion) VALUES
    ('MALLA_VIAL',         'Red vial completa de Bogotá'),
    ('CICLORRUTA',         'Ciclorrutas permanentes oficiales'),
    ('ZONA_RIESGO',        'Zonas con alto índice de hurtos o accidentes'),
    ('CICLOVIA_DOMINICAL', 'Ciclovía dominical de Bogotá'),
    ('CICLOPARQUEADERO',   'Puntos oficiales de cicloparqueaderos certificados en Bogotá');

INSERT INTO tipo_accion_log (nombre, descripcion) VALUES
    ('INSERT', 'Creación de un nuevo registro en la tabla'),
    ('UPDATE', 'Modificación de un registro existente'),
    ('DELETE', 'Eliminación de un registro de la tabla');

INSERT INTO tipo_voto (nombre, descripcion) VALUES
    ('CONFIRMAR', 'El ciclista confirma que el incidente sigue activo en la vía'),
    ('DESMENTIR', 'El ciclista indica que el incidente ya no existe en la vía');

INSERT INTO nivel (nombre, puntos_minimos, puntos_maximos, descripcion) VALUES
    ('Explorador',      0,     499,  'Nivel inicial — primeros kilómetros en BiciSafe'),
    ('Ciclista Bronce', 500,   1499, 'Usuario comprometido con la comunidad ciclista'),
    ('Ciclista Plata',  1500,  3999, 'Contribuidor activo de reportes y rutas'),
    ('Ciclista Oro',    4000,  9999, 'Embajador de la movilidad sostenible en Bogotá'),
    ('BiciSafe Pro',    10000, NULL, 'Nivel máximo — líder reconocido de la comunidad');

-- ============================================================================
-- BLOQUE 7: VERIFICACIÓN DE INTEGRIDAD DEL ESQUEMA DESPLEGADO
-- ============================================================================

SELECT COUNT(*) AS total_extensiones
FROM   pg_extension
WHERE  extname IN ('postgis', 'pgrouting');

SELECT COUNT(*) AS total_tablas
FROM   information_schema.tables
WHERE  table_schema = 'public'
AND    table_type   = 'BASE TABLE';

SELECT COUNT(*) AS total_vistas
FROM   information_schema.views
WHERE  table_schema = 'public';

SELECT COUNT(*) AS total_triggers
FROM   information_schema.triggers
WHERE  trigger_schema = 'public';
