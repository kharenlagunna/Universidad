<?php
session_start();
require_once "conexion.php";

if (!isset($_SESSION['usuario'])) {
    header("Location: login.php");
    exit();
}

$usuario = $_SESSION['usuario'];
$rol = $_SESSION['rol'] ?? 'visor'; // Para mostrar la barra lateral

// Validar POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header("Location: simulacro_inicio.php");
    exit();
}

// Recibir filtros
$grupo_referencia = $_POST['grupo_referencia'] ?? '';
$modulo = $_POST['modulo'] ?? '';
$tipo_prueba = $_POST['tipo_prueba'] ?? '';
$cantidad = intval($_POST['cantidad'] ?? 0);
$duracion_minutos = intval($_POST['cantidad'] ?? 0); // 1 min por pregunta

$error = '';
if (!$grupo_referencia || !$modulo || !$tipo_prueba || $cantidad <= 0) {
    $error = "Selecciona todos los filtros correctamente.";
} else {
    // Obtener preguntas según filtros
    $stmt = $conn->prepare("
        SELECT id 
        FROM preguntas 
        WHERE grupo_referencia = ? AND modulo = ? AND tipo_prueba = ? 
        ORDER BY RAND() 
        LIMIT ?
    ");
    $stmt->bind_param("sssi", $grupo_referencia, $modulo, $tipo_prueba, $cantidad);
    $stmt->execute();
    $result = $stmt->get_result();
    $preguntas = $result->fetch_all(MYSQLI_ASSOC);

    if (count($preguntas) === 0) {
        $error = "No hay preguntas disponibles para los filtros seleccionados.";
    } else {
        // Crear intento
        $stmt = $conn->prepare("
            INSERT INTO simulacros_intentos 
            (usuario, fecha_inicio, total_preguntas, duracion_minutos, filtro_grupo_referencia, filtro_modulo, filtro_tipo_prueba) 
            VALUES (?,?,?, ?, ?, ?, ?)
        ");
        $fecha_inicio = date('Y-m-d H:i:s');
        $total_preguntas = count($preguntas);
        $stmt->bind_param("ssiiiss", $usuario, $fecha_inicio, $total_preguntas, $duracion_minutos, $grupo_referencia, $modulo, $tipo_prueba);
        $stmt->execute();
        $intento_id = $conn->insert_id;

        // Insertar cada pregunta en simulacros_respuestas
        $stmt = $conn->prepare("INSERT INTO simulacros_respuestas (intento_id, pregunta_id) VALUES (?, ?)");
        foreach ($preguntas as $p) {
            $stmt->bind_param("ii", $intento_id, $p['id']);
            $stmt->execute();
        }

        // Redirigir a la primera pregunta
        header("Location: simulacro_pregunta.php?intento_id=$intento_id&pregunta_index=0");
        exit();
    }
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Simulacro - Inicio</title>
<link rel="stylesheet" href="estilos.css">
</head>
<body>
<div class="sidebar">
    <h2>Panel <?php echo ($rol==='admin')?'Admin':'Visor'; ?></h2>
    <?php if($rol==='admin'): ?>
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
        <?php if($error): ?>
            <div class="alert-warning" style="margin:10px 0; padding:10px; border-radius:5px;">
                ⚠️ <?= htmlspecialchars($error) ?>
            </div>
            <a href="simulacro_inicio.php" class="btn">⬅ Volver</a>
        <?php endif; ?>
    </div>
</div>
</body>
</html>
