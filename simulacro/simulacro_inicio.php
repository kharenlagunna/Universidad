<?php
session_start();
require_once __DIR__ . '/../conexion.php';

if (!isset($_SESSION['usuario']) || !in_array($_SESSION['rol'], ['admin', 'visor'])) {
    header("Location: ../auth/login.php");
    exit();
}

$rol = $_SESSION['rol'];
$usuario = $_SESSION['usuario'];

$tiposPrueba = $conn->query("SELECT id, nombre FROM tipos_prueba ORDER BY nombre ASC");
$competencias = $conn->query("SELECT id, nombre FROM competencias ORDER BY nombre ASC");
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<title>Simulacro - Inicio</title>
<link rel="stylesheet" href="../estilos.css" />
<link rel="icon" href="../favicon.svg" type="image/svg+xml">
<link rel="alternate icon" href="../favicon.ico">
<link rel="apple-touch-icon" href="../apple-touch-icon.png">
<script>
document.addEventListener("DOMContentLoaded", function () {
    const tipoSelect = document.getElementById("tipo_prueba_id");
    const competenciaSelect = document.getElementById("competencia_id");
    const cantidadInput = document.getElementById("cantidad");
    const tiempoInput = document.getElementById("tiempo");
    const avisoSinPreguntas = document.getElementById("avisoSinPreguntas");
    const botonIniciar = document.getElementById("botonIniciar");

    function consultarDisponibilidad() {
        cantidadInput.value = "";
        tiempoInput.value = "";
        avisoSinPreguntas.style.display = "none";
        botonIniciar.disabled = true;

        if (!tipoSelect.value || !competenciaSelect.value) {
            return;
        }

        fetch("obtener_cantidad_max.php?tipo_prueba_id=" + encodeURIComponent(tipoSelect.value) + "&competencia_id=" + encodeURIComponent(competenciaSelect.value))
            .then(res => res.json())
            .then(data => {
                if (data.max && data.max > 0) {
                    cantidadInput.value = data.max;
                    tiempoInput.value = data.duracion_minutos + " minutos";
                    botonIniciar.disabled = false;
                } else {
                    avisoSinPreguntas.style.display = "block";
                }
            });
    }

    tipoSelect.addEventListener("change", consultarDisponibilidad);
    competenciaSelect.addEventListener("change", consultarDisponibilidad);
});
</script>
</head>
<body>
<?php require __DIR__ . '/../sidebar.php'; ?>

<div class="content">
    <div class="contenedor-derecho">
        <h2>Simulacro Saber Pro y T&T</h2>
        <p>Elige el tipo de prueba y la competencia que quieres presentar. El sistema te mostrará cuántas preguntas y cuánto tiempo tendrás antes de iniciar.</p>

        <form action="procesar_simulacro.php" method="post">
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

            <label for="cantidad">Cantidad de preguntas:</label>
            <input type="number" id="cantidad" name="cantidad" readonly required>

            <label for="tiempo">Tiempo asignado:</label>
            <input type="text" id="tiempo" name="tiempo" readonly required>

            <p id="avisoSinPreguntas" class="error" style="display:none;">
                Todavía no hay preguntas cargadas para esa combinación de tipo de prueba y competencia.
            </p>

            <button type="submit" class="btn" id="botonIniciar" disabled>Iniciar simulacro</button>
        </form>
    </div>
</div>
</body>
</html>
