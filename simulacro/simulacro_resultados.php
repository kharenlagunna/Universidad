<?php
session_start();
require_once __DIR__ . '/../conexion.php';

if (!isset($_SESSION['usuario'])) {
    header("Location: ../auth/login.php");
    exit();
}

$rol = $_SESSION['rol'];
$usuario = $_SESSION['usuario'];

if (!isset($_GET['intento_id'])) {
    header("Location: simulacro_historial.php");
    exit();
}

$intento_id = intval($_GET['intento_id']);

// El cálculo de correctas se hace por join contra la respuesta correcta real
// (no depende de que simulacros_respuestas.es_correcta esté siempre al día).
$stmt = $conn->prepare("
    SELECT i.id, i.fecha_inicio, i.fecha_fin, i.finalizado_manual, i.duracion_minutos,
           tp.nombre AS tipo_prueba, c.nombre AS competencia,
           COUNT(r.id) AS total_preguntas,
           SUM(CASE WHEN o.es_correcta = 1 AND r.opcion_elegida = o.etiqueta THEN 1 ELSE 0 END) AS correctas
    FROM simulacros_intentos i
    INNER JOIN simulacros_respuestas r ON i.id = r.intento_id
    LEFT JOIN opciones o ON o.pregunta_id = r.pregunta_id AND o.etiqueta = r.opcion_elegida
    LEFT JOIN tipos_prueba tp ON tp.id = i.tipo_prueba_id
    LEFT JOIN competencias c ON c.id = i.competencia_id
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
$porcentaje = $intento['total_preguntas'] > 0
    ? round(($intento['correctas'] / $intento['total_preguntas']) * 100)
    : 0;

// Tiempo utilizado: solo se puede calcular si el intento ya tiene fecha_fin
$tiempoUtilizado = '—';
if (!empty($intento['fecha_fin'])) {
    $segundos = strtotime($intento['fecha_fin']) - strtotime($intento['fecha_inicio']);
    $segundos = max(0, $segundos);
    $tiempoUtilizado = sprintf('%d min %02d seg', intdiv($segundos, 60), $segundos % 60);
}

// Retroalimentación simple según el % de aciertos
if ($porcentaje >= 80) {
    $retroalimentacion = "¡Excelente! Dominas muy bien esta competencia.";
} elseif ($porcentaje >= 60) {
    $retroalimentacion = "Buen desempeño. Repasa los temas donde tuviste errores para mejorar aún más.";
} elseif ($porcentaje >= 40) {
    $retroalimentacion = "Desempeño regular. Te recomendamos reforzar esta competencia antes de tu próximo intento.";
} else {
    $retroalimentacion = "Necesitas reforzar bastante esta competencia. Sigue practicando y vuelve a intentarlo.";
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Resultados del Simulacro</title>
<link rel="stylesheet" href="../estilos.css">
<link rel="icon" href="../favicon.svg" type="image/svg+xml">
<link rel="alternate icon" href="../favicon.ico">
<link rel="apple-touch-icon" href="../apple-touch-icon.png">
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
<?php require __DIR__ . '/../sidebar.php'; ?>

<div class="content">
    <div class="contenedor-derecho">
        <h2>Resultados del Simulacro</h2>

        <div class="resultado-grid">
            <div class="resultado-info">
                <p><strong>Tipo de Prueba:</strong> <?= htmlspecialchars($intento['tipo_prueba'] ?? '—') ?></p>
                <p><strong>Competencia:</strong> <?= htmlspecialchars($intento['competencia'] ?? '—') ?></p>
                <p><strong>Fecha:</strong> <?= htmlspecialchars($intento['fecha_inicio']) ?></p>
                <p><strong>Tiempo asignado:</strong> <?= (int)$intento['duracion_minutos'] ?> minutos</p>
                <p><strong>Tiempo utilizado:</strong> <?= htmlspecialchars($tiempoUtilizado) ?></p>
                <p><strong>Total de Preguntas:</strong> <?= $intento['total_preguntas'] ?></p>
                <p><strong>Correctas:</strong> <?= $intento['correctas'] ?></p>
                <p><strong>Incorrectas:</strong> <?= $incorrectas ?></p>

                <?php if ($finalizado_manual): ?>
                    <div class="alert-warning">
                        ⚠️ Este simulacro fue finalizado manualmente por el usuario.
                    </div>
                <?php endif; ?>
            </div>

            <div class="resultado-grafico"
                 data-correctas="<?= (int)$intento['correctas'] ?>"
                 data-incorrectas="<?= (int)$incorrectas ?>">
                <canvas id="resultadoChart"></canvas>
            </div>
        </div>

        <div class="alert-warning" style="background-color:#eef2fb;border-color:#d7e6ff;color:#0056b3;">
            📋 <strong>Retroalimentación:</strong> <?= htmlspecialchars($retroalimentacion) ?>
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
