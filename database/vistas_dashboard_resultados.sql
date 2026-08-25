-- =====================================================================
-- Vistas homologadas para el Dashboard de Resultados (Saber Pro / T&T)
--
-- Se ejecuta UNA vez sobre la base `resultados_saber_pro_tyt` (datos
-- agregados del ICFES). No modifica ni reemplaza nada de lo que ya
-- existe ahí (las 51 tablas originales y las vistas viejas rotas
-- `vista_master_saber`/`vista_master_saber_consolidada` quedan intactas,
-- solo que el dashboard no las usa).
--
-- Uso:  mysql -u root resultados_saber_pro_tyt < database/vistas_dashboard_resultados.sql
-- =====================================================================

USE resultados_saber_pro_tyt;

-- ---------------------------------------------------------------------
-- vista_resultados_grupo_referencia
--
-- Une, con columnas homologadas, las tablas que ya vienen agregadas a
-- nivel "grupo de referencia x módulo genérico" para cada año/prueba
-- disponible con esa granularidad. Ver database/schema.sql / el plan
-- para el detalle de qué tabla origen alimenta cada fila.
--
-- Nota: 2015 (Saber Pro) usa una escala de puntaje distinta a 2016+
-- (columna `escala_no_comparable`). No se incluyen las filas "(TYT)"
-- de esa misma tabla 2015: son ruido (casi todas con 1 solo estudiante,
-- cobertura parcial de solo 3 grupos), no un dataset TyT 2015 real.
--
-- Saber T&T 2017 no trae cantidad de evaluados en su tabla origen
-- (columna queda NULL para esas filas).
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS vista_resultados_grupo_referencia;
CREATE VIEW vista_resultados_grupo_referencia AS

-- Saber Pro 2015 (escala distinta, sin filas "(TYT)")
SELECT
    2015 AS anio,
    'Saber Pro' AS tipo_prueba,
    UPPER(TRIM(NOMBRE_GRUPO_REFERENCIA)) AS grupo_referencia,
    UPPER(TRIM(NOMBRE_PRUEBA)) AS modulo,
    CANTIDAD_ESTUDIANTES AS cantidad_evaluados,
    CAST(REPLACE(PROMEDIO, ',', '.') AS DECIMAL(8,2)) AS promedio_puntaje,
    1 AS escala_no_comparable
FROM rep_resul_agre_sab_pro_2015_gener_mod_grup_ref
WHERE NOMBRE_PRUEBA NOT LIKE '%(TYT)%'

UNION ALL

-- Saber Pro 2016
SELECT
    2016, 'Saber Pro',
    UPPER(TRIM(GRUPO_REFERENCIA)), UPPER(TRIM(NOMBRE_MODULO)),
    TOTAL_EVAGRUPOREF_PRUEBA, PROMEDIO_PUNTAJEPRUEBA, 0
FROM `resul_agreg_sab_pro_mod_gener 2016 mod grup ref`

UNION ALL

-- Saber Pro 2017
SELECT
    2017, 'Saber Pro',
    UPPER(TRIM(GRUPO_REFERENCIA)), UPPER(TRIM(NOMBRE_MODULO)),
    TOTAL_EVAGRUPOREF_PRUEBA, PROMEDIO_PUNTAJEPRUEBA, 0
FROM `agregados_saber_pro 2017 2 3 gener mod grupo refer`

UNION ALL

-- Saber Pro 2018
SELECT
    2018, 'Saber Pro',
    UPPER(TRIM(GRUPO_REFERENCIA)), UPPER(TRIM(NOMBRE_MODULO)),
    TOTAL_EVAGRUPOREF_PRUEBA, PROMEDIO_PUNTAJEPRUEBA, 0
FROM `resultados_agregados_saber_pro 2018 prueb gener grup refe`

UNION ALL

-- Saber T&T 2016
SELECT
    2016, 'Saber TyT',
    UPPER(TRIM(GRUPO_REFERENCIA)), UPPER(TRIM(NOMBRE_MODULO)),
    TOTAL_EVAGRUPOREF_PRUEBA, PROMEDIO_PUNTAJEPRUEBA, 0
FROM resul_agreg_sab_tyt_2016_mod_gener_grup_ref

UNION ALL

-- Saber T&T 2017 (tabla "cubo": hay que filtrar por AGREGACION/MEDIDA_AGREGACION;
-- esta tabla origen no trae cantidad de evaluados; se limita a los 5
-- módulos genéricos, igual que las demás fuentes)
SELECT
    2017, 'Saber TyT',
    UPPER(TRIM(NOMBRE_GRUPOREF)), UPPER(TRIM(NOMBRE_PRUEBA)),
    NULL, CAST(REPLACE(PROMEDIO_PRUEBA, ',', '.') AS DECIMAL(8,2)), 0
FROM resul_agreg_saber_tyt_2017
WHERE AGREGACION = 'GRUPO_REFERENCIA' AND MEDIDA_AGREGACION = 'PUNTAJE_PRUEBA'
  AND UPPER(TRIM(NOMBRE_PRUEBA)) IN ('COMPETENCIAS CIUDADANAS','COMUNICACIÓN ESCRITA','INGLÉS','LECTURA CRÍTICA','RAZONAMIENTO CUANTITATIVO')

UNION ALL

