<?php
session_start();
require_once __DIR__ . '/../conexion.php';

if (!isset($_SESSION['usuario']) || $_SESSION['rol'] !== 'admin') {
    header("Location: ../auth/login.php");
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header("Location: admin_configuracion_pruebas.php");
    exit();
}

$id = intval($_POST['id'] ?? 0);
$duracion_minutos = intval($_POST['duracion_minutos'] ?? 0);
$cantidad_preguntas = trim($_POST['cantidad_preguntas'] ?? '');

if (!$id || $duracion_minutos <= 0) {
    $_SESSION['flash_error'] = "La duración debe ser un número mayor a 0.";
    header("Location: admin_configuracion_pruebas.php");
    exit();
}

$cantidadParam = ($cantidad_preguntas === '') ? null : max(1, intval($cantidad_preguntas));

$stmt = $conn->prepare("UPDATE configuracion_pruebas SET duracion_minutos = ?, cantidad_preguntas = ? WHERE id = ?");
$stmt->bind_param("iii", $duracion_minutos, $cantidadParam, $id);
$stmt->execute();

$_SESSION['flash_ok'] = "Configuración actualizada correctamente.";
header("Location: admin_configuracion_pruebas.php");
exit();
