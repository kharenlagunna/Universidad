<?php
require_once "conexion.php";

$grupo = isset($_GET['grupo']) ? trim($_GET['grupo']) : '';
$modulo = isset($_GET['modulo']) ? trim($_GET['modulo']) : '';

$opciones = [];

if ($grupo && !$modulo) {
    // Obtener módulos filtrados por grupo
    $stmt = $conn->prepare("SELECT DISTINCT modulo FROM preguntas WHERE grupo_referencia = ? AND modulo <> '' ORDER BY modulo ASC");
    $stmt->bind_param("s", $grupo);
    $stmt->execute();
    $result = $stmt->get_result();
    while ($row = $result->fetch_assoc()) {
        $opciones[] = $row['modulo'];
    }
}
elseif ($grupo && $modulo) {
    // Obtener tipos de prueba filtrados por grupo y módulo
    $stmt = $conn->prepare("SELECT DISTINCT tipo_prueba FROM preguntas WHERE grupo_referencia = ? AND modulo = ? AND tipo_prueba <> '' ORDER BY tipo_prueba ASC");
    $stmt->bind_param("ss", $grupo, $modulo);
    $stmt->execute();
    $result = $stmt->get_result();
    while ($row = $result->fetch_assoc()) {
        $opciones[] = $row['tipo_prueba'];
    }
}

header('Content-Type: application/json');
echo json_encode($opciones);
