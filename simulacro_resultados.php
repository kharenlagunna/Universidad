<?php
session_start();
require_once "conexion.php";

if (!isset($_SESSION['usuario'])) {
    header("Location: login.php");
    exit();
}

$rol = $_SESSION['rol'];
$usuario = $_SESSION['usuario'];

if (!isset($_GET['intento_id'])) {
    header("Location: simulacro_historial.php");
    exit();
}

$intento_id = intval($_GET['intento_id']);

$stmt = $conn->prepare("
    SELECT i.id, i.fecha_inicio, i.finalizado_manual, COUNT(r.id) as total_preguntas,
           SUM(CASE WHEN r.es_correcta = 1 THEN 1 ELSE 0 END) as correctas
    FROM simulacros_intentos i
    INNER JOIN simulacros_respuestas r ON i.id = r.intento_id
    WHERE i.id = ? AND i.usuario = ?
    GROUP BY i.id
");
$stmt->bind_param("is", $intento_id, $usuario);
$stmt->execute();
$intento = $stmt->get_result()->fetch_assoc();

if (!$intento) {
    header("Location: simulacro_historial.php");
    exit();
}

$incorrectas = $intento['total_preguntas'] - $intento['correctas'];
$finalizado_manual = $intento['finalizado_manual'] == 1;
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Resultados del Simulacro</title>
<link rel="stylesheet" href="estilos.css">
<link rel="icon" href="favicon.svg" type="image/svg+xml">
<link rel="alternate icon" href="favicon.ico">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
<?php require __DIR__ . '/sidebar.php'; ?>

<div class="content">
    <div class="contenedor-derecho" style="max-width:820px">
        <h2>Resultados del Simulacro</h2>
        <p><strong>Fecha:</strong> <?= htmlspecialchars($intento['fecha_inicio']) ?></p>
        <p><strong>Total de Preguntas:</strong> <?= $intento['total_preguntas'] ?></p>
        <p><strong>Correctas:</strong> <?= $intento['correctas'] ?></p>
        <p><strong>Incorrectas:</strong> <?= $incorrectas ?></p>

        <?php if ($finalizado_manual): ?>
            <div class="alert-warning">
                ⚠️ Este simulacro fue finalizado manualmente por el usuario.
            </div>
        <?php endif; ?>

        <div style="width: 400px; margin-top: 20px;">
            <canvas id="resultadoChart"></canvas>
        </div>
    </div>
</div>

<script>
const ctx = document.getElementById('resultadoChart').getContext('2d');
new Chart(ctx, {
    type: 'pie',
    data: {
        labels: ['Correctas', 'Incorrectas'],
        datasets: [{
            data: [<?= $intento['correctas'] ?>, <?= $incorrectas ?>],
            backgroundColor: ['#4CAF50', '#F44336']
        }]
    },
    options: { responsive: true }
});
</script>
</body>
</html>
