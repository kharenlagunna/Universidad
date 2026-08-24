<?php
session_start();
require __DIR__ . '/../conexion.php';

$error = '';

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $usuario = $_POST['usuario'] ?? '';
    $contrasena = $_POST['contrasena'] ?? '';

    $sql = "SELECT * FROM usuarios WHERE usuario = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $usuario);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = ($result && $result->num_rows === 1) ? $result->fetch_assoc() : null;

    // Acepta el hash nuevo (password_hash) o, si aún no se ha migrado,
    // la contraseña antigua en texto plano; en ese caso la re-guarda como hash.
    $credencialesValidas = false;
    if ($row) {
        if (password_verify($contrasena, $row['contrasena'])) {
            $credencialesValidas = true;
        } elseif (hash_equals($row['contrasena'], $contrasena)) {
            $credencialesValidas = true;
            $nuevoHash = password_hash($contrasena, PASSWORD_DEFAULT);
            $upd = $conn->prepare("UPDATE usuarios SET contrasena = ? WHERE id = ?");
            $upd->bind_param("si", $nuevoHash, $row['id']);
            $upd->execute();
        }
    }

    if ($credencialesValidas) {
        // ✅ Guardar también el ID en sesión para usarlo en el simulacro
        session_regenerate_id(true);
        $_SESSION['usuario_id'] = (int)$row['id'];  // <-- clave para evitar el warning
        $_SESSION['usuario']    = $row['usuario'];
        $_SESSION['rol']        = $row['rol'];

        // "Recordarme": extiende la cookie de sesión a 30 días en vez de
        // expirar al cerrar el navegador.
        if (!empty($_POST['recordar'])) {
            $params = session_get_cookie_params();
            setcookie(session_name(), session_id(), [
                'expires'  => time() + 60 * 60 * 24 * 30,
                'path'     => $params['path'],
                'domain'   => $params['domain'],
                'secure'   => $params['secure'],
                'httponly' => true,
                'samesite' => 'Lax',
            ]);
        }

        if (empty($row['email'])) {
            // Sin correo registrado todavía: no podría recuperar su
            // contraseña más adelante, así que se lo pedimos primero.
            header("Location: completar_perfil.php");
        } elseif ($row['rol'] === 'admin') {
            header("Location: ../admin/dashboard_admin.php");
        } elseif ($row['rol'] === 'visor') {
            header("Location: ../visor/dashboard_visor.php");
        } else {
            $error = "Rol no reconocido.";
        }
        exit();
    } else {
        $error = "Usuario o contraseña incorrectos.";
    }
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8" />
    <title>Login - Universidad</title>
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
            <p class="login-tagline">Inicia sesión en tu cuenta</p>
        </div>

        <div class="login-card">
            <?php if (!empty($error)) : ?>
                <p class="error"><?php echo htmlspecialchars($error); ?></p>
            <?php endif; ?>

            <form method="post" action="">
                <label for="usuario">Usuario</label>
                <div class="input-icon">
                    <span class="input-icon-glyph">👤</span>
                    <input type="text" id="usuario" name="usuario" autocomplete="username" required autofocus />
                </div>

                <label for="contrasena">Contraseña</label>
                <div class="input-icon">
                    <span class="input-icon-glyph">🔒</span>
                    <input type="password" id="contrasena" name="contrasena" autocomplete="current-password" required />
                </div>

                <div class="login-row">
                    <label class="remember">
                        <input type="checkbox" name="recordar" value="1" />
                        Recordarme
                    </label>
                    <a href="recuperar_contrasena.php" class="forgot-link">¿Olvidaste tu contraseña?</a>
                </div>

                <button type="submit" class="login-submit">Iniciar sesión</button>
            </form>
        </div>

        <p class="login-footer">© <?php echo date('Y'); ?> Universidad. Todos los derechos reservados.</p>
    </div>
</body>
</html>
