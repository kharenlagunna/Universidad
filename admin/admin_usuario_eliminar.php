<?php
session_start();
require_once __DIR__ . '/../conexion.php';

if (!isset($_SESSION['usuario']) || $_SESSION['rol'] !== 'admin') {
    header("Location: ../auth/login.php");
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header("Location: admin_usuarios.php");
    exit();
}

$id = intval($_POST['id'] ?? 0);

if ($id === (int)($_SESSION['usuario_id'] ?? 0)) {
    $_SESSION['flash_error'] = "No puedes eliminar tu propia cuenta mientras estás conectado con ella.";
    header("Location: admin_usuarios.php");
    exit();
}

$stmt = $conn->prepare("SELECT usuario, rol FROM usuarioss WHERE id = ?");
$stmt->bind_param("i", $id);
$stmt->execute();
$usuario = $stmt->get_result()->fetch_assoc();

if (!$usuario) {
    $_SESSION['flash_error'] = "El usuario ya no existe.";
    header("Location: admin_usuarios.php");
    exit();
}

// No permitir eliminar al último administrador del sistema.
if ($usuario['rol'] === 'admin') {
    $stmt = $conn->prepare("SELECT COUNT(*) AS total FROM usuarioss WHERE rol = 'admin'");
    $stmt->execute();
    $totalAdmins = $stmt->get_result()->fetch_assoc()['total'];
    if ($totalAdmins <= 1) {
        $_SESSION['flash_error'] = "No puedes eliminar al único administrador del sistema.";
        header("Location: admin_usuarios.php");
        exit();
    }
}

$stmt = $conn->prepare("DELETE FROM usuarioss WHERE id = ?");
$stmt->bind_param("i", $id);
$stmt->execute();

$_SESSION['flash_ok'] = "Usuario \"{$usuario['usuario']}\" eliminado correctamente.";
header("Location: admin_usuarios.php");
exit();