-- Saber T&T 2018
SELECT
    2018, 'Saber TyT',
    UPPER(TRIM(GRUPO_REFERENCIA)), UPPER(TRIM(NOMBRE_MODULO)),
    TOTAL_EVAGRUPOREF_PRUEBA, PROMEDIO_PUNTAJEPRUEBA, 0
FROM resul_agreg_sab_tyt_2018_generi_mod_grup_ref;

-- ---------------------------------------------------------------------
-- vista_promedio_nacional_anual
--
-- Promedio nacional ponderado por año/prueba/módulo, calculado a partir
-- de vista_resultados_grupo_referencia (ponderando por cantidad de
-- evaluados donde se conoce), más Saber T&T 2024 a nivel país (esa
-- tabla no tiene nivel "grupo de referencia", usa otra clasificación).
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS vista_promedio_nacional_anual;
CREATE VIEW vista_promedio_nacional_anual AS

SELECT
    anio,
    tipo_prueba,
    modulo,
    SUM(cantidad_evaluados) AS cantidad_evaluados,
    ROUND(
        SUM(promedio_puntaje * COALESCE(cantidad_evaluados, 1))
        / SUM(COALESCE(cantidad_evaluados, 1)),
        2
    ) AS promedio_puntaje,
    MAX(escala_no_comparable) AS escala_no_comparable
FROM vista_resultados_grupo_referencia
GROUP BY anio, tipo_prueba, modulo

UNION ALL

-- Saber T&T 2024, nivel país (único año/prueba que no tiene grupo de referencia)
SELECT
    2024, 'Saber TyT',
    UPPER(TRIM(NOMBRE_PRUEBA)),
    CANTIDADEVALUADOS,
    CAST(REPLACE(PROMEDIO_PRUEBA, ',', '.') AS DECIMAL(8,2)),
    0
FROM agregados_saber_tyt_2024
WHERE AGREGACION = 'PAIS' AND MEDIDA_AGREGACION = 'PUNTAJE_PRUEBA'
  AND NOMBRE_PRUEBA IN ('COMPETENCIAS CIUDADANAS','COMUNICACIÓN ESCRITA','INGLÉS','LECTURA CRÍTICA','RAZONAMIENTO CUANTITATIVO');

