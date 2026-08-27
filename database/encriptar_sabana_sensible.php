<?php
/**
 * Migración única: cifra las columnas EVALUADO (nombre del estudiante) y
 * NÚMERO REGISTRO (número de registro del examen) dentro del dump
 * resultados_saber_pro_tyt_dump_completo.sql, en las dos únicas tablas que
 * contienen datos personales:
 *   - `sabana_especif_ing_telema 2015 3`
 *   - `sabana_generi_ing_telema 2015 3`
 *
 * El resto del archivo (tablas de estadísticas agregadas, datos abiertos del
 * ICFES) se deja intacto.
 *
 * Uso:
 *   /Applications/XAMPP/xamppfiles/bin/php database/encriptar_sabana_sensible.php
 *
 * El script:
 *   1. Crea un respaldo del .sql original (una sola vez).
 *   2. Reescribe el archivo línea por línea (streaming, sin cargarlo entero
 *      en memoria) hacia un archivo temporal.
 *   3. Ensancha `EVALUADO`/`NÚMERO REGISTRO` de varchar(50) a varchar(255)
 *      en el CREATE TABLE de esas dos tablas (el texto cifrado en base64 no
 *      cabe en 50 caracteres).
 *   4. Sustituye el valor en texto plano de esas dos columnas por su valor
 *      cifrado (ver crypto_sensible.php) en cada INSERT de esas dos tablas.
 *   5. Reemplaza el archivo original solo si todo el proceso termina bien.
 */

require_once __DIR__ . '/../crypto_sensible.php';

$rutaOriginal = __DIR__ . '/resultados_saber_pro_tyt_dump_completo.sql';
$rutaRespaldo = __DIR__ . '/resultados_saber_pro_tyt_dump_completo.sql.antes_de_cifrar.bak';
$rutaTemporal = __DIR__ . '/resultados_saber_pro_tyt_dump_completo.sql.tmp';

const TABLAS_SENSIBLES = [
    'sabana_especif_ing_telema 2015 3',
    'sabana_generi_ing_telema 2015 3',
];

// Índices (0-based) de las columnas sensibles dentro de la tupla de valores,
// según el orden de columnas del CREATE TABLE de ambas tablas:
// 0 PROGRAMA ACADÉMICO, 1 MUNICIPIO, 2 GRUPO REFERENCIA, 3 INSTITUCIÓN,
// 4 MÓDULO, 5-9 Column6..10, 10 EVALUADO, 11-15 Column12..16,
// 16 NÚMERO REGISTRO, 17 Puntaje, 18 Nivel, 19 Quintil, 20 Column21.
const INDICE_EVALUADO = 10;
const INDICE_NUMERO_REGISTRO = 16;

if (!file_exists($rutaOriginal)) {
    fwrite(STDERR, "No se encontró el archivo: {$rutaOriginal}\n");
    exit(1);
}

if (file_exists($rutaRespaldo)) {
    fwrite(STDERR, "Ya existe un respaldo previo ({$rutaRespaldo}).\n");
    fwrite(STDERR, "Esto sugiere que el script ya se corrió antes. Abortando para no cifrar dos veces.\n");
    fwrite(STDERR, "Si de verdad quieres repetir el proceso, borra el respaldo manualmente primero.\n");
    exit(1);
}

echo "Creando respaldo del archivo original...\n";
if (!copy($rutaOriginal, $rutaRespaldo)) {
    fwrite(STDERR, "No se pudo crear el respaldo. Abortando.\n");
    exit(1);
}
echo "Respaldo creado en: {$rutaRespaldo}\n";

$entrada = fopen($rutaOriginal, 'r');
$salida = fopen($rutaTemporal, 'w');
if (!$entrada || !$salida) {
    fwrite(STDERR, "No se pudo abrir el archivo de entrada/salida.\n");
    exit(1);
}

// Estados del procesado línea a línea.
const ESTADO_NORMAL = 'normal';
const ESTADO_EN_CREATE_SENSIBLE = 'en_create_sensible';
const ESTADO_EN_INSERT_SENSIBLE = 'en_insert_sensible';

$estado = ESTADO_NORMAL;
$filasCifradasPorTabla = [];
foreach (TABLAS_SENSIBLES as $tabla) {
    $filasCifradasPorTabla[$tabla] = 0;
}
$tablaActual = null;

/**
 * Divide una línea de tupla SQL en sus valores entre comillas simples, en
 * orden. Todas las columnas de estas dos tablas son varchar, así que basta
 * con extraer cada segmento '...'; no hay comillas escapadas en estos datos
 * (se verificó de antemano sobre el archivo original).
 */
