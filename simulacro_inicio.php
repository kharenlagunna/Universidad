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
<link rel="icon" href="favicon.svg" type="image/svg+xml">
<link rel="alternate icon" href="favicon.ico">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
<script>
document.addEventListener("DOMContentLoaded", function(){
    const grupoSelect = document.getElementById("grupo_referencia");
    const moduloSelect = document.getElementById("modulo");
    const tipoSelect = document.getElementById("tipo_prueba");
    const cantidadInput = document.getElementById("cantidad");
    const tiempoInput = document.getElementById("tiempo");

    grupoSelect.addEventListener("change", function(){
        moduloSelect.innerHTML = '<option value="">-- Cargando... --</option>';
        tipoSelect.innerHTML = '<option value="">-- Seleccione módulo primero --</option>';
        cantidadInput.value = "";
        tiempoInput.value = "";

        fetch("obtener_opciones.php?grupo=" + encodeURIComponent(this.value))
        .then(res => res.json())
        .then(data => {
            moduloSelect.innerHTML = '<option value="">-- Seleccione --</option>';
            data.forEach(op => {
                moduloSelect.innerHTML += `<option value="${op}">${op}</option>`;
            });
        });
    });

    moduloSelect.addEventListener("change", function(){
        tipoSelect.innerHTML = '<option value="">-- Cargando... --</option>';
        cantidadInput.value = "";
        tiempoInput.value = "";

        fetch("obtener_opciones.php?grupo=" + encodeURIComponent(grupoSelect.value) + "&modulo=" + encodeURIComponent(this.value))
        .then(res => res.json())
        .then(data => {
            tipoSelect.innerHTML = '<option value="">-- Seleccione --</option>';
            data.forEach(op => {
                tipoSelect.innerHTML += `<option value="${op}">${op}</option>`;
            });
        });
    });

    tipoSelect.addEventListener("change", function(){
        cantidadInput.value = "";
        tiempoInput.value = "";

        fetch("obtener_cantidad_max.php?grupo=" + encodeURIComponent(grupoSelect.value) + "&modulo=" + encodeURIComponent(moduloSelect.value) + "&tipo_prueba=" + encodeURIComponent(this.value))
        .then(res => res.json())
        .then(data => {
            if(data.max){
                cantidadInput.value = data.max;
                tiempoInput.value = data.max + " minutos";
            }
        });
    });
});
</script>
</head>
<body>
<?php require __DIR__ . '/sidebar.php'; ?>

<div class="content">
    <div class="contenedor-derecho">
        <h2>Simulacro Saber Pro y TyT</h2>
        <p>Configura tu simulacro. Selecciona filtros y el sistema asignará la cantidad máxima de preguntas y el tiempo (1 minuto por cada pregunta).</p>

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
            <input type="number" id="cantidad" name="cantidad" readonly required>

            <label for="tiempo">Tiempo límite:</label>
            <input type="text" id="tiempo" name="tiempo" readonly required>

            <button type="submit" class="btn">Iniciar simulacro</button>
        </form>
    </div>
</div>
</body>
</html>
