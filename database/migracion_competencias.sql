-- =====================================================================
-- Migración: Tipo de Prueba (Saber Pro / Saber TyT) + Competencias
--
-- Archiva el banco de preguntas actual (esquema grupo/módulo) y crea
-- el nuevo modelo: tipos_prueba, competencias, configuracion_pruebas,
-- y un banco de preguntas nuevo clasificado por esas dos dimensiones.
--
-- Ejecutar UNA sola vez: mysql -u root proyecto_saber_pro_tyt < database/migracion_competencias.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Catálogos
-- ---------------------------------------------------------------------
CREATE TABLE `tipos_prueba` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_tipos_prueba_nombre` (`nombre`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `tipos_prueba` (`nombre`) VALUES ('Saber Pro'), ('Saber TyT');

CREATE TABLE `competencias` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_competencias_nombre` (`nombre`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `competencias` (`nombre`) VALUES
  ('Razonamiento cuantitativo'),
  ('Lectura crítica'),
  ('Competencias ciudadanas'),
  ('Comunicación escrita'),
  ('Inglés');

CREATE TABLE `configuracion_pruebas` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `tipo_prueba_id` int(11) NOT NULL,
  `competencia_id` int(11) NOT NULL,
  `duracion_minutos` int(11) NOT NULL DEFAULT 45,
  `cantidad_preguntas` int(11) DEFAULT NULL COMMENT 'NULL = usar todas las disponibles',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_config_tipo_competencia` (`tipo_prueba_id`, `competencia_id`),
  KEY `idx_config_competencia` (`competencia_id`),
  CONSTRAINT `fk_config_tipo` FOREIGN KEY (`tipo_prueba_id`) REFERENCES `tipos_prueba` (`id`),
  CONSTRAINT `fk_config_competencia` FOREIGN KEY (`competencia_id`) REFERENCES `competencias` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `configuracion_pruebas` (`tipo_prueba_id`, `competencia_id`, `duracion_minutos`, `cantidad_preguntas`)
SELECT tp.id, c.id, 45, NULL
FROM `tipos_prueba` tp CROSS JOIN `competencias` c;

-- ---------------------------------------------------------------------
-- 2. Archivar el banco de preguntas actual (esquema grupo/módulo)
-- ---------------------------------------------------------------------
RENAME TABLE `preguntas` TO `preguntas_legado`, `opciones` TO `opciones_legado`;

-- ---------------------------------------------------------------------
-- 3. Banco de preguntas nuevo, clasificado por Tipo de Prueba + Competencia
-- ---------------------------------------------------------------------
CREATE TABLE `preguntas` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `enunciado` text NOT NULL,
  `tipo_prueba_id` int(11) NOT NULL,
  `competencia_id` int(11) NOT NULL,
  `puntaje` decimal(5,2) DEFAULT 1.00,
  PRIMARY KEY (`id`),
  KEY `idx_preguntas_competencia` (`competencia_id`),
  CONSTRAINT `fk_preguntas_tipo` FOREIGN KEY (`tipo_prueba_id`) REFERENCES `tipos_prueba` (`id`),
  CONSTRAINT `fk_preguntas_competencia` FOREIGN KEY (`competencia_id`) REFERENCES `competencias` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `opciones` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `pregunta_id` int(11) NOT NULL,
  `etiqueta` char(1) NOT NULL,
  `texto` text NOT NULL,
  `es_correcta` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_opciones_pregunta` (`pregunta_id`),
  CONSTRAINT `fk_opciones_pregunta` FOREIGN KEY (`pregunta_id`) REFERENCES `preguntas` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- 4. simulacros_intentos: nuevas columnas (nullable, no tocan lo histórico)
-- ---------------------------------------------------------------------
ALTER TABLE `simulacros_intentos`
  ADD COLUMN `tipo_prueba_id` int(11) DEFAULT NULL AFTER `usuario`,
  ADD COLUMN `competencia_id` int(11) DEFAULT NULL AFTER `tipo_prueba_id`,
  ADD CONSTRAINT `fk_intentos_tipo` FOREIGN KEY (`tipo_prueba_id`) REFERENCES `tipos_prueba` (`id`),
  ADD CONSTRAINT `fk_intentos_competencia` FOREIGN KEY (`competencia_id`) REFERENCES `competencias` (`id`);
