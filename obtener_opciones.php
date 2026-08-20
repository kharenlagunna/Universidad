<?php
session_start();
require_once "conexion.php";

if (!isset($_SESSION['usuario'])) {
    header("HTTP/1.1 403 Forbidden");
    exit();
}

$grupo = isset($_GET['grupo']) ? trim($_GET['grupo']) : '';
$modulo = isset($_GET['modulo']) ? trim($_GET['modulo']) : '';

// Si solo envían grupo, devolvemos los módulos
if ($grupo && !$modulo) {
    $stmt = $conn->prepare("SELECT DISTINCT modulo FROM preguntas WHERE grupo_referencia = ? AND modulo <> '' ORDER BY modulo ASC");
    $stmt->bind_param("s", $grupo);
    $stmt->execute();
    $result = $stmt->get_result();
    $modulos = [];
    while ($row = $result->fetch_assoc()) {
        $modulos[] = $row['modulo'];
    }
    echo json_encode($modulos);
    exit();
}

// Si envían grupo + módulo, devolvemos los tipos de prueba
if ($grupo && $modulo) {
    $stmt = $conn->prepare("SELECT DISTINCT tipo_prueba FROM preguntas WHERE grupo_referencia = ? AND modulo = ? AND tipo_prueba <> '' ORDER BY tipo_prueba ASC");
    $stmt->bind_param("ss", $grupo, $modulo);
    $stmt->execute();
    $result = $stmt->get_result();
    $tipos = [];
    while ($row = $result->fetch_assoc()) {
        $tipos[] = $row['tipo_prueba'];
    }
    echo json_encode($tipos);
    exit();
}

// Si no hay parámetros válidos, devolvemos un array vacío
echo json_encode([]);