-- ---------------------------------------------------------------------
-- tabla_equivalencia_areas
--
-- Cruce Saber T&T -> Saber Pro por área afín (criterio propio, editable).
-- No hay ninguna columna en los datos originales que los relacione.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tabla_equivalencia_areas;
CREATE TABLE tabla_equivalencia_areas (
    id INT NOT NULL AUTO_INCREMENT,
    grupo_referencia_tyt VARCHAR(150) NOT NULL,
    area_homologada VARCHAR(100) NOT NULL,
    grupo_referencia_pro VARCHAR(150) NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO tabla_equivalencia_areas (grupo_referencia_tyt, area_homologada, grupo_referencia_pro) VALUES
('TECNICO EN SALUD', 'Salud', 'ENFERMERÍA'),
('TECNOLOGICO EN SALUD', 'Salud', 'ENFERMERÍA'),
('TECNICO EN INGENIERÍA, INDUSTRIA Y MINAS', 'Ingeniería', 'INGENIERÍA'),
('TECNOLOGICO EN INGENIERÍA, INDUSTRIA Y MINAS', 'Ingeniería', 'INGENIERÍA'),
('TECNICO EN ADMINISTRACIÓN Y TURISMO', 'Administración', 'ADMINISTRACIÓN Y AFINES'),
('TECNOLOGICO EN ADMINISTRACIÓN Y TURISMO', 'Administración', 'ADMINISTRACIÓN Y AFINES'),
('TECNICO EN TIC', 'Tecnología / Informática', 'INGENIERÍA'),
('TECNOLOGICO EN TIC', 'Tecnología / Informática', 'INGENIERÍA'),
('TECNICO EN ARTES - DISEÑO - COMUNICACIÓN', 'Artes y Comunicación', 'BELLAS ARTES Y DISEÑO'),
('TECNOLOGICO EN ARTES - DISEÑO - COMUNICACIÓN', 'Artes y Comunicación', 'COMUNICACIÓN, PERIODISMO Y PUBLICIDAD'),
('TECNICO EN CIENCIAS AGROPECUARIAS', 'Agropecuario', 'CIENCIAS AGROPECUARIAS'),
('TECNOLOGICO EN CIENCIAS AGROPECUARIAS', 'Agropecuario', 'CIENCIAS AGROPECUARIAS'),
('TECNOLOGICO EN JUDICIAL', 'Derecho', 'DERECHO'),
('TECNOLOGICO EN MILITAR Y POLICIAL', 'Militar', 'CIENCIAS MILITARES Y NAVALES'),
('EDUCACIÓN TYT', 'Educación', 'EDUCACIÓN');

-- ---------------------------------------------------------------------
-- tabla_departamento_region
--
-- Departamento -> Región de Colombia. Extraída de la propia clasificación
-- del ICFES (columnas NOMBRE_DEPARTAMENTO/NOMBRE_REGION de las tablas
-- "cubo" agregados_saber_tyt_2024 y resultados_agregados_saber_pro 2017,
-- que sí las traen explícitas), completada con la división político-
-- administrativa estándar de Colombia para los pocos departamentos que
-- no aparecían en esas tablas (regiones con poca o ninguna institución
-- evaluada en esos años).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tabla_departamento_region;
CREATE TABLE tabla_departamento_region (
    departamento VARCHAR(50) NOT NULL PRIMARY KEY,
    region VARCHAR(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO tabla_departamento_region (departamento, region) VALUES
('CAQUETA', 'AMAZONÍA'), ('PUTUMAYO', 'AMAZONÍA'), ('AMAZONAS', 'AMAZONÍA'),
('ANTIOQUIA', 'ANDINA'), ('BOGOTA', 'ANDINA'), ('BOYACA', 'ANDINA'),
('CALDAS', 'ANDINA'), ('CUNDINAMARCA', 'ANDINA'), ('HUILA', 'ANDINA'),
('NORTE SANTANDER', 'ANDINA'), ('QUINDIO', 'ANDINA'), ('RISARALDA', 'ANDINA'),
('SANTANDER', 'ANDINA'), ('TOLIMA', 'ANDINA'),
('ATLANTICO', 'CARIBE'), ('BOLIVAR', 'CARIBE'), ('CESAR', 'CARIBE'),
('CORDOBA', 'CARIBE'), ('LA GUAJIRA', 'CARIBE'), ('MAGDALENA', 'CARIBE'),
('SUCRE', 'CARIBE'),
('SAN ANDRES', 'INSULAR'),
('CASANARE', 'ORINOQUIA'), ('META', 'ORINOQUIA'), ('VICHADA', 'ORINOQUIA'),
('ARAUCA', 'ORINOQUIA'), ('GUAINIA', 'ORINOQUIA'), ('GUAVIARE', 'ORINOQUIA'), ('VAUPES', 'ORINOQUIA'),
('CAUCA', 'PACÍFICA'), ('CHOCO', 'PACÍFICA'), ('NARIÑO', 'PACÍFICA'), ('VALLE', 'PACÍFICA');

-- ---------------------------------------------------------------------
-- vista_resultados_institucion
--
-- Homologada a nivel institución x módulo genérico x año x prueba.
-- Algunas fuentes vienen a un grano más fino (institución x grupo de
-- referencia), se colapsan aquí con un promedio ponderado por cantidad
-- de evaluados antes de unirlas con las demás.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS vista_resultados_institucion;
CREATE VIEW vista_resultados_institucion AS

-- Saber Pro 2015 (escala distinta; sin filas "(TYT)")
SELECT
    2015 AS anio, 'Saber Pro' AS tipo_prueba,
    UPPER(TRIM(NOMBRE_INSTITUCION)) AS institucion,
    UPPER(TRIM(DEPARTAMENTO)) AS departamento,
    UPPER(TRIM(NOMBRE_PRUEBA)) AS modulo,
    SUM(CANTIDAD_ESTUDIANTES) AS cantidad_evaluados,
    ROUND(SUM(CAST(REPLACE(PROMEDIO, ',', '.') AS DECIMAL(8,2)) * CANTIDAD_ESTUDIANTES) / SUM(CANTIDAD_ESTUDIANTES), 2) AS promedio_puntaje,
    1 AS escala_no_comparable
FROM rep_resul_agre_sab_pro_2015_generi_insti
WHERE NOMBRE_PRUEBA NOT LIKE '%(TYT)%' AND CANTIDAD_ESTUDIANTES > 0
GROUP BY UPPER(TRIM(NOMBRE_INSTITUCION)), UPPER(TRIM(DEPARTAMENTO)), UPPER(TRIM(NOMBRE_PRUEBA))

UNION ALL

-- Saber Pro 2016
SELECT
    2016, 'Saber Pro',
    UPPER(TRIM(INSTITUCION)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO)),
    SUM(TOTAL_EVALINSTITUCION_GRUPREF),
    ROUND(SUM(PROMEDIO_PUNTAJEPRUEBA * TOTAL_EVALINSTITUCION_GRUPREF) / SUM(TOTAL_EVALINSTITUCION_GRUPREF), 2),
    0
FROM `resul_agreg_sab_pro_mod_gener 2016 insti`
WHERE TOTAL_EVALINSTITUCION_GRUPREF > 0
GROUP BY UPPER(TRIM(INSTITUCION)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO))

UNION ALL

-- Saber Pro 2017 (tabla "cubo")
SELECT
    2017, 'Saber Pro',
    UPPER(TRIM(NOMBRE_INSTITUCION)), UPPER(TRIM(NOMBRE_DEPARTAMENTO)), UPPER(TRIM(NOMBRE_PRUEBA)),
    NULL,
    CAST(REPLACE(PROMEDIO_PRUEBA, ',', '.') AS DECIMAL(8,2)),
    0
FROM `resultados_agregados_saber_pro 2017`
WHERE AGREGACION = 'INSTITUCIÓN' AND MEDIDA_AGREGACION = 'PUNTAJE_PRUEBA'
  AND UPPER(TRIM(NOMBRE_PRUEBA)) IN ('COMPETENCIAS CIUDADANAS','COMUNICACIÓN ESCRITA','INGLÉS','LECTURA CRÍTICA','RAZONAMIENTO CUANTITATIVO')

UNION ALL

-- Saber Pro 2018
SELECT
    2018, 'Saber Pro',
    UPPER(TRIM(INSTITUCION)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO)),
    SUM(TOTAL_EVALINSTITUCION_GRUPREF),
    ROUND(SUM(PROMEDIO_PUNTAJEPRUEBA * TOTAL_EVALINSTITUCION_GRUPREF) / SUM(TOTAL_EVALINSTITUCION_GRUPREF), 2),
    0
