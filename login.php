<?php
session_start();
require 'conexion.php';

$error = '';

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $usuario = $_POST['usuario'] ?? '';
    $contrasena = $_POST['contrasena'] ?? '';

    $sql = "SELECT * FROM usuarioss WHERE usuario = ?";
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
            $upd = $conn->prepare("UPDATE usuarioss SET contrasena = ? WHERE id = ?");
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

        if ($row['rol'] === 'admin') {
            header("Location: dashboard_admin.php");
        } elseif ($row['rol'] === 'visor') {
            header("Location: dashboard_visor.php");
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
    <link rel="stylesheet" href="estilos.css" />
</head>
<body class="login-body">
    <div class="login-container">
        <h2>Portal Universitario pruebas Saber Pro y T&T</h2>

        <?php if (!empty($error)) : ?>
            <p class="error"><?php echo htmlspecialchars($error); ?></p>
        <?php endif; ?>

        <form method="post" action="">
            <label for="usuario">Usuario:</label>
            <input type="text" id="usuario" name="usuario" required />

            <label for="contrasena">Contraseña:</label>
            <input type="password" id="contrasena" name="contrasena" required />

            <button type="submit" class="btn">Ingresar</button>
        </form>
    </div>
</body>
</html>
