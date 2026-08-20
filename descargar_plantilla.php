<?php
$rutaArchivo = __DIR__ . "/templates/plantilla.xlsx";

if (file_exists($rutaArchivo)) {
    header('Content-Description: File Transfer');
    header('Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    header('Content-Disposition: attachment; filename="plantilla.xlsx"');
    header('Content-Length: ' . filesize($rutaArchivo));
    readfile($rutaArchivo);
    exit;
} else {
    echo "No se encontró la plantilla.";
}
?>
