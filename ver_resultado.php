<?php
session_start();
require_once "conexion.php";

// Validar intento_id recibido por GET
if (!isset($_GET['intento_id']) || !is_numeric($_GET['intento_id'])) {
    header("Location: simulacro_historial.php");
    exit();
}

$intento_id = intval($_GET['intento_id']);

// Guardar en sesión el intento seleccionado
$_SESSION['intento_id'] = $intento_id;

// Redirigir a la página de resultados
header("Location: simulacro_resultados.php");
exit();