FROM `resultados_agregados_saber_pro 2018 prueb gener insti`
WHERE TOTAL_EVALINSTITUCION_GRUPREF > 0
GROUP BY UPPER(TRIM(INSTITUCION)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO))

UNION ALL

-- Saber T&T 2016
SELECT
    2016, 'Saber TyT',
    UPPER(TRIM(INSTITUCION)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO)),
    SUM(TOTAL_EVALINSTITUCION_GRUPREF),
    ROUND(SUM(PROMEDIO_PUNTAJEPRUEBA * TOTAL_EVALINSTITUCION_GRUPREF) / SUM(TOTAL_EVALINSTITUCION_GRUPREF), 2),
    0
FROM resul_agreg_sab_tyt_2016_mod_gener_insti
WHERE TOTAL_EVALINSTITUCION_GRUPREF > 0
GROUP BY UPPER(TRIM(INSTITUCION)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO))

UNION ALL

-- Saber T&T 2017 (tabla "cubo", nivel institución, sin cantidad de evaluados)
SELECT
    2017, 'Saber TyT',
    UPPER(TRIM(NOMBRE_INSTITUCION)), UPPER(TRIM(NOMBRE_DEPARTAMENTO)), UPPER(TRIM(NOMBRE_PRUEBA)),
    NULL,
    CAST(REPLACE(PROMEDIO_PRUEBA, ',', '.') AS DECIMAL(8,2)),
    0
FROM resul_agreg_saber_tyt_2017
WHERE AGREGACION = 'INSTITUCIÓN' AND MEDIDA_AGREGACION = 'PUNTAJE_PRUEBA'
  AND UPPER(TRIM(NOMBRE_PRUEBA)) IN ('COMPETENCIAS CIUDADANAS','COMUNICACIÓN ESCRITA','INGLÉS','LECTURA CRÍTICA','RAZONAMIENTO CUANTITATIVO')

UNION ALL

-- Saber T&T 2018
SELECT
    2018, 'Saber TyT',
    UPPER(TRIM(INSTITUCION)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO)),
    SUM(TOTAL_EVALINSTITUCION_GRUPREF),
    ROUND(SUM(PROMEDIO_PUNTAJEPRUEBA * TOTAL_EVALINSTITUCION_GRUPREF) / SUM(TOTAL_EVALINSTITUCION_GRUPREF), 2),
    0
FROM resul_agreg_sab_tyt_2018_generi_mod_insti
WHERE TOTAL_EVALINSTITUCION_GRUPREF > 0
GROUP BY UPPER(TRIM(INSTITUCION)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO))

UNION ALL

-- Saber T&T 2024 (tabla "cubo", sin cantidad de evaluados desagregada por módulo a este nivel)
SELECT
    2024, 'Saber TyT',
    UPPER(TRIM(NOMBRE_INSTITUCION)), UPPER(TRIM(NOMBRE_DEPARTAMENTO)), UPPER(TRIM(NOMBRE_PRUEBA)),
    NULL,
    CAST(REPLACE(PROMEDIO_PRUEBA, ',', '.') AS DECIMAL(8,2)),
    0
FROM agregados_saber_tyt_2024
WHERE AGREGACION = 'INSTITUCIÓN' AND MEDIDA_AGREGACION = 'PUNTAJE_PRUEBA'
  AND UPPER(TRIM(NOMBRE_PRUEBA)) IN ('COMPETENCIAS CIUDADANAS','COMUNICACIÓN ESCRITA','INGLÉS','LECTURA CRÍTICA','RAZONAMIENTO CUANTITATIVO');

-- ---------------------------------------------------------------------
-- vista_resultados_region
--
-- Promedio por región (a partir de vista_resultados_institucion, vía
-- tabla_departamento_region). Los departamentos sin región mapeada
-- quedan agrupados en 'SIN CLASIFICAR' en vez de perderse.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS vista_resultados_region;
CREATE VIEW vista_resultados_region AS
SELECT
    i.anio,
    i.tipo_prueba,
    COALESCE(r.region, 'SIN CLASIFICAR') AS region,
    i.modulo,
    SUM(i.cantidad_evaluados) AS cantidad_evaluados,
    ROUND(
        SUM(i.promedio_puntaje * COALESCE(i.cantidad_evaluados, 1))
        / SUM(COALESCE(i.cantidad_evaluados, 1)),
        2
    ) AS promedio_puntaje,
    MAX(i.escala_no_comparable) AS escala_no_comparable
FROM vista_resultados_institucion i
LEFT JOIN tabla_departamento_region r ON r.departamento = i.departamento
GROUP BY i.anio, i.tipo_prueba, COALESCE(r.region, 'SIN CLASIFICAR'), i.modulo;

