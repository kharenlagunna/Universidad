<?php
session_start();

// Validar si el usuario está logueado y es admin
if (!isset($_SESSION['usuario']) || $_SESSION['rol'] !== 'admin') {
    header("Location: login.php");
    exit();
}

// Verificar si se subió un archivo
if (!isset($_FILES['archivo']) || $_FILES['archivo']['error'] !== UPLOAD_ERR_OK) {
    die("Error: No se subió ningún archivo válido.");
}

require 'vendor/autoload.php';
use PhpOffice\PhpSpreadsheet\IOFactory;

// Ruta temporal del archivo
$archivoTmp = $_FILES['archivo']['tmp_name'];

// Leer el archivo Excel
try {
    $spreadsheet = IOFactory::load($archivoTmp);
    $hoja = $spreadsheet->getActiveSheet();
    $filas = $hoja->toArray(null, true, true, true);
} catch (Exception $e) {
    die("Error al leer el archivo: " . $e->getMessage());
}

// Validar encabezados
$encabezadosEsperados = ['Columna 1', 'Columna 2', 'Columna 3', 'Columna 4'];
$encabezadosArchivo = array_values($filas[1]);

if ($encabezadosArchivo !== $encabezadosEsperados) {
    die("Error: El archivo no tiene los encabezados correctos. 
        Asegúrate de usar la plantilla proporcionada.");
}

// Procesar filas (desde la segunda fila)
$datos = [];
for ($i = 2; $i <= count($filas); $i++) {
    $fila = $filas[$i];
    if (!empty($fila['A']) || !empty($fila['B']) || !empty($fila['C']) || !empty($fila['D'])) {
        $datos[] = [
            'columna1' => trim($fila['A']),
            'columna2' => trim($fila['B']),
            'columna3' => trim($fila['C']),
            'columna4' => trim($fila['D']),
        ];
    }
}

// Aquí podrías insertar en la base de datos
/*
require 'conexion.php';
foreach ($datos as $fila) {
    $stmt = $conn->prepare("INSERT INTO tu_tabla (columna1, columna2, columna3, columna4) VALUES (?, ?, ?, ?)");
    $stmt->bind_param("ssss", $fila['columna1'], $fila['columna2'], $fila['columna3'], $fila['columna4']);
    $stmt->execute();
}
*/

// Mostrar confirmación
echo "<h2>Archivo procesado correctamente</h2>";
echo "<p>Se encontraron <strong>" . count($datos) . "</strong> filas con datos válidos.</p>";
echo "<a href='cargar_informacion.php'>Volver</a>";
