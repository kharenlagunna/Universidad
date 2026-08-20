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
<title>Cargar Preguntas</title>
<link rel="stylesheet" href="estilos.css" />
</head>
<body>
    <div class="sidebar">
        <h2>Panel Admin</h2>
        <a href="dashboard_admin.php">🏠 Dashboard</a>
        <a href="cargar_informacion.php">📂 Cargar Información</a>
        <a href="analisis_grafico.php">📊 Análisis Gráfico</a>
        <a href="admin_cargar_preguntas.php" class="active">📝 Cargar Preguntas</a>
        <a href="logout.php" class="logout">🚪 Cerrar Sesión</a>
    </div>

    <div class="content">
        <div class="contenedor-derecho">
            <h2>Cargar banco de preguntas (Excel)</h2>
            <p>La plantilla debe tener estos encabezados (fila 1):</p>
            <pre style="background:#f1f5f9;padding:12px;border-radius:8px;overflow:auto;">
Enunciado | GrupoReferencia | Modulo | TipoPrueba | OpcionA | OpcionB | OpcionC | OpcionD | Correcta | Puntaje
            </pre>
            <p><em>TipoPrueba</em> acepta <strong>generica</strong> o <strong>especifica</strong>. <em>Correcta</em> acepta <strong>A, B, C o D</strong>. <em>Puntaje</em> es numérico (por defecto 1).</p>

            <!-- (Opcional) botón para descargar plantilla -->
            <a href="descargar_plantilla_preguntas.php" class="btn" style="width:fit-content">📥 Descargar plantilla</a>

            <form action="procesar_carga_preguntas.php" method="POST" enctype="multipart/form-data">
                <label for="archivo">Selecciona archivo Excel (.xlsx):</label>
                <input type="file" id="archivo" name="archivo" accept=".xlsx" required />
                <button type="submit" class="btn">Cargar Preguntas</button>
            </form>
        </div>
    </div>
</body>
</html>
