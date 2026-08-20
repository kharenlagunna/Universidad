<?php
session_start();
require_once "conexion.php";

if (!isset($_SESSION['usuario'])) {
    header("Location: login.php");
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header("Location: simulacro_inicio.php");
    exit();
}

// Recibir datos del formulario
$intento_id = intval($_POST['intento_id'] ?? 0);
$pregunta_id = intval($_POST['pregunta_id'] ?? 0);
$pregunta_index = intval($_POST['pregunta_index'] ?? 0);
$opcion_elegida = $_POST['opcion_elegida'] ?? null;
$accion = $_POST['accion'] ?? 'guardar';

if (!$intento_id || !$pregunta_id) {
    echo "<p>Error: Intento o pregunta inválidos.</p>";
    exit();
}

// Obtener tiempo y fecha de inicio del intento
$stmt = $conn->prepare("SELECT fecha_inicio, tiempo FROM simulacros_intentos WHERE id=?");
$stmt->bind_param("i", $intento_id);
$stmt->execute();
$res = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$res) {
    echo "<p>Error: Intento no encontrado.</p>";
    exit();
}

$fecha_inicio = strtotime($res['fecha_inicio']);
$tiempo_limite_segundos = intval($res['tiempo']) * 60;
$tiempo_fin = $fecha_inicio + $tiempo_limite_segundos;
$ahora = time();
$tiempo_restante = $tiempo_fin - $ahora;

// Validar tiempo restante
if ($tiempo_restante <= 0) {
    // Marcar intento como finalizado automáticamente
    $stmt = $conn->prepare("UPDATE simulacros_intentos SET finalizado_manual=1 WHERE id=?");
    $stmt->bind_param("i", $intento_id);
    $stmt->execute();
    $stmt->close();

    header("Location: simulacro_resultados.php?intento_id=".$intento_id);
    exit();
}

// Guardar o actualizar respuesta
$stmt = $conn->prepare("SELECT id FROM simulacros_respuestas WHERE intento_id=? AND pregunta_id=?");
$stmt->bind_param("ii", $intento_id, $pregunta_id);
$stmt->execute();
$respuesta_existente = $stmt->get_result()->fetch_assoc();
$stmt->close();

if ($respuesta_existente) {
    $stmt = $conn->prepare("UPDATE simulacros_respuestas SET opcion_elegida=? WHERE id=?");
    $stmt->bind_param("si", $opcion_elegida, $respuesta_existente['id']);
    $stmt->execute();
    $stmt->close();
} else {
    $stmt = $conn->prepare("INSERT INTO simulacros_respuestas (intento_id, pregunta_id, opcion_elegida) VALUES (?,?,?)");
    $stmt->bind_param("iis", $intento_id, $pregunta_id, $opcion_elegida);
    $stmt->execute();
    $stmt->close();
}

// Redirigir según acción
if ($accion === "finalizar") {
    // Marcar intento como finalizado manualmente
    $stmt = $conn->prepare("UPDATE simulacros_intentos SET finalizado_manual=1 WHERE id=?");
    $stmt->bind_param("i", $intento_id);
    $stmt->execute();
    $stmt->close();

    header("Location: simulacro_resultados.php?intento_id=".$intento_id);
    exit();
} else {
    // Continuar a la siguiente pregunta
    $siguiente_index = $pregunta_index + 1;
    header("Location: simulacro_pregunta.php?intento_id=$intento_id&pregunta_index=$siguiente_index");
    exit();
}
?>
