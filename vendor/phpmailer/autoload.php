<?php
/**
 * Carga manual de PHPMailer (sin Composer).
 * El orden importa: Exception antes que SMTP y PHPMailer.
 */
require_once __DIR__ . '/src/Exception.php';
require_once __DIR__ . '/src/PHPMailer.php';
require_once __DIR__ . '/src/SMTP.php';
