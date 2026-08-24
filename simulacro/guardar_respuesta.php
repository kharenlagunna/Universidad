<?php
session_start();
require_once __DIR__ . '/../conexion.php';

if (!isset($_SESSION['usuario'])) {
    header("Location: ../auth/login.php");
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header("Location: simulacro_inicio.php");
    exit();
}

$usuario = $_SESSION['usuario'];
$intento_id = intval($_POST['intento_id']);
$pregunta_id = intval($_POST['pregunta_id']);
$pregunta_index = intval($_POST['pregunta_index']);
$opcion_elegida = $_POST['opcion_elegida'] ?? null;
$accion = $_POST['accion'] ?? 'guardar';

// Verificar que el intento pertenece al usuario logueado
$stmt = $conn->prepare("SELECT id FROM simulacros_intentos WHERE id = ? AND usuario = ?");
$stmt->bind_param("is", $intento_id, $usuario);
$stmt->execute();
if (!$stmt->get_result()->fetch_assoc()) {
    header("HTTP/1.1 403 Forbidden");
    exit();
}

// Determinar si la opción elegida es la correcta y cuánto puntaje aplica
$es_correcta = 0;
$puntaje_obtenido = 0;

if ($opcion_elegida) {
    $stmt = $conn->prepare("
        SELECT o.es_correcta, p.puntaje
        FROM opciones o
        INNER JOIN preguntas p ON p.id = o.pregunta_id
        WHERE o.pregunta_id = ? AND o.etiqueta = ?
    ");
    $stmt->bind_param("is", $pregunta_id, $opcion_elegida);
    $stmt->execute();
    $opcion = $stmt->get_result()->fetch_assoc();

    if ($opcion && (int)$opcion['es_correcta'] === 1) {
        $es_correcta = 1;
        $puntaje_obtenido = (float) $opcion['puntaje'];
    }
}

// Guardar respuesta
$stmt = $conn->prepare("
    UPDATE simulacros_respuestas
    SET opcion_elegida = ?, es_correcta = ?, puntaje_obtenido = ?
    WHERE intento_id = ? AND pregunta_id = ?
");
$stmt->bind_param("sidii", $opcion_elegida, $es_correcta, $puntaje_obtenido, $intento_id, $pregunta_id);
$stmt->execute();

// Finalizar manualmente
if ($accion === "finalizar") {
    $stmt = $conn->prepare("UPDATE simulacros_intentos SET finalizado_manual = 1, fecha_fin = NOW() WHERE id = ?");
    $stmt->bind_param("i", $intento_id);
    $stmt->execute();
    header("Location: simulacro_resultados.php?intento_id=$intento_id");
    exit();
}

// Siguiente pregunta
$siguiente_index = $pregunta_index + 1;
$stmt = $conn->prepare("SELECT COUNT(*) AS total FROM simulacros_respuestas WHERE intento_id = ?");
$stmt->bind_param("i", $intento_id);
$stmt->execute();
$total_preguntas = $stmt->get_result()->fetch_assoc()['total'];

if ($siguiente_index >= $total_preguntas) {
    // Se respondieron todas las preguntas: se considera finalizado
    $stmt = $conn->prepare("UPDATE simulacros_intentos SET fecha_fin = NOW() WHERE id = ? AND fecha_fin IS NULL");
    $stmt->bind_param("i", $intento_id);
    $stmt->execute();
    header("Location: simulacro_resultados.php?intento_id=$intento_id");
} else {
    header("Location: simulacro_pregunta.php?intento_id=$intento_id&pregunta_index=$siguiente_index");
}
exit();
