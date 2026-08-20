<?php
session_start();
if (!isset($_SESSION['usuario']) || !in_array($_SESSION['rol'], ['admin','visor'])) {
    header("Location: login.php");
    exit();
}
$rol = $_SESSION['rol'];
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<title>Análisis Gráfico</title>
<link rel="stylesheet" href="estilos.css" />
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <div class="sidebar">
        <h2>Panel <?php echo ($rol === 'admin') ? 'Admin' : 'Visor'; ?></h2>
        <?php if($rol === 'admin'): ?>
            <a href="dashboard_admin.php">🏠 Dashboard</a>
            <a href="cargar_informacion.php">📂 Cargar Información</a>
        <?php else: ?>
            <a href="dashboard_visor.php">🏠 Dashboard</a>
        <?php endif; ?>
        <a href="analisis_grafico.php" class="active">📊 Análisis Gráfico</a>
        <a href="logout.php" class="logout">🚪 Cerrar Sesión</a>
    </div>

    <div class="content">
        <div class="container">
            <h1>Análisis Gráfico</h1>
            <p>Gráfico de llamadas atendidas en la última semana.</p>

            <canvas id="llamadasChart" width="800" height="400"></canvas>

            <script>
                const ctx = document.getElementById('llamadasChart').getContext('2d');
                const llamadasChart = new Chart(ctx, {
                    type: 'bar',
                    data: {
                        labels: ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'],
                        datasets: [{
                            label: 'Llamadas Atendidas',
                            data: [1200, 1500, 1300, 1700, 1600, 900, 800],
                            backgroundColor: 'rgba(15, 188, 249, 0.7)',
                            borderColor: 'rgba(15, 188, 249, 1)',
                            borderWidth: 1,
                            borderRadius: 5
                        }]
                    },
                    options: {
                        scales: {
                            y: {
                                beginAtZero: true,
                                ticks: { stepSize: 200 }
                            }
                        },
                        plugins: {
                            legend: {
                                display: true,
                                position: 'top',
                                labels: {
                                    font: { size: 14 },
                                    color: '#333'
                                }
                            },
                            tooltip: {
                                enabled: true
                            }
                        }
                    }
                });
            </script>
        </div>
    </div>
</body>
</html>
