<?php
require_once __DIR__ . '/vendor/phpmailer/autoload.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception as PHPMailerException;

/**
 * Envía el correo con el enlace para restablecer la contraseña.
 *
 * @return array{ok:bool, error:?string}
 */
function enviarCorreoRecuperacion(string $emailDestino, string $usuarioDestino, string $enlace): array
{
    $config = require __DIR__ . '/mail_config.php';

    $mail = new PHPMailer(true);
    try {
        $mail->isSMTP();
        $mail->Host       = $config['host'];
        $mail->SMTPAuth   = true;
        $mail->Username   = $config['username'];
        $mail->Password   = $config['password'];
        $mail->SMTPSecure = $config['encryption'];
        $mail->Port       = $config['port'];
        $mail->CharSet    = 'UTF-8';

        $mail->setFrom($config['from_email'], $config['from_name']);
        $mail->addAddress($emailDestino, $usuarioDestino);

        $mail->isHTML(true);
        $mail->Subject = 'Recupera tu contraseña - Universidad';
        $mail->Body    = '
            <p>Hola <strong>' . htmlspecialchars($usuarioDestino) . '</strong>,</p>
            <p>Recibimos una solicitud para restablecer tu contraseña. Haz clic en el siguiente enlace para crear una nueva (válido por 1 hora):</p>
            <p><a href="' . htmlspecialchars($enlace) . '">' . htmlspecialchars($enlace) . '</a></p>
            <p>Si tú no solicitaste esto, puedes ignorar este correo.</p>
        ';
        $mail->AltBody = "Recupera tu contraseña usando este enlace (válido por 1 hora): {$enlace}";

        $mail->send();
        return ['ok' => true, 'error' => null];
    } catch (PHPMailerException $e) {
        return ['ok' => false, 'error' => $mail->ErrorInfo];
    }
}
