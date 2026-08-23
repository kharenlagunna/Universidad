-- =====================================================================
-- Esquema de base de datos - Proyecto Universidad (Simulacro Saber Pro y T&T)
--
-- Uso:
--   1. Crea la base de datos (o usa la existente).
--   2. Ejecuta este script completo (phpMyAdmin > Importar, o por CLI:
--      mysql -u root proyecto_saber_pro_tyt < database/schema.sql)
--   3. Queda creado un usuario administrador de arranque:
--        usuario:    admin
--        contraseña: changeme123   <-- cámbiala apenas entres, desde
--                                      Gestión de Usuarios (admin_usuarios.php)
-- =====================================================================

CREATE DATABASE IF NOT EXISTS proyecto_saber_pro_tyt
    CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

USE proyecto_saber_pro_tyt;

SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- usuarioss: cuentas del sistema (admin / visor)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `usuarioss`;
CREATE TABLE `usuarioss` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `usuario` varchar(50) NOT NULL,
  `contrasena` varchar(255) NOT NULL,
  `rol` varchar(20) NOT NULL,
  `email` varchar(150) DEFAULT NULL,
  `reset_token_hash` varchar(64) DEFAULT NULL,
  `reset_token_expira` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_usuarioss_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Usuario administrador de arranque (contraseña: changeme123)
INSERT INTO `usuarioss` (`usuario`, `contrasena`, `rol`, `email`) VALUES
  ('admin', '$2y$10$jAQq8nfUpIrWKRCDQaDC6.WjA8hQw6T7c5M7zUwmowscCtRGjROxm', 'admin', NULL);

-- ---------------------------------------------------------------------
-- preguntas: banco de preguntas del simulacro
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `preguntas`;
CREATE TABLE `preguntas` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `enunciado` text NOT NULL,
  `componente` varchar(100) DEFAULT NULL,
  `grupo_referencia` varchar(100) DEFAULT NULL,
  `modulo` varchar(100) DEFAULT NULL,
  `tipo_prueba` varchar(50) DEFAULT NULL,
  `puntaje` decimal(5,2) DEFAULT 1.00,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- opciones: las 4 alternativas (A-D) de cada pregunta
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `opciones`;
CREATE TABLE `opciones` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `pregunta_id` int(11) NOT NULL,
  `etiqueta` char(1) NOT NULL,
  `texto` text NOT NULL,
  `es_correcta` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_opciones_pregunta` (`pregunta_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- simulacros_intentos: cada vez que un usuario inicia un simulacro
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `simulacros_intentos`;
CREATE TABLE `simulacros_intentos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `usuario` varchar(100) NOT NULL,
  `fecha_inicio` datetime NOT NULL,
  `fecha_fin` datetime DEFAULT NULL,
  `total_preguntas` int(11) NOT NULL,
  `puntaje_obtenido` decimal(10,2) DEFAULT 0.00,
  `tiempo_limite_segundos` int(11) NOT NULL DEFAULT 0,
  `filtro_grupo_referencia` varchar(100) DEFAULT NULL,
  `filtro_modulo` varchar(100) DEFAULT NULL,
  `filtro_tipo_prueba` enum('generica','especifica') DEFAULT NULL,
  `duracion_minutos` int(11) NOT NULL DEFAULT 60,
  `finalizado_manual` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_intentos_usuario` (`usuario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- simulacros_respuestas: una fila por cada pregunta dentro de un intento
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `simulacros_respuestas`;
CREATE TABLE `simulacros_respuestas` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `intento_id` int(11) NOT NULL,
  `pregunta_id` int(11) NOT NULL,
  `opcion_elegida` char(1) DEFAULT NULL,
  `es_correcta` tinyint(1) DEFAULT 0,
  `puntaje_obtenido` decimal(5,2) DEFAULT 0.00,
  PRIMARY KEY (`id`),
  KEY `idx_respuestas_intento` (`intento_id`),
  KEY `idx_respuestas_pregunta` (`pregunta_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- Tablas heredadas que el código actual ya NO usa. Se conservan solo
-- por si algún reporte externo o dato histórico depende de ellas.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `preguntas_old`;
CREATE TABLE `preguntas_old` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `enunciado` text NOT NULL,
  `grupo_referencia` varchar(100) NOT NULL,
  `modulo` varchar(100) NOT NULL,
  `tipo_prueba` enum('generica','especifica') NOT NULL,
  `puntaje` decimal(5,2) NOT NULL DEFAULT 1.00,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

DROP TABLE IF EXISTS `resultados`;
CREATE TABLE `resultados` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `usuario_id` int(11) NOT NULL,
  `pregunta_id` int(11) NOT NULL,
  `respuesta` enum('A','B','C','D') DEFAULT NULL,
  `es_correcta` tinyint(1) DEFAULT NULL,
  `fecha` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

DROP TABLE IF EXISTS `calendario`;
CREATE TABLE `calendario` (
  `fecha` date NOT NULL,
  `anio` int(11) DEFAULT NULL,
  `mes` int(11) DEFAULT NULL,
  `dia` int(11) DEFAULT NULL,
  `dia_semana` int(11) DEFAULT NULL,
  `nombre_dia` varchar(20) DEFAULT NULL,
  `nombre_mes` varchar(20) DEFAULT NULL,
  `es_fin_semana` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`fecha`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

SET FOREIGN_KEY_CHECKS = 1;
