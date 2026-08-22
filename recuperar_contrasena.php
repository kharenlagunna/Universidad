<?php
require_once "conexion.php";
require_once "enviar_correo.php";

$mensaje = '';
$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = trim($_POST['email'] ?? '');

    if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $error = "Ingresa un correo válido.";
    } else {
        $stmt = $conn->prepare("SELECT id, usuario FROM usuarioss WHERE email = ?");
        $stmt->bind_param("s", $email);
        $stmt->execute();
        $usuario = $stmt->get_result()->fetch_assoc();

        if ($usuario) {
            $token = bin2hex(random_bytes(32));
            $tokenHash = hash('sha256', $token);
            $expira = date('Y-m-d H:i:s', time() + 3600); // 1 hora

            $upd = $conn->prepare("UPDATE usuarioss SET reset_token_hash = ?, reset_token_expira = ? WHERE id = ?");
            $upd->bind_param("ssi", $tokenHash, $expira, $usuario['id']);
            $upd->execute();

            $esquema = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
            $base = $esquema . '://' . $_SERVER['HTTP_HOST'] . dirname($_SERVER['SCRIPT_NAME']);
            $enlace = $base . '/restablecer_contrasena.php?token=' . $token;

            enviarCorreoRecuperacion($email, $usuario['usuario'], $enlace);
        }

        // Mensaje genérico siempre igual, exista o no el correo,
        // para no revelar qué correos están registrados.
        $mensaje = "Si el correo está registrado, te enviamos un enlace para restablecer tu contraseña. Revisa también tu carpeta de spam.";
    }
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8" />
    <title>Recuperar contraseña - Universidad</title>
    <link rel="stylesheet" href="estilos.css" />
</head>
<body class="login-page">
    <div class="login-wrap">
        <div class="login-brand">
            <div class="login-logo">🎓</div>
            <h1>Universidad</h1>
            <p class="login-tagline">Recupera el acceso a tu cuenta</p>
        </div>

        <div class="login-card">
            <?php if ($error): ?>
                <p class="error"><?php echo htmlspecialchars($error); ?></p>
            <?php endif; ?>

            <?php if ($mensaje): ?>
                <p style="color:#1a7f37;font-weight:600;margin-bottom:18px;"><?php echo htmlspecialchars($mensaje); ?></p>
                <p><a href="login.php" class="forgot-link">← Volver al inicio de sesión</a></p>
            <?php else: ?>
                <p style="margin-top:0;color:#555;font-size:14px;">
                    Ingresa el correo asociado a tu cuenta y te enviaremos un enlace para crear una nueva contraseña.
                </p>
                <form method="post" action="">
                    <label for="email">Correo electrónico</label>
                    <div class="input-icon">
                        <span class="input-icon-glyph">📧</span>
                        <input type="email" id="email" name="email" required autofocus />
                    </div>

                    <button type="submit" class="login-submit">Enviar enlace de recuperación</button>
                </form>
                <p style="margin-top:18px;"><a href="login.php" class="forgot-link">← Volver al inicio de sesión</a></p>
            <?php endif; ?>
        </div>

        <p class="login-footer">© <?php echo date('Y'); ?> Universidad. Todos los derechos reservados.</p>
    </div>
</body>
</html>
