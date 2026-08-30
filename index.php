<?php
session_start();

if (isset($_SESSION['usuario'])) {
    $destino = $_SESSION['rol'] === 'admin'
        ? 'admin/dashboard_resultados.php'
        : 'visor/dashboard_visor.php';
    header("Location: $destino");
} else {
    header("Location: auth/login.php");
}
exit();
