<?php
require_once "conexion.php";

$token = $_GET['token'] ?? $_POST['token'] ?? '';
$error = '';
$exito = false;

function buscarUsuarioPorToken($conn, string $token)
{
    if ($token === '') {
        return null;
    }
    $tokenHash = hash('sha256', $token);
    $stmt = $conn->prepare("SELECT id, usuario FROM usuarioss WHERE reset_token_hash = ? AND reset_token_expira > NOW()");
    $stmt->bind_param("s", $tokenHash);
    $stmt->execute();
    return $stmt->get_result()->fetch_assoc();
}

$usuarioToken = buscarUsuarioPorToken($conn, $token);

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $nueva = $_POST['nueva_contrasena'] ?? '';
    $confirmar = $_POST['confirmar_contrasena'] ?? '';

    if (!$usuarioToken) {
        $error = "El enlace no es válido o ya expiró. Solicita uno nuevo.";
    } elseif (strlen($nueva) < 8) {
        $error = "La nueva contraseña debe tener al menos 8 caracteres.";
    } elseif ($nueva !== $confirmar) {
        $error = "Las contraseñas no coinciden.";
    } else {
        $hash = password_hash($nueva, PASSWORD_DEFAULT);
        $upd = $conn->prepare("UPDATE usuarioss SET contrasena = ?, reset_token_hash = NULL, reset_token_expira = NULL WHERE id = ?");
        $upd->bind_param("si", $hash, $usuarioToken['id']);
        $upd->execute();
        $exito = true;
    }
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8" />
    <title>Restablecer contraseña - Universidad</title>
    <link rel="stylesheet" href="estilos.css" />
</head>
<body class="login-page">
    <div class="login-wrap">
        <div class="login-brand">
            <div class="login-logo">🎓</div>
            <h1>Universidad</h1>
            <p class="login-tagline">Crea una nueva contraseña</p>
        </div>

        <div class="login-card">
            <?php if ($exito): ?>
                <p style="color:#1a7f37;font-weight:600;margin-bottom:18px;">✅ Tu contraseña fue actualizada correctamente.</p>
                <p><a href="login.php" class="forgot-link">Ir a iniciar sesión →</a></p>
            <?php elseif (!$usuarioToken): ?>
                <p class="error">El enlace no es válido o ya expiró.</p>
                <p><a href="recuperar_contrasena.php" class="forgot-link">Solicitar un nuevo enlace →</a></p>
            <?php else: ?>
                <?php if ($error): ?>
                    <p class="error"><?php echo htmlspecialchars($error); ?></p>
                <?php endif; ?>

                <p style="margin-top:0;color:#555;font-size:14px;">
                    Hola <strong><?php echo htmlspecialchars($usuarioToken['usuario']); ?></strong>, define tu nueva contraseña.
                </p>

                <form method="post" action="">
                    <input type="hidden" name="token" value="<?php echo htmlspecialchars($token); ?>" />

                    <label for="nueva_contrasena">Nueva contraseña</label>
                    <div class="input-icon">
                        <span class="input-icon-glyph">🔒</span>
                        <input type="password" id="nueva_contrasena" name="nueva_contrasena" minlength="8" required autofocus />
                    </div>

                    <label for="confirmar_contrasena">Confirmar contraseña</label>
                    <div class="input-icon">
                        <span class="input-icon-glyph">🔒</span>
                        <input type="password" id="confirmar_contrasena" name="confirmar_contrasena" minlength="8" required />
                    </div>

                    <button type="submit" class="login-submit">Guardar nueva contraseña</button>
                </form>
            <?php endif; ?>
        </div>

        <p class="login-footer">© <?php echo date('Y'); ?> Universidad. Todos los derechos reservados.</p>
    </div>
</body>
</html>
