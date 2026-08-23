<?php
session_start();
if (!isset($_SESSION['usuario']) || $_SESSION['rol'] !== 'admin') {
    header("Location: login.php");
    exit();
}
require_once 'conexion.php';
require_once 'lector_xlsx.php';

function volverConError(string $mensaje): void
{
    $_SESSION['flash_error'] = $mensaje;
    header("Location: admin_cargar_preguntas.php");
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header("Location: admin_cargar_preguntas.php");
    exit();
}

$tipoPruebaId = intval($_POST['tipo_prueba_id'] ?? 0);
$competenciaId = intval($_POST['competencia_id'] ?? 0);

if (!$tipoPruebaId || !$competenciaId) {
    volverConError("Selecciona el tipo de prueba y la competencia.");
}

if (!isset($_FILES['archivo']) || $_FILES['archivo']['error'] !== UPLOAD_ERR_OK) {
    volverConError("No se subió ningún archivo válido.");
}

try {
    $filas = leerFilasXlsx($_FILES['archivo']['tmp_name']);
} catch (RuntimeException $e) {
    volverConError("Error al leer el archivo: " . $e->getMessage());
}

$esperados = ['Enunciado', 'OpcionA', 'OpcionB', 'OpcionC', 'OpcionD', 'Correcta'];
$encabezados = array_map('trim', $filas[0] ?? []);
// Solo compara las primeras 6 columnas: si el admin dejó una columna extra
// (por ejemplo Puntaje) no rompe la validación.
if (array_slice($encabezados, 0, 6) !== $esperados) {
    volverConError("Encabezados inválidos. La primera fila debe ser: " . implode(', ', $esperados));
}

// Reemplaza solo las preguntas de esta combinación Tipo de Prueba + Competencia
// (el borrado de sus opciones es automático por la FK ON DELETE CASCADE).
$stmt = $conn->prepare("DELETE FROM preguntas WHERE tipo_prueba_id = ? AND competencia_id = ?");
$stmt->bind_param("ii", $tipoPruebaId, $competenciaId);
$stmt->execute();

$insPregunta = $conn->prepare("INSERT INTO preguntas (enunciado, tipo_prueba_id, competencia_id, puntaje) VALUES (?, ?, ?, 1.0)");
$insOpcion = $conn->prepare("INSERT INTO opciones (pregunta_id, etiqueta, texto, es_correcta) VALUES (?, ?, ?, ?)");

$insertadas = 0;
$filasOmitidas = 0;

for ($i = 1; $i < count($filas); $i++) {
    $f = $filas[$i];
    $enunciado = trim($f[0] ?? '');
    if ($enunciado === '') {
        continue; // fila vacía
    }

    $opA = trim($f[1] ?? '');
    $opB = trim($f[2] ?? '');
    $opC = trim($f[3] ?? '');
    $opD = trim($f[4] ?? '');
    $correcta = strtoupper(trim($f[5] ?? ''));

    if (!in_array($correcta, ['A', 'B', 'C', 'D'], true)) {
        $filasOmitidas++;
        continue;
    }

    $insPregunta->bind_param("sii", $enunciado, $tipoPruebaId, $competenciaId);
    $insPregunta->execute();
    $pid = $insPregunta->insert_id;

    $opciones = ['A' => $opA, 'B' => $opB, 'C' => $opC, 'D' => $opD];
    foreach ($opciones as $etiqueta => $texto) {
        if ($texto === '') {
            $texto = '-';
        }
        $esCorrecta = ($etiqueta === $correcta) ? 1 : 0;
        $insOpcion->bind_param("issi", $pid, $etiqueta, $texto, $esCorrecta);
        $insOpcion->execute();
    }

    $insertadas++;
}

$mensaje = "Se cargaron $insertadas preguntas.";
if ($filasOmitidas > 0) {
    $mensaje .= " Se omitieron $filasOmitidas filas con una respuesta correcta inválida (debe ser A, B, C o D).";
}

$_SESSION['flash_ok'] = $mensaje;
header("Location: admin_cargar_preguntas.php");
exit();
