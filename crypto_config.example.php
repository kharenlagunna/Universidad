<?php
/**
 * PLANTILLA de configuración de cifrado para datos sensibles (ej. nombres de
 * evaluados en las tablas "sabana_*" del dump de resultados Saber Pro/TyT).
 *
 * Este archivo SÍ se sube al repositorio, como ejemplo. El archivo real que
 * usa la aplicación es "crypto_config.php" (ignorado por git, ver .gitignore)
 * con tu clave verdadera.
 *
 * Para usarlo:
 *   1. Copia este archivo como crypto_config.php
 *   2. Genera una clave nueva de 32 bytes en base64, por ejemplo con:
 *        php -r "echo base64_encode(random_bytes(32)), PHP_EOL;"
 *   3. Pega el resultado en 'key' abajo.
 *
 * "crypto_config.php" contiene la clave que descifra información personal:
 * nunca lo subas a un repositorio ni lo compartas. Si la clave se pierde,
 * los datos cifrados con ella NO se pueden recuperar.
 */

return [
    // Clave AES-256 en base64 (32 bytes al decodificar). Debe ser secreta y
    // distinta en cada entorno (desarrollo, producción, etc.).
    'key' => 'CAMBIA_ESTA_CLAVE_GENERADA_CON_random_bytes_32_EN_BASE64',
];
