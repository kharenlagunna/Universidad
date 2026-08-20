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
</head>
<body>
    <div class="sidebar">
        <h2>Panel Admin</h2>
        <a href="dashboard_admin.php">🏠 Dashboard</a>
        <a href="cargar_informacion.php" class="active">📂 Cargar Información</a>
        <a href="analisis_grafico.php">📊 Análisis Gráfico</a>
        <a href="logout.php" class="logout">🚪 Cerrar Sesión</a>
    </div>

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
