<?php
require_once "conexion.php";

$grupo = isset($_GET['grupo']) ? trim($_GET['grupo']) : '';
$modulo = isset($_GET['modulo']) ? trim($_GET['modulo']) : '';
$tipo   = isset($_GET['tipo_prueba']) ? trim($_GET['tipo_prueba']) : '';

$max = 0;

if ($grupo && $modulo && $tipo) {
    $stmt = $conn->prepare("SELECT COUNT(*) AS total 
                            FROM preguntas 
                            WHERE grupo = ? 
                              AND modulo = ? 
                              AND tipo_prueba = ?");
    $stmt->bind_param("sss", $grupo, $modulo, $tipo);
    $stmt->execute();
    $result = $stmt->get_result();
    if ($row = $result->fetch_assoc()) {
        $max = (int)$row['total'];
    }
    $stmt->close();
}

header('Content-Type: application/json');
echo json_encode(["max" => $max]);
?>
