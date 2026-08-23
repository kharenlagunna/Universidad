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

// Catálogos: nombre (en minúsculas, sin espacios extra) => id
$tiposPrueba = [];
$res = $conn->query("SELECT id, nombre FROM tipos_prueba");
while ($row = $res->fetch_assoc()) {
    $tiposPrueba[mb_strtolower(trim($row['nombre']))] = (int) $row['id'];
}

$competencias = [];
$res = $conn->query("SELECT id, nombre FROM competencias");
while ($row = $res->fetch_assoc()) {
    $competencias[mb_strtolower(trim($row['nombre']))] = (int) $row['id'];
}

// 🔹 Eliminar banco de preguntas actual y reiniciar IDs
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
$filasOmitidas = [];
$numeroFila = 1;

while (($data = fgetcsv($handle, 2000, $delimitador)) !== FALSE) {
    $numeroFila++;

    if ($primeraFila) {
        $primeraFila = false;
        $numeroFila = 1;
        continue;
    }

    // Enunciado, TipoPrueba, Competencia, OpcionA, OpcionB, OpcionC, OpcionD, Correcta, Puntaje
    if (count($data) < 9) {
        $filasOmitidas[] = "Fila $numeroFila: columnas insuficientes.";
        continue;
    }

    list($enunciado, $tipoPruebaNombre, $competenciaNombre, $op_a, $op_b, $op_c, $op_d, $correcta, $puntaje) = $data;

    $tipoPruebaId = $tiposPrueba[mb_strtolower(trim($tipoPruebaNombre))] ?? null;
    $competenciaId = $competencias[mb_strtolower(trim($competenciaNombre))] ?? null;

    if (!$tipoPruebaId) {
        $filasOmitidas[] = "Fila $numeroFila: tipo de prueba \"$tipoPruebaNombre\" no reconocido (debe ser Saber Pro o Saber TyT).";
        continue;
    }
    if (!$competenciaId) {
        $filasOmitidas[] = "Fila $numeroFila: competencia \"$competenciaNombre\" no reconocida.";
        continue;
    }

    $puntajeValor = is_numeric($puntaje) ? (float) $puntaje : 1.0;

    // Insertar pregunta
    $stmt = $conn->prepare("
        INSERT INTO preguntas (enunciado, tipo_prueba_id, competencia_id, puntaje)
        VALUES (?, ?, ?, ?)
    ");
    $stmt->bind_param("siid", $enunciado, $tipoPruebaId, $competenciaId, $puntajeValor);
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

if (!empty($filasOmitidas)) {
    echo "<br><b>Filas omitidas (" . count($filasOmitidas) . "):</b><br>";
    foreach ($filasOmitidas as $mensaje) {
        echo htmlspecialchars($mensaje) . "<br>";
    }
}

$conn->close();
?>
