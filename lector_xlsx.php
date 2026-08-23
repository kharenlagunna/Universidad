<?php
/**
 * Lector propio y liviano de archivos .xlsx (sin librerías externas).
 *
 * Un .xlsx es un .zip que contiene archivos XML. Esta función abre esa
 * estructura con ZipArchive (extensión nativa de PHP) y lee la primera
 * hoja con SimpleXML, resolviendo el texto compartido (sharedStrings).
 *
 * Solo sirve para leer tablas simples de valores (texto/números) de una
 * hoja: no interpreta fórmulas, estilos, fechas con formato especial ni
 * múltiples hojas. Es justo lo que necesitan las plantillas de carga de
 * este proyecto.
 */

/**
 * Lee la primera hoja de un archivo .xlsx y devuelve sus filas como un
 * array de arrays de strings (una fila = un array de celdas en orden,
 * de A en adelante; las celdas vacías intermedias quedan como '').
 *
 * @throws RuntimeException si el archivo no se puede abrir o no tiene hojas.
 */
function leerFilasXlsx(string $ruta): array
{
    $zip = new ZipArchive();
    if ($zip->open($ruta) !== true) {
        throw new RuntimeException("No se pudo abrir el archivo .xlsx (¿está dañado o no es un Excel válido?).");
    }

    // 1. Texto compartido: la mayoría de las celdas de texto en un .xlsx
    //    no guardan el texto directamente, sino un índice a esta tabla.
    $sharedStrings = [];
    $sharedXml = $zip->getFromName('xl/sharedStrings.xml');
    if ($sharedXml !== false) {
        $sst = @simplexml_load_string($sharedXml);
        if ($sst !== false) {
            foreach ($sst->si as $si) {
                if (isset($si->t)) {
                    $sharedStrings[] = (string) $si->t;
                } else {
                    // Texto "enriquecido" (varios <r><t>...): se concatenan los fragmentos
                    $texto = '';
                    foreach ($si->r as $run) {
                        $texto .= (string) $run->t;
                    }
                    $sharedStrings[] = $texto;
                }
            }
        }
    }

    // 2. Localizar la primera hoja del libro
    $hojaXmlNombre = 'xl/worksheets/sheet1.xml';
    if ($zip->locateName($hojaXmlNombre) === false) {
        $hojaXmlNombre = null;
        for ($i = 0; $i < $zip->numFiles; $i++) {
            $nombre = $zip->getNameIndex($i);
            if (preg_match('#^xl/worksheets/sheet\d+\.xml$#', $nombre)) {
                $hojaXmlNombre = $nombre;
                break;
            }
        }
    }

    $hojaXml = $hojaXmlNombre ? $zip->getFromName($hojaXmlNombre) : false;
    $zip->close();

    if ($hojaXml === false) {
        throw new RuntimeException("El archivo .xlsx no tiene ninguna hoja legible.");
    }

    $sheet = @simplexml_load_string($hojaXml);
    if ($sheet === false || !isset($sheet->sheetData)) {
        throw new RuntimeException("No se pudo leer el contenido de la hoja.");
    }

    $filas = [];
    foreach ($sheet->sheetData->row as $row) {
        $celdas = [];
        foreach ($row->c as $c) {
            $ref = (string) $c['r']; // ej: "C5"
            $columnaLetra = preg_replace('/[0-9]/', '', $ref);
            $columnaIndice = _xlsxColumnaLetraAIndice($columnaLetra);

            $tipo = (string) $c['t'];
            if ($tipo === 's') {
                $indice = (int) $c->v;
                $valor = $sharedStrings[$indice] ?? '';
            } elseif ($tipo === 'inlineStr') {
                $valor = isset($c->is->t) ? (string) $c->is->t : '';
            } else {
                $valor = (string) $c->v;
            }

            $celdas[$columnaIndice] = $valor;
        }

        if (empty($celdas)) {
            continue;
        }

        // Rellenar huecos (celdas vacías intermedias) para que todas las
        // filas queden alineadas por columna.
        $maxIndice = max(array_keys($celdas));
        $filaCompleta = [];
        for ($i = 0; $i <= $maxIndice; $i++) {
            $filaCompleta[] = $celdas[$i] ?? '';
        }

        $filas[] = $filaCompleta;
    }

    return $filas;
}

function _xlsxColumnaLetraAIndice(string $letra): int
{
    $letra = strtoupper($letra);
    $indice = 0;
    for ($i = 0; $i < strlen($letra); $i++) {
        $indice = $indice * 26 + (ord($letra[$i]) - ord('A') + 1);
    }
    return $indice - 1; // 0-based
}
