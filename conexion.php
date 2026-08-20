<?php
// conexion.php
$servername = "localhost";
$username_db = "root";
$password_db = "";
$dbname = "proyecto_saber_pro_tyt";

$conn = new mysqli($servername, $username_db, $password_db, $dbname);
if ($conn->connect_error) {
    die("Conexión fallida: " . $conn->connect_error);
}
// Asegura charset
$conn->set_charset("utf8mb4");
