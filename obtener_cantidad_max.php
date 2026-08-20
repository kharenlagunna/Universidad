<?php
session_start();
require_once "conexion.php";

if (!isset($_SESSION['usuario'])) {
    header("HTTP/1.1 403 Forbidden");
    exit();
}

$grupo = $_GET['grupo'] ?? '';
$modulo = $_GET['modulo'] ?? '';
$tipo = $_GET['tipo_prueba'] ?? '';

$max = 0;

if($grupo && $modulo && $tipo){
    $stmt = $conn->prepare("SELECT COUNT(*) AS total FROM preguntas 
                            WHERE grupo_referencia = ? 
                              AND modulo = ? 
                              AND tipo_prueba = ?");
    $stmt->bind_param("sss", $grupo, $modulo, $tipo);
    $stmt->execute();
    $result = $stmt->get_result();
    if($row = $result->fetch_assoc()){
        $max = (int)$row['total'];
    }
}

header('Content-Type: application/json');
echo json_encode(["max" => $max]);
