<?php
session_start();
require_once "conexion.php";

if (!isset($_SESSION['usuario']) || !in_array($_SESSION['rol'], ['admin', 'visor'])) {
    header("Location: login.php");
    exit();
}

$rol = $_SESSION['rol'];
$usuario = $_SESSION['usuario'];
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<title>Simulacro - Inicio</title>
<link rel="stylesheet" href="estilos.css" />
<script>
document.addEventListener("DOMContentLoaded", function(){
    const grupoSelect = document.getElementById("grupo_referencia");
    const moduloSelect = document.getElementById("modulo");
    const tipoSelect = document.getElementById("tipo_prueba");

    // Cuando cambie grupo
    grupoSelect.addEventListener("change", function(){
        moduloSelect.innerHTML = '<option value="">-- Cargando... --</option>';
        fetch("obtener_opciones.php?grupo=" + encodeURIComponent(this.value))
        .then(res => res.json())
        .then(data => {
            moduloSelect.innerHTML = '<option value="">-- Seleccione --</option>';
            data.forEach(op => {
                moduloSelect.innerHTML += `<option value="${op}">${op}</option>`;
            });
        });
    });

    // Cuando cambie módulo
    moduloSelect.addEventListener("change", function(){
        tipoSelect.innerHTML = '<option value="">-- Cargando... --</option>';
        fetch("obtener_opciones.php?grupo=" + encodeURIComponent(grupoSelect.value) + "&modulo=" + encodeURIComponent(this.value))
        .then(res => res.json())
        .then(data => {
            tipoSelect.innerHTML = '<option value="">-- Seleccione --</option>';
            data.forEach(op => {
                tipoSelect.innerHTML += `<option value="${op}">${op}</option>`;
            });
        });
    });
});
</script>
</head>
<body>
    <div class="sidebar">
        <h2>Panel <?php echo ($rol === 'admin') ? 'Admin' : 'Visor'; ?></h2>
        <?php if($rol === 'admin'): ?>
            <a href="dashboard_admin.php">🏠 Dashboard</a>
            <a href="cargar_informacion.php">📂 Cargar BD Saber Pro T&T</a>
            <a href="admin_cargar_preguntas.php">📝 Cargar Preguntas</a>
        <?php else: ?>
            <a href="dashboard_visor.php">🏠 Dashboard</a>
        <?php endif; ?>
        <a href="analisis_grafico.php">📊 Análisis Gráfico</a>
        <a href="simulacro_inicio.php" class="active">🧪 Simulador Prueba SaberPro T&T</a>
        <a href="logout.php" class="logout">🚪 Cerrar Sesión</a>
    </div>

    <div class="content">
        <div class="contenedor-derecho" style="max-width:820px">
            <h2>Simulacro Saber Pro y TyT</h2>
            <p>Configura tu simulacro. Selecciona filtros y define la cantidad de preguntas y el tiempo límite.</p>

            <form action="procesar_simulacro.php" method="post">
                <label for="grupo_referencia">Grupo de referencia:</label>
                <select id="grupo_referencia" name="grupo_referencia" required>
                    <option value="">-- Seleccione --</option>
                    <?php
                    $result = $conn->query("SELECT DISTINCT grupo_referencia FROM preguntas WHERE grupo_referencia <> '' ORDER BY grupo_referencia ASC");
                    while ($row = $result->fetch_assoc()) {
                        echo '<option value="'.htmlspecialchars($row['grupo_referencia']).'">'.htmlspecialchars($row['grupo_referencia']).'</option>';
                    }
                    ?>
                </select>

                <label for="modulo">Módulo:</label>
                <select id="modulo" name="modulo" required>
                    <option value="">-- Seleccione grupo primero --</option>
                </select>

                <label for="tipo_prueba">Tipo de prueba:</label>
                <select id="tipo_prueba" name="tipo_prueba" required>
                    <option value="">-- Seleccione módulo primero --</option>
                </select>

                <label for="cantidad">Cantidad de preguntas:</label>
                <input type="number" id="cantidad" name="cantidad" value="10" min="1" max="100" required>

                <label for="tiempo">Tiempo límite (minutos):</label>
                <input type="number" id="tiempo" name="tiempo" value="30" min="1" max="240" required>

                <button type="submit" class="btn">Iniciar simulacro</button>
            </form>
        </div>
    </div>
</body>
</html>
