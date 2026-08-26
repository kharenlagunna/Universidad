<?php
session_start();
require_once __DIR__ . '/../conexion.php';

if (!isset($_SESSION['usuario'], $_SESSION['usuario_id'])) {
    header("Location: login.php");
    exit();
}

$destino = ($_SESSION['rol'] === 'admin') ? '../admin/dashboard_resultados.php' : '../visor/dashboard_visor.php';

// Si ya tiene correo registrado, no necesita pasar por aquí.
$stmt = $conn->prepare("SELECT email FROM usuarios WHERE id = ?");
$stmt->bind_param("i", $_SESSION['usuario_id']);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();

if (!empty($row['email'])) {
    header("Location: $destino");
    exit();
}

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = trim($_POST['email'] ?? '');

    if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $error = "Ingresa un correo válido.";
    } else {
        // Verificar que ningún otro usuario ya use este correo.
        $stmt = $conn->prepare("SELECT id FROM usuarios WHERE email = ? AND id <> ?");
        $stmt->bind_param("si", $email, $_SESSION['usuario_id']);
        $stmt->execute();
        if ($stmt->get_result()->fetch_assoc()) {
            $error = "Ese correo ya está registrado con otra cuenta.";
        } else {
            $upd = $conn->prepare("UPDATE usuarios SET email = ? WHERE id = ?");
            $upd->bind_param("si", $email, $_SESSION['usuario_id']);
            $upd->execute();
            header("Location: $destino");
            exit();
        }
    }
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8" />
    <title>Completa tu perfil - Universidad</title>
    <link rel="stylesheet" href="../estilos.css" />
    <link rel="icon" href="../favicon.svg" type="image/svg+xml">
    <link rel="alternate icon" href="../favicon.ico">
    <link rel="apple-touch-icon" href="../apple-touch-icon.png">
</head>
<body class="login-page">
    <div class="login-wrap">
        <div class="login-brand">
            <div class="login-logo">🎓</div>
            <h1>Universidad</h1>
            <p class="login-tagline">Un último paso antes de continuar</p>
        </div>

        <div class="login-card">
            <?php if ($error): ?>
                <p class="error"><?php echo htmlspecialchars($error); ?></p>
            <?php endif; ?>

            <p style="margin-top:0;color:#555;font-size:14px;">
                Necesitamos tu correo electrónico para poder ayudarte a recuperar tu contraseña si alguna vez la olvidas.
            </p>

            <form method="post" action="">
                <label for="email">Correo electrónico</label>
                <div class="input-icon">
                    <span class="input-icon-glyph">📧</span>
                    <input type="email" id="email" name="email" required autofocus />
                </div>

                <button type="submit" class="login-submit">Guardar y continuar</button>
            </form>
        </div>
    </div>
</body>
</html>