-- ---------------------------------------------------------------------
-- vista_resultados_especificas_grupo_referencia
--
-- Contraparte "específica" de vista_resultados_grupo_referencia. Los
-- módulos específicos evalúan competencias propias de cada carrera
-- (ej. "Formulación y Evaluación de Proyectos" en Administración), a
-- diferencia de los 5 módulos genéricos que se evalúan a todos por
-- igual. Por eso aquí no hay una lista fija de módulos: el módulo
-- disponible depende del grupo_referencia.
--
-- Identificación de qué tabla es específica vs. genérica: el propio
-- nombre de la tabla original del ICFES lo indica ("...especif...",
-- "...especi...", "...gener...", "...generi..."). Se verificó columna
-- por columna que ambas variantes comparten exactamente el mismo
-- esquema dentro de cada año/prueba (confirmado con DESCRIBE), lo que
-- permite homologarlas con el mismo criterio ya usado para las
-- genéricas.
--
-- Saber T&T 2017 es un caso especial: no tiene una tabla "específica"
-- separada, sino que la tabla cubo `resul_agreg_saber_tyt_2017` trae
-- genéricas y específicas mezcladas en el mismo AGREGACION=
-- 'GRUPO_REFERENCIA'; se distinguen por exclusión (todo lo que no es
-- uno de los 5 módulos genéricos, es específico).
--
-- Saber T&T 2024 no se incluye: esa tabla no tiene nivel "grupo de
-- referencia" en absoluto (usa otra clasificación, NBC), ni genérica
-- ni específica, igual que ya ocurre en vista_resultados_grupo_referencia.
--
-- Nota de calidad de datos: la tabla cubo de T&T 2017 trae, para algunas
-- carreras, cruces con módulos específicos "ajenos" a esa carrera (ej.
-- "Agropecuario" cruzado con un módulo de Industria/Minas) con un solo
-- valor y sin cantidad de evaluados (ya es NULL en toda la fuente 2017).
-- Es un artefacto de la fuente original del ICFES, no un error de esta
-- vista; puede hacer que el promedio de esa área para un año puntual se
-- vea con un valor atípico. No se filtró para no descartar datos reales
-- sin poder distinguir señal de ruido con la información disponible.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS vista_resultados_especificas_grupo_referencia;
CREATE VIEW vista_resultados_especificas_grupo_referencia AS

-- Saber Pro 2015 (escala distinta)
SELECT
    2015 AS anio, 'Saber Pro' AS tipo_prueba,
    UPPER(TRIM(NOMBRE_GRUPO_REFERENCIA)) AS grupo_referencia,
    UPPER(TRIM(NOMBRE_PRUEBA)) AS modulo,
    CANTIDAD_ESTUDIANTES AS cantidad_evaluados,
    CAST(REPLACE(PROMEDIO, ',', '.') AS DECIMAL(8,2)) AS promedio_puntaje,
    1 AS escala_no_comparable
FROM repo_resul_agre_sab_pro_2015_especif_mod_grup_ref

UNION ALL

-- Saber Pro 2016
SELECT
    2016, 'Saber Pro',
    UPPER(TRIM(GRUPO_REFERENCIA)), UPPER(TRIM(NOMBRE_MODULO)),
    TOTAL_EVAGRUPOREF_PRUEBA, PROMEDIO_PUNTAJEPRUEBA, 0
FROM `resul_agreg_sab_pro_mod_especif 2016 mod grup ref`

UNION ALL

-- Saber Pro 2017
SELECT
    2017, 'Saber Pro',
    UPPER(TRIM(GRUPO_REFERENCIA)), UPPER(TRIM(NOMBRE_MODULO)),
    TOTAL_EVAGRUPOREF_PRUEBA, PROMEDIO_PUNTAJEPRUEBA, 0
FROM `agregados_saber_pro 201702-3 especificas modulo grupo referencia`

UNION ALL

-- Saber Pro 2018
SELECT
    2018, 'Saber Pro',
    UPPER(TRIM(GRUPO_REFERENCIA)), UPPER(TRIM(NOMBRE_MODULO)),
    TOTAL_EVAGRUPOREF_PRUEBA, PROMEDIO_PUNTAJEPRUEBA, 0
FROM `resultados_agregados_saber_pro 2018 prueb especif grup refer`

UNION ALL

-- Saber T&T 2016
SELECT
    2016, 'Saber TyT',
    UPPER(TRIM(GRUPO_REFERENCIA)), UPPER(TRIM(NOMBRE_MODULO)),
    TOTAL_EVAGRUPOREF_PRUEBA, PROMEDIO_PUNTAJEPRUEBA, 0
FROM resul_agreg_sab_tyt_2016_especifi_mod_grup_ref

UNION ALL

-- Saber T&T 2017 (tabla "cubo" compartida con la genérica; se distingue
-- por exclusión de los 5 módulos genéricos, ver nota arriba)
SELECT
    2017, 'Saber TyT',
    UPPER(TRIM(NOMBRE_GRUPOREF)), UPPER(TRIM(NOMBRE_PRUEBA)),
    NULL, CAST(REPLACE(PROMEDIO_PRUEBA, ',', '.') AS DECIMAL(8,2)), 0
FROM resul_agreg_saber_tyt_2017
WHERE AGREGACION = 'GRUPO_REFERENCIA' AND MEDIDA_AGREGACION = 'PUNTAJE_PRUEBA'
  AND UPPER(TRIM(NOMBRE_PRUEBA)) NOT IN ('COMPETENCIAS CIUDADANAS','COMUNICACIÓN ESCRITA','INGLÉS','LECTURA CRÍTICA','RAZONAMIENTO CUANTITATIVO')
  AND TRIM(NOMBRE_PRUEBA) <> ''

