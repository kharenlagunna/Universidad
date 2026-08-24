<?php
// conexion_resultados.php
//
// Conexión a la segunda base de datos: resultados_saber_pro_tyt
// (datos agregados oficiales del ICFES, de solo lectura, usados en el
// dashboard para comparar/consultar resultados reales).
//
// Es independiente de conexion.php (la base de la app de simulacros).
// Usa la variable $connResultados (no $conn) para poder incluir ambos
// archivos en la misma página sin que se pisen entre sí:
//
//   require_once __DIR__ . '/../conexion.php';            // $conn
//   require_once __DIR__ . '/../conexion_resultados.php'; // $connResultados

$servername = "localhost";
$username_db = "root";
$password_db = "";
$dbname_resultados = "resultados_saber_pro_tyt";

$connResultados = new mysqli($servername, $username_db, $password_db, $dbname_resultados);
if ($connResultados->connect_error) {
    die("Conexión fallida a resultados_saber_pro_tyt: " . $connResultados->connect_error);
}
// Asegura charset
$connResultados->set_charset("utf8mb4");
