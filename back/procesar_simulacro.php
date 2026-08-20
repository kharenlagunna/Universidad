<?php
session_start();
require_once "conexion.php";

if (!isset($_SESSION['usuario']) || !in_array($_SESSION['rol'], ['admin', 'visor'])) {
    header("Location: login.php");
    exit();
}

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $usuario = $_SESSION['usuario'];
    $grupo = $_POST['grupo_referencia'] ?? '';
    $modulo = $_POST['modulo'] ?? '';
    $tipo_prueba = $_POST['tipo_prueba'] ?? '';
    $cantidad = intval($_POST['cantidad'] ?? 0);

    // El tiempo viene como "XX minutos"
    $tiempoStr = $_POST['tiempo'] ?? '0';
    $tiempo_minutos = (int) filter_var($tiempoStr, FILTER_SANITIZE_NUMBER_INT);

    if ($grupo && $modulo && $tipo_prueba && $cantidad > 0) {
        // Insertar intento
        $stmt = $conn->prepare("INSERT INTO simulacros_intentos 
            (usuario, grupo_referencia, modulo, tipo_prueba, cantidad, tiempo, fecha_inicio, finalizado_manual) 
            VALUES (?,?,?,?,?,?,NOW(),0)");
        $stmt->bind_param("ssssii", $usuario, $grupo, $modulo, $tipo_prueba, $cantidad, $tiempo_minutos);
        $stmt->execute();
        $intento_id = $stmt->insert_id;
        $stmt->close();

        // Seleccionar preguntas aleatorias
        $stmt = $conn->prepare("SELECT id FROM preguntas 
                                WHERE grupo_referencia=? AND modulo=? AND tipo_prueba=? 
                                ORDER BY RAND() LIMIT ?");
        $stmt->bind_param("sssi", $grupo, $modulo, $tipo_prueba, $cantidad);
        $stmt->execute();
        $result = $stmt->get_result();

        while ($row = $result->fetch_assoc()) {
            $id_pregunta = $row['id'];
            $stmt2 = $conn->prepare("INSERT INTO simulacros_respuestas (intento_id, pregunta_id) VALUES (?,?)");
            $stmt2->bind_param("ii", $intento_id, $id_pregunta);
            $stmt2->execute();
            $stmt2->close();
        }

        $stmt->close();

        // Redirigir al simulacro
        header("Location: simulacro_pregunta.php?intento_id=".$intento_id."&pregunta_index=0");
        exit();
    } else {
        echo "<p>Error: Debes completar todos los campos.</p>";
        echo "<a href='simulacro_inicio.php'>Volver</a>";
    }
} else {
    header("Location: simulacro_inicio.php");
    exit();
}
?>