UNION ALL

-- Saber T&T 2018
SELECT
    2018, 'Saber TyT',
    UPPER(TRIM(GRUPO_REFERENCIA)), UPPER(TRIM(NOMBRE_MODULO)),
    TOTAL_EVAGRUPOREF_PRUEBA, PROMEDIO_PUNTAJEPRUEBA, 0
FROM resul_agreg_sab_tyt_2018_especif_mod_grup_ref;

-- ---------------------------------------------------------------------
-- vista_resultados_programa
--
-- Nivel de agregación más fino: institución x programa académico x
-- módulo. Incluye tanto módulos genéricos como específicos, marcados
-- con la columna tipo_modulo (identificados igual que en la vista
-- anterior, por el nombre de la tabla origen del ICFES). Solo se usa
-- desde el servidor (con filtros GET + LIMIT), nunca se manda completa
-- al navegador: son decenas de miles de programas.
--
-- No incluye Saber T&T 2017 ni 2024 a nivel programa: esas tablas cubo
-- sí tienen un nivel "PROGRAMA_ACÁDEMICO", pero mezclado con muchas
-- otras cosas y sin cantidad de evaluados confiable a ese detalle;
-- queda pendiente para una futura iteración (ver README).
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS vista_resultados_programa;
CREATE VIEW vista_resultados_programa AS

-- Saber Pro 2015, genérica
SELECT
    2015 AS anio, 'Saber Pro' AS tipo_prueba, 'GENERICA' AS tipo_modulo,
    UPPER(TRIM(NOMBRE_GRUPO_REFERENCIA)) AS grupo_referencia,
    UPPER(TRIM(NOMBRE_INSTITUCION)) AS institucion,
    UPPER(TRIM(NOMBRE_PROGRAMA_ACADEMICO)) AS programa,
    UPPER(TRIM(DEPARTAMENTO_INSTITUCION)) AS departamento,
    UPPER(TRIM(NOMBRE_PRUEBA)) AS modulo,
    SUM(CANTIDAD_ESTUDIANTES) AS cantidad_evaluados,
    ROUND(SUM(CAST(REPLACE(PROMEDIO, ',', '.') AS DECIMAL(8,2)) * CANTIDAD_ESTUDIANTES) / SUM(CANTIDAD_ESTUDIANTES), 2) AS promedio_puntaje,
    1 AS escala_no_comparable
FROM rep_resul_agreg_sab_pro_2015_generi_prog
WHERE NOMBRE_PRUEBA NOT LIKE '%(TYT)%' AND CANTIDAD_ESTUDIANTES > 0
GROUP BY UPPER(TRIM(NOMBRE_INSTITUCION)), UPPER(TRIM(NOMBRE_PROGRAMA_ACADEMICO)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_PRUEBA)), UPPER(TRIM(NOMBRE_GRUPO_REFERENCIA))

UNION ALL

-- Saber Pro 2015, específica
SELECT
    2015, 'Saber Pro', 'ESPECIFICA',
    UPPER(TRIM(NOMBRE_GRUPO_REFERENCIA)),
    UPPER(TRIM(NOMBRE_INSTITUCION)),
    UPPER(TRIM(NOMBRE_PROGRAMA_ACADEMICO)),
    UPPER(TRIM(DEPARTAMENTO_INSTITUCION)),
    UPPER(TRIM(NOMBRE_PRUEBA)),
    SUM(CANTIDAD_ESTUDIANTES),
    ROUND(SUM(CAST(REPLACE(PROMEDIO, ',', '.') AS DECIMAL(8,2)) * CANTIDAD_ESTUDIANTES) / SUM(CANTIDAD_ESTUDIANTES), 2),
    1
FROM rep_resul_agre_sab_pro_2015_especif_prog
WHERE CANTIDAD_ESTUDIANTES > 0
GROUP BY UPPER(TRIM(NOMBRE_INSTITUCION)), UPPER(TRIM(NOMBRE_PROGRAMA_ACADEMICO)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_PRUEBA)), UPPER(TRIM(NOMBRE_GRUPO_REFERENCIA))

UNION ALL

-- Saber Pro 2016, genérica
SELECT
    2016, 'Saber Pro', 'GENERICA',
    UPPER(TRIM(GRUPO_REFERENCIA)),
    UPPER(TRIM(INSTITUCION)),
    UPPER(TRIM(PROGRAMA_ACADEMICO)),
    UPPER(TRIM(DEPARTAMENTO_INSTITUCION)),
    UPPER(TRIM(NOMBRE_MODULO)),
    SUM(TOTAL_EVALGRUPO_INSTPROGRAMA),
    ROUND(SUM(PROMEDIO_PUNTAJEPRUEBA * TOTAL_EVALGRUPO_INSTPROGRAMA) / SUM(TOTAL_EVALGRUPO_INSTPROGRAMA), 2),
    0
FROM `resul_agreg_sab_pro_mod_gener 2016 prog`
WHERE TOTAL_EVALGRUPO_INSTPROGRAMA > 0
GROUP BY UPPER(TRIM(INSTITUCION)), UPPER(TRIM(PROGRAMA_ACADEMICO)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO)), UPPER(TRIM(GRUPO_REFERENCIA))

