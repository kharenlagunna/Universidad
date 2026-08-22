<?php
/**
 * Configuración de envío de correo (SMTP) para la recuperación de contraseña.
 *
 * ⚠️ IMPORTANTE: completa estos valores con los datos reales de tu proveedor
 * de correo antes de usar "Olvidé mi contraseña". Mientras tengan los
 * valores de ejemplo, el envío de correos fallará.
 *
 * Ejemplo con Gmail:
 *   MAIL_HOST     -> 'smtp.gmail.com'
 *   MAIL_PORT     -> 587
 *   MAIL_ENCRYPTION -> 'tls'
 *   MAIL_USERNAME -> tu correo completo, ej. 'universidad@gmail.com'
 *   MAIL_PASSWORD -> una "contraseña de aplicación" (NO tu contraseña normal).
 *                    Se genera en: https://myaccount.google.com/apppasswords
 *                    (requiere tener activada la verificación en 2 pasos).
 *
 * Este archivo contiene credenciales sensibles: no lo subas a un repositorio
 * público ni lo compartas.
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
