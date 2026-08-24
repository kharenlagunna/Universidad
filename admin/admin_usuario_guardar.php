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

function volverConError(string $mensaje, ?int $id = null): void
{
    $_SESSION['flash_error'] = $mensaje;
    header("Location: admin_usuarios.php" . ($id ? "?editar=$id" : ""));
    exit();
}

$id = isset($_POST['id']) && $_POST['id'] !== '' ? intval($_POST['id']) : null;
$usuario = trim($_POST['usuario'] ?? '');
$email = trim($_POST['email'] ?? '');
$rol = $_POST['rol'] ?? '';
$contrasena = $_POST['contrasena'] ?? '';

if ($usuario === '') {
    volverConError("El nombre de usuario es obligatorio.", $id);
}
if (!in_array($rol, ['admin', 'visor'], true)) {
    volverConError("Selecciona un rol válido.", $id);
}
if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    volverConError("El correo no tiene un formato válido.", $id);
}

// bind_param exige variables (no expresiones) para pasar por referencia.
$idParaComparar = $id ?? 0;

// Nombre de usuario único (sin contar al propio registro si estamos editando).
$stmt = $conn->prepare("SELECT id FROM usuarios WHERE usuario = ? AND id <> ?");
$stmt->bind_param("si", $usuario, $idParaComparar);
$stmt->execute();
if ($stmt->get_result()->fetch_assoc()) {
    volverConError("Ya existe otro usuario con ese nombre de usuario.", $id);
}

// Correo único (si se indicó uno).
if ($email !== '') {
    $stmt = $conn->prepare("SELECT id FROM usuarios WHERE email = ? AND id <> ?");
    $stmt->bind_param("si", $email, $idParaComparar);
    $stmt->execute();
    if ($stmt->get_result()->fetch_assoc()) {
        volverConError("Ya existe otro usuario con ese correo.", $id);
    }
}

$emailParam = $email !== '' ? $email : null;

if ($id === null) {
    // ----- Crear usuario -----
    if (strlen($contrasena) < 8) {
        volverConError("La contraseña debe tener al menos 8 caracteres.");
    }
    $hash = password_hash($contrasena, PASSWORD_DEFAULT);

    $stmt = $conn->prepare("INSERT INTO usuarios (usuario, contrasena, rol, email) VALUES (?, ?, ?, ?)");
    $stmt->bind_param("ssss", $usuario, $hash, $rol, $emailParam);
    $stmt->execute();

    $_SESSION['flash_ok'] = "Usuario \"$usuario\" creado correctamente.";
} else {
    // ----- Editar usuario existente -----
    $stmt = $conn->prepare("SELECT rol FROM usuarios WHERE id = ?");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $actual = $stmt->get_result()->fetch_assoc();
    if (!$actual) {
        volverConError("El usuario ya no existe.");
    }

    // No permitir quitarle el rol de admin al último administrador del sistema.
    if ($actual['rol'] === 'admin' && $rol !== 'admin') {
        $stmt = $conn->prepare("SELECT COUNT(*) AS total FROM usuarios WHERE rol = 'admin'");
        $stmt->execute();
        $totalAdmins = $stmt->get_result()->fetch_assoc()['total'];
        if ($totalAdmins <= 1) {
            volverConError("No puedes quitarle el rol de administrador al único administrador del sistema.", $id);
        }
    }

    if ($contrasena !== '') {
        if (strlen($contrasena) < 8) {
            volverConError("La contraseña debe tener al menos 8 caracteres.", $id);
        }
        $hash = password_hash($contrasena, PASSWORD_DEFAULT);
        $stmt = $conn->prepare("
            UPDATE usuarios
            SET usuario = ?, email = ?, rol = ?, contrasena = ?, reset_token_hash = NULL, reset_token_expira = NULL
            WHERE id = ?
        ");
        $stmt->bind_param("ssssi", $usuario, $emailParam, $rol, $hash, $id);
    } else {
        $stmt = $conn->prepare("UPDATE usuarios SET usuario = ?, email = ?, rol = ? WHERE id = ?");
        $stmt->bind_param("sssi", $usuario, $emailParam, $rol, $id);
    }
    $stmt->execute();

    // Si el admin se edita a sí mismo, refleja el cambio en su propia sesión.
    if ($id === (int)($_SESSION['usuario_id'] ?? 0)) {
        $_SESSION['usuario'] = $usuario;
        $_SESSION['rol'] = $rol;
    }

    $_SESSION['flash_ok'] = "Usuario \"$usuario\" actualizado correctamente.";
}

header("Location: admin_usuarios.php");
exit();
