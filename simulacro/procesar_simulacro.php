<?php
session_start();
require_once __DIR__ . '/../conexion.php';

if (!isset($_SESSION['usuario'])) {
    header("Location: ../auth/login.php");
    exit();
}

$usuario = $_SESSION['usuario'];

// Validar POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header("Location: simulacro_inicio.php");
    exit();
}

$tipo_prueba_id = intval($_POST['tipo_prueba_id'] ?? 0);
$competencia_id = intval($_POST['competencia_id'] ?? 0);

if (!$tipo_prueba_id || !$competencia_id) {
    $_SESSION['error_simulacro'] = "Selecciona el tipo de prueba y la competencia.";
    header("Location: simulacro_inicio.php");
    exit();
}

// Configuración del admin para esta combinación (tiempo y tope de preguntas)
$stmt = $conn->prepare("SELECT duracion_minutos, cantidad_preguntas FROM configuracion_pruebas WHERE tipo_prueba_id = ? AND competencia_id = ?");
$stmt->bind_param("ii", $tipo_prueba_id, $competencia_id);
$stmt->execute();
$config = $stmt->get_result()->fetch_assoc();

if (!$config) {
    $_SESSION['error_simulacro'] = "Esta combinación de tipo de prueba y competencia no está configurada.";
    header("Location: simulacro_inicio.php");
    exit();
}

$duracion_minutos = (int) $config['duracion_minutos'];
$tope = $config['cantidad_preguntas'];

// Obtener preguntas disponibles para esa competencia y tipo de prueba
$sql = "SELECT id FROM preguntas WHERE tipo_prueba_id = ? AND competencia_id = ? ORDER BY RAND()";
if ($tope !== null && (int)$tope > 0) {
    $sql .= " LIMIT ?";
    $stmt = $conn->prepare($sql);
    $limite = (int)$tope;
    $stmt->bind_param("iii", $tipo_prueba_id, $competencia_id, $limite);
} else {
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ii", $tipo_prueba_id, $competencia_id);
}
$stmt->execute();
$preguntas = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

if (count($preguntas) === 0) {
    $_SESSION['error_simulacro'] = "No hay preguntas disponibles para esa combinación de tipo de prueba y competencia.";
    header("Location: simulacro_inicio.php");
    exit();
}

// Crear intento
$stmt = $conn->prepare("
    INSERT INTO simulacros_intentos
    (usuario, tipo_prueba_id, competencia_id, fecha_inicio, total_preguntas, duracion_minutos)
    VALUES (?, ?, ?, ?, ?, ?)
");
$fecha_inicio = date('Y-m-d H:i:s');
$total_preguntas = count($preguntas);
$stmt->bind_param("siisii", $usuario, $tipo_prueba_id, $competencia_id, $fecha_inicio, $total_preguntas, $duracion_minutos);
$stmt->execute();
$intento_id = $conn->insert_id;

// Insertar cada pregunta en simulacros_respuestas
$stmt = $conn->prepare("INSERT INTO simulacros_respuestas (intento_id, pregunta_id) VALUES (?, ?)");
foreach ($preguntas as $p) {
    $stmt->bind_param("ii", $intento_id, $p['id']);
    $stmt->execute();
}

// Redirigir a la primera pregunta
header("Location: simulacro_pregunta.php?intento_id=$intento_id&pregunta_index=0");
exit();
