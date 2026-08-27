<?php
/**
 * Cifrado/descifrado de columnas sensibles (ej. EVALUADO / NÚMERO REGISTRO
 * en las tablas "sabana_*" de resultados_saber_pro_tyt_dump_completo.sql).
 *
 * Usa AES-256-GCM (cifrado autenticado): cada valor se guarda como
 * "IV(base64):TAG(base64):CIPHERTEXT(base64)". La clave vive solo en
 * crypto_config.php (ignorado por git) — sin ella, el valor cifrado es
 * ilegible, incluso con acceso directo a la base de datos o al .sql.
 *
 * Uso:
 *   require_once __DIR__ . '/crypto_sensible.php';
 *   $cifrado    = encrypt_sensible('ACOSTA FELIPE ALONSO');
 *   $original   = decrypt_sensible($cifrado);
 */

const CRYPTO_SENSIBLE_METODO = 'aes-256-gcm';

/**
 * Carga la clave real desde crypto_config.php.
 * Lanza una excepción si el archivo no existe o la clave no es válida,
 * en vez de cifrar/descifrar en silencio con una clave vacía.
 */
function crypto_sensible_clave(): string
{
    static $clave = null;
    if ($clave !== null) {
        return $clave;
    }

    $rutaConfig = __DIR__ . '/crypto_config.php';
    if (!file_exists($rutaConfig)) {
        throw new RuntimeException(
            'Falta crypto_config.php. Copia crypto_config.example.php como ' .
            'crypto_config.php y genera una clave real (ver instrucciones dentro).'
        );
    }

    $config = require $rutaConfig;
    $keyB64 = $config['key'] ?? '';
    $key = base64_decode($keyB64, true);

    if ($key === false || strlen($key) !== 32) {
        throw new RuntimeException(
            'La clave en crypto_config.php no es válida: debe ser 32 bytes ' .
            'codificados en base64 (ver crypto_config.example.php).'
        );
    }

    return $clave = $key;
}

/**
 * Cifra un valor sensible en texto plano. Devuelve una cadena imprimible
 * segura para guardar en una columna varchar/text.
 */
function encrypt_sensible(?string $texto_plano): ?string
{
    if ($texto_plano === null) {
        return null;
    }

    $clave = crypto_sensible_clave();
    $iv = random_bytes(openssl_cipher_iv_length(CRYPTO_SENSIBLE_METODO)); // 12 bytes en GCM

    $tag = '';
    $cifrado = openssl_encrypt(
        $texto_plano,
        CRYPTO_SENSIBLE_METODO,
        $clave,
        OPENSSL_RAW_DATA,
        $iv,
        $tag
    );

    if ($cifrado === false) {
        throw new RuntimeException('No se pudo cifrar el valor.');
    }

    return base64_encode($iv) . ':' . base64_encode($tag) . ':' . base64_encode($cifrado);
}

/**
 * Descifra un valor producido por encrypt_sensible(). Devuelve el texto
 * plano original, o lanza una excepción si el valor fue alterado
 * (autenticación GCM) o la clave no es la correcta.
 */
function decrypt_sensible(?string $valor_cifrado): ?string
{
    if ($valor_cifrado === null || $valor_cifrado === '') {
        return $valor_cifrado;
    }

    $partes = explode(':', $valor_cifrado, 3);
    if (count($partes) !== 3) {
        throw new InvalidArgumentException('Formato de valor cifrado inválido.');
    }

    [$ivB64, $tagB64, $cifradoB64] = $partes;
    $clave = crypto_sensible_clave();

    $iv = base64_decode($ivB64, true);
    $tag = base64_decode($tagB64, true);
    $cifrado = base64_decode($cifradoB64, true);

    if ($iv === false || $tag === false || $cifrado === false) {
        throw new InvalidArgumentException('Formato de valor cifrado inválido.');
    }

    $texto_plano = openssl_decrypt(
        $cifrado,
        CRYPTO_SENSIBLE_METODO,
        $clave,
        OPENSSL_RAW_DATA,
        $iv,
        $tag
    );

    if ($texto_plano === false) {
        throw new RuntimeException('No se pudo descifrar el valor (clave incorrecta o dato alterado).');
    }

    return $texto_plano;
}
