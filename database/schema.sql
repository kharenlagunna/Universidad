-- =====================================================================
-- Esquema de base de datos - Proyecto Universidad (Simulacro Saber Pro y T&T)
--
-- ÚNICO paso de base de datos que necesita un desarrollador nuevo.
-- No hace falta crear ninguna base de datos a mano primero: este script
-- las crea él mismo (usa CREATE DATABASE IF NOT EXISTS).
--
-- Uso (CLI):
--   mysql -u root < database/schema.sql
-- o desde phpMyAdmin: pestaña SQL (de cualquier base) > pegar el
-- contenido completo de este archivo > Continuar.
--
-- Qué crea:
--   1. `proyecto_saber_pro_tyt`      — la base de la app, con todas sus
--      tablas y un usuario administrador de arranque:
--        usuario:    admin
--        contraseña: changeme123   <-- cámbiala apenas entres, desde
--                                      Gestión de Usuarios (admin_usuarios.php)
--   2. `resultados_saber_pro_tyt`    — solo la ESTRUCTURA (51 tablas/vistas)
--      de los datos agregados del ICFES. Los datos (~456 MB) no van aquí
--      por su tamaño; se cargan aparte con:
--        mysql -u root resultados_saber_pro_tyt < database/resultados_saber_pro_tyt_dump_completo.sql
--
-- Los demás archivos .sql en database/ (backup_*.sql) son respaldos
-- puntuales de la base de datos real — NO hace falta correrlos.
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
-- tipos_prueba / competencias: catálogos fijos del simulacro
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `tipos_prueba`;
CREATE TABLE `tipos_prueba` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_tipos_prueba_nombre` (`nombre`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `tipos_prueba` (`nombre`) VALUES ('Saber Pro'), ('Saber TyT');

DROP TABLE IF EXISTS `competencias`;
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

-- ---------------------------------------------------------------------
-- configuracion_pruebas: tiempo y cantidad de preguntas por cada
-- combinación Tipo de Prueba x Competencia (editable desde
-- admin_configuracion_pruebas.php)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `configuracion_pruebas`;
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
-- preguntas: banco de preguntas del simulacro, clasificado por
-- Tipo de Prueba + Competencia
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `preguntas`;
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
  KEY `idx_opciones_pregunta` (`pregunta_id`),
  CONSTRAINT `fk_opciones_pregunta` FOREIGN KEY (`pregunta_id`) REFERENCES `preguntas` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- simulacros_intentos: cada vez que un usuario inicia un simulacro
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS `simulacros_intentos`;
CREATE TABLE `simulacros_intentos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `usuario` varchar(100) NOT NULL,
  `tipo_prueba_id` int(11) DEFAULT NULL,
  `competencia_id` int(11) DEFAULT NULL,
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
  KEY `idx_intentos_usuario` (`usuario`),
  KEY `idx_intentos_competencia` (`competencia_id`),
  CONSTRAINT `fk_intentos_tipo` FOREIGN KEY (`tipo_prueba_id`) REFERENCES `tipos_prueba` (`id`),
  CONSTRAINT `fk_intentos_competencia` FOREIGN KEY (`competencia_id`) REFERENCES `competencias` (`id`)
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
-- Tabla heredada que el código actual ya NO usa. Se conserva solo
-- por si algún reporte externo o dato histórico depende de ella.
-- (preguntas_old, resultados, opciones_legado y preguntas_legado ya
-- se depuraron de la base real y de este esquema.)
-- ---------------------------------------------------------------------
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

-- =====================================================================
-- Segunda base de datos: resultados_saber_pro_tyt
--
-- Datos agregados oficiales del ICFES (Saber Pro / Saber T&T, 2015-2024)
-- desglosados por grupo de referencia, módulo, institución y programa.
-- Es un dataset de solo lectura, independiente de proyecto_saber_pro_tyt
-- (la app de simulacros); se usa para comparar/consultar resultados reales
-- desde el dashboard.
--
-- ⚠️ Este bloque solo crea la ESTRUCTURA (51 tablas/vistas, tal como
-- vinieron en el dump original). NO incluye los datos: pesan ~456 MB y
-- no es práctico versionarlos en git. Para cargar los datos reales,
-- importa aparte el dump completo:
--   mysql -u root resultados_saber_pro_tyt < database/resultados_saber_pro_tyt_dump_completo.sql
-- (ese archivo está en .gitignore por su tamaño; consíguelo con quien
-- te compartió este proyecto si no lo tienes).
--
-- Nota sobre los nombres: las tablas vienen con espacios, paréntesis e
-- incluso ".csv" en el nombre (ej. `resultados_agregados_saber pro
-- 2018(pro 2018).csv`) porque así se generaron al importar los CSV
-- originales del ICFES. Se dejaron tal cual para no romper la
-- correspondencia con el dataset fuente; en PHP siempre van entre
-- backticks.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS resultados_saber_pro_tyt
    CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

USE resultados_saber_pro_tyt;

