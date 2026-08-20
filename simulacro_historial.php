<?php
session_start();
require_once "conexion.php";

if (!isset($_SESSION['usuario'])) {
    header("Location: login.php");
    exit();
}

$usuario = $_SESSION['usuario'];

$stmt = $conn->prepare("
    SELECT si.id, si.fecha_inicio, si.fecha_fin, si.finalizado_manual,
           COUNT(sr.id) AS total_preguntas,
           SUM(CASE WHEN sr.opcion_elegida IS NOT NULL THEN 1 ELSE 0 END) AS respondidas,
           SUM(CASE WHEN o.es_correcta = 1 AND sr.opcion_elegida = o.etiqueta THEN 1 ELSE 0 END) AS correctas
    FROM simulacros_intentos si
    LEFT JOIN simulacros_respuestas sr ON si.id = sr.intento_id
    LEFT JOIN opciones o ON sr.pregunta_id = o.pregunta_id AND sr.opcion_elegida = o.etiqueta
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
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
    <style>
        body { display: flex; min-height: 100vh; }
        .sidebar {
            width: 230px; background-color: #2c3e50; color: white;
            padding: 20px; display: flex; flex-direction: column;
        }
        .sidebar h4 { color: #ecf0f1; margin-bottom: 20px; }
        .sidebar a {
            color: white; text-decoration: none; margin: 8px 0;
            padding: 8px; border-radius: 5px; display: block;
        }
        .sidebar a:hover { background-color: #34495e; }
        .content { flex: 1; padding: 20px; }
        .badge-manual { background-color: #e74c3c; }
        .badge-normal { background-color: #27ae60; }
    </style>
</head>
<body>
    <div class="sidebar">
        <h4>📘 Menú</h4>
        <a href="simulacro_inicio.php">▶️ Iniciar Simulacro</a>
        <a href="simulacro_historial.php">📊 Historial</a>
        <a href="logout.php">🚪 Cerrar Sesión</a>
    </div>

    <div class="content">
        <h2>📊 Historial de Simulacros</h2>
        <table class="table table-bordered mt-3">
            <thead class="table-dark">
                <tr>
                    <th>#</th>
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
                        <td><?= $row['fecha_inicio'] ?></td>
                        <td><?= $row['fecha_fin'] ?? '-' ?></td>
                        <td><?= $row['total_preguntas'] ?></td>
                        <td><?= $row['respondidas'] ?></td>
                        <td><?= $row['correctas'] ?></td>
                        <td>
                            <?php if ($row['finalizado_manual']): ?>
                                <span class="badge badge-manual">Finalizado manualmente</span>
                            <?php else: ?>
                                <span class="badge badge-normal">Completado</span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <a href="simulacro_resultados.php?id=<?= $row['id'] ?>" class="btn btn-sm btn-primary">Ver</a>
                        </td>
                    </tr>
                <?php endwhile; ?>
            </tbody>
        </table>
    </div>
</body>
</html>
