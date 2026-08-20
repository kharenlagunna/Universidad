<?php
session_start();
if (!isset($_SESSION['usuario']) || $_SESSION['rol'] !== 'admin') {
    header("Location: login.php");
    exit();
}
require_once "conexion.php";

$archivoCSV = __DIR__ . "/templates/preguntas.csv";
$delimitador = ",";

// Validar si existe el archivo
if (!file_exists($archivoCSV)) {
    die("No se encontró el archivo CSV en: " . $archivoCSV);
}

// 🔹 Eliminar datos y reiniciar IDs
$conn->query("DELETE FROM opciones");
$conn->query("DELETE FROM preguntas");
$conn->query("ALTER TABLE opciones AUTO_INCREMENT = 1");
$conn->query("ALTER TABLE preguntas AUTO_INCREMENT = 1");

echo "Datos anteriores eliminados.<br>";

// Abrir CSV
$handle = fopen($archivoCSV, "r");
if (!$handle) {
    die("No se pudo abrir el archivo CSV.");
}

$primeraFila = true;
$totalPreguntas = 0;
$totalOpciones = 0;

while (($data = fgetcsv($handle, 2000, $delimitador)) !== FALSE) {
    if ($primeraFila) {
        $primeraFila = false;
        continue;
    }

    if (count($data) < 11) {
        continue;
    }

    list($_id_csv, $componente, $modulo, $grupo_ref, $tipo_prueba, $enunciado,
         $op_a, $op_b, $op_c, $op_d, $correcta) = $data;

    // Insertar pregunta
    $stmt = $conn->prepare("
        INSERT INTO preguntas (enunciado, componente, grupo_referencia, modulo, tipo_prueba, puntaje)
        VALUES (?, ?, ?, ?, ?, 1.0)
    ");
    $stmt->bind_param("sssss", $enunciado, $componente, $grupo_ref, $modulo, $tipo_prueba);
    $stmt->execute();

    $id_pregunta_insertada = $stmt->insert_id;
    $stmt->close();
    $totalPreguntas++;

    // Insertar opciones
    $opciones = [
        ['A', $op_a],
        ['B', $op_b],
        ['C', $op_c],
        ['D', $op_d]
    ];

    foreach ($opciones as $op) {
        $es_correcta = (strtoupper(trim($correcta)) == $op[0]) ? 1 : 0;
        $stmt = $conn->prepare("
            INSERT INTO opciones (pregunta_id, etiqueta, texto, es_correcta)
            VALUES (?, ?, ?, ?)
        ");
        $stmt->bind_param("issi", $id_pregunta_insertada, $op[0], $op[1], $es_correcta);
        $stmt->execute();
        $stmt->close();
        $totalOpciones++;
    }
}

fclose($handle);

echo "<b>Importación finalizada</b><br>";
echo "Preguntas insertadas: $totalPreguntas<br>";
echo "Opciones insertadas: $totalOpciones<br>";

$conn->close();
?>