UNION ALL

-- Saber Pro 2016, específica
SELECT
    2016, 'Saber Pro', 'ESPECIFICA',
    UPPER(TRIM(GRUPO_REFERENCIA)),
    UPPER(TRIM(INSTITUCION)),
    UPPER(TRIM(PROGRAMA_ACADEMICO)),
    UPPER(TRIM(DEPARTAMENTO_INSTITUCION)),
    UPPER(TRIM(NOMBRE_MODULO)),
    SUM(TOTAL_EVALGRUPO_INSTPROGRAMA),
    ROUND(SUM(PROMEDIO_PUNTAJEPRUEBA * TOTAL_EVALGRUPO_INSTPROGRAMA) / SUM(TOTAL_EVALGRUPO_INSTPROGRAMA), 2),
    0
FROM `resul_agreg_sab_pro_mod_especif 2016 prog`
WHERE TOTAL_EVALGRUPO_INSTPROGRAMA > 0
GROUP BY UPPER(TRIM(INSTITUCION)), UPPER(TRIM(PROGRAMA_ACADEMICO)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO)), UPPER(TRIM(GRUPO_REFERENCIA))

UNION ALL

-- Saber Pro 2017, genérica (tabla combinada institución+programa)
SELECT
    2017, 'Saber Pro', 'GENERICA',
    UPPER(TRIM(GRUPO_REFERENCIA)),
    UPPER(TRIM(INSTITUCION)),
    UPPER(TRIM(PROGRAMA_ACADEMICO)),
    UPPER(TRIM(DEPARTAMENTO_INSTITUCION)),
    UPPER(TRIM(NOMBRE_MODULO)),
    SUM(TOTAL_EVALGRUPO_INSTPROGRAMA),
    ROUND(SUM(PROMEDIO_PUNTAJEPRUEBA * TOTAL_EVALGRUPO_INSTPROGRAMA) / SUM(TOTAL_EVALGRUPO_INSTPROGRAMA), 2),
    0
FROM `agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`
WHERE TOTAL_EVALGRUPO_INSTPROGRAMA > 0
GROUP BY UPPER(TRIM(INSTITUCION)), UPPER(TRIM(PROGRAMA_ACADEMICO)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO)), UPPER(TRIM(GRUPO_REFERENCIA))

UNION ALL

-- Saber Pro 2017, específica (tabla combinada institución+programa)
SELECT
    2017, 'Saber Pro', 'ESPECIFICA',
    UPPER(TRIM(GRUPO_REFERENCIA)),
    UPPER(TRIM(INSTITUCION)),
    UPPER(TRIM(PROGRAMA_ACADEMICO)),
    UPPER(TRIM(DEPARTAMENTO_INSTITUCION)),
    UPPER(TRIM(NOMBRE_MODULO)),
    SUM(TOTAL_EVALGRUPO_INSTPROGRAMA),
    ROUND(SUM(PROMEDIO_PUNTAJEPRUEBA * TOTAL_EVALGRUPO_INSTPROGRAMA) / SUM(TOTAL_EVALGRUPO_INSTPROGRAMA), 2),
    0
FROM `agre_saber_pro2017 23 especi mod gruporef insti prog`
WHERE TOTAL_EVALGRUPO_INSTPROGRAMA > 0
GROUP BY UPPER(TRIM(INSTITUCION)), UPPER(TRIM(PROGRAMA_ACADEMICO)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO)), UPPER(TRIM(GRUPO_REFERENCIA))

UNION ALL

-- Saber Pro 2018, genérica
SELECT
    2018, 'Saber Pro', 'GENERICA',
    UPPER(TRIM(GRUPO_REFERENCIA)),
    UPPER(TRIM(INSTITUCION)),
    UPPER(TRIM(PROGRAMA_ACADEMICO)),
    UPPER(TRIM(DEPARTAMENTO_INSTITUCION)),
    UPPER(TRIM(NOMBRE_MODULO)),
    SUM(TOTAL_EVALGRUPO_INSTPROGRAMA),
    ROUND(SUM(PROMEDIO_PUNTAJEPRUEBA * TOTAL_EVALGRUPO_INSTPROGRAMA) / SUM(TOTAL_EVALGRUPO_INSTPROGRAMA), 2),
    0
FROM `resultados_agregados_saber_pro 2018 prueb gener prog`
WHERE TOTAL_EVALGRUPO_INSTPROGRAMA > 0
GROUP BY UPPER(TRIM(INSTITUCION)), UPPER(TRIM(PROGRAMA_ACADEMICO)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO)), UPPER(TRIM(GRUPO_REFERENCIA))

UNION ALL

-- Saber Pro 2018, específica
SELECT
    2018, 'Saber Pro', 'ESPECIFICA',
    UPPER(TRIM(GRUPO_REFERENCIA)),
    UPPER(TRIM(INSTITUCION)),
    UPPER(TRIM(PROGRAMA_ACADEMICO)),
    UPPER(TRIM(DEPARTAMENTO_INSTITUCION)),
    UPPER(TRIM(NOMBRE_MODULO)),
    SUM(TOTAL_EVALGRUPO_INSTPROGRAMA),
    ROUND(SUM(PROMEDIO_PUNTAJEPRUEBA * TOTAL_EVALGRUPO_INSTPROGRAMA) / SUM(TOTAL_EVALGRUPO_INSTPROGRAMA), 2),
    0
