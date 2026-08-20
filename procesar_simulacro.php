<?php
session_start();
require_once "conexion.php";

if (!isset($_SESSION['usuario'])) {
    header("Location: login.php");
    exit();
}

$usuario = $_SESSION['usuario'];

// Validar POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header("Location: simulacro_inicio.php");
    exit();
}

// Recibir filtros
$grupo_referencia = $_POST['grupo_referencia'] ?? '';
$modulo = $_POST['modulo'] ?? '';
$tipo_prueba = $_POST['tipo_prueba'] ?? '';
$cantidad = intval($_POST['cantidad'] ?? 0);
$duracion_minutos = intval($_POST['cantidad'] ?? 0); // 1 min por pregunta

if (!$grupo_referencia || !$modulo || !$tipo_prueba || $cantidad <= 0) {
    $_SESSION['error_simulacro'] = "Selecciona todos los filtros correctamente.";
    header("Location: simulacro_inicio.php");
    exit();
}

// Obtener preguntas según filtros
$stmt = $conn->prepare("
    SELECT id 
    FROM preguntas 
    WHERE grupo_referencia = ? AND modulo = ? AND tipo_prueba = ? 
    ORDER BY RAND() 
    LIMIT ?
");
$stmt->bind_param("sssi", $grupo_referencia, $modulo, $tipo_prueba, $cantidad);
$stmt->execute();
$result = $stmt->get_result();
$preguntas = $result->fetch_all(MYSQLI_ASSOC);

if (count($preguntas) === 0) {
    $_SESSION['error_simulacro'] = "No hay preguntas disponibles para los filtros seleccionados.";
    header("Location: simulacro_inicio.php");
    exit();
}

// Crear intento
$stmt = $conn->prepare("
    INSERT INTO simulacros_intentos 
    (usuario, fecha_inicio, total_preguntas, duracion_minutos, filtro_grupo_referencia, filtro_modulo, filtro_tipo_prueba) 
    VALUES (?,?,?, ?, ?, ?, ?)
");
$fecha_inicio = date('Y-m-d H:i:s');
$total_preguntas = count($preguntas);
$stmt->bind_param("ssiiiss", $usuario, $fecha_inicio, $total_preguntas, $duracion_minutos, $grupo_referencia, $modulo, $tipo_prueba);
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
?>
