<?php
session_start();
require_once "conexion.php";

if (!isset($_SESSION['usuario'])) {
    header("Location: login.php");
    exit();
}

$usuario = $_SESSION['usuario'];
$rol = $_SESSION['rol'] ?? 'visor';

if (!isset($_GET['intento_id']) || !isset($_GET['pregunta_index'])) {
    header("Location: simulacro_inicio.php");
    exit();
}

$intento_id = intval($_GET['intento_id']);
$pregunta_index = intval($_GET['pregunta_index']);

// Info del intento (solo si pertenece al usuario logueado)
$stmt = $conn->prepare("SELECT fecha_inicio, duracion_minutos FROM simulacros_intentos WHERE id = ? AND usuario = ?");
$stmt->bind_param("is", $intento_id, $usuario);
$stmt->execute();
$res_intento = $stmt->get_result()->fetch_assoc();

if (!$res_intento) {
    header("Location: simulacro_inicio.php");
    exit();
}

// Tiempo restante
$fecha_inicio = strtotime($res_intento['fecha_inicio']);
$tiempo_limite_segundos = intval($res_intento['duracion_minutos']) * 60;
$tiempo_fin = $fecha_inicio + $tiempo_limite_segundos;
$ahora = time();
$tiempo_restante = $tiempo_fin - $ahora;

if ($tiempo_restante <= 0) {
    header("Location: simulacro_resultados.php?intento_id=$intento_id");
    exit();
}

// Total preguntas
$stmt = $conn->prepare("SELECT COUNT(*) AS total FROM simulacros_respuestas WHERE intento_id = ?");
$stmt->bind_param("i", $intento_id);
$stmt->execute();
$total_preguntas = $stmt->get_result()->fetch_assoc()['total'];

if ($pregunta_index >= $total_preguntas) {
    header("Location: simulacro_resultados.php?intento_id=$intento_id");
    exit();
}

// Pregunta actual
$stmt = $conn->prepare("
    SELECT p.id, p.enunciado
    FROM simulacros_respuestas sr
    INNER JOIN preguntas p ON sr.pregunta_id = p.id
    WHERE sr.intento_id = ?
    ORDER BY sr.id
    LIMIT ?,1
");
$stmt->bind_param("ii", $intento_id, $pregunta_index);
$stmt->execute();
$pregunta_actual = $stmt->get_result()->fetch_assoc();

// Opciones
$stmt = $conn->prepare("SELECT id, etiqueta, texto FROM opciones WHERE pregunta_id = ? ORDER BY etiqueta");
$stmt->bind_param("i", $pregunta_actual['id']);
$stmt->execute();
$opciones = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

// Respuesta existente
$stmt = $conn->prepare("SELECT opcion_elegida FROM simulacros_respuestas WHERE intento_id = ? AND pregunta_id = ?");
$stmt->bind_param("ii", $intento_id, $pregunta_actual['id']);
$stmt->execute();
$respuesta_existente = $stmt->get_result()->fetch_assoc();
$opcion_elegida = $respuesta_existente ? $respuesta_existente['opcion_elegida'] : null;
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Pregunta <?= $pregunta_index + 1 ?> / <?= $total_preguntas ?></title>
<link rel="stylesheet" href="estilos.css">
<link rel="icon" href="favicon.svg" type="image/svg+xml">
<link rel="alternate icon" href="favicon.ico">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
<script>
let tiempoRestante = <?= $tiempo_restante ?>;
function actualizarTimer() {
    if (tiempoRestante <= 0) {
        alert("⏰ El tiempo ha finalizado");
        window.location.href = "simulacro_resultados.php?intento_id=<?= $intento_id ?>";
    } else {
        let minutos = Math.floor(tiempoRestante / 60);
        let segundos = tiempoRestante % 60;
        document.getElementById("timer").innerText = 
            (minutos<10?"0":"")+minutos+":"+(segundos<10?"0":"")+segundos;
        tiempoRestante--;
    }
}
setInterval(actualizarTimer,1000);
window.onload = actualizarTimer;
</script>
</head>
<body>
<?php require __DIR__ . '/sidebar.php'; ?>

<div class="content">
    <div class="contenedor-derecho">
        <h2>Pregunta <?= $pregunta_index + 1 ?> de <?= $total_preguntas ?></h2>
        <p class="enunciado"><?= htmlspecialchars($pregunta_actual['enunciado']) ?></p>

        <div class="timer-box">
            ⏳ Tiempo restante: <span id="timer"></span>
        </div>

        <form method="post" action="guardar_respuesta.php" class="form-pregunta">
            <input type="hidden" name="intento_id" value="<?= $intento_id ?>">
            <input type="hidden" name="pregunta_id" value="<?= $pregunta_actual['id'] ?>">
            <input type="hidden" name="pregunta_index" value="<?= $pregunta_index ?>">

            <?php foreach ($opciones as $op): ?>
                <div class="opcion">
                    <label>
                        <input type="radio" name="opcion_elegida" value="<?= $op['etiqueta'] ?>" 
                            <?= ($opcion_elegida == $op['etiqueta'])?'checked':'' ?>>
                        <span class="etiqueta"><?= htmlspecialchars($op['etiqueta']) ?>)</span> 
                        <?= htmlspecialchars($op['texto']) ?>
                    </label>
                </div>
            <?php endforeach; ?>

            <div class="acciones">
                <button type="submit" name="accion" value="guardar" class="btn">💾 Guardar y continuar</button>
                <button type="submit" name="accion" value="finalizar" class="btn-peligro">🚪 Guardar y finalizar</button>
            </div>
        </form>
    </div>
</div>
</body>
</html>
