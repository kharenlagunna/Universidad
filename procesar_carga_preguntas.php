<?php
session_start();
if (!isset($_SESSION['usuario']) || $_SESSION['rol'] !== 'admin') {
    header("Location: login.php");
    exit();
}
require_once 'conexion.php';

if (!isset($_FILES['archivo']) || $_FILES['archivo']['error'] !== UPLOAD_ERR_OK) {
    die("Error: No se subió ningún archivo válido.");
}

require 'vendor/autoload.php';
use PhpOffice\PhpSpreadsheet\IOFactory;

$archivoTmp = $_FILES['archivo']['tmp_name'];

try {
    $spreadsheet = IOFactory::load($archivoTmp);
    $hoja = $spreadsheet->getActiveSheet();
    $filas = $hoja->toArray(null, true, true, true);
} catch (Exception $e) {
    die("Error al leer el archivo: " . $e->getMessage());
}

$esperados = ['Enunciado','GrupoReferencia','Modulo','TipoPrueba','OpcionA','OpcionB','OpcionC','OpcionD','Correcta','Puntaje'];
$encabezadosArchivo = array_map('trim', array_values($filas[1] ?? []));

if ($encabezadosArchivo !== $esperados) {
    die("Error: Encabezados inválidos. Usa la plantilla proporcionada.");
}

$insPregunta = $conn->prepare("INSERT INTO preguntas (enunciado, grupo_referencia, modulo, tipo_prueba, puntaje) VALUES (?, ?, ?, ?, ?)");
$insOpcion   = $conn->prepare("INSERT INTO opciones (pregunta_id, etiqueta, texto, es_correcta) VALUES (?, ?, ?, ?)");

$insertadas = 0;
for ($i = 2; $i <= count($filas); $i++) {
    $f = $filas[$i];
    if (!isset($f['A']) || trim($f['A']) === '') continue; // enunciado obligatorio

    $enunciado = trim($f['A']);
    $grupo = trim($f['B']);
    $modulo = trim($f['C']);
    $tipo = strtolower(trim($f['D']));
    if (!in_array($tipo, ['generica','especifica'])) $tipo = 'generica';

    $A = trim($f['E']); $B = trim($f['F']); $C = trim($f['G']); $D = trim($f['H']);
    $correcta = strtoupper(trim($f['I']));
    $puntaje = is_numeric($f['J']) ? (float)$f['J'] : 1.0;

    // Insertar pregunta
    $insPregunta->bind_param("ssssd", $enunciado, $grupo, $modulo, $tipo, $puntaje);
    $insPregunta->execute();
    $pid = $insPregunta->insert_id;

    // Insertar opciones
    $opcs = ['A'=>$A,'B'=>$B,'C'=>$C,'D'=>$D];
    foreach ($opcs as $etq=>$txt) {
        if ($txt === '') $txt = '-';
        $ok = ($etq === $correcta) ? 1 : 0;
        $insOpcion->bind_param("issi", $pid, $etq, $txt, $ok);
        $insOpcion->execute();
    }

    $insertadas++;
}

echo "<h2>¡Carga completa!</h2>";
echo "<p>Preguntas insertadas: <strong>{$insertadas}</strong></p>";
echo "<a href='admin_cargar_preguntas.php'>Volver</a>";
