<?php
session_start();
if (!isset($_SESSION['usuario']) || $_SESSION['rol'] !== 'visor') {
    header("Location: login.php");
    exit();
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<title>Dashboard - Visor</title>
<link rel="stylesheet" href="estilos.css" />
<link rel="icon" href="favicon.svg" type="image/svg+xml">
<link rel="alternate icon" href="favicon.ico">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
</head>
<body>
    <?php require __DIR__ . '/sidebar.php'; ?>

    <div class="content">
        <div class="contenedor-derecho">
            <h2>Bienvenido, <?php echo htmlspecialchars($_SESSION['usuario']); ?> (Visor)</h2>
            <p>Solo puedes acceder a las opciones de visualización.</p>

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
                    <tr><td>TMO (Tiempo Medio de Operación)</td><td>225 seg</td><td>200 seg</td></tr>
                    <tr><td>AWA (Average Wait Time)</td><td>28 seg</td><td>25 seg</td></tr>
                    <tr><td>Abandono</td><td>3.5%</td><td>3%</td></tr>
                    <tr><td>Llamadas Atendidas</td><td>13,800</td><td>14,000</td></tr>
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
