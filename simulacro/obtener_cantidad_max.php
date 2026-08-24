<?php
session_start();
require_once __DIR__ . '/../conexion.php';

if (!isset($_SESSION['usuario'])) {
    header("HTTP/1.1 403 Forbidden");
    exit();
}

$tipoPruebaId = intval($_GET['tipo_prueba_id'] ?? 0);
$competenciaId = intval($_GET['competencia_id'] ?? 0);

$max = 0;
$duracionMinutos = 0;

if ($tipoPruebaId && $competenciaId) {
    // Cuántas preguntas hay realmente cargadas para esta combinación
    $stmt = $conn->prepare("SELECT COUNT(*) AS total FROM preguntas WHERE tipo_prueba_id = ? AND competencia_id = ?");
    $stmt->bind_param("ii", $tipoPruebaId, $competenciaId);
    $stmt->execute();
    $disponibles = (int) $stmt->get_result()->fetch_assoc()['total'];

    // Configuración del admin para esta combinación (tiempo y tope de preguntas)
    $stmt = $conn->prepare("SELECT duracion_minutos, cantidad_preguntas FROM configuracion_pruebas WHERE tipo_prueba_id = ? AND competencia_id = ?");
    $stmt->bind_param("ii", $tipoPruebaId, $competenciaId);
    $stmt->execute();
    $config = $stmt->get_result()->fetch_assoc();

    if ($config) {
        $duracionMinutos = (int) $config['duracion_minutos'];
        $tope = $config['cantidad_preguntas'];
        $max = ($tope !== null && (int)$tope > 0) ? min((int)$tope, $disponibles) : $disponibles;
    }
}

header('Content-Type: application/json');
echo json_encode(["max" => $max, "duracion_minutos" => $duracionMinutos]);