FROM `resultados_agregados_saber_pro 2018 prueb especi prog`
WHERE TOTAL_EVALGRUPO_INSTPROGRAMA > 0
GROUP BY UPPER(TRIM(INSTITUCION)), UPPER(TRIM(PROGRAMA_ACADEMICO)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO)), UPPER(TRIM(GRUPO_REFERENCIA))

UNION ALL

-- Saber T&T 2016, genérica
SELECT
    2016, 'Saber TyT', 'GENERICA',
    UPPER(TRIM(GRUPO_REFERENCIA)),
    UPPER(TRIM(INSTITUCION)),
    UPPER(TRIM(PROGRAMA_ACADEMICO)),
    UPPER(TRIM(DEPARTAMENTO_INSTITUCION)),
    UPPER(TRIM(NOMBRE_MODULO)),
    SUM(TOTAL_EVALGRUPO_INSTPROGRAMA),
    ROUND(SUM(PROMEDIO_PUNTAJEPRUEBA * TOTAL_EVALGRUPO_INSTPROGRAMA) / SUM(TOTAL_EVALGRUPO_INSTPROGRAMA), 2),
    0
FROM resul_agreg_sab_tyt_2016_mod_gener_prog
WHERE TOTAL_EVALGRUPO_INSTPROGRAMA > 0
GROUP BY UPPER(TRIM(INSTITUCION)), UPPER(TRIM(PROGRAMA_ACADEMICO)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO)), UPPER(TRIM(GRUPO_REFERENCIA))

UNION ALL

-- Saber T&T 2016, específica
SELECT
    2016, 'Saber TyT', 'ESPECIFICA',
    UPPER(TRIM(GRUPO_REFERENCIA)),
    UPPER(TRIM(INSTITUCION)),
    UPPER(TRIM(PROGRAMA_ACADEMICO)),
    UPPER(TRIM(DEPARTAMENTO_INSTITUCION)),
    UPPER(TRIM(NOMBRE_MODULO)),
    SUM(TOTAL_EVALGRUPO_INSTPROGRAMA),
    ROUND(SUM(PROMEDIO_PUNTAJEPRUEBA * TOTAL_EVALGRUPO_INSTPROGRAMA) / SUM(TOTAL_EVALGRUPO_INSTPROGRAMA), 2),
    0
FROM resul_agreg_sab_tyt_2016_mod_especifi_prog
WHERE TOTAL_EVALGRUPO_INSTPROGRAMA > 0
GROUP BY UPPER(TRIM(INSTITUCION)), UPPER(TRIM(PROGRAMA_ACADEMICO)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO)), UPPER(TRIM(GRUPO_REFERENCIA))

UNION ALL

-- Saber T&T 2018, genérica
SELECT
    2018, 'Saber TyT', 'GENERICA',
    UPPER(TRIM(GRUPO_REFERENCIA)),
    UPPER(TRIM(INSTITUCION)),
    UPPER(TRIM(PROGRAMA_ACADEMICO)),
    UPPER(TRIM(DEPARTAMENTO_INSTITUCION)),
    UPPER(TRIM(NOMBRE_MODULO)),
    SUM(TOTAL_EVALGRUPO_INSTPROGRAMA),
    ROUND(SUM(PROMEDIO_PUNTAJEPRUEBA * TOTAL_EVALGRUPO_INSTPROGRAMA) / SUM(TOTAL_EVALGRUPO_INSTPROGRAMA), 2),
    0
FROM resul_agreg_sab_tyt_2018_generi_mod_prog
WHERE TOTAL_EVALGRUPO_INSTPROGRAMA > 0
GROUP BY UPPER(TRIM(INSTITUCION)), UPPER(TRIM(PROGRAMA_ACADEMICO)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO)), UPPER(TRIM(GRUPO_REFERENCIA))

UNION ALL

-- Saber T&T 2018, específica
SELECT
    2018, 'Saber TyT', 'ESPECIFICA',
    UPPER(TRIM(GRUPO_REFERENCIA)),
    UPPER(TRIM(INSTITUCION)),
    UPPER(TRIM(PROGRAMA_ACADEMICO)),
    UPPER(TRIM(DEPARTAMENTO_INSTITUCION)),
    UPPER(TRIM(NOMBRE_MODULO)),
    SUM(TOTAL_EVALGRUPO_INSTPROGRAMA),
    ROUND(SUM(PROMEDIO_PUNTAJEPRUEBA * TOTAL_EVALGRUPO_INSTPROGRAMA) / SUM(TOTAL_EVALGRUPO_INSTPROGRAMA), 2),
    0
FROM resul_agreg_sab_tyt_2018_especifi_mod_prog
WHERE TOTAL_EVALGRUPO_INSTPROGRAMA > 0
GROUP BY UPPER(TRIM(INSTITUCION)), UPPER(TRIM(PROGRAMA_ACADEMICO)), UPPER(TRIM(DEPARTAMENTO_INSTITUCION)), UPPER(TRIM(NOMBRE_MODULO)), UPPER(TRIM(GRUPO_REFERENCIA));