SET FOREIGN_KEY_CHECKS = 0;


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
DROP TABLE IF EXISTS `agre_saber_pro2017 23 especi mod gruporef insti prog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `agre_saber_pro2017 23 especi mod gruporef insti prog` (
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `SNIES` int(11) DEFAULT NULL,
  `MUNICIPIO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `PROGRAMA_ACADEMICO` varchar(200) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(200) DEFAULT NULL,
  `TOTAL_EVALGRUPO_INSTPROGRAMA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `agre_saber_pro2017 23 especi mod gruporef institucion`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `agre_saber_pro2017 23 especi mod gruporef institucion` (
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(128) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(200) DEFAULT NULL,
  `TOTAL_EVALINSTITUCION_GRUPREF` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `agregados_saber_pro 2017 2 3 gener mod grup refer inst prog` (
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(128) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `SNIES` int(11) DEFAULT NULL,
  `MUNICIPIO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `PROGRAMA_ACADEMICO` varchar(200) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(200) DEFAULT NULL,
  `TOTAL_EVALGRUPO_INSTPROGRAMA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `agregados_saber_pro 2017 2 3 gener mod grup refer insti`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `agregados_saber_pro 2017 2 3 gener mod grup refer insti` (
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(128) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(200) DEFAULT NULL,
  `TOTAL_EVALINSTITUCION_GRUPREF` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `agregados_saber_pro 2017 2 3 gener mod grupo refer`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `agregados_saber_pro 2017 2 3 gener mod grupo refer` (
  `GRUPO_REFERENCIA` varchar(100) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(200) DEFAULT NULL,
  `TOTAL_EVAGRUPOREF_PRUEBA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `agregados_saber_pro 201702-3 especificas modulo grupo referencia`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `agregados_saber_pro 201702-3 especificas modulo grupo referencia` (
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(64) DEFAULT NULL,
  `TOTAL_EVAGRUPOREF_PRUEBA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `agregados_saber_tyt_2024`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `agregados_saber_tyt_2024` (
  `EXAMEN` varchar(50) DEFAULT NULL,
  `AGREGACION` varchar(50) DEFAULT NULL,
  `MEDIDA_AGREGACION` varchar(50) DEFAULT NULL,
  `CANTIDADEVALUADOS` int(11) DEFAULT NULL,
  `ID_PAIS` int(11) DEFAULT NULL,
  `ID_REGION` int(11) DEFAULT NULL,
  `NOMBRE_REGION` varchar(50) DEFAULT NULL,
  `ID_DEPARTAMENTO` int(11) DEFAULT NULL,
  `NOMBRE_DEPARTAMENTO` varchar(50) DEFAULT NULL,
  `ID_MUNICIPIO` varchar(50) DEFAULT NULL,
  `NOMBRE_MUNICIPIO` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` varchar(50) DEFAULT NULL,
  `NOMBRE_INSTITUCION` varchar(100) DEFAULT NULL,
  `ID_SEDE` varchar(50) DEFAULT NULL,
  `NOMBRE_SEDE` varchar(100) DEFAULT NULL,
  `ID_GRUPOREFERENCIA` varchar(50) DEFAULT NULL,
  `NOMBRE_GRUPOREF` varchar(50) DEFAULT NULL,
  `ID_NBC` varchar(50) DEFAULT NULL,
  `NBC` varchar(100) DEFAULT NULL,
  `ID_PROGRAMA_ACAD` varchar(50) DEFAULT NULL,
  `NOMBRE_PROGRAMA_ACAD` varchar(200) DEFAULT NULL,
  `NOMBRE_PRUEBA` varchar(100) DEFAULT NULL,
  `CATEGORIAPRUEBA` int(11) DEFAULT NULL,
  `PROMEDIO_GLOBAL` varchar(50) DEFAULT NULL,
  `PROMEDIO_PRUEBA` varchar(50) DEFAULT NULL,
  `DESVIACION` varchar(50) DEFAULT NULL,
  `PROMEDIO_PERCENTIL` varchar(50) DEFAULT NULL,
  `NIVEL1` int(11) DEFAULT NULL,
  `NIVEL2` int(11) DEFAULT NULL,
  `NIVEL3` int(11) DEFAULT NULL,
  `NIVEL4` int(11) DEFAULT NULL,
  `NIVEL5` int(11) DEFAULT NULL,
  `AFIRMACION` varchar(200) DEFAULT NULL,
  `PORCENTAJERTAINCORRECTA` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `rep_resul_agre_sab_pro_2015_especif_prog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rep_resul_agre_sab_pro_2015_especif_prog` (
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `CODIGO_INSTITUCION` int(11) DEFAULT NULL,
  `NOMBRE_INSTITUCION` varchar(200) DEFAULT NULL,
  `PRAC_ID` int(11) DEFAULT NULL,
  `NOMBRE_PROGRAMA_ACADEMICO` varchar(200) DEFAULT NULL,
  `MUNICIPIO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `NOMBRE_PRUEBA` varchar(100) DEFAULT NULL,
  `NOMBRE_GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `CANTIDAD_ESTUDIANTES` int(11) DEFAULT NULL,
  `PROMEDIO` varchar(50) DEFAULT NULL,
  `DESVIACION_ESTANDAR` varchar(50) DEFAULT NULL,
  `CANTIDAD_Q1` int(11) DEFAULT NULL,
  `CANTIDAD_Q2` int(11) DEFAULT NULL,
  `CANTIDAD_Q3` int(11) DEFAULT NULL,
  `CANTIDAD_Q4` int(11) DEFAULT NULL,
  `CANTIDAD_Q5` int(11) DEFAULT NULL,
  `CANTIDAD_A-` int(11) DEFAULT NULL,
  `CANTIDAD_A1` int(11) DEFAULT NULL,
  `CANTIDAD_A2` int(11) DEFAULT NULL,
  `CANTIDAD_B+` int(11) DEFAULT NULL,
  `CANTIDAD_B1` int(11) DEFAULT NULL,
  `CANTIDAD_SIN_NIVEL` int(11) DEFAULT NULL,
  `CANTIDAD_N1` int(11) DEFAULT NULL,
  `CANTIDAD_N2` int(11) DEFAULT NULL,
  `CANTIDAD_N3` int(11) DEFAULT NULL,
  `CANTIDAD_N4` int(11) DEFAULT NULL,
  `CANTIDAD_N5` int(11) DEFAULT NULL,
  `CANTIDAD_N6` int(11) DEFAULT NULL,
  `CANTIDAD_N7` int(11) DEFAULT NULL,
  `CANTIDAD_N8` int(11) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rep_resul_agre_sab_pro_2015_gener_mod_grup_ref` (
  `NOMBRE_PRUEBA` varchar(100) DEFAULT NULL,
  `NOMBRE_GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `CANTIDAD_ESTUDIANTES` int(11) DEFAULT NULL,
  `PROMEDIO` varchar(50) DEFAULT NULL,
  `DESVIACION_ESTANDAR` varchar(50) DEFAULT NULL,
  `CANTIDAD_Q1` int(11) DEFAULT NULL,
  `CANTIDAD_Q2` int(11) DEFAULT NULL,
  `CANTIDAD_Q3` int(11) DEFAULT NULL,
  `CANTIDAD_Q4` int(11) DEFAULT NULL,
  `CANTIDAD_Q5` int(11) DEFAULT NULL,
  `CANTIDAD_A-` int(11) DEFAULT NULL,
  `CANTIDAD_A1` int(11) DEFAULT NULL,
  `CANTIDAD_A2` int(11) DEFAULT NULL,
  `CANTIDAD_B+` int(11) DEFAULT NULL,
  `CANTIDAD_B1` int(11) DEFAULT NULL,
  `CANTIDAD_SIN_NIVEL` int(11) DEFAULT NULL,
  `CANTIDAD_N1` int(11) DEFAULT NULL,
  `CANTIDAD_N2` int(11) DEFAULT NULL,
  `CANTIDAD_N3` int(11) DEFAULT NULL,
  `CANTIDAD_N4` int(11) DEFAULT NULL,
  `CANTIDAD_N5` int(11) DEFAULT NULL,
  `CANTIDAD_N6` int(11) DEFAULT NULL,
  `CANTIDAD_N7` int(11) DEFAULT NULL,
  `CANTIDAD_N8` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `rep_resul_agre_sab_pro_2015_generi_insti`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rep_resul_agre_sab_pro_2015_generi_insti` (
  `MUNICIPIO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO` varchar(50) DEFAULT NULL,
  `NOMBRE_INSTITUCION` varchar(200) DEFAULT NULL,
  `CODIGO_INSTITUCION` int(11) DEFAULT NULL,
  `NOMBRE_PRUEBA` varchar(100) DEFAULT NULL,
  `NOMBRE_GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `CANTIDAD_ESTUDIANTES` int(11) DEFAULT NULL,
  `PROMEDIO` varchar(50) DEFAULT NULL,
  `DESVIACION_ESTANDAR` varchar(50) DEFAULT NULL,
  `CANTIDAD_Q1` int(11) DEFAULT NULL,
  `CANTIDAD_Q2` int(11) DEFAULT NULL,
  `CANTIDAD_Q3` int(11) DEFAULT NULL,
  `CANTIDAD_Q4` int(11) DEFAULT NULL,
  `CANTIDAD_Q5` int(11) DEFAULT NULL,
  `CANTIDAD_A-` int(11) DEFAULT NULL,
  `CANTIDAD_A1` int(11) DEFAULT NULL,
  `CANTIDAD_A2` int(11) DEFAULT NULL,
  `CANTIDAD_B+` int(11) DEFAULT NULL,
  `CANTIDAD_B1` int(11) DEFAULT NULL,
  `CANTIDAD_SIN_NIVEL` int(11) DEFAULT NULL,
  `CANTIDAD_N1` int(11) DEFAULT NULL,
  `CANTIDAD_N2` int(11) DEFAULT NULL,
  `CANTIDAD_N3` int(11) DEFAULT NULL,
  `CANTIDAD_N4` int(11) DEFAULT NULL,
  `CANTIDAD_N5` int(11) DEFAULT NULL,
  `CANTIDAD_N6` int(11) DEFAULT NULL,
  `CANTIDAD_N7` int(11) DEFAULT NULL,
  `CANTIDAD_N8` int(11) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `rep_resul_agreg_sab_pro_2015_especif_mod_inst`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rep_resul_agreg_sab_pro_2015_especif_mod_inst` (
  `MUNICIPIO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO` varchar(50) DEFAULT NULL,
  `NOMBRE_INSTITUCION` varchar(200) DEFAULT NULL,
  `CODIGO_INSTITUCION` int(11) DEFAULT NULL,
  `NOMBRE_PRUEBA` varchar(100) DEFAULT NULL,
  `NOMBRE_GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `CANTIDAD_ESTUDIANTES` int(11) DEFAULT NULL,
  `PROMEDIO` varchar(50) DEFAULT NULL,
  `DESVIACION_ESTANDAR` varchar(50) DEFAULT NULL,
  `CANTIDAD_Q1` int(11) DEFAULT NULL,
  `CANTIDAD_Q2` int(11) DEFAULT NULL,
  `CANTIDAD_Q3` int(11) DEFAULT NULL,
  `CANTIDAD_Q4` int(11) DEFAULT NULL,
  `CANTIDAD_Q5` int(11) DEFAULT NULL,
  `CANTIDAD_A-` int(11) DEFAULT NULL,
  `CANTIDAD_A1` int(11) DEFAULT NULL,
  `CANTIDAD_A2` int(11) DEFAULT NULL,
  `CANTIDAD_B+` int(11) DEFAULT NULL,
  `CANTIDAD_B1` int(11) DEFAULT NULL,
  `CANTIDAD_SIN_NIVEL` int(11) DEFAULT NULL,
  `CANTIDAD_N1` int(11) DEFAULT NULL,
  `CANTIDAD_N2` int(11) DEFAULT NULL,
  `CANTIDAD_N3` int(11) DEFAULT NULL,
  `CANTIDAD_N4` int(11) DEFAULT NULL,
  `CANTIDAD_N5` int(11) DEFAULT NULL,
  `CANTIDAD_N6` int(11) DEFAULT NULL,
  `CANTIDAD_N7` int(11) DEFAULT NULL,
  `CANTIDAD_N8` int(11) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `rep_resul_agreg_sab_pro_2015_generi_prog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rep_resul_agreg_sab_pro_2015_generi_prog` (
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `CODIGO_INSTITUCION` int(11) DEFAULT NULL,
  `NOMBRE_INSTITUCION` varchar(200) DEFAULT NULL,
  `PRAC_ID` int(11) DEFAULT NULL,
  `NOMBRE_PROGRAMA_ACADEMICO` varchar(200) DEFAULT NULL,
  `MUNICIPIO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `NOMBRE_PRUEBA` varchar(100) DEFAULT NULL,
  `NOMBRE_GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `CANTIDAD_ESTUDIANTES` int(11) DEFAULT NULL,
  `PROMEDIO` varchar(50) DEFAULT NULL,
  `DESVIACION_ESTANDAR` varchar(50) DEFAULT NULL,
  `CANTIDAD_Q1` int(11) DEFAULT NULL,
  `CANTIDAD_Q2` int(11) DEFAULT NULL,
  `CANTIDAD_Q3` int(11) DEFAULT NULL,
  `CANTIDAD_Q4` int(11) DEFAULT NULL,
  `CANTIDAD_Q5` int(11) DEFAULT NULL,
  `CANTIDAD_A-` int(11) DEFAULT NULL,
  `CANTIDAD_A1` int(11) DEFAULT NULL,
  `CANTIDAD_A2` int(11) DEFAULT NULL,
  `CANTIDAD_B+` int(11) DEFAULT NULL,
  `CANTIDAD_B1` int(11) DEFAULT NULL,
  `CANTIDAD_SIN_NIVEL` int(11) DEFAULT NULL,
  `CANTIDAD_N1` int(11) DEFAULT NULL,
  `CANTIDAD_N2` int(11) DEFAULT NULL,
  `CANTIDAD_N3` int(11) DEFAULT NULL,
  `CANTIDAD_N4` int(11) DEFAULT NULL,
  `CANTIDAD_N5` int(11) DEFAULT NULL,
  `CANTIDAD_N6` int(11) DEFAULT NULL,
  `CANTIDAD_N7` int(11) DEFAULT NULL,
  `CANTIDAD_N8` int(11) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `repo_resu_agre_sab_pro 2015 comp espec mod ref ins prog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `repo_resu_agre_sab_pro 2015 comp espec mod ref ins prog` (
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `CODIGO_INSTITUCION` int(11) DEFAULT NULL,
  `NOMBRE_INSTITUCION` varchar(200) DEFAULT NULL,
  `PRAC_ID` int(11) DEFAULT NULL,
  `NOMBRE_PROGRAMA_ACADEMICO` varchar(200) DEFAULT NULL,
  `MUNICIPIO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `NOMBRE_PRUEBA` varchar(100) DEFAULT NULL,
  `NOMBRE_GRUPO_REFERENCIA` varchar(200) DEFAULT NULL,
  `CANTIDAD_ESTUDIANTES` int(11) DEFAULT NULL,
  `PROMEDIO` varchar(50) DEFAULT NULL,
  `DESVIACION_ESTANDAR` varchar(50) DEFAULT NULL,
  `CANTIDAD_Q1` int(11) DEFAULT NULL,
  `CANTIDAD_Q2` int(11) DEFAULT NULL,
  `CANTIDAD_Q3` int(11) DEFAULT NULL,
  `CANTIDAD_Q4` int(11) DEFAULT NULL,
  `CANTIDAD_Q5` int(11) DEFAULT NULL,
  `CANTIDAD_A-` int(11) DEFAULT NULL,
  `CANTIDAD_A1` int(11) DEFAULT NULL,
  `CANTIDAD_A2` int(11) DEFAULT NULL,
  `CANTIDAD_B+` int(11) DEFAULT NULL,
  `CANTIDAD_B1` int(11) DEFAULT NULL,
  `CANTIDAD_SIN_NIVEL` int(11) DEFAULT NULL,
  `CANTIDAD_N1` int(11) DEFAULT NULL,
  `CANTIDAD_N2` int(11) DEFAULT NULL,
  `CANTIDAD_N3` int(11) DEFAULT NULL,
  `CANTIDAD_N4` int(11) DEFAULT NULL,
  `CANTIDAD_N5` int(11) DEFAULT NULL,
  `CANTIDAD_N6` int(11) DEFAULT NULL,
  `CANTIDAD_N7` int(11) DEFAULT NULL,
  `CANTIDAD_N8` int(11) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `repo_resul_agre_sab_pro_2015_especif_mod_grup_ref` (
  `NOMBRE_PRUEBA` varchar(100) DEFAULT NULL,
  `NOMBRE_GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `CANTIDAD_ESTUDIANTES` int(11) DEFAULT NULL,
  `PROMEDIO` varchar(50) DEFAULT NULL,
  `DESVIACION_ESTANDAR` varchar(50) DEFAULT NULL,
  `CANTIDAD_Q1` int(11) DEFAULT NULL,
  `CANTIDAD_Q2` int(11) DEFAULT NULL,
  `CANTIDAD_Q3` int(11) DEFAULT NULL,
  `CANTIDAD_Q4` int(11) DEFAULT NULL,
  `CANTIDAD_Q5` int(11) DEFAULT NULL,
  `CANTIDAD_A-` int(11) DEFAULT NULL,
  `CANTIDAD_A1` int(11) DEFAULT NULL,
  `CANTIDAD_A2` int(11) DEFAULT NULL,
  `CANTIDAD_B+` int(11) DEFAULT NULL,
  `CANTIDAD_B1` int(11) DEFAULT NULL,
  `CANTIDAD_SIN_NIVEL` int(11) DEFAULT NULL,
  `CANTIDAD_N1` int(11) DEFAULT NULL,
  `CANTIDAD_N2` int(11) DEFAULT NULL,
  `CANTIDAD_N3` int(11) DEFAULT NULL,
  `CANTIDAD_N4` int(11) DEFAULT NULL,
  `CANTIDAD_N5` int(11) DEFAULT NULL,
  `CANTIDAD_N6` int(11) DEFAULT NULL,
  `CANTIDAD_N7` int(11) DEFAULT NULL,
  `CANTIDAD_N8` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `repo_resul_agreg_sab_pro 2015 comp espec mod grup ref` (
  `NOMBRE_PRUEBA` varchar(100) DEFAULT NULL,
  `NOMBRE_GRUPO_REFERENCIA` varchar(200) DEFAULT NULL,
  `CANTIDAD_ESTUDIANTES` int(11) DEFAULT NULL,
  `PROMEDIO` varchar(50) DEFAULT NULL,
  `DESVIACION_ESTANDAR` varchar(50) DEFAULT NULL,
  `CANTIDAD_Q1` int(11) DEFAULT NULL,
  `CANTIDAD_Q2` int(11) DEFAULT NULL,
  `CANTIDAD_Q3` int(11) DEFAULT NULL,
  `CANTIDAD_Q4` int(11) DEFAULT NULL,
  `CANTIDAD_Q5` int(11) DEFAULT NULL,
  `CANTIDAD_A-` int(11) DEFAULT NULL,
  `CANTIDAD_A1` int(11) DEFAULT NULL,
  `CANTIDAD_A2` int(11) DEFAULT NULL,
  `CANTIDAD_B+` int(11) DEFAULT NULL,
  `CANTIDAD_B1` int(11) DEFAULT NULL,
  `CANTIDAD_SIN_NIVEL` int(11) DEFAULT NULL,
  `CANTIDAD_N1` int(11) DEFAULT NULL,
  `CANTIDAD_N2` int(11) DEFAULT NULL,
  `CANTIDAD_N3` int(11) DEFAULT NULL,
  `CANTIDAD_N4` int(11) DEFAULT NULL,
  `CANTIDAD_N5` int(11) DEFAULT NULL,
  `CANTIDAD_N6` int(11) DEFAULT NULL,
  `CANTIDAD_N7` int(11) DEFAULT NULL,
  `CANTIDAD_N8` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `repo_resul_agreg_sab_pro 2015 comp gener mod grup ref` (
  `NOMBRE_PRUEBA` varchar(100) DEFAULT NULL,
  `NOMBRE_GRUPO_REFERENCIA` varchar(100) DEFAULT NULL,
  `CANTIDAD_ESTUDIANTES` int(11) DEFAULT NULL,
  `PROMEDIO` varchar(50) DEFAULT NULL,
  `DESVIACION_ESTANDAR` varchar(50) DEFAULT NULL,
  `CANTIDAD_Q1` int(11) DEFAULT NULL,
  `CANTIDAD_Q2` int(11) DEFAULT NULL,
  `CANTIDAD_Q3` int(11) DEFAULT NULL,
  `CANTIDAD_Q4` int(11) DEFAULT NULL,
  `CANTIDAD_Q5` int(11) DEFAULT NULL,
  `CANTIDAD_A-` int(11) DEFAULT NULL,
  `CANTIDAD_A1` int(11) DEFAULT NULL,
  `CANTIDAD_A2` int(11) DEFAULT NULL,
  `CANTIDAD_B+` int(11) DEFAULT NULL,
  `CANTIDAD_B1` int(11) DEFAULT NULL,
  `CANTIDAD_SIN_NIVEL` int(11) DEFAULT NULL,
  `CANTIDAD_N1` int(11) DEFAULT NULL,
  `CANTIDAD_N2` int(11) DEFAULT NULL,
  `CANTIDAD_N3` int(11) DEFAULT NULL,
  `CANTIDAD_N4` int(11) DEFAULT NULL,
  `CANTIDAD_N5` int(11) DEFAULT NULL,
  `CANTIDAD_N6` int(11) DEFAULT NULL,
  `CANTIDAD_N7` int(11) DEFAULT NULL,
  `CANTIDAD_N8` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti` (
  `MUNICIPIO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO` varchar(50) DEFAULT NULL,
  `NOMBRE_INSTITUCION` varchar(200) DEFAULT NULL,
  `CODIGO_INSTITUCION` int(11) DEFAULT NULL,
  `NOMBRE_PRUEBA` varchar(100) DEFAULT NULL,
  `NOMBRE_GRUPO_REFERENCIA` varchar(100) DEFAULT NULL,
  `CANTIDAD_ESTUDIANTES` int(11) DEFAULT NULL,
  `PROMEDIO` varchar(50) DEFAULT NULL,
  `DESVIACION_ESTANDAR` varchar(50) DEFAULT NULL,
  `CANTIDAD_Q1` int(11) DEFAULT NULL,
  `CANTIDAD_Q2` int(11) DEFAULT NULL,
  `CANTIDAD_Q3` int(11) DEFAULT NULL,
  `CANTIDAD_Q4` int(11) DEFAULT NULL,
  `CANTIDAD_Q5` int(11) DEFAULT NULL,
  `CANTIDAD_A-` int(11) DEFAULT NULL,
  `CANTIDAD_A1` int(11) DEFAULT NULL,
  `CANTIDAD_A2` int(11) DEFAULT NULL,
  `CANTIDAD_B+` int(11) DEFAULT NULL,
  `CANTIDAD_B1` int(11) DEFAULT NULL,
  `CANTIDAD_SIN_NIVEL` int(11) DEFAULT NULL,
  `CANTIDAD_N1` int(11) DEFAULT NULL,
  `CANTIDAD_N2` int(11) DEFAULT NULL,
  `CANTIDAD_N3` int(11) DEFAULT NULL,
  `CANTIDAD_N4` int(11) DEFAULT NULL,
  `CANTIDAD_N5` int(11) DEFAULT NULL,
  `CANTIDAD_N6` int(11) DEFAULT NULL,
  `CANTIDAD_N7` int(11) DEFAULT NULL,
  `CANTIDAD_N8` int(11) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog` (
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `CODIGO_INSTITUCION` int(11) DEFAULT NULL,
  `NOMBRE_INSTITUCION` varchar(200) DEFAULT NULL,
  `PRAC_ID` int(11) DEFAULT NULL,
  `NOMBRE_PROGRAMA_ACADEMICO` varchar(200) DEFAULT NULL,
  `MUNICIPIO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `NOMBRE_PRUEBA` varchar(100) DEFAULT NULL,
  `NOMBRE_GRUPO_REFERENCIA` varchar(100) DEFAULT NULL,
  `CANTIDAD_ESTUDIANTES` int(11) DEFAULT NULL,
  `PROMEDIO` varchar(50) DEFAULT NULL,
  `DESVIACION_ESTANDAR` varchar(50) DEFAULT NULL,
  `CANTIDAD_Q1` int(11) DEFAULT NULL,
  `CANTIDAD_Q2` int(11) DEFAULT NULL,
  `CANTIDAD_Q3` int(11) DEFAULT NULL,
  `CANTIDAD_Q4` int(11) DEFAULT NULL,
  `CANTIDAD_Q5` int(11) DEFAULT NULL,
  `CANTIDAD_A-` int(11) DEFAULT NULL,
  `CANTIDAD_A1` int(11) DEFAULT NULL,
  `CANTIDAD_A2` int(11) DEFAULT NULL,
  `CANTIDAD_B+` int(11) DEFAULT NULL,
  `CANTIDAD_B1` int(11) DEFAULT NULL,
  `CANTIDAD_SIN_NIVEL` int(11) DEFAULT NULL,
  `CANTIDAD_N1` int(11) DEFAULT NULL,
  `CANTIDAD_N2` int(11) DEFAULT NULL,
  `CANTIDAD_N3` int(11) DEFAULT NULL,
  `CANTIDAD_N4` int(11) DEFAULT NULL,
  `CANTIDAD_N5` int(11) DEFAULT NULL,
  `CANTIDAD_N6` int(11) DEFAULT NULL,
  `CANTIDAD_N7` int(11) DEFAULT NULL,
  `CANTIDAD_N8` int(11) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti` (
  `MUNICIPIO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO` varchar(50) DEFAULT NULL,
  `NOMBRE_INSTITUCION` varchar(200) DEFAULT NULL,
  `CODIGO_INSTITUCION` int(11) DEFAULT NULL,
  `NOMBRE_PRUEBA` varchar(100) DEFAULT NULL,
  `NOMBRE_GRUPO_REFERENCIA` varchar(200) DEFAULT NULL,
  `CANTIDAD_ESTUDIANTES` int(11) DEFAULT NULL,
  `PROMEDIO` varchar(50) DEFAULT NULL,
  `DESVIACION_ESTANDAR` varchar(50) DEFAULT NULL,
  `CANTIDAD_Q1` int(11) DEFAULT NULL,
  `CANTIDAD_Q2` int(11) DEFAULT NULL,
  `CANTIDAD_Q3` int(11) DEFAULT NULL,
  `CANTIDAD_Q4` int(11) DEFAULT NULL,
  `CANTIDAD_Q5` int(11) DEFAULT NULL,
  `CANTIDAD_A-` int(11) DEFAULT NULL,
  `CANTIDAD_A1` int(11) DEFAULT NULL,
  `CANTIDAD_A2` int(11) DEFAULT NULL,
  `CANTIDAD_B+` int(11) DEFAULT NULL,
  `CANTIDAD_B1` int(11) DEFAULT NULL,
  `CANTIDAD_SIN_NIVEL` int(11) DEFAULT NULL,
  `CANTIDAD_N1` int(11) DEFAULT NULL,
  `CANTIDAD_N2` int(11) DEFAULT NULL,
  `CANTIDAD_N3` int(11) DEFAULT NULL,
  `CANTIDAD_N4` int(11) DEFAULT NULL,
  `CANTIDAD_N5` int(11) DEFAULT NULL,
  `CANTIDAD_N6` int(11) DEFAULT NULL,
  `CANTIDAD_N7` int(11) DEFAULT NULL,
  `CANTIDAD_N8` int(11) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_pro_mod_especif 2016 insti`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_pro_mod_especif 2016 insti` (
  `GRUPO_REFERENCIA` varchar(100) DEFAULT NULL,
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVALINSTITUCION_GRUPREF` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_pro_mod_especif 2016 mod grup ref`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_pro_mod_especif 2016 mod grup ref` (
  `GRUPO_REFERENCIA` varchar(100) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVAGRUPOREF_PRUEBA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_pro_mod_especif 2016 prog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_pro_mod_especif 2016 prog` (
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `GRUPO_REFERENCIA` varchar(100) DEFAULT NULL,
  `SNIES` int(11) DEFAULT NULL,
  `MUNICIPIO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `PROGRAMA_ACADEMICO` varchar(200) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVALGRUPO_INSTPROGRAMA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_pro_mod_gener 2016 insti`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_pro_mod_gener 2016 insti` (
  `GRUPO_REFERENCIA` varchar(100) DEFAULT NULL,
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVALINSTITUCION_GRUPREF` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_pro_mod_gener 2016 mod grup ref`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_pro_mod_gener 2016 mod grup ref` (
  `GRUPO_REFERENCIA` varchar(100) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVAGRUPOREF_PRUEBA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_pro_mod_gener 2016 prog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_pro_mod_gener 2016 prog` (
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `GRUPO_REFERENCIA` varchar(100) DEFAULT NULL,
  `SNIES` int(11) DEFAULT NULL,
  `MUNICIPIO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `PROGRAMA_ACADEMICO` varchar(200) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVALGRUPO_INSTPROGRAMA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_tyt_2016_especifi_mod_grup_ref`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_tyt_2016_especifi_mod_grup_ref` (
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVAGRUPOREF_PRUEBA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_tyt_2016_mod_especifi_insti`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_tyt_2016_mod_especifi_insti` (
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVALINSTITUCION_GRUPREF` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_tyt_2016_mod_especifi_prog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_tyt_2016_mod_especifi_prog` (
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `SNIES` int(11) DEFAULT NULL,
  `MUNICIPIO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `PROGRAMA_ACADEMICO` varchar(200) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVALGRUPO_INSTPROGRAMA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_tyt_2016_mod_gener_grup_ref`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_tyt_2016_mod_gener_grup_ref` (
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVAGRUPOREF_PRUEBA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_tyt_2016_mod_gener_insti`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_tyt_2016_mod_gener_insti` (
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVALINSTITUCION_GRUPREF` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_tyt_2016_mod_gener_prog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_tyt_2016_mod_gener_prog` (
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `SNIES` int(11) DEFAULT NULL,
  `MUNICIPIO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `PROGRAMA_ACADEMICO` varchar(200) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVALGRUPO_INSTPROGRAMA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_tyt_2018`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_tyt_2018` (
  `EXAMEN` varchar(50) DEFAULT NULL,
  `AGREGACION` varchar(50) DEFAULT NULL,
  `MEDIDA_AGREGACION` varchar(50) DEFAULT NULL,
  `CANTIDADEVALUADOS` int(11) DEFAULT NULL,
  `ID_PAIS` int(11) DEFAULT NULL,
  `NOMBRE_REGION` varchar(50) DEFAULT NULL,
  `NOMBRE_DEPARTAMENTO` varchar(50) DEFAULT NULL,
  `NOMBRE_MUNICIPIO` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `NOMBRE_INSTITUCION` varchar(200) DEFAULT NULL,
  `ID_SEDE` int(11) DEFAULT NULL,
  `NOMBRE_SEDE` varchar(200) DEFAULT NULL,
  `NOMBRE_GRUPOREF` varchar(50) DEFAULT NULL,
  `NOMBRE_NBC` varchar(100) DEFAULT NULL,
  `NOMBRE_PROGRAMA_ACAD` varchar(300) DEFAULT NULL,
  `NOMBRE_PRUEBA` varchar(100) DEFAULT NULL,
  `PROMEDIO_GLOBAL` varchar(50) DEFAULT NULL,
  `PROMEDIO_PRUEBA` int(11) DEFAULT NULL,
  `DESVIACION` int(11) DEFAULT NULL,
  `PROMEDIO_PERCENTIL` varchar(50) DEFAULT NULL,
  `NIVEL1` int(11) DEFAULT NULL,
  `NIVEL2` int(11) DEFAULT NULL,
  `NIVEL3` int(11) DEFAULT NULL,
  `NIVEL4` int(11) DEFAULT NULL,
  `NIVEL5` int(11) DEFAULT NULL,
  `AFIRMACION` varchar(200) DEFAULT NULL,
  `PORCENTAJERTAINCORRECTA` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_tyt_2018_especif_mod_grup_ref`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_tyt_2018_especif_mod_grup_ref` (
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVAGRUPOREF_PRUEBA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_tyt_2018_especifi_mod_inst`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_tyt_2018_especifi_mod_inst` (
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVALINSTITUCION_GRUPREF` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_tyt_2018_especifi_mod_prog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_tyt_2018_especifi_mod_prog` (
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `SNIES` varchar(50) DEFAULT NULL,
  `MUNICIPIO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `PROGRAMA_ACADEMICO` varchar(200) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVALGRUPO_INSTPROGRAMA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_tyt_2018_generi_mod_grup_ref`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_tyt_2018_generi_mod_grup_ref` (
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVAGRUPOREF_PRUEBA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_tyt_2018_generi_mod_insti`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_tyt_2018_generi_mod_insti` (
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVALINSTITUCION_GRUPREF` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_sab_tyt_2018_generi_mod_prog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_sab_tyt_2018_generi_mod_prog` (
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `SNIES` int(11) DEFAULT NULL,
  `MUNICIPIO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `PROGRAMA_ACADEMICO` varchar(200) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVALGRUPO_INSTPROGRAMA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resul_agreg_saber_tyt_2017`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resul_agreg_saber_tyt_2017` (
  `EXAMEN` varchar(50) DEFAULT NULL,
  `AGREGACION` varchar(50) DEFAULT NULL,
  `MEDIDA_AGREGACION` varchar(50) DEFAULT NULL,
  `ID_PAIS` int(11) DEFAULT NULL,
  `ID_REGION` int(11) DEFAULT NULL,
  `NOMBRE_REGION` varchar(50) DEFAULT NULL,
  `ID_DEPARTAMENTO` int(11) DEFAULT NULL,
  `NOMBRE_DEPARTAMENTO` varchar(50) DEFAULT NULL,
  `ID_MUNICIPIO` int(11) DEFAULT NULL,
  `NOMBRE_MUNICIPIO` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `NOMBRE_INSTITUCION` varchar(200) DEFAULT NULL,
  `ID_SEDE` int(11) DEFAULT NULL,
  `NOMBRE_SEDE` varchar(200) DEFAULT NULL,
  `ID_GRUPOREFERENCIA` int(11) DEFAULT NULL,
  `NOMBRE_GRUPOREF` varchar(50) DEFAULT NULL,
  `ID_PROGRAMA_ACAD` varchar(50) DEFAULT NULL,
  `NOMBRE_PROGRAMA_ACAD` varchar(200) DEFAULT NULL,
  `NOMBRE_PRUEBA` varchar(100) DEFAULT NULL,
  `PROMEDIO_GLOBAL` varchar(50) DEFAULT NULL,
  `PROMEDIO_PRUEBA` varchar(50) DEFAULT NULL,
  `DESVIACION` varchar(50) DEFAULT NULL,
  `PROMEDIO_PERCENTIL` int(11) DEFAULT NULL,
  `NIVEL1` varchar(50) DEFAULT NULL,
  `NIVEL2` varchar(50) DEFAULT NULL,
  `NIVEL3` varchar(50) DEFAULT NULL,
  `NIVEL4` varchar(50) DEFAULT NULL,
  `NIVEL5` varchar(50) DEFAULT NULL,
  `PORCENTAJERTAINCORRECTA` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resultados_agregados_saber pro 2018(pro 2018).csv`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resultados_agregados_saber pro 2018(pro 2018).csv` (
  `EXAMEN` varchar(50) DEFAULT NULL,
  `AGREGACION` varchar(50) DEFAULT NULL,
  `MEDIDA_AGREGACION` varchar(50) DEFAULT NULL,
  `CANTIDADEVALUADOS` int(11) DEFAULT NULL,
  `ID_PAIS` int(11) DEFAULT NULL,
  `NOMBRE_REGION` varchar(50) DEFAULT NULL,
  `NOMBRE_DEPARTAMENTO` varchar(50) DEFAULT NULL,
  `NOMBRE_MUNICIPIO` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `NOMBRE_INSTITUCION` varchar(128) DEFAULT NULL,
  `ID_SEDE` int(11) DEFAULT NULL,
  `NOMBRE_SEDE` varchar(128) DEFAULT NULL,
  `NOMBRE_GRUPOREF` varchar(50) DEFAULT NULL,
  `NOMBRE_NBC` varchar(100) DEFAULT NULL,
  `NOMBRE_PROGRAMA_ACAD` varchar(200) DEFAULT NULL,
  `NOMBRE_PRUEBA` varchar(64) DEFAULT NULL,
  `PROMEDIO_GLOBAL` varchar(50) DEFAULT NULL,
  `PROMEDIO_PRUEBA` int(11) DEFAULT NULL,
  `DESVIACION` int(11) DEFAULT NULL,
  `PROMEDIO_PERCENTIL` varchar(50) DEFAULT NULL,
  `NIVEL1` varchar(50) DEFAULT NULL,
  `NIVEL2` varchar(50) DEFAULT NULL,
  `NIVEL3` varchar(50) DEFAULT NULL,
  `NIVEL4` varchar(50) DEFAULT NULL,
  `NIVEL5` varchar(50) DEFAULT NULL,
  `AFIRMACION` varchar(500) DEFAULT NULL,
  `PORCENTAJERTAINCORRECTA` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resultados_agregados_saber_pro 2017`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resultados_agregados_saber_pro 2017` (
  `EXAMEN` varchar(50) DEFAULT NULL,
  `AGREGACION` varchar(50) DEFAULT NULL,
  `MEDIDA_AGREGACION` varchar(50) DEFAULT NULL,
  `ID_PAIS` int(11) DEFAULT NULL,
  `ID_REGION` int(11) DEFAULT NULL,
  `NOMBRE_REGION` varchar(50) DEFAULT NULL,
  `ID_DEPARTAMENTO` int(11) DEFAULT NULL,
  `NOMBRE_DEPARTAMENTO` varchar(50) DEFAULT NULL,
  `ID_MUNICIPIO` int(11) DEFAULT NULL,
  `NOMBRE_MUNICIPIO` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `NOMBRE_INSTITUCION` varchar(128) DEFAULT NULL,
  `ID_SEDE` int(11) DEFAULT NULL,
  `NOMBRE_SEDE` varchar(128) DEFAULT NULL,
  `ID_GRUPOREFERENCIA` int(11) DEFAULT NULL,
  `NOMBRE_GRUPOREF` varchar(50) DEFAULT NULL,
  `ID_PROGRAMA_ACAD` int(11) DEFAULT NULL,
  `NOMBRE_PROGRAMA_ACAD` varchar(200) DEFAULT NULL,
  `NOMBRE_PRUEBA` varchar(64) DEFAULT NULL,
  `PROMEDIO_GLOBAL` varchar(50) DEFAULT NULL,
  `PROMEDIO_PRUEBA` varchar(50) DEFAULT NULL,
  `DESVIACION` varchar(50) DEFAULT NULL,
  `PROMEDIO_PERCENTIL` varchar(50) DEFAULT NULL,
  `NIVEL1` int(11) DEFAULT NULL,
  `NIVEL2` int(11) DEFAULT NULL,
  `NIVEL3` int(11) DEFAULT NULL,
  `NIVEL4` int(11) DEFAULT NULL,
  `NIVEL5` varchar(50) DEFAULT NULL,
  `PORCENTAJERTAINCORRECTA` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resultados_agregados_saber_pro 2018 prueb especi prog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resultados_agregados_saber_pro 2018 prueb especi prog` (
  `GRUPO_REFERENCIA` varchar(100) DEFAULT NULL,
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `SNIES` int(11) DEFAULT NULL,
  `MUNICIPIO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `PROGRAMA_ACADEMICO` varchar(200) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(200) DEFAULT NULL,
  `TOTAL_EVALGRUPO_INSTPROGRAMA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resultados_agregados_saber_pro 2018 prueb especif grup refer`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resultados_agregados_saber_pro 2018 prueb especif grup refer` (
  `GRUPO_REFERENCIA` varchar(50) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVAGRUPOREF_PRUEBA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resultados_agregados_saber_pro 2018 prueb especif instit`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resultados_agregados_saber_pro 2018 prueb especif instit` (
  `GRUPO_REFERENCIA` varchar(100) DEFAULT NULL,
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVALINSTITUCION_GRUPREF` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resultados_agregados_saber_pro 2018 prueb gener grup refe`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resultados_agregados_saber_pro 2018 prueb gener grup refe` (
  `GRUPO_REFERENCIA` varchar(100) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVAGRUPOREF_PRUEBA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resultados_agregados_saber_pro 2018 prueb gener insti`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resultados_agregados_saber_pro 2018 prueb gener insti` (
  `GRUPO_REFERENCIA` varchar(100) DEFAULT NULL,
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(100) DEFAULT NULL,
  `TOTAL_EVALINSTITUCION_GRUPREF` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resultados_agregados_saber_pro 2018 prueb gener prog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resultados_agregados_saber_pro 2018 prueb gener prog` (
  `GRUPO_REFERENCIA` varchar(100) DEFAULT NULL,
  `MUNICIPIO_INSTITUCION` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_INSTITUCION` varchar(50) DEFAULT NULL,
  `ID_INSTITUCION` int(11) DEFAULT NULL,
  `INSTITUCION` varchar(200) DEFAULT NULL,
  `ORIGEN` varchar(50) DEFAULT NULL,
  `CARACTER` varchar(50) DEFAULT NULL,
  `SNIES` int(11) DEFAULT NULL,
  `MUNICIPIO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `DEPARTAMENTO_PROGRAMAACADEMICO` varchar(50) DEFAULT NULL,
  `PROGRAMA_ACADEMICO` varchar(200) DEFAULT NULL,
  `NOMBRE_MODULO` varchar(200) DEFAULT NULL,
  `TOTAL_EVALGRUPO_INSTPROGRAMA` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEGLOBAL` int(11) DEFAULT NULL,
  `PROMEDIO_PUNTAJEPRUEBA` int(11) DEFAULT NULL,
  `DESVI_ESTANDAR_PUNTAJEPRUEBA` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `sabana_especif_ing_telema 2015 3`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sabana_especif_ing_telema 2015 3` (
  `PROGRAMA ACADÉMICO:` varchar(50) DEFAULT NULL,
  `MUNICIPIO:` varchar(50) DEFAULT NULL,
  `GRUPO REFERENCIA:` varchar(50) DEFAULT NULL,
  `INSTITUCIÓN:` varchar(50) DEFAULT NULL,
  `MÓDULO` varchar(100) DEFAULT NULL,
  `Column6` varchar(50) DEFAULT NULL,
  `Column7` varchar(50) DEFAULT NULL,
  `Column8` varchar(50) DEFAULT NULL,
  `Column9` varchar(50) DEFAULT NULL,
  `Column10` varchar(50) DEFAULT NULL,
  `EVALUADO` varchar(50) DEFAULT NULL,
  `Column12` varchar(50) DEFAULT NULL,
  `Column13` varchar(50) DEFAULT NULL,
  `Column14` varchar(50) DEFAULT NULL,
  `Column15` varchar(50) DEFAULT NULL,
  `Column16` varchar(50) DEFAULT NULL,
  `NÚMERO REGISTRO` varchar(50) DEFAULT NULL,
  `Puntaje` varchar(50) DEFAULT NULL,
  `Nivel` varchar(50) DEFAULT NULL,
  `Quintil` varchar(50) DEFAULT NULL,
  `Column21` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `sabana_generi_ing_telema 2015 3`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sabana_generi_ing_telema 2015 3` (
  `PROGRAMA ACADÉMICO:` varchar(50) DEFAULT NULL,
  `MUNICIPIO:` varchar(50) DEFAULT NULL,
  `GRUPO REFERENCIA:` varchar(50) DEFAULT NULL,
  `INSTITUCIÓN:` varchar(50) DEFAULT NULL,
  `MÓDULO` varchar(100) DEFAULT NULL,
  `Column6` varchar(50) DEFAULT NULL,
  `Column7` varchar(50) DEFAULT NULL,
  `Column8` varchar(50) DEFAULT NULL,
  `Column9` varchar(50) DEFAULT NULL,
  `Column10` varchar(50) DEFAULT NULL,
  `EVALUADO` varchar(50) DEFAULT NULL,
  `Column12` varchar(50) DEFAULT NULL,
  `Column13` varchar(50) DEFAULT NULL,
  `Column14` varchar(50) DEFAULT NULL,
  `Column15` varchar(50) DEFAULT NULL,
  `Column16` varchar(50) DEFAULT NULL,
  `NÚMERO REGISTRO` varchar(50) DEFAULT NULL,
  `Puntaje` varchar(50) DEFAULT NULL,
  `Nivel` varchar(50) DEFAULT NULL,
  `Quintil` varchar(50) DEFAULT NULL,
  `Column21` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `vista_master_saber`;
/*!50001 DROP VIEW IF EXISTS `vista_master_saber`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
/*!50001 CREATE VIEW `vista_master_saber` AS SELECT
 1 AS `GRUPO_REFERENCIA`,
  1 AS `NOMBRE_MODULO`,
  1 AS `PROMEDIO_PUNTAJEGLOBAL`,
  1 AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,
  1 AS `PROMEDIO_PUNTAJEPRUEBA`,
  1 AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,
  1 AS `ORIGEN`,
  1 AS `CARACTER`,
  1 AS `ID_INSTITUCION`,
  1 AS `MUNICIPIO_INSTITUCION`,
  1 AS `DEPARTAMENTO_INSTITUCION`,
  1 AS `INSTITUCION`,
  1 AS `NOMBRE_PRUEBA`,
  1 AS `MUNICIPIO_PROGRAMAACADEMICO`,
  1 AS `DEPARTAMENTO_PROGRAMAACADEMICO`,
  1 AS `NOMBRE_INSTITUCION`,
  1 AS `NOMBRE_GRUPO_REFERENCIA`,
  1 AS `CANTIDAD_ESTUDIANTES`,
  1 AS `PROMEDIO`,
  1 AS `DESVIACION_ESTANDAR`,
  1 AS `CANTIDAD_Q1`,
  1 AS `CANTIDAD_Q2`,
  1 AS `CANTIDAD_Q3`,
  1 AS `CANTIDAD_Q4`,
  1 AS `CANTIDAD_Q5`,
  1 AS `CANTIDAD_A-`,
  1 AS `CANTIDAD_A1`,
  1 AS `CANTIDAD_A2`,
  1 AS `CANTIDAD_B+`,
  1 AS `CANTIDAD_B1`,
  1 AS `CANTIDAD_SIN_NIVEL`,
  1 AS `CANTIDAD_N1`,
  1 AS `CANTIDAD_N2`,
  1 AS `CANTIDAD_N3`,
  1 AS `CANTIDAD_N4`,
  1 AS `CANTIDAD_N5`,
  1 AS `CANTIDAD_N6`,
  1 AS `CANTIDAD_N7`,
  1 AS `CANTIDAD_N8`,
  1 AS `TOTAL_EVAGRUPOREF_PRUEBA`,
  1 AS `SNIES`,
  1 AS `PROGRAMA_ACADEMICO`,
  1 AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,
  1 AS `TOTAL_EVALINSTITUCION_GRUPREF`,
  1 AS `CODIGO_INSTITUCION`,
  1 AS `EXAMEN`,
  1 AS `AGREGACION`,
  1 AS `MEDIDA_AGREGACION`,
  1 AS `ID_PAIS`,
  1 AS `NOMBRE_REGION`,
  1 AS `NOMBRE_DEPARTAMENTO`,
  1 AS `NOMBRE_MUNICIPIO`,
  1 AS `ID_SEDE`,
  1 AS `NOMBRE_SEDE`,
  1 AS `NOMBRE_GRUPOREF`,
  1 AS `NOMBRE_PROGRAMA_ACAD`,
  1 AS `PROMEDIO_GLOBAL`,
  1 AS `PROMEDIO_PRUEBA`,
  1 AS `DESVIACION`,
  1 AS `PROMEDIO_PERCENTIL`,
  1 AS `NIVEL1`,
  1 AS `NIVEL2`,
  1 AS `NIVEL3`,
  1 AS `NIVEL4`,
  1 AS `NIVEL5`,
  1 AS `PORCENTAJERTAINCORRECTA`,
  1 AS `MUNICIPIO`,
  1 AS `DEPARTAMENTO`,
  1 AS `CANTIDADEVALUADOS`,
  1 AS `ID_REGION`,
  1 AS `ID_DEPARTAMENTO`,
  1 AS `ID_MUNICIPIO`,
  1 AS `ID_GRUPOREFERENCIA`,
  1 AS `ID_PROGRAMA_ACAD`,
  1 AS `AFIRMACION`,
  1 AS `PRAC_ID`,
  1 AS `NOMBRE_PROGRAMA_ACADEMICO`,
  1 AS `NOMBRE_NBC`,
  1 AS `PROGRAMA ACADÉMICO:`,
  1 AS `MUNICIPIO:`,
  1 AS `GRUPO REFERENCIA:`,
  1 AS `INSTITUCIÓN:`,
  1 AS `MÓDULO`,
  1 AS `Column6`,
  1 AS `Column7`,
  1 AS `Column8`,
  1 AS `Column9`,
  1 AS `Column10`,
  1 AS `EVALUADO`,
  1 AS `Column12`,
  1 AS `Column13`,
  1 AS `Column14`,
  1 AS `Column15`,
  1 AS `Column16`,
  1 AS `NÚMERO REGISTRO`,
  1 AS `Puntaje`,
  1 AS `Nivel`,
  1 AS `Quintil`,
  1 AS `Column21`,
  1 AS `ID_NBC`,
  1 AS `NBC`,
  1 AS `CATEGORIAPRUEBA`,
  1 AS `NOMBRE_TABLA` */;
SET character_set_client = @saved_cs_client;
DROP TABLE IF EXISTS `vista_master_saber_consolidada`;
/*!50001 DROP VIEW IF EXISTS `vista_master_saber_consolidada`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
/*!50001 CREATE VIEW `vista_master_saber_consolidada` AS SELECT
 1 AS `GRUPO_REFERENCIA_MASTER`,
  1 AS `MODULO_MASTER`,
  1 AS `TOTAL_EVAGRUPOREF_PRUEBA`,
  1 AS `PROMEDIO_PUNTAJEGLOBAL`,
  1 AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,
  1 AS `PROMEDIO_PUNTAJEPRUEBA`,
  1 AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,
  1 AS `MUNICIPIO_INSTITUCION`,
  1 AS `DEPARTAMENTO_INSTITUCION`,
  1 AS `ID_INSTITUCION`,
  1 AS `INSTITUCION_MASTER`,
  1 AS `ORIGEN`,
  1 AS `CARACTER`,
  1 AS `SNIES`,
  1 AS `MUNICIPIO_PROGRAMAACADEMICO`,
  1 AS `DEPARTAMENTO_PROGRAMAACADEMICO`,
  1 AS `PROGRAMA_ACADEMICO_MASTER`,
  1 AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,
  1 AS `TOTAL_EVALINSTITUCION_GRUPREF`,
  1 AS `EXAMEN`,
  1 AS `AGREGACION`,
  1 AS `MEDIDA_AGREGACION`,
  1 AS `CANTIDADEVALUADOS`,
  1 AS `ID_PAIS`,
  1 AS `ID_REGION`,
  1 AS `NOMBRE_REGION`,
  1 AS `ID_DEPARTAMENTO`,
  1 AS `NOMBRE_DEPARTAMENTO`,
  1 AS `ID_MUNICIPIO`,
  1 AS `NOMBRE_MUNICIPIO`,
  1 AS `ID_SEDE`,
  1 AS `NOMBRE_SEDE`,
  1 AS `ID_GRUPOREFERENCIA`,
  1 AS `ID_NBC`,
  1 AS `NBC`,
  1 AS `ID_PROGRAMA_ACAD_MASTER`,
  1 AS `NOMBRE_PRUEBA`,
  1 AS `CATEGORIAPRUEBA`,
  1 AS `PROMEDIO_GLOBAL`,
  1 AS `PROMEDIO_PRUEBA`,
  1 AS `DESVIACION`,
  1 AS `PROMEDIO_PERCENTIL`,
  1 AS `NIVEL1`,
  1 AS `NIVEL2`,
  1 AS `NIVEL3`,
  1 AS `NIVEL4`,
  1 AS `NIVEL5`,
  1 AS `AFIRMACION`,
  1 AS `PORCENTAJERTAINCORRECTA`,
  1 AS `MUNICIPIO_MASTER`,
  1 AS `DEPARTAMENTO_MASTER`,
  1 AS `CODIGO_INSTITUCION`,
  1 AS `CANTIDAD_ESTUDIANTES`,
  1 AS `PROMEDIO`,
  1 AS `DESVIACION_ESTANDAR`,
  1 AS `CANTIDAD_Q1`,
  1 AS `CANTIDAD_Q2`,
  1 AS `CANTIDAD_Q3`,
  1 AS `CANTIDAD_Q4`,
  1 AS `CANTIDAD_Q5`,
  1 AS `CANTIDAD_A-`,
  1 AS `CANTIDAD_A1`,
  1 AS `CANTIDAD_A2`,
  1 AS `CANTIDAD_B+`,
  1 AS `CANTIDAD_B1`,
  1 AS `CANTIDAD_SIN_NIVEL`,
  1 AS `CANTIDAD_N1`,
  1 AS `CANTIDAD_N2`,
  1 AS `CANTIDAD_N3`,
  1 AS `CANTIDAD_N4`,
  1 AS `CANTIDAD_N5`,
  1 AS `CANTIDAD_N6`,
  1 AS `CANTIDAD_N7`,
  1 AS `CANTIDAD_N8`,
  1 AS `NOMBRE_NBC`,
  1 AS `Column6`,
  1 AS `Column7`,
  1 AS `Column8`,
  1 AS `Column9`,
  1 AS `Column10`,
  1 AS `EVALUADO`,
  1 AS `Column12`,
  1 AS `Column13`,
  1 AS `Column14`,
  1 AS `Column15`,
  1 AS `Column16`,
  1 AS `NÚMERO REGISTRO`,
  1 AS `Puntaje`,
  1 AS `Nivel`,
  1 AS `Quintil`,
  1 AS `Column21`,
  1 AS `NOMBRE_TABLA` */;
SET character_set_client = @saved_cs_client;
/*!50001 DROP VIEW IF EXISTS `vista_master_saber`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vista_master_saber` AS select `agregados_saber_pro 201702-3 especificas modulo grupo referencia`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`agregados_saber_pro 201702-3 especificas modulo grupo referencia`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`agregados_saber_pro 201702-3 especificas modulo grupo referencia`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`agregados_saber_pro 201702-3 especificas modulo grupo referencia`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`agregados_saber_pro 201702-3 especificas modulo grupo referencia`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`agregados_saber_pro 201702-3 especificas modulo grupo referencia`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,`agregados_saber_pro 201702-3 especificas modulo grupo referencia`.`TOTAL_EVAGRUPOREF_PRUEBA` AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'agregados_saber_pro 201702-3 especificas modulo grupo referencia' AS `NOMBRE_TABLA` from `agregados_saber_pro 201702-3 especificas modulo grupo referencia` union all select `agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`ORIGEN` AS `ORIGEN`,`agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`CARACTER` AS `CARACTER`,`agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,`agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`MUNICIPIO_PROGRAMAACADEMICO` AS `MUNICIPIO_PROGRAMAACADEMICO`,`agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`DEPARTAMENTO_PROGRAMAACADEMICO` AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,`agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`SNIES` AS `SNIES`,`agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`PROGRAMA_ACADEMICO` AS `PROGRAMA_ACADEMICO`,`agregados_saber_pro 2017 2 3 gener mod grup refer inst prog`.`TOTAL_EVALGRUPO_INSTPROGRAMA` AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'agregados_saber_pro 2017 2 3 gener mod grup refer inst prog' AS `NOMBRE_TABLA` from `agregados_saber_pro 2017 2 3 gener mod grup refer inst prog` union all select `agregados_saber_pro 2017 2 3 gener mod grup refer insti`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`agregados_saber_pro 2017 2 3 gener mod grup refer insti`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`agregados_saber_pro 2017 2 3 gener mod grup refer insti`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`agregados_saber_pro 2017 2 3 gener mod grup refer insti`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`agregados_saber_pro 2017 2 3 gener mod grup refer insti`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`agregados_saber_pro 2017 2 3 gener mod grup refer insti`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`agregados_saber_pro 2017 2 3 gener mod grup refer insti`.`ORIGEN` AS `ORIGEN`,`agregados_saber_pro 2017 2 3 gener mod grup refer insti`.`CARACTER` AS `CARACTER`,`agregados_saber_pro 2017 2 3 gener mod grup refer insti`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`agregados_saber_pro 2017 2 3 gener mod grup refer insti`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`agregados_saber_pro 2017 2 3 gener mod grup refer insti`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`agregados_saber_pro 2017 2 3 gener mod grup refer insti`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,`agregados_saber_pro 2017 2 3 gener mod grup refer insti`.`TOTAL_EVALINSTITUCION_GRUPREF` AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'agregados_saber_pro 2017 2 3 gener mod grup refer insti' AS `NOMBRE_TABLA` from `agregados_saber_pro 2017 2 3 gener mod grup refer insti` union all select `agregados_saber_pro 2017 2 3 gener mod grupo refer`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`agregados_saber_pro 2017 2 3 gener mod grupo refer`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`agregados_saber_pro 2017 2 3 gener mod grupo refer`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`agregados_saber_pro 2017 2 3 gener mod grupo refer`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`agregados_saber_pro 2017 2 3 gener mod grupo refer`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`agregados_saber_pro 2017 2 3 gener mod grupo refer`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,`agregados_saber_pro 2017 2 3 gener mod grupo refer`.`TOTAL_EVAGRUPOREF_PRUEBA` AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'agregados_saber_pro 2017 2 3 gener mod grupo refer' AS `NOMBRE_TABLA` from `agregados_saber_pro 2017 2 3 gener mod grupo refer` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,`agregados_saber_tyt_2024`.`ID_INSTITUCION` AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,`agregados_saber_tyt_2024`.`NOMBRE_PRUEBA` AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,`agregados_saber_tyt_2024`.`NOMBRE_INSTITUCION` AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,`agregados_saber_tyt_2024`.`EXAMEN` AS `EXAMEN`,`agregados_saber_tyt_2024`.`AGREGACION` AS `AGREGACION`,`agregados_saber_tyt_2024`.`MEDIDA_AGREGACION` AS `MEDIDA_AGREGACION`,`agregados_saber_tyt_2024`.`ID_PAIS` AS `ID_PAIS`,`agregados_saber_tyt_2024`.`NOMBRE_REGION` AS `NOMBRE_REGION`,`agregados_saber_tyt_2024`.`NOMBRE_DEPARTAMENTO` AS `NOMBRE_DEPARTAMENTO`,`agregados_saber_tyt_2024`.`NOMBRE_MUNICIPIO` AS `NOMBRE_MUNICIPIO`,`agregados_saber_tyt_2024`.`ID_SEDE` AS `ID_SEDE`,`agregados_saber_tyt_2024`.`NOMBRE_SEDE` AS `NOMBRE_SEDE`,`agregados_saber_tyt_2024`.`NOMBRE_GRUPOREF` AS `NOMBRE_GRUPOREF`,`agregados_saber_tyt_2024`.`NOMBRE_PROGRAMA_ACAD` AS `NOMBRE_PROGRAMA_ACAD`,`agregados_saber_tyt_2024`.`PROMEDIO_GLOBAL` AS `PROMEDIO_GLOBAL`,`agregados_saber_tyt_2024`.`PROMEDIO_PRUEBA` AS `PROMEDIO_PRUEBA`,`agregados_saber_tyt_2024`.`DESVIACION` AS `DESVIACION`,`agregados_saber_tyt_2024`.`PROMEDIO_PERCENTIL` AS `PROMEDIO_PERCENTIL`,`agregados_saber_tyt_2024`.`NIVEL1` AS `NIVEL1`,`agregados_saber_tyt_2024`.`NIVEL2` AS `NIVEL2`,`agregados_saber_tyt_2024`.`NIVEL3` AS `NIVEL3`,`agregados_saber_tyt_2024`.`NIVEL4` AS `NIVEL4`,`agregados_saber_tyt_2024`.`NIVEL5` AS `NIVEL5`,`agregados_saber_tyt_2024`.`PORCENTAJERTAINCORRECTA` AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,`agregados_saber_tyt_2024`.`CANTIDADEVALUADOS` AS `CANTIDADEVALUADOS`,`agregados_saber_tyt_2024`.`ID_REGION` AS `ID_REGION`,`agregados_saber_tyt_2024`.`ID_DEPARTAMENTO` AS `ID_DEPARTAMENTO`,`agregados_saber_tyt_2024`.`ID_MUNICIPIO` AS `ID_MUNICIPIO`,`agregados_saber_tyt_2024`.`ID_GRUPOREFERENCIA` AS `ID_GRUPOREFERENCIA`,`agregados_saber_tyt_2024`.`ID_PROGRAMA_ACAD` AS `ID_PROGRAMA_ACAD`,`agregados_saber_tyt_2024`.`AFIRMACION` AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,`agregados_saber_tyt_2024`.`ID_NBC` AS `ID_NBC`,`agregados_saber_tyt_2024`.`NBC` AS `NBC`,`agregados_saber_tyt_2024`.`CATEGORIAPRUEBA` AS `CATEGORIAPRUEBA`,'agregados_saber_tyt_2024' AS `NOMBRE_TABLA` from `agregados_saber_tyt_2024` union all select `agre_saber_pro2017 23 especi mod gruporef insti prog`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`agre_saber_pro2017 23 especi mod gruporef insti prog`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`agre_saber_pro2017 23 especi mod gruporef insti prog`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`agre_saber_pro2017 23 especi mod gruporef insti prog`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`agre_saber_pro2017 23 especi mod gruporef insti prog`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`agre_saber_pro2017 23 especi mod gruporef insti prog`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`agre_saber_pro2017 23 especi mod gruporef insti prog`.`ORIGEN` AS `ORIGEN`,`agre_saber_pro2017 23 especi mod gruporef insti prog`.`CARACTER` AS `CARACTER`,`agre_saber_pro2017 23 especi mod gruporef insti prog`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`agre_saber_pro2017 23 especi mod gruporef insti prog`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`agre_saber_pro2017 23 especi mod gruporef insti prog`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`agre_saber_pro2017 23 especi mod gruporef insti prog`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,`agre_saber_pro2017 23 especi mod gruporef insti prog`.`MUNICIPIO_PROGRAMAACADEMICO` AS `MUNICIPIO_PROGRAMAACADEMICO`,`agre_saber_pro2017 23 especi mod gruporef insti prog`.`DEPARTAMENTO_PROGRAMAACADEMICO` AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,`agre_saber_pro2017 23 especi mod gruporef insti prog`.`SNIES` AS `SNIES`,`agre_saber_pro2017 23 especi mod gruporef insti prog`.`PROGRAMA_ACADEMICO` AS `PROGRAMA_ACADEMICO`,`agre_saber_pro2017 23 especi mod gruporef insti prog`.`TOTAL_EVALGRUPO_INSTPROGRAMA` AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'agre_saber_pro2017 23 especi mod gruporef insti prog' AS `NOMBRE_TABLA` from `agre_saber_pro2017 23 especi mod gruporef insti prog` union all select `agre_saber_pro2017 23 especi mod gruporef institucion`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`agre_saber_pro2017 23 especi mod gruporef institucion`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`agre_saber_pro2017 23 especi mod gruporef institucion`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`agre_saber_pro2017 23 especi mod gruporef institucion`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`agre_saber_pro2017 23 especi mod gruporef institucion`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`agre_saber_pro2017 23 especi mod gruporef institucion`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`agre_saber_pro2017 23 especi mod gruporef institucion`.`ORIGEN` AS `ORIGEN`,`agre_saber_pro2017 23 especi mod gruporef institucion`.`CARACTER` AS `CARACTER`,`agre_saber_pro2017 23 especi mod gruporef institucion`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`agre_saber_pro2017 23 especi mod gruporef institucion`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`agre_saber_pro2017 23 especi mod gruporef institucion`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`agre_saber_pro2017 23 especi mod gruporef institucion`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,`agre_saber_pro2017 23 especi mod gruporef institucion`.`TOTAL_EVALINSTITUCION_GRUPREF` AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'agre_saber_pro2017 23 especi mod gruporef institucion' AS `NOMBRE_TABLA` from `agre_saber_pro2017 23 especi mod gruporef institucion` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`ORIGEN` AS `ORIGEN`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CARACTER` AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`NOMBRE_PRUEBA` AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`NOMBRE_INSTITUCION` AS `NOMBRE_INSTITUCION`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`NOMBRE_GRUPO_REFERENCIA` AS `NOMBRE_GRUPO_REFERENCIA`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_ESTUDIANTES` AS `CANTIDAD_ESTUDIANTES`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`PROMEDIO` AS `PROMEDIO`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`DESVIACION_ESTANDAR` AS `DESVIACION_ESTANDAR`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_Q1` AS `CANTIDAD_Q1`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_Q2` AS `CANTIDAD_Q2`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_Q3` AS `CANTIDAD_Q3`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_Q4` AS `CANTIDAD_Q4`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_Q5` AS `CANTIDAD_Q5`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_A-` AS `CANTIDAD_A-`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_A1` AS `CANTIDAD_A1`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_A2` AS `CANTIDAD_A2`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_B+` AS `CANTIDAD_B+`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_B1` AS `CANTIDAD_B1`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_SIN_NIVEL` AS `CANTIDAD_SIN_NIVEL`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_N1` AS `CANTIDAD_N1`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_N2` AS `CANTIDAD_N2`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_N3` AS `CANTIDAD_N3`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_N4` AS `CANTIDAD_N4`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_N5` AS `CANTIDAD_N5`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_N6` AS `CANTIDAD_N6`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_N7` AS `CANTIDAD_N7`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CANTIDAD_N8` AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`CODIGO_INSTITUCION` AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`MUNICIPIO` AS `MUNICIPIO`,`repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti`.`DEPARTAMENTO` AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti' AS `NOMBRE_TABLA` from `repo_result_agreg_sab_pro 2015 comp especif mod grup refer insti` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`NOMBRE_PRUEBA` AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`NOMBRE_GRUPO_REFERENCIA` AS `NOMBRE_GRUPO_REFERENCIA`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_ESTUDIANTES` AS `CANTIDAD_ESTUDIANTES`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`PROMEDIO` AS `PROMEDIO`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`DESVIACION_ESTANDAR` AS `DESVIACION_ESTANDAR`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_Q1` AS `CANTIDAD_Q1`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_Q2` AS `CANTIDAD_Q2`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_Q3` AS `CANTIDAD_Q3`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_Q4` AS `CANTIDAD_Q4`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_Q5` AS `CANTIDAD_Q5`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_A-` AS `CANTIDAD_A-`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_A1` AS `CANTIDAD_A1`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_A2` AS `CANTIDAD_A2`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_B+` AS `CANTIDAD_B+`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_B1` AS `CANTIDAD_B1`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_SIN_NIVEL` AS `CANTIDAD_SIN_NIVEL`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_N1` AS `CANTIDAD_N1`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_N2` AS `CANTIDAD_N2`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_N3` AS `CANTIDAD_N3`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_N4` AS `CANTIDAD_N4`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_N5` AS `CANTIDAD_N5`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_N6` AS `CANTIDAD_N6`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_N7` AS `CANTIDAD_N7`,`repo_resul_agreg_sab_pro 2015 comp espec mod grup ref`.`CANTIDAD_N8` AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'repo_resul_agreg_sab_pro 2015 comp espec mod grup ref' AS `NOMBRE_TABLA` from `repo_resul_agreg_sab_pro 2015 comp espec mod grup ref` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`NOMBRE_PRUEBA` AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`NOMBRE_GRUPO_REFERENCIA` AS `NOMBRE_GRUPO_REFERENCIA`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_ESTUDIANTES` AS `CANTIDAD_ESTUDIANTES`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`PROMEDIO` AS `PROMEDIO`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`DESVIACION_ESTANDAR` AS `DESVIACION_ESTANDAR`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_Q1` AS `CANTIDAD_Q1`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_Q2` AS `CANTIDAD_Q2`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_Q3` AS `CANTIDAD_Q3`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_Q4` AS `CANTIDAD_Q4`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_Q5` AS `CANTIDAD_Q5`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_A-` AS `CANTIDAD_A-`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_A1` AS `CANTIDAD_A1`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_A2` AS `CANTIDAD_A2`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_B+` AS `CANTIDAD_B+`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_B1` AS `CANTIDAD_B1`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_SIN_NIVEL` AS `CANTIDAD_SIN_NIVEL`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_N1` AS `CANTIDAD_N1`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_N2` AS `CANTIDAD_N2`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_N3` AS `CANTIDAD_N3`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_N4` AS `CANTIDAD_N4`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_N5` AS `CANTIDAD_N5`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_N6` AS `CANTIDAD_N6`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_N7` AS `CANTIDAD_N7`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref`.`CANTIDAD_N8` AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'repo_resul_agreg_sab_pro 2015 comp gener mod grup ref' AS `NOMBRE_TABLA` from `repo_resul_agreg_sab_pro 2015 comp gener mod grup ref` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`ORIGEN` AS `ORIGEN`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CARACTER` AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`NOMBRE_PRUEBA` AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`NOMBRE_INSTITUCION` AS `NOMBRE_INSTITUCION`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`NOMBRE_GRUPO_REFERENCIA` AS `NOMBRE_GRUPO_REFERENCIA`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_ESTUDIANTES` AS `CANTIDAD_ESTUDIANTES`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`PROMEDIO` AS `PROMEDIO`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`DESVIACION_ESTANDAR` AS `DESVIACION_ESTANDAR`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_Q1` AS `CANTIDAD_Q1`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_Q2` AS `CANTIDAD_Q2`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_Q3` AS `CANTIDAD_Q3`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_Q4` AS `CANTIDAD_Q4`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_Q5` AS `CANTIDAD_Q5`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_A-` AS `CANTIDAD_A-`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_A1` AS `CANTIDAD_A1`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_A2` AS `CANTIDAD_A2`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_B+` AS `CANTIDAD_B+`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_B1` AS `CANTIDAD_B1`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_SIN_NIVEL` AS `CANTIDAD_SIN_NIVEL`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_N1` AS `CANTIDAD_N1`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_N2` AS `CANTIDAD_N2`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_N3` AS `CANTIDAD_N3`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_N4` AS `CANTIDAD_N4`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_N5` AS `CANTIDAD_N5`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_N6` AS `CANTIDAD_N6`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_N7` AS `CANTIDAD_N7`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CANTIDAD_N8` AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`CODIGO_INSTITUCION` AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`MUNICIPIO` AS `MUNICIPIO`,`repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti`.`DEPARTAMENTO` AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti' AS `NOMBRE_TABLA` from `repo_resul_agreg_sab_pro 2015 comp gener mod grup ref insti` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`ORIGEN` AS `ORIGEN`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CARACTER` AS `CARACTER`,NULL AS `ID_INSTITUCION`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`NOMBRE_PRUEBA` AS `NOMBRE_PRUEBA`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`MUNICIPIO_PROGRAMAACADEMICO` AS `MUNICIPIO_PROGRAMAACADEMICO`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`DEPARTAMENTO_PROGRAMAACADEMICO` AS `DEPARTAMENTO_PROGRAMAACADEMICO`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`NOMBRE_INSTITUCION` AS `NOMBRE_INSTITUCION`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`NOMBRE_GRUPO_REFERENCIA` AS `NOMBRE_GRUPO_REFERENCIA`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_ESTUDIANTES` AS `CANTIDAD_ESTUDIANTES`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`PROMEDIO` AS `PROMEDIO`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`DESVIACION_ESTANDAR` AS `DESVIACION_ESTANDAR`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_Q1` AS `CANTIDAD_Q1`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_Q2` AS `CANTIDAD_Q2`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_Q3` AS `CANTIDAD_Q3`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_Q4` AS `CANTIDAD_Q4`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_Q5` AS `CANTIDAD_Q5`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_A-` AS `CANTIDAD_A-`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_A1` AS `CANTIDAD_A1`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_A2` AS `CANTIDAD_A2`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_B+` AS `CANTIDAD_B+`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_B1` AS `CANTIDAD_B1`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_SIN_NIVEL` AS `CANTIDAD_SIN_NIVEL`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_N1` AS `CANTIDAD_N1`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_N2` AS `CANTIDAD_N2`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_N3` AS `CANTIDAD_N3`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_N4` AS `CANTIDAD_N4`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_N5` AS `CANTIDAD_N5`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_N6` AS `CANTIDAD_N6`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_N7` AS `CANTIDAD_N7`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CANTIDAD_N8` AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`CODIGO_INSTITUCION` AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`PRAC_ID` AS `PRAC_ID`,`repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog`.`NOMBRE_PROGRAMA_ACADEMICO` AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog' AS `NOMBRE_TABLA` from `repo_resul_agreg_sab_pro 2015 comp gener mod ref inst prog` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`NOMBRE_PRUEBA` AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`NOMBRE_GRUPO_REFERENCIA` AS `NOMBRE_GRUPO_REFERENCIA`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_ESTUDIANTES` AS `CANTIDAD_ESTUDIANTES`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`PROMEDIO` AS `PROMEDIO`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`DESVIACION_ESTANDAR` AS `DESVIACION_ESTANDAR`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_Q1` AS `CANTIDAD_Q1`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_Q2` AS `CANTIDAD_Q2`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_Q3` AS `CANTIDAD_Q3`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_Q4` AS `CANTIDAD_Q4`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_Q5` AS `CANTIDAD_Q5`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_A-` AS `CANTIDAD_A-`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_A1` AS `CANTIDAD_A1`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_A2` AS `CANTIDAD_A2`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_B+` AS `CANTIDAD_B+`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_B1` AS `CANTIDAD_B1`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_SIN_NIVEL` AS `CANTIDAD_SIN_NIVEL`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_N1` AS `CANTIDAD_N1`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_N2` AS `CANTIDAD_N2`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_N3` AS `CANTIDAD_N3`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_N4` AS `CANTIDAD_N4`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_N5` AS `CANTIDAD_N5`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_N6` AS `CANTIDAD_N6`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_N7` AS `CANTIDAD_N7`,`repo_resul_agre_sab_pro_2015_especif_mod_grup_ref`.`CANTIDAD_N8` AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'repo_resul_agre_sab_pro_2015_especif_mod_grup_ref' AS `NOMBRE_TABLA` from `repo_resul_agre_sab_pro_2015_especif_mod_grup_ref` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`ORIGEN` AS `ORIGEN`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CARACTER` AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`NOMBRE_PRUEBA` AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`NOMBRE_INSTITUCION` AS `NOMBRE_INSTITUCION`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`NOMBRE_GRUPO_REFERENCIA` AS `NOMBRE_GRUPO_REFERENCIA`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_ESTUDIANTES` AS `CANTIDAD_ESTUDIANTES`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`PROMEDIO` AS `PROMEDIO`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`DESVIACION_ESTANDAR` AS `DESVIACION_ESTANDAR`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_Q1` AS `CANTIDAD_Q1`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_Q2` AS `CANTIDAD_Q2`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_Q3` AS `CANTIDAD_Q3`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_Q4` AS `CANTIDAD_Q4`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_Q5` AS `CANTIDAD_Q5`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_A-` AS `CANTIDAD_A-`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_A1` AS `CANTIDAD_A1`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_A2` AS `CANTIDAD_A2`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_B+` AS `CANTIDAD_B+`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_B1` AS `CANTIDAD_B1`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_SIN_NIVEL` AS `CANTIDAD_SIN_NIVEL`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_N1` AS `CANTIDAD_N1`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_N2` AS `CANTIDAD_N2`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_N3` AS `CANTIDAD_N3`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_N4` AS `CANTIDAD_N4`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_N5` AS `CANTIDAD_N5`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_N6` AS `CANTIDAD_N6`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_N7` AS `CANTIDAD_N7`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CANTIDAD_N8` AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`CODIGO_INSTITUCION` AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`MUNICIPIO` AS `MUNICIPIO`,`rep_resul_agreg_sab_pro_2015_especif_mod_inst`.`DEPARTAMENTO` AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'rep_resul_agreg_sab_pro_2015_especif_mod_inst' AS `NOMBRE_TABLA` from `rep_resul_agreg_sab_pro_2015_especif_mod_inst` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`ORIGEN` AS `ORIGEN`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CARACTER` AS `CARACTER`,NULL AS `ID_INSTITUCION`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`NOMBRE_PRUEBA` AS `NOMBRE_PRUEBA`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`MUNICIPIO_PROGRAMAACADEMICO` AS `MUNICIPIO_PROGRAMAACADEMICO`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`DEPARTAMENTO_PROGRAMAACADEMICO` AS `DEPARTAMENTO_PROGRAMAACADEMICO`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`NOMBRE_INSTITUCION` AS `NOMBRE_INSTITUCION`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`NOMBRE_GRUPO_REFERENCIA` AS `NOMBRE_GRUPO_REFERENCIA`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_ESTUDIANTES` AS `CANTIDAD_ESTUDIANTES`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`PROMEDIO` AS `PROMEDIO`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`DESVIACION_ESTANDAR` AS `DESVIACION_ESTANDAR`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_Q1` AS `CANTIDAD_Q1`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_Q2` AS `CANTIDAD_Q2`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_Q3` AS `CANTIDAD_Q3`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_Q4` AS `CANTIDAD_Q4`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_Q5` AS `CANTIDAD_Q5`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_A-` AS `CANTIDAD_A-`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_A1` AS `CANTIDAD_A1`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_A2` AS `CANTIDAD_A2`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_B+` AS `CANTIDAD_B+`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_B1` AS `CANTIDAD_B1`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_SIN_NIVEL` AS `CANTIDAD_SIN_NIVEL`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_N1` AS `CANTIDAD_N1`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_N2` AS `CANTIDAD_N2`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_N3` AS `CANTIDAD_N3`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_N4` AS `CANTIDAD_N4`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_N5` AS `CANTIDAD_N5`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_N6` AS `CANTIDAD_N6`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_N7` AS `CANTIDAD_N7`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CANTIDAD_N8` AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`CODIGO_INSTITUCION` AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`PRAC_ID` AS `PRAC_ID`,`rep_resul_agreg_sab_pro_2015_generi_prog`.`NOMBRE_PROGRAMA_ACADEMICO` AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'rep_resul_agreg_sab_pro_2015_generi_prog' AS `NOMBRE_TABLA` from `rep_resul_agreg_sab_pro_2015_generi_prog` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`rep_resul_agre_sab_pro_2015_especif_prog`.`ORIGEN` AS `ORIGEN`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CARACTER` AS `CARACTER`,NULL AS `ID_INSTITUCION`,`rep_resul_agre_sab_pro_2015_especif_prog`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`rep_resul_agre_sab_pro_2015_especif_prog`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,`rep_resul_agre_sab_pro_2015_especif_prog`.`NOMBRE_PRUEBA` AS `NOMBRE_PRUEBA`,`rep_resul_agre_sab_pro_2015_especif_prog`.`MUNICIPIO_PROGRAMAACADEMICO` AS `MUNICIPIO_PROGRAMAACADEMICO`,`rep_resul_agre_sab_pro_2015_especif_prog`.`DEPARTAMENTO_PROGRAMAACADEMICO` AS `DEPARTAMENTO_PROGRAMAACADEMICO`,`rep_resul_agre_sab_pro_2015_especif_prog`.`NOMBRE_INSTITUCION` AS `NOMBRE_INSTITUCION`,`rep_resul_agre_sab_pro_2015_especif_prog`.`NOMBRE_GRUPO_REFERENCIA` AS `NOMBRE_GRUPO_REFERENCIA`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_ESTUDIANTES` AS `CANTIDAD_ESTUDIANTES`,`rep_resul_agre_sab_pro_2015_especif_prog`.`PROMEDIO` AS `PROMEDIO`,`rep_resul_agre_sab_pro_2015_especif_prog`.`DESVIACION_ESTANDAR` AS `DESVIACION_ESTANDAR`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_Q1` AS `CANTIDAD_Q1`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_Q2` AS `CANTIDAD_Q2`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_Q3` AS `CANTIDAD_Q3`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_Q4` AS `CANTIDAD_Q4`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_Q5` AS `CANTIDAD_Q5`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_A-` AS `CANTIDAD_A-`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_A1` AS `CANTIDAD_A1`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_A2` AS `CANTIDAD_A2`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_B+` AS `CANTIDAD_B+`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_B1` AS `CANTIDAD_B1`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_SIN_NIVEL` AS `CANTIDAD_SIN_NIVEL`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_N1` AS `CANTIDAD_N1`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_N2` AS `CANTIDAD_N2`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_N3` AS `CANTIDAD_N3`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_N4` AS `CANTIDAD_N4`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_N5` AS `CANTIDAD_N5`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_N6` AS `CANTIDAD_N6`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_N7` AS `CANTIDAD_N7`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CANTIDAD_N8` AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,`rep_resul_agre_sab_pro_2015_especif_prog`.`CODIGO_INSTITUCION` AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,`rep_resul_agre_sab_pro_2015_especif_prog`.`PRAC_ID` AS `PRAC_ID`,`rep_resul_agre_sab_pro_2015_especif_prog`.`NOMBRE_PROGRAMA_ACADEMICO` AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'rep_resul_agre_sab_pro_2015_especif_prog' AS `NOMBRE_TABLA` from `rep_resul_agre_sab_pro_2015_especif_prog` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`rep_resul_agre_sab_pro_2015_generi_insti`.`ORIGEN` AS `ORIGEN`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CARACTER` AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,`rep_resul_agre_sab_pro_2015_generi_insti`.`NOMBRE_PRUEBA` AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,`rep_resul_agre_sab_pro_2015_generi_insti`.`NOMBRE_INSTITUCION` AS `NOMBRE_INSTITUCION`,`rep_resul_agre_sab_pro_2015_generi_insti`.`NOMBRE_GRUPO_REFERENCIA` AS `NOMBRE_GRUPO_REFERENCIA`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_ESTUDIANTES` AS `CANTIDAD_ESTUDIANTES`,`rep_resul_agre_sab_pro_2015_generi_insti`.`PROMEDIO` AS `PROMEDIO`,`rep_resul_agre_sab_pro_2015_generi_insti`.`DESVIACION_ESTANDAR` AS `DESVIACION_ESTANDAR`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_Q1` AS `CANTIDAD_Q1`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_Q2` AS `CANTIDAD_Q2`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_Q3` AS `CANTIDAD_Q3`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_Q4` AS `CANTIDAD_Q4`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_Q5` AS `CANTIDAD_Q5`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_A-` AS `CANTIDAD_A-`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_A1` AS `CANTIDAD_A1`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_A2` AS `CANTIDAD_A2`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_B+` AS `CANTIDAD_B+`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_B1` AS `CANTIDAD_B1`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_SIN_NIVEL` AS `CANTIDAD_SIN_NIVEL`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_N1` AS `CANTIDAD_N1`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_N2` AS `CANTIDAD_N2`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_N3` AS `CANTIDAD_N3`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_N4` AS `CANTIDAD_N4`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_N5` AS `CANTIDAD_N5`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_N6` AS `CANTIDAD_N6`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_N7` AS `CANTIDAD_N7`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CANTIDAD_N8` AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,`rep_resul_agre_sab_pro_2015_generi_insti`.`CODIGO_INSTITUCION` AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,`rep_resul_agre_sab_pro_2015_generi_insti`.`MUNICIPIO` AS `MUNICIPIO`,`rep_resul_agre_sab_pro_2015_generi_insti`.`DEPARTAMENTO` AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'rep_resul_agre_sab_pro_2015_generi_insti' AS `NOMBRE_TABLA` from `rep_resul_agre_sab_pro_2015_generi_insti` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`NOMBRE_PRUEBA` AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`NOMBRE_GRUPO_REFERENCIA` AS `NOMBRE_GRUPO_REFERENCIA`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_ESTUDIANTES` AS `CANTIDAD_ESTUDIANTES`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`PROMEDIO` AS `PROMEDIO`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`DESVIACION_ESTANDAR` AS `DESVIACION_ESTANDAR`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_Q1` AS `CANTIDAD_Q1`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_Q2` AS `CANTIDAD_Q2`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_Q3` AS `CANTIDAD_Q3`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_Q4` AS `CANTIDAD_Q4`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_Q5` AS `CANTIDAD_Q5`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_A-` AS `CANTIDAD_A-`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_A1` AS `CANTIDAD_A1`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_A2` AS `CANTIDAD_A2`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_B+` AS `CANTIDAD_B+`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_B1` AS `CANTIDAD_B1`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_SIN_NIVEL` AS `CANTIDAD_SIN_NIVEL`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_N1` AS `CANTIDAD_N1`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_N2` AS `CANTIDAD_N2`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_N3` AS `CANTIDAD_N3`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_N4` AS `CANTIDAD_N4`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_N5` AS `CANTIDAD_N5`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_N6` AS `CANTIDAD_N6`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_N7` AS `CANTIDAD_N7`,`rep_resul_agre_sab_pro_2015_gener_mod_grup_ref`.`CANTIDAD_N8` AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'rep_resul_agre_sab_pro_2015_gener_mod_grup_ref' AS `NOMBRE_TABLA` from `rep_resul_agre_sab_pro_2015_gener_mod_grup_ref` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`ID_INSTITUCION` AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`NOMBRE_PRUEBA` AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`NOMBRE_INSTITUCION` AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`EXAMEN` AS `EXAMEN`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`AGREGACION` AS `AGREGACION`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`MEDIDA_AGREGACION` AS `MEDIDA_AGREGACION`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`ID_PAIS` AS `ID_PAIS`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`NOMBRE_REGION` AS `NOMBRE_REGION`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`NOMBRE_DEPARTAMENTO` AS `NOMBRE_DEPARTAMENTO`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`NOMBRE_MUNICIPIO` AS `NOMBRE_MUNICIPIO`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`ID_SEDE` AS `ID_SEDE`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`NOMBRE_SEDE` AS `NOMBRE_SEDE`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`NOMBRE_GRUPOREF` AS `NOMBRE_GRUPOREF`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`NOMBRE_PROGRAMA_ACAD` AS `NOMBRE_PROGRAMA_ACAD`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`PROMEDIO_GLOBAL` AS `PROMEDIO_GLOBAL`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`PROMEDIO_PRUEBA` AS `PROMEDIO_PRUEBA`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`DESVIACION` AS `DESVIACION`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`PROMEDIO_PERCENTIL` AS `PROMEDIO_PERCENTIL`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`NIVEL1` AS `NIVEL1`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`NIVEL2` AS `NIVEL2`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`NIVEL3` AS `NIVEL3`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`NIVEL4` AS `NIVEL4`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`NIVEL5` AS `NIVEL5`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`PORCENTAJERTAINCORRECTA` AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`CANTIDADEVALUADOS` AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`AFIRMACION` AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,`resultados_agregados_saber pro 2018(pro 2018).csv`.`NOMBRE_NBC` AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resultados_agregados_saber pro 2018(pro 2018).csv' AS `NOMBRE_TABLA` from `resultados_agregados_saber pro 2018(pro 2018).csv` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,`resultados_agregados_saber_pro 2017`.`ID_INSTITUCION` AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,`resultados_agregados_saber_pro 2017`.`NOMBRE_PRUEBA` AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,`resultados_agregados_saber_pro 2017`.`NOMBRE_INSTITUCION` AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,`resultados_agregados_saber_pro 2017`.`EXAMEN` AS `EXAMEN`,`resultados_agregados_saber_pro 2017`.`AGREGACION` AS `AGREGACION`,`resultados_agregados_saber_pro 2017`.`MEDIDA_AGREGACION` AS `MEDIDA_AGREGACION`,`resultados_agregados_saber_pro 2017`.`ID_PAIS` AS `ID_PAIS`,`resultados_agregados_saber_pro 2017`.`NOMBRE_REGION` AS `NOMBRE_REGION`,`resultados_agregados_saber_pro 2017`.`NOMBRE_DEPARTAMENTO` AS `NOMBRE_DEPARTAMENTO`,`resultados_agregados_saber_pro 2017`.`NOMBRE_MUNICIPIO` AS `NOMBRE_MUNICIPIO`,`resultados_agregados_saber_pro 2017`.`ID_SEDE` AS `ID_SEDE`,`resultados_agregados_saber_pro 2017`.`NOMBRE_SEDE` AS `NOMBRE_SEDE`,`resultados_agregados_saber_pro 2017`.`NOMBRE_GRUPOREF` AS `NOMBRE_GRUPOREF`,`resultados_agregados_saber_pro 2017`.`NOMBRE_PROGRAMA_ACAD` AS `NOMBRE_PROGRAMA_ACAD`,`resultados_agregados_saber_pro 2017`.`PROMEDIO_GLOBAL` AS `PROMEDIO_GLOBAL`,`resultados_agregados_saber_pro 2017`.`PROMEDIO_PRUEBA` AS `PROMEDIO_PRUEBA`,`resultados_agregados_saber_pro 2017`.`DESVIACION` AS `DESVIACION`,`resultados_agregados_saber_pro 2017`.`PROMEDIO_PERCENTIL` AS `PROMEDIO_PERCENTIL`,`resultados_agregados_saber_pro 2017`.`NIVEL1` AS `NIVEL1`,`resultados_agregados_saber_pro 2017`.`NIVEL2` AS `NIVEL2`,`resultados_agregados_saber_pro 2017`.`NIVEL3` AS `NIVEL3`,`resultados_agregados_saber_pro 2017`.`NIVEL4` AS `NIVEL4`,`resultados_agregados_saber_pro 2017`.`NIVEL5` AS `NIVEL5`,`resultados_agregados_saber_pro 2017`.`PORCENTAJERTAINCORRECTA` AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,`resultados_agregados_saber_pro 2017`.`ID_REGION` AS `ID_REGION`,`resultados_agregados_saber_pro 2017`.`ID_DEPARTAMENTO` AS `ID_DEPARTAMENTO`,`resultados_agregados_saber_pro 2017`.`ID_MUNICIPIO` AS `ID_MUNICIPIO`,`resultados_agregados_saber_pro 2017`.`ID_GRUPOREFERENCIA` AS `ID_GRUPOREFERENCIA`,`resultados_agregados_saber_pro 2017`.`ID_PROGRAMA_ACAD` AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resultados_agregados_saber_pro 2017' AS `NOMBRE_TABLA` from `resultados_agregados_saber_pro 2017` union all select `resultados_agregados_saber_pro 2018 prueb especi prog`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resultados_agregados_saber_pro 2018 prueb especi prog`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resultados_agregados_saber_pro 2018 prueb especi prog`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resultados_agregados_saber_pro 2018 prueb especi prog`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resultados_agregados_saber_pro 2018 prueb especi prog`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resultados_agregados_saber_pro 2018 prueb especi prog`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`resultados_agregados_saber_pro 2018 prueb especi prog`.`ORIGEN` AS `ORIGEN`,`resultados_agregados_saber_pro 2018 prueb especi prog`.`CARACTER` AS `CARACTER`,`resultados_agregados_saber_pro 2018 prueb especi prog`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`resultados_agregados_saber_pro 2018 prueb especi prog`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`resultados_agregados_saber_pro 2018 prueb especi prog`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`resultados_agregados_saber_pro 2018 prueb especi prog`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,`resultados_agregados_saber_pro 2018 prueb especi prog`.`MUNICIPIO_PROGRAMAACADEMICO` AS `MUNICIPIO_PROGRAMAACADEMICO`,`resultados_agregados_saber_pro 2018 prueb especi prog`.`DEPARTAMENTO_PROGRAMAACADEMICO` AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,`resultados_agregados_saber_pro 2018 prueb especi prog`.`SNIES` AS `SNIES`,`resultados_agregados_saber_pro 2018 prueb especi prog`.`PROGRAMA_ACADEMICO` AS `PROGRAMA_ACADEMICO`,`resultados_agregados_saber_pro 2018 prueb especi prog`.`TOTAL_EVALGRUPO_INSTPROGRAMA` AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resultados_agregados_saber_pro 2018 prueb especi prog' AS `NOMBRE_TABLA` from `resultados_agregados_saber_pro 2018 prueb especi prog` union all select `resultados_agregados_saber_pro 2018 prueb especif grup refer`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resultados_agregados_saber_pro 2018 prueb especif grup refer`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resultados_agregados_saber_pro 2018 prueb especif grup refer`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resultados_agregados_saber_pro 2018 prueb especif grup refer`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resultados_agregados_saber_pro 2018 prueb especif grup refer`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resultados_agregados_saber_pro 2018 prueb especif grup refer`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,`resultados_agregados_saber_pro 2018 prueb especif grup refer`.`TOTAL_EVAGRUPOREF_PRUEBA` AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resultados_agregados_saber_pro 2018 prueb especif grup refer' AS `NOMBRE_TABLA` from `resultados_agregados_saber_pro 2018 prueb especif grup refer` union all select `resultados_agregados_saber_pro 2018 prueb especif instit`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resultados_agregados_saber_pro 2018 prueb especif instit`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resultados_agregados_saber_pro 2018 prueb especif instit`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resultados_agregados_saber_pro 2018 prueb especif instit`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resultados_agregados_saber_pro 2018 prueb especif instit`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resultados_agregados_saber_pro 2018 prueb especif instit`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`resultados_agregados_saber_pro 2018 prueb especif instit`.`ORIGEN` AS `ORIGEN`,`resultados_agregados_saber_pro 2018 prueb especif instit`.`CARACTER` AS `CARACTER`,`resultados_agregados_saber_pro 2018 prueb especif instit`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`resultados_agregados_saber_pro 2018 prueb especif instit`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`resultados_agregados_saber_pro 2018 prueb especif instit`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`resultados_agregados_saber_pro 2018 prueb especif instit`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,`resultados_agregados_saber_pro 2018 prueb especif instit`.`TOTAL_EVALINSTITUCION_GRUPREF` AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resultados_agregados_saber_pro 2018 prueb especif instit' AS `NOMBRE_TABLA` from `resultados_agregados_saber_pro 2018 prueb especif instit` union all select `resultados_agregados_saber_pro 2018 prueb gener grup refe`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resultados_agregados_saber_pro 2018 prueb gener grup refe`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resultados_agregados_saber_pro 2018 prueb gener grup refe`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resultados_agregados_saber_pro 2018 prueb gener grup refe`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resultados_agregados_saber_pro 2018 prueb gener grup refe`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resultados_agregados_saber_pro 2018 prueb gener grup refe`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,`resultados_agregados_saber_pro 2018 prueb gener grup refe`.`TOTAL_EVAGRUPOREF_PRUEBA` AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resultados_agregados_saber_pro 2018 prueb gener grup refe' AS `NOMBRE_TABLA` from `resultados_agregados_saber_pro 2018 prueb gener grup refe` union all select `resultados_agregados_saber_pro 2018 prueb gener insti`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resultados_agregados_saber_pro 2018 prueb gener insti`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resultados_agregados_saber_pro 2018 prueb gener insti`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resultados_agregados_saber_pro 2018 prueb gener insti`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resultados_agregados_saber_pro 2018 prueb gener insti`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resultados_agregados_saber_pro 2018 prueb gener insti`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`resultados_agregados_saber_pro 2018 prueb gener insti`.`ORIGEN` AS `ORIGEN`,`resultados_agregados_saber_pro 2018 prueb gener insti`.`CARACTER` AS `CARACTER`,`resultados_agregados_saber_pro 2018 prueb gener insti`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`resultados_agregados_saber_pro 2018 prueb gener insti`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`resultados_agregados_saber_pro 2018 prueb gener insti`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`resultados_agregados_saber_pro 2018 prueb gener insti`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,`resultados_agregados_saber_pro 2018 prueb gener insti`.`TOTAL_EVALINSTITUCION_GRUPREF` AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resultados_agregados_saber_pro 2018 prueb gener insti' AS `NOMBRE_TABLA` from `resultados_agregados_saber_pro 2018 prueb gener insti` union all select `resultados_agregados_saber_pro 2018 prueb gener prog`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resultados_agregados_saber_pro 2018 prueb gener prog`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resultados_agregados_saber_pro 2018 prueb gener prog`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resultados_agregados_saber_pro 2018 prueb gener prog`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resultados_agregados_saber_pro 2018 prueb gener prog`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resultados_agregados_saber_pro 2018 prueb gener prog`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`resultados_agregados_saber_pro 2018 prueb gener prog`.`ORIGEN` AS `ORIGEN`,`resultados_agregados_saber_pro 2018 prueb gener prog`.`CARACTER` AS `CARACTER`,`resultados_agregados_saber_pro 2018 prueb gener prog`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`resultados_agregados_saber_pro 2018 prueb gener prog`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`resultados_agregados_saber_pro 2018 prueb gener prog`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`resultados_agregados_saber_pro 2018 prueb gener prog`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,`resultados_agregados_saber_pro 2018 prueb gener prog`.`MUNICIPIO_PROGRAMAACADEMICO` AS `MUNICIPIO_PROGRAMAACADEMICO`,`resultados_agregados_saber_pro 2018 prueb gener prog`.`DEPARTAMENTO_PROGRAMAACADEMICO` AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,`resultados_agregados_saber_pro 2018 prueb gener prog`.`SNIES` AS `SNIES`,`resultados_agregados_saber_pro 2018 prueb gener prog`.`PROGRAMA_ACADEMICO` AS `PROGRAMA_ACADEMICO`,`resultados_agregados_saber_pro 2018 prueb gener prog`.`TOTAL_EVALGRUPO_INSTPROGRAMA` AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resultados_agregados_saber_pro 2018 prueb gener prog' AS `NOMBRE_TABLA` from `resultados_agregados_saber_pro 2018 prueb gener prog` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,`resul_agreg_saber_tyt_2017`.`ID_INSTITUCION` AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,`resul_agreg_saber_tyt_2017`.`NOMBRE_PRUEBA` AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,`resul_agreg_saber_tyt_2017`.`NOMBRE_INSTITUCION` AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,`resul_agreg_saber_tyt_2017`.`EXAMEN` AS `EXAMEN`,`resul_agreg_saber_tyt_2017`.`AGREGACION` AS `AGREGACION`,`resul_agreg_saber_tyt_2017`.`MEDIDA_AGREGACION` AS `MEDIDA_AGREGACION`,`resul_agreg_saber_tyt_2017`.`ID_PAIS` AS `ID_PAIS`,`resul_agreg_saber_tyt_2017`.`NOMBRE_REGION` AS `NOMBRE_REGION`,`resul_agreg_saber_tyt_2017`.`NOMBRE_DEPARTAMENTO` AS `NOMBRE_DEPARTAMENTO`,`resul_agreg_saber_tyt_2017`.`NOMBRE_MUNICIPIO` AS `NOMBRE_MUNICIPIO`,`resul_agreg_saber_tyt_2017`.`ID_SEDE` AS `ID_SEDE`,`resul_agreg_saber_tyt_2017`.`NOMBRE_SEDE` AS `NOMBRE_SEDE`,`resul_agreg_saber_tyt_2017`.`NOMBRE_GRUPOREF` AS `NOMBRE_GRUPOREF`,`resul_agreg_saber_tyt_2017`.`NOMBRE_PROGRAMA_ACAD` AS `NOMBRE_PROGRAMA_ACAD`,`resul_agreg_saber_tyt_2017`.`PROMEDIO_GLOBAL` AS `PROMEDIO_GLOBAL`,`resul_agreg_saber_tyt_2017`.`PROMEDIO_PRUEBA` AS `PROMEDIO_PRUEBA`,`resul_agreg_saber_tyt_2017`.`DESVIACION` AS `DESVIACION`,`resul_agreg_saber_tyt_2017`.`PROMEDIO_PERCENTIL` AS `PROMEDIO_PERCENTIL`,`resul_agreg_saber_tyt_2017`.`NIVEL1` AS `NIVEL1`,`resul_agreg_saber_tyt_2017`.`NIVEL2` AS `NIVEL2`,`resul_agreg_saber_tyt_2017`.`NIVEL3` AS `NIVEL3`,`resul_agreg_saber_tyt_2017`.`NIVEL4` AS `NIVEL4`,`resul_agreg_saber_tyt_2017`.`NIVEL5` AS `NIVEL5`,`resul_agreg_saber_tyt_2017`.`PORCENTAJERTAINCORRECTA` AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,`resul_agreg_saber_tyt_2017`.`ID_REGION` AS `ID_REGION`,`resul_agreg_saber_tyt_2017`.`ID_DEPARTAMENTO` AS `ID_DEPARTAMENTO`,`resul_agreg_saber_tyt_2017`.`ID_MUNICIPIO` AS `ID_MUNICIPIO`,`resul_agreg_saber_tyt_2017`.`ID_GRUPOREFERENCIA` AS `ID_GRUPOREFERENCIA`,`resul_agreg_saber_tyt_2017`.`ID_PROGRAMA_ACAD` AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_saber_tyt_2017' AS `NOMBRE_TABLA` from `resul_agreg_saber_tyt_2017` union all select `resul_agreg_sab_pro_mod_especif 2016 insti`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_pro_mod_especif 2016 insti`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_pro_mod_especif 2016 insti`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_pro_mod_especif 2016 insti`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_pro_mod_especif 2016 insti`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_pro_mod_especif 2016 insti`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`resul_agreg_sab_pro_mod_especif 2016 insti`.`ORIGEN` AS `ORIGEN`,`resul_agreg_sab_pro_mod_especif 2016 insti`.`CARACTER` AS `CARACTER`,`resul_agreg_sab_pro_mod_especif 2016 insti`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`resul_agreg_sab_pro_mod_especif 2016 insti`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`resul_agreg_sab_pro_mod_especif 2016 insti`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`resul_agreg_sab_pro_mod_especif 2016 insti`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,`resul_agreg_sab_pro_mod_especif 2016 insti`.`TOTAL_EVALINSTITUCION_GRUPREF` AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_pro_mod_especif 2016 insti' AS `NOMBRE_TABLA` from `resul_agreg_sab_pro_mod_especif 2016 insti` union all select `resul_agreg_sab_pro_mod_especif 2016 mod grup ref`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_pro_mod_especif 2016 mod grup ref`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_pro_mod_especif 2016 mod grup ref`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_pro_mod_especif 2016 mod grup ref`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_pro_mod_especif 2016 mod grup ref`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_pro_mod_especif 2016 mod grup ref`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,`resul_agreg_sab_pro_mod_especif 2016 mod grup ref`.`TOTAL_EVAGRUPOREF_PRUEBA` AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_pro_mod_especif 2016 mod grup ref' AS `NOMBRE_TABLA` from `resul_agreg_sab_pro_mod_especif 2016 mod grup ref` union all select `resul_agreg_sab_pro_mod_especif 2016 prog`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_pro_mod_especif 2016 prog`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_pro_mod_especif 2016 prog`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_pro_mod_especif 2016 prog`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_pro_mod_especif 2016 prog`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_pro_mod_especif 2016 prog`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`resul_agreg_sab_pro_mod_especif 2016 prog`.`ORIGEN` AS `ORIGEN`,`resul_agreg_sab_pro_mod_especif 2016 prog`.`CARACTER` AS `CARACTER`,`resul_agreg_sab_pro_mod_especif 2016 prog`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`resul_agreg_sab_pro_mod_especif 2016 prog`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`resul_agreg_sab_pro_mod_especif 2016 prog`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`resul_agreg_sab_pro_mod_especif 2016 prog`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,`resul_agreg_sab_pro_mod_especif 2016 prog`.`MUNICIPIO_PROGRAMAACADEMICO` AS `MUNICIPIO_PROGRAMAACADEMICO`,`resul_agreg_sab_pro_mod_especif 2016 prog`.`DEPARTAMENTO_PROGRAMAACADEMICO` AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,`resul_agreg_sab_pro_mod_especif 2016 prog`.`SNIES` AS `SNIES`,`resul_agreg_sab_pro_mod_especif 2016 prog`.`PROGRAMA_ACADEMICO` AS `PROGRAMA_ACADEMICO`,`resul_agreg_sab_pro_mod_especif 2016 prog`.`TOTAL_EVALGRUPO_INSTPROGRAMA` AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_pro_mod_especif 2016 prog' AS `NOMBRE_TABLA` from `resul_agreg_sab_pro_mod_especif 2016 prog` union all select `resul_agreg_sab_pro_mod_gener 2016 insti`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_pro_mod_gener 2016 insti`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_pro_mod_gener 2016 insti`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_pro_mod_gener 2016 insti`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_pro_mod_gener 2016 insti`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_pro_mod_gener 2016 insti`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`resul_agreg_sab_pro_mod_gener 2016 insti`.`ORIGEN` AS `ORIGEN`,`resul_agreg_sab_pro_mod_gener 2016 insti`.`CARACTER` AS `CARACTER`,`resul_agreg_sab_pro_mod_gener 2016 insti`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`resul_agreg_sab_pro_mod_gener 2016 insti`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`resul_agreg_sab_pro_mod_gener 2016 insti`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`resul_agreg_sab_pro_mod_gener 2016 insti`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,`resul_agreg_sab_pro_mod_gener 2016 insti`.`TOTAL_EVALINSTITUCION_GRUPREF` AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_pro_mod_gener 2016 insti' AS `NOMBRE_TABLA` from `resul_agreg_sab_pro_mod_gener 2016 insti` union all select `resul_agreg_sab_pro_mod_gener 2016 mod grup ref`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_pro_mod_gener 2016 mod grup ref`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_pro_mod_gener 2016 mod grup ref`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_pro_mod_gener 2016 mod grup ref`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_pro_mod_gener 2016 mod grup ref`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_pro_mod_gener 2016 mod grup ref`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,`resul_agreg_sab_pro_mod_gener 2016 mod grup ref`.`TOTAL_EVAGRUPOREF_PRUEBA` AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_pro_mod_gener 2016 mod grup ref' AS `NOMBRE_TABLA` from `resul_agreg_sab_pro_mod_gener 2016 mod grup ref` union all select `resul_agreg_sab_pro_mod_gener 2016 prog`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_pro_mod_gener 2016 prog`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_pro_mod_gener 2016 prog`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_pro_mod_gener 2016 prog`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_pro_mod_gener 2016 prog`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_pro_mod_gener 2016 prog`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`resul_agreg_sab_pro_mod_gener 2016 prog`.`ORIGEN` AS `ORIGEN`,`resul_agreg_sab_pro_mod_gener 2016 prog`.`CARACTER` AS `CARACTER`,`resul_agreg_sab_pro_mod_gener 2016 prog`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`resul_agreg_sab_pro_mod_gener 2016 prog`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`resul_agreg_sab_pro_mod_gener 2016 prog`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`resul_agreg_sab_pro_mod_gener 2016 prog`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,`resul_agreg_sab_pro_mod_gener 2016 prog`.`MUNICIPIO_PROGRAMAACADEMICO` AS `MUNICIPIO_PROGRAMAACADEMICO`,`resul_agreg_sab_pro_mod_gener 2016 prog`.`DEPARTAMENTO_PROGRAMAACADEMICO` AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,`resul_agreg_sab_pro_mod_gener 2016 prog`.`SNIES` AS `SNIES`,`resul_agreg_sab_pro_mod_gener 2016 prog`.`PROGRAMA_ACADEMICO` AS `PROGRAMA_ACADEMICO`,`resul_agreg_sab_pro_mod_gener 2016 prog`.`TOTAL_EVALGRUPO_INSTPROGRAMA` AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_pro_mod_gener 2016 prog' AS `NOMBRE_TABLA` from `resul_agreg_sab_pro_mod_gener 2016 prog` union all select `resul_agreg_sab_tyt_2016_especifi_mod_grup_ref`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_tyt_2016_especifi_mod_grup_ref`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_tyt_2016_especifi_mod_grup_ref`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2016_especifi_mod_grup_ref`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2016_especifi_mod_grup_ref`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2016_especifi_mod_grup_ref`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,`resul_agreg_sab_tyt_2016_especifi_mod_grup_ref`.`TOTAL_EVAGRUPOREF_PRUEBA` AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_tyt_2016_especifi_mod_grup_ref' AS `NOMBRE_TABLA` from `resul_agreg_sab_tyt_2016_especifi_mod_grup_ref` union all select `resul_agreg_sab_tyt_2016_mod_especifi_insti`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_tyt_2016_mod_especifi_insti`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_tyt_2016_mod_especifi_insti`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2016_mod_especifi_insti`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2016_mod_especifi_insti`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2016_mod_especifi_insti`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2016_mod_especifi_insti`.`ORIGEN` AS `ORIGEN`,`resul_agreg_sab_tyt_2016_mod_especifi_insti`.`CARACTER` AS `CARACTER`,`resul_agreg_sab_tyt_2016_mod_especifi_insti`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`resul_agreg_sab_tyt_2016_mod_especifi_insti`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`resul_agreg_sab_tyt_2016_mod_especifi_insti`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`resul_agreg_sab_tyt_2016_mod_especifi_insti`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,`resul_agreg_sab_tyt_2016_mod_especifi_insti`.`TOTAL_EVALINSTITUCION_GRUPREF` AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_tyt_2016_mod_especifi_insti' AS `NOMBRE_TABLA` from `resul_agreg_sab_tyt_2016_mod_especifi_insti` union all select `resul_agreg_sab_tyt_2016_mod_especifi_prog`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_tyt_2016_mod_especifi_prog`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_tyt_2016_mod_especifi_prog`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2016_mod_especifi_prog`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2016_mod_especifi_prog`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2016_mod_especifi_prog`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2016_mod_especifi_prog`.`ORIGEN` AS `ORIGEN`,`resul_agreg_sab_tyt_2016_mod_especifi_prog`.`CARACTER` AS `CARACTER`,`resul_agreg_sab_tyt_2016_mod_especifi_prog`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`resul_agreg_sab_tyt_2016_mod_especifi_prog`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`resul_agreg_sab_tyt_2016_mod_especifi_prog`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`resul_agreg_sab_tyt_2016_mod_especifi_prog`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,`resul_agreg_sab_tyt_2016_mod_especifi_prog`.`MUNICIPIO_PROGRAMAACADEMICO` AS `MUNICIPIO_PROGRAMAACADEMICO`,`resul_agreg_sab_tyt_2016_mod_especifi_prog`.`DEPARTAMENTO_PROGRAMAACADEMICO` AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,`resul_agreg_sab_tyt_2016_mod_especifi_prog`.`SNIES` AS `SNIES`,`resul_agreg_sab_tyt_2016_mod_especifi_prog`.`PROGRAMA_ACADEMICO` AS `PROGRAMA_ACADEMICO`,`resul_agreg_sab_tyt_2016_mod_especifi_prog`.`TOTAL_EVALGRUPO_INSTPROGRAMA` AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_tyt_2016_mod_especifi_prog' AS `NOMBRE_TABLA` from `resul_agreg_sab_tyt_2016_mod_especifi_prog` union all select `resul_agreg_sab_tyt_2016_mod_gener_grup_ref`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_tyt_2016_mod_gener_grup_ref`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_tyt_2016_mod_gener_grup_ref`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2016_mod_gener_grup_ref`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2016_mod_gener_grup_ref`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2016_mod_gener_grup_ref`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,`resul_agreg_sab_tyt_2016_mod_gener_grup_ref`.`TOTAL_EVAGRUPOREF_PRUEBA` AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_tyt_2016_mod_gener_grup_ref' AS `NOMBRE_TABLA` from `resul_agreg_sab_tyt_2016_mod_gener_grup_ref` union all select `resul_agreg_sab_tyt_2016_mod_gener_insti`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_tyt_2016_mod_gener_insti`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_tyt_2016_mod_gener_insti`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2016_mod_gener_insti`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2016_mod_gener_insti`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2016_mod_gener_insti`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2016_mod_gener_insti`.`ORIGEN` AS `ORIGEN`,`resul_agreg_sab_tyt_2016_mod_gener_insti`.`CARACTER` AS `CARACTER`,`resul_agreg_sab_tyt_2016_mod_gener_insti`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`resul_agreg_sab_tyt_2016_mod_gener_insti`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`resul_agreg_sab_tyt_2016_mod_gener_insti`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`resul_agreg_sab_tyt_2016_mod_gener_insti`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,`resul_agreg_sab_tyt_2016_mod_gener_insti`.`TOTAL_EVALINSTITUCION_GRUPREF` AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_tyt_2016_mod_gener_insti' AS `NOMBRE_TABLA` from `resul_agreg_sab_tyt_2016_mod_gener_insti` union all select `resul_agreg_sab_tyt_2016_mod_gener_prog`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_tyt_2016_mod_gener_prog`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_tyt_2016_mod_gener_prog`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2016_mod_gener_prog`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2016_mod_gener_prog`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2016_mod_gener_prog`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2016_mod_gener_prog`.`ORIGEN` AS `ORIGEN`,`resul_agreg_sab_tyt_2016_mod_gener_prog`.`CARACTER` AS `CARACTER`,`resul_agreg_sab_tyt_2016_mod_gener_prog`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`resul_agreg_sab_tyt_2016_mod_gener_prog`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`resul_agreg_sab_tyt_2016_mod_gener_prog`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`resul_agreg_sab_tyt_2016_mod_gener_prog`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,`resul_agreg_sab_tyt_2016_mod_gener_prog`.`MUNICIPIO_PROGRAMAACADEMICO` AS `MUNICIPIO_PROGRAMAACADEMICO`,`resul_agreg_sab_tyt_2016_mod_gener_prog`.`DEPARTAMENTO_PROGRAMAACADEMICO` AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,`resul_agreg_sab_tyt_2016_mod_gener_prog`.`SNIES` AS `SNIES`,`resul_agreg_sab_tyt_2016_mod_gener_prog`.`PROGRAMA_ACADEMICO` AS `PROGRAMA_ACADEMICO`,`resul_agreg_sab_tyt_2016_mod_gener_prog`.`TOTAL_EVALGRUPO_INSTPROGRAMA` AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_tyt_2016_mod_gener_prog' AS `NOMBRE_TABLA` from `resul_agreg_sab_tyt_2016_mod_gener_prog` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,`resul_agreg_sab_tyt_2018`.`ID_INSTITUCION` AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,`resul_agreg_sab_tyt_2018`.`NOMBRE_PRUEBA` AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,`resul_agreg_sab_tyt_2018`.`NOMBRE_INSTITUCION` AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,`resul_agreg_sab_tyt_2018`.`EXAMEN` AS `EXAMEN`,`resul_agreg_sab_tyt_2018`.`AGREGACION` AS `AGREGACION`,`resul_agreg_sab_tyt_2018`.`MEDIDA_AGREGACION` AS `MEDIDA_AGREGACION`,`resul_agreg_sab_tyt_2018`.`ID_PAIS` AS `ID_PAIS`,`resul_agreg_sab_tyt_2018`.`NOMBRE_REGION` AS `NOMBRE_REGION`,`resul_agreg_sab_tyt_2018`.`NOMBRE_DEPARTAMENTO` AS `NOMBRE_DEPARTAMENTO`,`resul_agreg_sab_tyt_2018`.`NOMBRE_MUNICIPIO` AS `NOMBRE_MUNICIPIO`,`resul_agreg_sab_tyt_2018`.`ID_SEDE` AS `ID_SEDE`,`resul_agreg_sab_tyt_2018`.`NOMBRE_SEDE` AS `NOMBRE_SEDE`,`resul_agreg_sab_tyt_2018`.`NOMBRE_GRUPOREF` AS `NOMBRE_GRUPOREF`,`resul_agreg_sab_tyt_2018`.`NOMBRE_PROGRAMA_ACAD` AS `NOMBRE_PROGRAMA_ACAD`,`resul_agreg_sab_tyt_2018`.`PROMEDIO_GLOBAL` AS `PROMEDIO_GLOBAL`,`resul_agreg_sab_tyt_2018`.`PROMEDIO_PRUEBA` AS `PROMEDIO_PRUEBA`,`resul_agreg_sab_tyt_2018`.`DESVIACION` AS `DESVIACION`,`resul_agreg_sab_tyt_2018`.`PROMEDIO_PERCENTIL` AS `PROMEDIO_PERCENTIL`,`resul_agreg_sab_tyt_2018`.`NIVEL1` AS `NIVEL1`,`resul_agreg_sab_tyt_2018`.`NIVEL2` AS `NIVEL2`,`resul_agreg_sab_tyt_2018`.`NIVEL3` AS `NIVEL3`,`resul_agreg_sab_tyt_2018`.`NIVEL4` AS `NIVEL4`,`resul_agreg_sab_tyt_2018`.`NIVEL5` AS `NIVEL5`,`resul_agreg_sab_tyt_2018`.`PORCENTAJERTAINCORRECTA` AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,`resul_agreg_sab_tyt_2018`.`CANTIDADEVALUADOS` AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,`resul_agreg_sab_tyt_2018`.`AFIRMACION` AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,`resul_agreg_sab_tyt_2018`.`NOMBRE_NBC` AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_tyt_2018' AS `NOMBRE_TABLA` from `resul_agreg_sab_tyt_2018` union all select `resul_agreg_sab_tyt_2018_especifi_mod_inst`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_tyt_2018_especifi_mod_inst`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_tyt_2018_especifi_mod_inst`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2018_especifi_mod_inst`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2018_especifi_mod_inst`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2018_especifi_mod_inst`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2018_especifi_mod_inst`.`ORIGEN` AS `ORIGEN`,`resul_agreg_sab_tyt_2018_especifi_mod_inst`.`CARACTER` AS `CARACTER`,`resul_agreg_sab_tyt_2018_especifi_mod_inst`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`resul_agreg_sab_tyt_2018_especifi_mod_inst`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`resul_agreg_sab_tyt_2018_especifi_mod_inst`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`resul_agreg_sab_tyt_2018_especifi_mod_inst`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,`resul_agreg_sab_tyt_2018_especifi_mod_inst`.`TOTAL_EVALINSTITUCION_GRUPREF` AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_tyt_2018_especifi_mod_inst' AS `NOMBRE_TABLA` from `resul_agreg_sab_tyt_2018_especifi_mod_inst` union all select `resul_agreg_sab_tyt_2018_especifi_mod_prog`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_tyt_2018_especifi_mod_prog`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_tyt_2018_especifi_mod_prog`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2018_especifi_mod_prog`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2018_especifi_mod_prog`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2018_especifi_mod_prog`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2018_especifi_mod_prog`.`ORIGEN` AS `ORIGEN`,`resul_agreg_sab_tyt_2018_especifi_mod_prog`.`CARACTER` AS `CARACTER`,`resul_agreg_sab_tyt_2018_especifi_mod_prog`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`resul_agreg_sab_tyt_2018_especifi_mod_prog`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`resul_agreg_sab_tyt_2018_especifi_mod_prog`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`resul_agreg_sab_tyt_2018_especifi_mod_prog`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,`resul_agreg_sab_tyt_2018_especifi_mod_prog`.`MUNICIPIO_PROGRAMAACADEMICO` AS `MUNICIPIO_PROGRAMAACADEMICO`,`resul_agreg_sab_tyt_2018_especifi_mod_prog`.`DEPARTAMENTO_PROGRAMAACADEMICO` AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,`resul_agreg_sab_tyt_2018_especifi_mod_prog`.`SNIES` AS `SNIES`,`resul_agreg_sab_tyt_2018_especifi_mod_prog`.`PROGRAMA_ACADEMICO` AS `PROGRAMA_ACADEMICO`,`resul_agreg_sab_tyt_2018_especifi_mod_prog`.`TOTAL_EVALGRUPO_INSTPROGRAMA` AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_tyt_2018_especifi_mod_prog' AS `NOMBRE_TABLA` from `resul_agreg_sab_tyt_2018_especifi_mod_prog` union all select `resul_agreg_sab_tyt_2018_especif_mod_grup_ref`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_tyt_2018_especif_mod_grup_ref`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_tyt_2018_especif_mod_grup_ref`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2018_especif_mod_grup_ref`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2018_especif_mod_grup_ref`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2018_especif_mod_grup_ref`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,`resul_agreg_sab_tyt_2018_especif_mod_grup_ref`.`TOTAL_EVAGRUPOREF_PRUEBA` AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_tyt_2018_especif_mod_grup_ref' AS `NOMBRE_TABLA` from `resul_agreg_sab_tyt_2018_especif_mod_grup_ref` union all select `resul_agreg_sab_tyt_2018_generi_mod_grup_ref`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_tyt_2018_generi_mod_grup_ref`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_tyt_2018_generi_mod_grup_ref`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2018_generi_mod_grup_ref`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2018_generi_mod_grup_ref`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2018_generi_mod_grup_ref`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,`resul_agreg_sab_tyt_2018_generi_mod_grup_ref`.`TOTAL_EVAGRUPOREF_PRUEBA` AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_tyt_2018_generi_mod_grup_ref' AS `NOMBRE_TABLA` from `resul_agreg_sab_tyt_2018_generi_mod_grup_ref` union all select `resul_agreg_sab_tyt_2018_generi_mod_insti`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_tyt_2018_generi_mod_insti`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_tyt_2018_generi_mod_insti`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2018_generi_mod_insti`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2018_generi_mod_insti`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2018_generi_mod_insti`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2018_generi_mod_insti`.`ORIGEN` AS `ORIGEN`,`resul_agreg_sab_tyt_2018_generi_mod_insti`.`CARACTER` AS `CARACTER`,`resul_agreg_sab_tyt_2018_generi_mod_insti`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`resul_agreg_sab_tyt_2018_generi_mod_insti`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`resul_agreg_sab_tyt_2018_generi_mod_insti`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`resul_agreg_sab_tyt_2018_generi_mod_insti`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,`resul_agreg_sab_tyt_2018_generi_mod_insti`.`TOTAL_EVALINSTITUCION_GRUPREF` AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_tyt_2018_generi_mod_insti' AS `NOMBRE_TABLA` from `resul_agreg_sab_tyt_2018_generi_mod_insti` union all select `resul_agreg_sab_tyt_2018_generi_mod_prog`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA`,`resul_agreg_sab_tyt_2018_generi_mod_prog`.`NOMBRE_MODULO` AS `NOMBRE_MODULO`,`resul_agreg_sab_tyt_2018_generi_mod_prog`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2018_generi_mod_prog`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`resul_agreg_sab_tyt_2018_generi_mod_prog`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2018_generi_mod_prog`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,`resul_agreg_sab_tyt_2018_generi_mod_prog`.`ORIGEN` AS `ORIGEN`,`resul_agreg_sab_tyt_2018_generi_mod_prog`.`CARACTER` AS `CARACTER`,`resul_agreg_sab_tyt_2018_generi_mod_prog`.`ID_INSTITUCION` AS `ID_INSTITUCION`,`resul_agreg_sab_tyt_2018_generi_mod_prog`.`MUNICIPIO_INSTITUCION` AS `MUNICIPIO_INSTITUCION`,`resul_agreg_sab_tyt_2018_generi_mod_prog`.`DEPARTAMENTO_INSTITUCION` AS `DEPARTAMENTO_INSTITUCION`,`resul_agreg_sab_tyt_2018_generi_mod_prog`.`INSTITUCION` AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,`resul_agreg_sab_tyt_2018_generi_mod_prog`.`MUNICIPIO_PROGRAMAACADEMICO` AS `MUNICIPIO_PROGRAMAACADEMICO`,`resul_agreg_sab_tyt_2018_generi_mod_prog`.`DEPARTAMENTO_PROGRAMAACADEMICO` AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,`resul_agreg_sab_tyt_2018_generi_mod_prog`.`SNIES` AS `SNIES`,`resul_agreg_sab_tyt_2018_generi_mod_prog`.`PROGRAMA_ACADEMICO` AS `PROGRAMA_ACADEMICO`,`resul_agreg_sab_tyt_2018_generi_mod_prog`.`TOTAL_EVALGRUPO_INSTPROGRAMA` AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,NULL AS `PROGRAMA ACADÉMICO:`,NULL AS `MUNICIPIO:`,NULL AS `GRUPO REFERENCIA:`,NULL AS `INSTITUCIÓN:`,NULL AS `MÓDULO`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'resul_agreg_sab_tyt_2018_generi_mod_prog' AS `NOMBRE_TABLA` from `resul_agreg_sab_tyt_2018_generi_mod_prog` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,`sabana_especif_ing_telema 2015 3`.`PROGRAMA ACADÉMICO:` AS `PROGRAMA ACADÉMICO:`,`sabana_especif_ing_telema 2015 3`.`MUNICIPIO:` AS `MUNICIPIO:`,`sabana_especif_ing_telema 2015 3`.`GRUPO REFERENCIA:` AS `GRUPO REFERENCIA:`,`sabana_especif_ing_telema 2015 3`.`INSTITUCIÓN:` AS `INSTITUCIÓN:`,`sabana_especif_ing_telema 2015 3`.`MÓDULO` AS `MÓDULO`,`sabana_especif_ing_telema 2015 3`.`Column6` AS `Column6`,`sabana_especif_ing_telema 2015 3`.`Column7` AS `Column7`,`sabana_especif_ing_telema 2015 3`.`Column8` AS `Column8`,`sabana_especif_ing_telema 2015 3`.`Column9` AS `Column9`,`sabana_especif_ing_telema 2015 3`.`Column10` AS `Column10`,`sabana_especif_ing_telema 2015 3`.`EVALUADO` AS `EVALUADO`,`sabana_especif_ing_telema 2015 3`.`Column12` AS `Column12`,`sabana_especif_ing_telema 2015 3`.`Column13` AS `Column13`,`sabana_especif_ing_telema 2015 3`.`Column14` AS `Column14`,`sabana_especif_ing_telema 2015 3`.`Column15` AS `Column15`,`sabana_especif_ing_telema 2015 3`.`Column16` AS `Column16`,`sabana_especif_ing_telema 2015 3`.`NÚMERO REGISTRO` AS `NÚMERO REGISTRO`,`sabana_especif_ing_telema 2015 3`.`Puntaje` AS `Puntaje`,`sabana_especif_ing_telema 2015 3`.`Nivel` AS `Nivel`,`sabana_especif_ing_telema 2015 3`.`Quintil` AS `Quintil`,`sabana_especif_ing_telema 2015 3`.`Column21` AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'sabana_especif_ing_telema 2015 3' AS `NOMBRE_TABLA` from `sabana_especif_ing_telema 2015 3` union all select NULL AS `GRUPO_REFERENCIA`,NULL AS `NOMBRE_MODULO`,NULL AS `PROMEDIO_PUNTAJEGLOBAL`,NULL AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,NULL AS `PROMEDIO_PUNTAJEPRUEBA`,NULL AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `ID_INSTITUCION`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `INSTITUCION`,NULL AS `NOMBRE_PRUEBA`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `NOMBRE_INSTITUCION`,NULL AS `NOMBRE_GRUPO_REFERENCIA`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `TOTAL_EVAGRUPOREF_PRUEBA`,NULL AS `SNIES`,NULL AS `PROGRAMA_ACADEMICO`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `CODIGO_INSTITUCION`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `ID_PAIS`,NULL AS `NOMBRE_REGION`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `NOMBRE_GRUPOREF`,NULL AS `NOMBRE_PROGRAMA_ACAD`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO`,NULL AS `DEPARTAMENTO`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_PROGRAMA_ACAD`,NULL AS `AFIRMACION`,NULL AS `PRAC_ID`,NULL AS `NOMBRE_PROGRAMA_ACADEMICO`,NULL AS `NOMBRE_NBC`,`sabana_generi_ing_telema 2015 3`.`PROGRAMA ACADÉMICO:` AS `PROGRAMA ACADÉMICO:`,`sabana_generi_ing_telema 2015 3`.`MUNICIPIO:` AS `MUNICIPIO:`,`sabana_generi_ing_telema 2015 3`.`GRUPO REFERENCIA:` AS `GRUPO REFERENCIA:`,`sabana_generi_ing_telema 2015 3`.`INSTITUCIÓN:` AS `INSTITUCIÓN:`,`sabana_generi_ing_telema 2015 3`.`MÓDULO` AS `MÓDULO`,`sabana_generi_ing_telema 2015 3`.`Column6` AS `Column6`,`sabana_generi_ing_telema 2015 3`.`Column7` AS `Column7`,`sabana_generi_ing_telema 2015 3`.`Column8` AS `Column8`,`sabana_generi_ing_telema 2015 3`.`Column9` AS `Column9`,`sabana_generi_ing_telema 2015 3`.`Column10` AS `Column10`,`sabana_generi_ing_telema 2015 3`.`EVALUADO` AS `EVALUADO`,`sabana_generi_ing_telema 2015 3`.`Column12` AS `Column12`,`sabana_generi_ing_telema 2015 3`.`Column13` AS `Column13`,`sabana_generi_ing_telema 2015 3`.`Column14` AS `Column14`,`sabana_generi_ing_telema 2015 3`.`Column15` AS `Column15`,`sabana_generi_ing_telema 2015 3`.`Column16` AS `Column16`,`sabana_generi_ing_telema 2015 3`.`NÚMERO REGISTRO` AS `NÚMERO REGISTRO`,`sabana_generi_ing_telema 2015 3`.`Puntaje` AS `Puntaje`,`sabana_generi_ing_telema 2015 3`.`Nivel` AS `Nivel`,`sabana_generi_ing_telema 2015 3`.`Quintil` AS `Quintil`,`sabana_generi_ing_telema 2015 3`.`Column21` AS `Column21`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `CATEGORIAPRUEBA`,'sabana_generi_ing_telema 2015 3' AS `NOMBRE_TABLA` from `sabana_generi_ing_telema 2015 3` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `vista_master_saber_consolidada`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `vista_master_saber_consolidada` AS select `agregados_saber_pro 201702-3 especificas modulo grupo referencia`.`GRUPO_REFERENCIA` AS `GRUPO_REFERENCIA_MASTER`,`agregados_saber_pro 201702-3 especificas modulo grupo referencia`.`NOMBRE_MODULO` AS `MODULO_MASTER`,`agregados_saber_pro 201702-3 especificas modulo grupo referencia`.`TOTAL_EVAGRUPOREF_PRUEBA` AS `TOTAL_EVAGRUPOREF_PRUEBA`,`agregados_saber_pro 201702-3 especificas modulo grupo referencia`.`PROMEDIO_PUNTAJEGLOBAL` AS `PROMEDIO_PUNTAJEGLOBAL`,`agregados_saber_pro 201702-3 especificas modulo grupo referencia`.`DESVI_ESTANDAR_PUNTAJEGLOBAL` AS `DESVI_ESTANDAR_PUNTAJEGLOBAL`,`agregados_saber_pro 201702-3 especificas modulo grupo referencia`.`PROMEDIO_PUNTAJEPRUEBA` AS `PROMEDIO_PUNTAJEPRUEBA`,`agregados_saber_pro 201702-3 especificas modulo grupo referencia`.`DESVI_ESTANDAR_PUNTAJEPRUEBA` AS `DESVI_ESTANDAR_PUNTAJEPRUEBA`,NULL AS `MUNICIPIO_INSTITUCION`,NULL AS `DEPARTAMENTO_INSTITUCION`,NULL AS `ID_INSTITUCION`,NULL AS `INSTITUCION_MASTER`,NULL AS `ORIGEN`,NULL AS `CARACTER`,NULL AS `SNIES`,NULL AS `MUNICIPIO_PROGRAMAACADEMICO`,NULL AS `DEPARTAMENTO_PROGRAMAACADEMICO`,NULL AS `PROGRAMA_ACADEMICO_MASTER`,NULL AS `TOTAL_EVALGRUPO_INSTPROGRAMA`,NULL AS `TOTAL_EVALINSTITUCION_GRUPREF`,NULL AS `EXAMEN`,NULL AS `AGREGACION`,NULL AS `MEDIDA_AGREGACION`,NULL AS `CANTIDADEVALUADOS`,NULL AS `ID_PAIS`,NULL AS `ID_REGION`,NULL AS `NOMBRE_REGION`,NULL AS `ID_DEPARTAMENTO`,NULL AS `NOMBRE_DEPARTAMENTO`,NULL AS `ID_MUNICIPIO`,NULL AS `NOMBRE_MUNICIPIO`,NULL AS `ID_SEDE`,NULL AS `NOMBRE_SEDE`,NULL AS `ID_GRUPOREFERENCIA`,NULL AS `ID_NBC`,NULL AS `NBC`,NULL AS `ID_PROGRAMA_ACAD_MASTER`,NULL AS `NOMBRE_PRUEBA`,NULL AS `CATEGORIAPRUEBA`,NULL AS `PROMEDIO_GLOBAL`,NULL AS `PROMEDIO_PRUEBA`,NULL AS `DESVIACION`,NULL AS `PROMEDIO_PERCENTIL`,NULL AS `NIVEL1`,NULL AS `NIVEL2`,NULL AS `NIVEL3`,NULL AS `NIVEL4`,NULL AS `NIVEL5`,NULL AS `AFIRMACION`,NULL AS `PORCENTAJERTAINCORRECTA`,NULL AS `MUNICIPIO_MASTER`,NULL AS `DEPARTAMENTO_MASTER`,NULL AS `CODIGO_INSTITUCION`,NULL AS `CANTIDAD_ESTUDIANTES`,NULL AS `PROMEDIO`,NULL AS `DESVIACION_ESTANDAR`,NULL AS `CANTIDAD_Q1`,NULL AS `CANTIDAD_Q2`,NULL AS `CANTIDAD_Q3`,NULL AS `CANTIDAD_Q4`,NULL AS `CANTIDAD_Q5`,NULL AS `CANTIDAD_A-`,NULL AS `CANTIDAD_A1`,NULL AS `CANTIDAD_A2`,NULL AS `CANTIDAD_B+`,NULL AS `CANTIDAD_B1`,NULL AS `CANTIDAD_SIN_NIVEL`,NULL AS `CANTIDAD_N1`,NULL AS `CANTIDAD_N2`,NULL AS `CANTIDAD_N3`,NULL AS `CANTIDAD_N4`,NULL AS `CANTIDAD_N5`,NULL AS `CANTIDAD_N6`,NULL AS `CANTIDAD_N7`,NULL AS `CANTIDAD_N8`,NULL AS `NOMBRE_NBC`,NULL AS `Column6`,NULL AS `Column7`,NULL AS `Column8`,NULL AS `Column9`,NULL AS `Column10`,NULL AS `EVALUADO`,NULL AS `Column12`,NULL AS `Column13`,NULL AS `Column14`,NULL AS `Column15`,NULL AS `Column16`,NULL AS `NÚMERO REGISTRO`,NULL AS `Puntaje`,NULL AS `Nivel`,NULL AS `Quintil`,NULL AS `Column21`,'agregados_saber_pro 201702-3 especificas modulo grupo referencia' AS `NOMBRE_TABLA` from `agregados_saber_pro 201702-3 especificas modulo grupo referencia` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;


SET FOREIGN_KEY_CHECKS = 1;
