<?php
session_start();
if (!isset($_SESSION['usuario']) || $_SESSION['rol'] !== 'admin') {
    header("Location: ../auth/login.php");
    exit();
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<title>Dashboard - Administrador</title>
<link rel="stylesheet" href="../estilos.css" />
<link rel="icon" href="../favicon.svg" type="image/svg+xml">
<link rel="alternate icon" href="../favicon.ico">
<link rel="apple-touch-icon" href="../apple-touch-icon.png">
</head>
<body>
    <?php require __DIR__ . '/../sidebar.php'; ?>

    <div class="content">
        <div class="contenedor-derecho">
            <h2>Bienvenido, <?php echo htmlspecialchars($_SESSION['usuario']); ?> (Administrador)</h2>
            <p>Desde aquí puedes administrar el sistema y acceder a todas las opciones disponibles.</p>

            <h2>Indicadores de Contact Center</h2>

            <table class="tabla-indicadores">
                <thead>
                    <tr>
                        <th>Indicador</th>
                        <th>Valor</th>
                        <th>Meta</th>
                    </tr>
                </thead>
                <tbody>
                    <tr><td>TMO (Tiempo Medio de Operación)</td><td>220 seg</td><td>200 seg</td></tr>
                    <tr><td>AWA (Average Wait Time)</td><td>30 seg</td><td>25 seg</td></tr>
                    <tr><td>Abandono</td><td>3.2%</td><td>3%</td></tr>
                    <tr><td>Llamadas Atendidas</td><td>15,000</td><td>14,000</td></tr>
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
