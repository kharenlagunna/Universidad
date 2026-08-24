<?php
session_start();
if (!isset($_SESSION['usuario']) || $_SESSION['rol'] !== 'admin') {
    header("Location: ../auth/login.php");
    exit();
}
require_once __DIR__ . '/../conexion.php';

$flashOk = $_SESSION['flash_ok'] ?? '';
$flashError = $_SESSION['flash_error'] ?? '';
unset($_SESSION['flash_ok'], $_SESSION['flash_error']);

$tiposPrueba = $conn->query("SELECT id, nombre FROM tipos_prueba ORDER BY nombre ASC");
$competencias = $conn->query("SELECT id, nombre FROM competencias ORDER BY nombre ASC");
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<title>Cargar Preguntas</title>
<link rel="stylesheet" href="../estilos.css" />
<link rel="icon" href="../favicon.svg" type="image/svg+xml">
<link rel="alternate icon" href="../favicon.ico">
<link rel="apple-touch-icon" href="../apple-touch-icon.png">
</head>
<body>
    <?php require __DIR__ . '/../sidebar.php'; ?>

    <div class="content">
        <div class="contenedor-derecho">
            <h2>Cargar banco de preguntas (Excel)</h2>
            <p>Elige a qué Tipo de Prueba y Competencia pertenecen las preguntas del archivo. <strong>Reemplaza</strong> las preguntas que ya existan para esa combinación (las demás competencias no se tocan).</p>

            <?php if ($flashOk): ?>
                <p style="color:#1a7f37;font-weight:600;"><?= htmlspecialchars($flashOk) ?></p>
            <?php endif; ?>
            <?php if ($flashError): ?>
                <p class="error"><?= htmlspecialchars($flashError) ?></p>
            <?php endif; ?>

            <p>La plantilla debe tener estos encabezados (fila 1):</p>
            <pre style="background:#f1f5f9;padding:12px;border-radius:8px;overflow:auto;">
Enunciado | OpcionA | OpcionB | OpcionC | OpcionD | Correcta
            </pre>
            <p><em>Correcta</em> acepta <strong>A, B, C o D</strong>.</p>

            <a href="descargar_plantilla_preguntas.php" class="btn" style="width:fit-content">📥 Descargar plantilla</a>

            <form action="procesar_carga_preguntas.php" method="POST" enctype="multipart/form-data">
                <label for="tipo_prueba_id">Tipo de prueba:</label>
                <select id="tipo_prueba_id" name="tipo_prueba_id" required>
                    <option value="">-- Seleccione --</option>
                    <?php while ($tipo = $tiposPrueba->fetch_assoc()): ?>
                        <option value="<?= (int)$tipo['id'] ?>"><?= htmlspecialchars($tipo['nombre']) ?></option>
                    <?php endwhile; ?>
                </select>

                <label for="competencia_id">Competencia:</label>
                <select id="competencia_id" name="competencia_id" required>
                    <option value="">-- Seleccione --</option>
                    <?php while ($competencia = $competencias->fetch_assoc()): ?>
                        <option value="<?= (int)$competencia['id'] ?>"><?= htmlspecialchars($competencia['nombre']) ?></option>
                    <?php endwhile; ?>
                </select>

                <label for="archivo">Selecciona archivo Excel (.xlsx):</label>
                <input type="file" id="archivo" name="archivo" accept=".xlsx" required />
                <button type="submit" class="btn">Cargar Preguntas</button>
            </form>
        </div>
    </div>
</body>
</html>
