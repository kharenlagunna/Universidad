<?php
session_start();

if (isset($_SESSION['usuario'])) {
    $destino = 'admin/dashboard_resultados.php';
    header("Location: $destino");
} else {
    header("Location: auth/login.php");
}
exit();
