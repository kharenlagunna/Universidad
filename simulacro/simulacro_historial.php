<?php
session_start();
require_once __DIR__ . '/../conexion.php';

if (!isset($_SESSION['usuario'])) {
    header("Location: ../auth/login.php");
    exit();
}

$usuario = $_SESSION['usuario'];
$rol = $_SESSION['rol'] ?? 'visor';

$stmt = $conn->prepare("
    SELECT si.id, si.fecha_inicio, si.fecha_fin, si.finalizado_manual,
           tp.nombre AS tipo_prueba, c.nombre AS competencia,
           COUNT(sr.id) AS total_preguntas,
           SUM(CASE WHEN sr.opcion_elegida IS NOT NULL THEN 1 ELSE 0 END) AS respondidas,
           SUM(CASE WHEN o.es_correcta = 1 AND sr.opcion_elegida = o.etiqueta THEN 1 ELSE 0 END) AS correctas
    FROM simulacros_intentos si
    LEFT JOIN simulacros_respuestas sr ON si.id = sr.intento_id
    LEFT JOIN opciones o ON sr.pregunta_id = o.pregunta_id AND sr.opcion_elegida = o.etiqueta
    LEFT JOIN tipos_prueba tp ON tp.id = si.tipo_prueba_id
    LEFT JOIN competencias c ON c.id = si.competencia_id
    WHERE si.usuario = ?
    GROUP BY si.id
    ORDER BY si.fecha_inicio DESC
");
$stmt->bind_param("s", $usuario);
$stmt->execute();
$result = $stmt->get_result();
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Historial de Simulacros</title>
    <link rel="stylesheet" href="../estilos.css">
    <link rel="icon" href="../favicon.svg" type="image/svg+xml">
    <link rel="alternate icon" href="../favicon.ico">
    <link rel="apple-touch-icon" href="../apple-touch-icon.png">
</head>
<body>
    <?php require __DIR__ . '/../sidebar.php'; ?>

    <div class="content">
        <div class="contenedor-derecho">
            <h2>📊 Historial de Simulacros</h2>
            <table class="tabla-indicadores">
                <thead>
                    <tr>
                        <th>#</th>
                        <th>Tipo de Prueba</th>
                        <th>Competencia</th>
                        <th>Fecha Inicio</th>
                        <th>Fecha Fin</th>
                        <th>Preguntas</th>
                        <th>Respondidas</th>
                        <th>Correctas</th>
                        <th>Estado</th>
                        <th>Ver Detalles</th>
                    </tr>
                </thead>
                <tbody>
                    <?php
                    $i = 1;
                    while ($row = $result->fetch_assoc()): ?>
                        <tr>
                            <td><?= $i++ ?></td>
                            <td><?= htmlspecialchars($row['tipo_prueba'] ?? '—') ?></td>
                            <td><?= htmlspecialchars($row['competencia'] ?? '—') ?></td>
                            <td><?= htmlspecialchars($row['fecha_inicio']) ?></td>
                            <td><?= htmlspecialchars($row['fecha_fin'] ?? '-') ?></td>
                            <td><?= $row['total_preguntas'] ?></td>
                            <td><?= $row['respondidas'] ?></td>
                            <td><?= $row['correctas'] ?></td>
                            <td>
                                <?php if ($row['finalizado_manual']): ?>
                                    <span class="estado-badge estado-manual">Finalizado manualmente</span>
                                <?php else: ?>
                                    <span class="estado-badge estado-normal">Completado</span>
                                <?php endif; ?>
                            </td>
                            <td>
                                <a href="simulacro_resultados.php?intento_id=<?= $row['id'] ?>" class="btn" style="padding:8px 16px;font-size:14px;">Ver</a>
                            </td>
                        </tr>
                    <?php endwhile; ?>
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