function extraerCamposDeFila(string $linea): array
{
    preg_match_all("/'([^']*)'/", $linea, $coincidencias);
    return $coincidencias[1];
}

while (($linea = fgets($entrada)) !== false) {
    $lineaSinSalto = rtrim($linea, "\r\n");

    if ($estado === ESTADO_NORMAL) {
        if (preg_match('/^CREATE TABLE `(.+)` \(/', $lineaSinSalto, $m) && in_array($m[1], TABLAS_SENSIBLES, true)) {
            $estado = ESTADO_EN_CREATE_SENSIBLE;
            $tablaActual = $m[1];
            fwrite($salida, $linea);
            continue;
        }

        if (preg_match('/^INSERT INTO `(.+)` \(/', $lineaSinSalto, $m) && in_array($m[1], TABLAS_SENSIBLES, true)) {
            $estado = ESTADO_EN_INSERT_SENSIBLE;
            $tablaActual = $m[1];
            fwrite($salida, $linea);
            continue;
        }

        fwrite($salida, $linea);
        continue;
    }

    if ($estado === ESTADO_EN_CREATE_SENSIBLE) {
        // Ensancha las dos columnas sensibles para que quepa el valor cifrado en base64.
        $linea = preg_replace(
            '/(`EVALUADO`|`NÚMERO REGISTRO`)\s+varchar\(50\)/u',
            '$1 varchar(255)',
            $linea
        );

        fwrite($salida, $linea);

        // La definición de columnas termina en la línea que cierra el paréntesis.
        if (preg_match('/^\)\s*ENGINE=/', $lineaSinSalto)) {
            $estado = ESTADO_NORMAL;
        }
        continue;
    }

    if ($estado === ESTADO_EN_INSERT_SENSIBLE) {
        $lineaProcesada = $linea;

        if (preg_match('/^\(/', trim($lineaSinSalto))) {
            $campos = extraerCamposDeFila($lineaSinSalto);

            if (count($campos) !== 21) {
                fclose($entrada);
                fclose($salida);
                unlink($rutaTemporal);
                fwrite(STDERR, "Fila con número de columnas inesperado en {$tablaActual}: " . count($campos) . "\n");
                fwrite(STDERR, "Línea: {$lineaSinSalto}\n");
                exit(1);
            }

            $evaluadoOriginal = $campos[INDICE_EVALUADO];
            $registroOriginal = $campos[INDICE_NUMERO_REGISTRO];

            // Los campos vacíos ('') se dejan vacíos: no hay nada que cifrar.
            $evaluadoCifrado = $evaluadoOriginal === '' ? '' : encrypt_sensible($evaluadoOriginal);
            $registroCifrado = $registroOriginal === '' ? '' : encrypt_sensible($registroOriginal);

            // Reemplaza únicamente la n-ésima ocurrencia de cada valor entre comillas,
            // reconstruyendo la línea campo por campo para no depender de que el
            // valor sea único dentro de la línea.
            $indiceCampo = 0;
            $lineaProcesada = preg_replace_callback(
                "/'([^']*)'/",
                function ($m) use (&$indiceCampo, $evaluadoCifrado, $registroCifrado) {
                    $valor = $m[1];
                    if ($indiceCampo === INDICE_EVALUADO) {
                        $valor = $evaluadoCifrado;
                    } elseif ($indiceCampo === INDICE_NUMERO_REGISTRO) {
                        $valor = $registroCifrado;
                    }
                    $indiceCampo++;
                    return "'" . $valor . "'";
                },
                $lineaSinSalto
            );

            $lineaProcesada .= "\n";
            $filasCifradasPorTabla[$tablaActual]++;
        }

        fwrite($salida, $lineaProcesada);

        if (preg_match('/;\s*$/', $lineaSinSalto)) {
            $estado = ESTADO_NORMAL;
        }
        continue;
    }
}

fclose($entrada);
fclose($salida);

if (!rename($rutaTemporal, $rutaOriginal)) {
    fwrite(STDERR, "No se pudo reemplazar el archivo original con la versión cifrada.\n");
    fwrite(STDERR, "El archivo cifrado quedó en: {$rutaTemporal}\n");
    exit(1);
}

echo "Listo. Filas cifradas por tabla:\n";
foreach ($filasCifradasPorTabla as $tabla => $conteo) {
    echo "  - {$tabla}: {$conteo}\n";
}
echo "Respaldo del original (sin cifrar) disponible en:\n  {$rutaRespaldo}\n";
