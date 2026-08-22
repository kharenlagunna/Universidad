<?php
/**
 * PLANTILLA de configuración de correo (SMTP) para la recuperación de contraseña.
 *
 * Este archivo SÍ se sube al repositorio, como ejemplo. El archivo real que
 * usa la aplicación es "mail_config.php" (ignorado por git, ver .gitignore)
 * con tus credenciales verdaderas.
 *
 * Para usarlo:
 *   1. Copia este archivo como mail_config.php
 *   2. Reemplaza los valores de ejemplo con los datos reales de tu proveedor.
 *
 * Ejemplo con Gmail:
 *   host       -> 'smtp.gmail.com'
 *   port       -> 587
 *   encryption -> 'tls'
 *   username   -> tu correo completo, ej. 'universidad@gmail.com'
 *   password   -> una "contraseña de aplicación" (NO tu contraseña normal).
 *                 Se genera en: https://myaccount.google.com/apppasswords
 *                 (requiere tener activada la verificación en 2 pasos).
 *
 * "mail_config.php" contiene credenciales sensibles: nunca lo subas a un
 * repositorio público ni lo compartas.
 */

return [
    'host'       => 'smtp.gmail.com',      // Servidor SMTP de tu proveedor
    'port'       => 587,                    // 587 (TLS) o 465 (SSL)
    'encryption' => 'tls',                  // 'tls' o 'ssl'
    'username'   => 'CAMBIA_ESTE_CORREO@gmail.com',
    'password'   => 'CAMBIA_ESTA_CONTRASENA_DE_APLICACION',
    'from_email' => 'CAMBIA_ESTE_CORREO@gmail.com',
    'from_name'  => 'Universidad - Simulacro Saber Pro',
];
