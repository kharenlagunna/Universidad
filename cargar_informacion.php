<?php
session_start();
if (!isset($_SESSION['usuario']) || $_SESSION['rol'] !== 'admin') {
    header("Location: login.php");
    exit();
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<title>Cargar Información</title>
<link rel="stylesheet" href="estilos.css" />
<link rel="icon" href="favicon.svg" type="image/svg+xml">
<link rel="alternate icon" href="favicon.ico">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
</head>
<body>
    <?php require __DIR__ . '/sidebar.php'; ?>

    <div class="content">
        <div class="contenedor-derecho">
            <h2>Cargar archivo Excel</h2>
            <p>Sube tu archivo .xlsx con las 4 columnas para importar datos al sistema.</p>

            <!-- Botón para descargar plantilla -->
            <a href="templates/plantilla.xlsx" download class="btn" style="width: fit-content; margin-bottom: 20px;">
                📥 Descargar plantilla Excel
            </a>

            <form action="procesar_carga.php" method="POST" enctype="multipart/form-data">
                <label for="archivo">Selecciona archivo Excel (.xlsx):</label>
                <input type="file" id="archivo" name="archivo" accept=".xlsx" required />

                <button type="submit" class="btn">Cargar Archivo</button>
            </form>
        </div>
    </div>
</body>
</html>
