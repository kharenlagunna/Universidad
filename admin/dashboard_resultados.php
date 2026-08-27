<?php
session_start();
require_once __DIR__ . '/../conexion_resultados.php';

if (!isset($_SESSION['usuario']) || $_SESSION['rol'] !== 'admin') {
    header("Location: ../auth/login.php");
    exit();
}

// ---------------------------------------------------------------------
// Filtro de ámbito: además del año, recorta TODO el dashboard (KPIs,
// gráficos, tablas y conclusiones) a uno de tres niveles. 'nacional' es
// el comportamiento original del dashboard (no recorta nada); los otros
// dos reutilizan el mismo criterio que ya usaba la sección Conclusiones
// (institución/programas de la Universidad Distrital), aplicado ahora a
// todos los demás paneles.
// ---------------------------------------------------------------------
$nombresDistrital = [
    'UNIVERSIDAD DISTRITAL FRANCISCO JOSE DE CALDAS',
    'UNIVERSIDAD DISTRITAL"FRANCISCO JOSE DE CALDAS"-BOGOTÁ D.C.',
];
$programaTelematica = 'INGENIERIA EN TELEMATICA';
$programaSistematizacion = 'TECNOLOGIA EN SISTEMATIZACION DE DATOS';

$ambitosValidos = ['programas', 'universidad', 'nacional'];
$ambito = in_array($_GET['ambito'] ?? '', $ambitosValidos, true) ? $_GET['ambito'] : 'nacional';
$ambitoEtiquetas = [
    'programas'   => 'Programas UD (Ingeniería en Telemática y Tecnología en Sistematización de Datos)',
    'universidad' => 'Toda la Universidad Distrital (todos sus programas)',
    'nacional'    => 'Todas las instituciones y programas (nacional)',
];

// --- Datos base: tendencia nacional por año/prueba/módulo. Se calcula
// siempre: la usa el ámbito 'nacional' y además sirve de referencia fija
// para las comparaciones "vs. promedio nacional" en Conclusiones, sin
// importar qué ámbito esté activo. ---
$tendenciaNacional = [];
$res = $connResultados->query("
    SELECT anio, tipo_prueba, modulo, cantidad_evaluados, promedio_puntaje, escala_no_comparable
    FROM vista_promedio_nacional_anual
    ORDER BY anio, tipo_prueba, modulo
");
while ($row = $res->fetch_assoc()) {
    $tendenciaNacional[] = $row;
}

// --- Datos base: comparación T&T vs Pro por región y módulo (nacional) ---
$regionesNacional = [];
$res = $connResultados->query("
    SELECT anio, tipo_prueba, region, modulo, cantidad_evaluados, promedio_puntaje, escala_no_comparable
    FROM vista_resultados_region
    ORDER BY region, anio, tipo_prueba, modulo
");
while ($row = $res->fetch_assoc()) {
    $regionesNacional[] = $row;
}

// --- Datos base: comparación T&T vs Pro por área homologada y módulo (nacional) ---
$areasNacional = [];
$res = $connResultados->query("
    SELECT e.area_homologada, v.modulo,
           ROUND(AVG(CASE WHEN v.tipo_prueba='Saber TyT' THEN v.promedio_puntaje END), 1) AS promedio_tyt,
           ROUND(AVG(CASE WHEN v.tipo_prueba='Saber Pro' THEN v.promedio_puntaje END), 1) AS promedio_pro
    FROM tabla_equivalencia_areas e
    JOIN vista_resultados_grupo_referencia v
      ON (v.tipo_prueba = 'Saber TyT' AND v.grupo_referencia = e.grupo_referencia_tyt)
      OR (v.tipo_prueba = 'Saber Pro' AND v.grupo_referencia = e.grupo_referencia_pro AND v.escala_no_comparable = 0)
    GROUP BY e.area_homologada, v.modulo
    ORDER BY e.area_homologada, v.modulo
");
while ($row = $res->fetch_assoc()) {
    $areasNacional[] = $row;
}

// --- Datos base: lo mismo, pero con módulos ESPECÍFICOS (propios de cada
// carrera, no los 5 genéricos) — ver vista_resultados_especificas_grupo_referencia.
// No se agrupa por módulo porque el vocabulario de módulos específicos
// cambia según la carrera; el área homologada sí sigue aplicando (el
// cruce es por grupo_referencia, no por nombre de módulo).
$areasEspecificasNacional = [];
$res = $connResultados->query("
    SELECT e.area_homologada,
           ROUND(AVG(CASE WHEN v.tipo_prueba='Saber TyT' THEN v.promedio_puntaje END), 1) AS promedio_tyt,
           ROUND(AVG(CASE WHEN v.tipo_prueba='Saber Pro' THEN v.promedio_puntaje END), 1) AS promedio_pro
    FROM tabla_equivalencia_areas e
    JOIN vista_resultados_especificas_grupo_referencia v
      ON (v.tipo_prueba = 'Saber TyT' AND v.grupo_referencia = e.grupo_referencia_tyt)
      OR (v.tipo_prueba = 'Saber Pro' AND v.grupo_referencia = e.grupo_referencia_pro AND v.escala_no_comparable = 0)
    GROUP BY e.area_homologada
    ORDER BY e.area_homologada
");
while ($row = $res->fetch_assoc()) {
    $areasEspecificasNacional[] = $row;
}

// ---------------------------------------------------------------------
// Datos base de la Universidad Distrital y de sus dos programas UD (usa
// $nombresDistrital/$programaTelematica/$programaSistematizacion de
// arriba). Se calculan siempre: los usan los ámbitos 'universidad' y
// 'programas' de todo el dashboard, y también la sección Conclusiones
// (que es siempre sobre la UD, sin importar el ámbito activo).
// ---------------------------------------------------------------------
$stmt = $connResultados->prepare("
    SELECT anio, tipo_prueba, modulo, promedio_puntaje, cantidad_evaluados, escala_no_comparable
    FROM vista_resultados_institucion
    WHERE institucion IN (?, ?)
    ORDER BY anio, tipo_prueba, modulo
");
$stmt->bind_param('ss', $nombresDistrital[0], $nombresDistrital[1]);
$stmt->execute();
$tendenciaDistrital = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

$stmt = $connResultados->prepare("
    SELECT anio, tipo_prueba, tipo_modulo, modulo, promedio_puntaje, cantidad_evaluados, escala_no_comparable
    FROM vista_resultados_programa
    WHERE institucion IN (?, ?) AND programa = ?
    ORDER BY anio, tipo_prueba, tipo_modulo, modulo
");
$stmt->bind_param('sss', $nombresDistrital[0], $nombresDistrital[1], $programaTelematica);
$stmt->execute();
$filasTelematica = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

$stmt->bind_param('sss', $nombresDistrital[0], $nombresDistrital[1], $programaSistematizacion);
$stmt->execute();
$filasSistematizacion = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

// Para la tendencia año a año solo se usan los módulos genéricos (los
// específicos cambian de nombre de un año a otro, ver comentario de
// $areasEspecificasNacional más arriba).
$filasTelematicaGenerica = array_values(array_filter($filasTelematica, fn($f) => $f['tipo_modulo'] === 'GENERICA'));
$filasSistematizacionGenerica = array_values(array_filter($filasSistematizacion, fn($f) => $f['tipo_modulo'] === 'GENERICA'));

// ---------------------------------------------------------------------
// Áreas y regiones recortadas a los ámbitos 'universidad'/'programas'
// (solo se consultan cuando hacen falta). Mismo cruce que las versiones
// nacionales de arriba, pero desde vista_resultados_institucion /
// vista_resultados_programa (que sí tienen institución/programa) en vez
// de vista_resultados_grupo_referencia / vista_resultados_region.
// ---------------------------------------------------------------------
$areasUniversidad = [];
$areasEspecificasUniversidad = [];
$regionesUniversidad = [];
$programasDetalleGenerica = [];
$programasDetalleEspecifica = [];
$areasProgramas = [];
$areasEspecificasProgramas = [];
$regionesProgramas = [];

if ($ambito === 'universidad') {
    $stmt = $connResultados->prepare("
        SELECT e.area_homologada, p.modulo,
               ROUND(AVG(CASE WHEN p.tipo_prueba='Saber TyT' THEN p.promedio_puntaje END), 1) AS promedio_tyt,
               ROUND(AVG(CASE WHEN p.tipo_prueba='Saber Pro' THEN p.promedio_puntaje END), 1) AS promedio_pro
        FROM tabla_equivalencia_areas e
        JOIN vista_resultados_programa p
          ON (p.tipo_prueba = 'Saber TyT' AND p.grupo_referencia = e.grupo_referencia_tyt AND p.tipo_modulo = 'GENERICA')
          OR (p.tipo_prueba = 'Saber Pro' AND p.grupo_referencia = e.grupo_referencia_pro AND p.tipo_modulo = 'GENERICA' AND p.escala_no_comparable = 0)
        WHERE p.institucion IN (?, ?)
        GROUP BY e.area_homologada, p.modulo
        ORDER BY e.area_homologada, p.modulo
    ");
    $stmt->bind_param('ss', $nombresDistrital[0], $nombresDistrital[1]);
    $stmt->execute();
    $areasUniversidad = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

    $stmt = $connResultados->prepare("
        SELECT e.area_homologada,
               ROUND(AVG(CASE WHEN p.tipo_prueba='Saber TyT' THEN p.promedio_puntaje END), 1) AS promedio_tyt,
               ROUND(AVG(CASE WHEN p.tipo_prueba='Saber Pro' THEN p.promedio_puntaje END), 1) AS promedio_pro
        FROM tabla_equivalencia_areas e
        JOIN vista_resultados_programa p
          ON (p.tipo_prueba = 'Saber TyT' AND p.grupo_referencia = e.grupo_referencia_tyt AND p.tipo_modulo = 'ESPECIFICA')
          OR (p.tipo_prueba = 'Saber Pro' AND p.grupo_referencia = e.grupo_referencia_pro AND p.tipo_modulo = 'ESPECIFICA' AND p.escala_no_comparable = 0)
        WHERE p.institucion IN (?, ?)
        GROUP BY e.area_homologada
        ORDER BY e.area_homologada
    ");
    $stmt->bind_param('ss', $nombresDistrital[0], $nombresDistrital[1]);
    $stmt->execute();
    $areasEspecificasUniversidad = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

    $stmt = $connResultados->prepare("
        SELECT i.anio, i.tipo_prueba, COALESCE(r.region, 'SIN CLASIFICAR') AS region, i.modulo,
               i.cantidad_evaluados, i.promedio_puntaje, i.escala_no_comparable
        FROM vista_resultados_institucion i
        LEFT JOIN tabla_departamento_region r ON r.departamento = i.departamento
        WHERE i.institucion IN (?, ?)
        ORDER BY region, anio, tipo_prueba, modulo
    ");
    $stmt->bind_param('ss', $nombresDistrital[0], $nombresDistrital[1]);
    $stmt->execute();
    $regionesUniversidad = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

    // ---------------------------------------------------------------------
    // Detalle por programa académico (sin homologar): mismo cruce T&T vs.
    // Pro que "Comparación por área", pero SIN agrupar por área — cada
    // barra es un programa de la universidad, con el nombre tal como está
    // registrado en los resultados del ICFES (no pasa por
    // tabla_equivalencia_areas). Alimenta el panel nuevo que se muestra
    // debajo de "Comparación por área" solo con este ámbito.
    // ---------------------------------------------------------------------
    $stmt = $connResultados->prepare("
        SELECT p.programa, p.modulo,
               ROUND(AVG(CASE WHEN p.tipo_prueba='Saber TyT' THEN p.promedio_puntaje END), 1) AS promedio_tyt,
               ROUND(AVG(CASE WHEN p.tipo_prueba='Saber Pro' THEN p.promedio_puntaje END), 1) AS promedio_pro
        FROM vista_resultados_programa p
        WHERE p.institucion IN (?, ?) AND p.tipo_modulo = 'GENERICA'
          AND (p.tipo_prueba != 'Saber Pro' OR p.escala_no_comparable = 0)
        GROUP BY p.programa, p.modulo
        ORDER BY p.programa, p.modulo
    ");
    $stmt->bind_param('ss', $nombresDistrital[0], $nombresDistrital[1]);
    $stmt->execute();
    $programasDetalleGenerica = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

    $stmt = $connResultados->prepare("
        SELECT p.programa,
               ROUND(AVG(CASE WHEN p.tipo_prueba='Saber TyT' THEN p.promedio_puntaje END), 1) AS promedio_tyt,
               ROUND(AVG(CASE WHEN p.tipo_prueba='Saber Pro' THEN p.promedio_puntaje END), 1) AS promedio_pro
        FROM vista_resultados_programa p
        WHERE p.institucion IN (?, ?) AND p.tipo_modulo = 'ESPECIFICA'
          AND (p.tipo_prueba != 'Saber Pro' OR p.escala_no_comparable = 0)
        GROUP BY p.programa
        ORDER BY p.programa
    ");
    $stmt->bind_param('ss', $nombresDistrital[0], $nombresDistrital[1]);
    $stmt->execute();
    $programasDetalleEspecifica = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

    // Nombre "legible" del programa (mismo criterio que las demás tablas
    // del dashboard: ucwords(mb_strtolower(...))); el campo 'programa'
    // original queda intacto por si hiciera falta más adelante.
    foreach ($programasDetalleGenerica as &$fila) {
        $fila['programa_legible'] = ucwords(mb_strtolower($fila['programa']));
    }
    unset($fila);
    foreach ($programasDetalleEspecifica as &$fila) {
        $fila['programa_legible'] = ucwords(mb_strtolower($fila['programa']));
    }
    unset($fila);
} elseif ($ambito === 'programas') {
    $stmt = $connResultados->prepare("
        SELECT e.area_homologada, p.modulo,
               ROUND(AVG(CASE WHEN p.tipo_prueba='Saber TyT' THEN p.promedio_puntaje END), 1) AS promedio_tyt,
               ROUND(AVG(CASE WHEN p.tipo_prueba='Saber Pro' THEN p.promedio_puntaje END), 1) AS promedio_pro
        FROM tabla_equivalencia_areas e
        JOIN vista_resultados_programa p
          ON (p.tipo_prueba = 'Saber TyT' AND p.grupo_referencia = e.grupo_referencia_tyt AND p.tipo_modulo = 'GENERICA')
          OR (p.tipo_prueba = 'Saber Pro' AND p.grupo_referencia = e.grupo_referencia_pro AND p.tipo_modulo = 'GENERICA' AND p.escala_no_comparable = 0)
        WHERE p.institucion IN (?, ?) AND p.programa IN (?, ?)
        GROUP BY e.area_homologada, p.modulo
        ORDER BY e.area_homologada, p.modulo
    ");
    $stmt->bind_param('ssss', $nombresDistrital[0], $nombresDistrital[1], $programaTelematica, $programaSistematizacion);
    $stmt->execute();
    $areasProgramas = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

    $stmt = $connResultados->prepare("
        SELECT e.area_homologada,
               ROUND(AVG(CASE WHEN p.tipo_prueba='Saber TyT' THEN p.promedio_puntaje END), 1) AS promedio_tyt,
               ROUND(AVG(CASE WHEN p.tipo_prueba='Saber Pro' THEN p.promedio_puntaje END), 1) AS promedio_pro
        FROM tabla_equivalencia_areas e
        JOIN vista_resultados_programa p
          ON (p.tipo_prueba = 'Saber TyT' AND p.grupo_referencia = e.grupo_referencia_tyt AND p.tipo_modulo = 'ESPECIFICA')
          OR (p.tipo_prueba = 'Saber Pro' AND p.grupo_referencia = e.grupo_referencia_pro AND p.tipo_modulo = 'ESPECIFICA' AND p.escala_no_comparable = 0)
        WHERE p.institucion IN (?, ?) AND p.programa IN (?, ?)
        GROUP BY e.area_homologada
        ORDER BY e.area_homologada
    ");
    $stmt->bind_param('ssss', $nombresDistrital[0], $nombresDistrital[1], $programaTelematica, $programaSistematizacion);
    $stmt->execute();
    $areasEspecificasProgramas = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

    $stmt = $connResultados->prepare("
        SELECT p.anio, p.tipo_prueba, COALESCE(r.region, 'SIN CLASIFICAR') AS region, p.modulo,
               p.cantidad_evaluados, p.promedio_puntaje, p.escala_no_comparable
        FROM vista_resultados_programa p
        LEFT JOIN tabla_departamento_region r ON r.departamento = p.departamento
        WHERE p.institucion IN (?, ?) AND p.programa IN (?, ?) AND p.tipo_modulo = 'GENERICA'
        ORDER BY region, anio, tipo_prueba, modulo
    ");
    $stmt->bind_param('ssss', $nombresDistrital[0], $nombresDistrital[1], $programaTelematica, $programaSistematizacion);
    $stmt->execute();
    $regionesProgramas = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
}

// Selección final según el ámbito activo: de aquí en adelante el resto
// del archivo sigue usando $tendencia/$areas/$areasEspecificas/$regiones
// tal como ya lo hacía (no hace falta tocar el resto del dashboard).
switch ($ambito) {
    case 'universidad':
        $tendencia = $tendenciaDistrital;
        $areas = $areasUniversidad;
        $areasEspecificas = $areasEspecificasUniversidad;
        $regiones = $regionesUniversidad;
        break;
    case 'programas':
        $tendencia = array_merge($filasTelematicaGenerica, $filasSistematizacionGenerica);
        $areas = $areasProgramas;
        $areasEspecificas = $areasEspecificasProgramas;
        $regiones = $regionesProgramas;
        break;
    default: // nacional
        $tendencia = $tendenciaNacional;
        $areas = $areasNacional;
        $areasEspecificas = $areasEspecificasNacional;
        $regiones = $regionesNacional;
}

$tituloTendencia = $ambito === 'nacional'
    ? '¿Mejoran los resultados con el tiempo?'
    : ($ambito === 'universidad' ? 'Tendencia — Universidad Distrital' : 'Tendencia — Programas UD (Telemática y Sistematización)');

// ---------------------------------------------------------------------
// KPIs y conclusiones automáticas (se calculan aquí para no duplicar
// la lógica en JS; los gráficos sí se arman en el navegador con estos
// mismos datos, ver más abajo).
// ---------------------------------------------------------------------

function promedioGeneral(array $filas, int $anio, string $tipo): ?float
{
    $vals = array_filter($filas, fn($f) => (int)$f['anio'] === $anio && $f['tipo_prueba'] === $tipo);
    if (!$vals) return null;
    return round(array_sum(array_column($vals, 'promedio_puntaje')) / count($vals), 1);
}

function moduloExtremos(array $filas, string $tipo): array
{
    $porModulo = [];
    foreach ($filas as $f) {
        if ($f['tipo_prueba'] !== $tipo) continue;
        $porModulo[$f['modulo']][] = (float) $f['promedio_puntaje'];
    }
    $promedios = [];
    foreach ($porModulo as $modulo => $vals) {
        $promedios[$modulo] = array_sum($vals) / count($vals);
    }
    if (!$promedios) return [null, null];
    arsort($promedios);
    return [array_key_first($promedios), array_key_last($promedios)];
}

function textoTendencia(?float $variacion, string $nombre): string
{
    if ($variacion === null) {
        return "No hay suficientes años comparables para determinar la tendencia de $nombre.";
    }
    if ($variacion > 1) {
        return "$nombre mejoró en promedio " . number_format($variacion, 1) . " puntos en el período analizado.";
    }
    if ($variacion < -1) {
        return "$nombre bajó en promedio " . number_format(abs($variacion), 1) . " puntos en el período analizado.";
    }
    return "$nombre se mantuvo relativamente estable en el período analizado.";
}

// Texto corto del botón del filtro principal de año (multiselección).
function resumenAnios(array $seleccionados, array $todos): string
{
    if (count($seleccionados) === count($todos)) return 'Todos los años';
    if (count($seleccionados) <= 2) return implode(', ', $seleccionados);
    return count($seleccionados) . ' años seleccionados';
}

// El año "reciente" de Saber T&T depende del ámbito: a nivel programa
// (vista_resultados_programa) no hay T&T 2017 ni 2024 (ver comentario en
// vistas_dashboard_resultados.sql), el año más reciente ahí es 2018.
$tytAnioReciente = ($ambito === 'programas') ? 2018 : 2024;

$proReciente = promedioGeneral($tendencia, 2018, 'Saber Pro');
$proInicial  = promedioGeneral($tendencia, 2016, 'Saber Pro');
$tytReciente = promedioGeneral($tendencia, $tytAnioReciente, 'Saber TyT');
$tytInicial  = promedioGeneral($tendencia, 2016, 'Saber TyT');

$variacionPro = ($proReciente !== null && $proInicial !== null) ? round($proReciente - $proInicial, 1) : null;
$variacionTyt = ($tytReciente !== null && $tytInicial !== null) ? round($tytReciente - $tytInicial, 1) : null;

$totalEvaluados = 0;
foreach ($tendencia as $f) {
    $totalEvaluados += (int) ($f['cantidad_evaluados'] ?? 0);
}

// Baseline nacional fijo: usado solo para las comparaciones "vs. promedio
// nacional" de Conclusiones, que deben seguir comparando contra el país
// real sin importar el ámbito activo (a diferencia de $proReciente/
// $tytReciente de arriba, que ahora sí varían con el ámbito).
$proRecienteNacional = promedioGeneral($tendenciaNacional, 2018, 'Saber Pro');
$tytRecienteNacional = promedioGeneral($tendenciaNacional, 2024, 'Saber TyT');

$modulosDisponibles = ['COMPETENCIAS CIUDADANAS', 'COMUNICACIÓN ESCRITA', 'INGLÉS', 'LECTURA CRÍTICA', 'RAZONAMIENTO CUANTITATIVO'];
$aniosDisponibles = [2015, 2016, 2017, 2018, 2024];

// --- Filtro principal de año: uno solo (multiselección), arriba del
// dashboard, que controla a la vez todos los cuadros que tienen una fila
// por año específico (comparación por región, top de instituciones, top
// de programas). Tendencia (que grafica varios años a la vez) y Áreas
// (que no tiene año en sus datos) no dependen de este filtro. Cuando se
// eligen varios años, instituciones y programas promedian ponderando por
// la cantidad de evaluados de cada año.
$aniosCrudo = $_GET['anio'] ?? [2018];
if (!is_array($aniosCrudo)) $aniosCrudo = [$aniosCrudo];
$aniosSeleccionados = array_values(array_unique(array_intersect(array_map('intval', $aniosCrudo), $aniosDisponibles)));
if (!$aniosSeleccionados) $aniosSeleccionados = [2018];
sort($aniosSeleccionados);

// ---------------------------------------------------------------------
// Top de instituciones y Top de programas académicos: solo tienen sentido
// como "ranking de 10" con el ámbito 'nacional' (con 'universidad' hay una
// sola institución y con 'programas' solo 2 programas — ver Conclusiones,
// que ya cubre el detalle de esos casos). Con los otros dos ámbitos ni
// siquiera se consultan.
// ---------------------------------------------------------------------
$mejoresInstituciones = [];
$peoresInstituciones = [];
$mejoresProgramas = [];
$peoresProgramas = [];
$aniosInst = $aniosSeleccionados;
$aniosProgramaDisponibles = [2015, 2016, 2017, 2018];
$aniosProg = array_values(array_intersect($aniosSeleccionados, $aniosProgramaDisponibles));
$anioProgDisponible = (bool) $aniosProg;
$modulosProgramaDisponibles = [];
$moduloProg = '';

if ($ambito === 'nacional') {

// Top de instituciones (requiere año específico + prueba + módulo:
// es demasiada información para mandar toda al navegador, se filtra
// aquí mismo con GET y se recalcula al enviar el formulario).
$aniosInstSql = implode(',', $aniosInst); // ya validados contra $aniosDisponibles (whitelist de enteros)
$tipoInst = in_array($_GET['tipo_inst'] ?? '', ['Saber Pro', 'Saber TyT']) ? $_GET['tipo_inst'] : 'Saber Pro';
$moduloInst = in_array($_GET['modulo_inst'] ?? '', $modulosDisponibles) ? $_GET['modulo_inst'] : 'RAZONAMIENTO CUANTITATIVO';

// Con varios años seleccionados se agrupa por institución y se promedia
// ponderando por cantidad_evaluados de cada año (un año solo se comporta
// igual que antes: SUM de una sola fila = esa fila).
$stmt = $connResultados->prepare("
    SELECT i.institucion, COALESCE(r.region, 'SIN CLASIFICAR') AS region,
           SUM(i.promedio_puntaje * i.cantidad_evaluados) / SUM(i.cantidad_evaluados) AS promedio_puntaje,
           SUM(i.cantidad_evaluados) AS cantidad_evaluados
    FROM vista_resultados_institucion i
    LEFT JOIN tabla_departamento_region r ON r.departamento = i.departamento
    WHERE i.anio IN ($aniosInstSql) AND i.tipo_prueba = ? AND i.modulo = ?
    GROUP BY i.institucion, r.region
    HAVING SUM(i.cantidad_evaluados) >= 30
    ORDER BY promedio_puntaje DESC
    LIMIT 10
");
$stmt->bind_param('ss', $tipoInst, $moduloInst);
$stmt->execute();
$mejoresInstituciones = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

$stmt = $connResultados->prepare("
    SELECT i.institucion, COALESCE(r.region, 'SIN CLASIFICAR') AS region,
           SUM(i.promedio_puntaje * i.cantidad_evaluados) / SUM(i.cantidad_evaluados) AS promedio_puntaje,
           SUM(i.cantidad_evaluados) AS cantidad_evaluados
    FROM vista_resultados_institucion i
    LEFT JOIN tabla_departamento_region r ON r.departamento = i.departamento
    WHERE i.anio IN ($aniosInstSql) AND i.tipo_prueba = ? AND i.modulo = ?
    GROUP BY i.institucion, r.region
    HAVING SUM(i.cantidad_evaluados) >= 30
    ORDER BY promedio_puntaje ASC
    LIMIT 10
");
$stmt->bind_param('ss', $tipoInst, $moduloInst);
$stmt->execute();
$peoresInstituciones = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

// ---------------------------------------------------------------------
// Top de programas académicos — nivel de agregación más fino (institución
// x programa). A diferencia del ranking de instituciones (que solo usa
// módulos genéricos), aquí sí se puede alternar Genérica/Específica,
// porque esta sección se construyó pensando en las dos. Igual que con
// instituciones, no viaja al navegador: se filtra en el servidor.
//
// Nota: vista_resultados_programa no cubre Saber T&T 2017 ni 2024 a
// este nivel de detalle (ver comentario en la vista), por eso no están
// en $aniosProgramaDisponibles.
// ---------------------------------------------------------------------
$aniosProgSql = $anioProgDisponible ? implode(',', $aniosProg) : '';
$tipoProg = in_array($_GET['tipo_prog'] ?? '', ['Saber Pro', 'Saber TyT']) ? $_GET['tipo_prog'] : 'Saber Pro';
$tipoModuloProg = in_array($_GET['tipomodulo_prog'] ?? '', ['GENERICA', 'ESPECIFICA']) ? $_GET['tipomodulo_prog'] : 'GENERICA';

// El módulo depende de tipo_prueba + tipo_modulo (los específicos varían
// por carrera), así que la lista de opciones se calcula en vivo.
if ($anioProgDisponible) {
    $stmt = $connResultados->prepare("
        SELECT DISTINCT modulo
        FROM vista_resultados_programa
        WHERE anio IN ($aniosProgSql) AND tipo_prueba = ? AND tipo_modulo = ?
        ORDER BY modulo
    ");
    $stmt->bind_param('ss', $tipoProg, $tipoModuloProg);
    $stmt->execute();
    $modulosProgramaDisponibles = array_column($stmt->get_result()->fetch_all(MYSQLI_ASSOC), 'modulo');
}

$moduloProgCrudo = $_GET['modulo_prog'] ?? '';
$moduloProg = in_array($moduloProgCrudo, $modulosProgramaDisponibles, true)
    ? $moduloProgCrudo
    : ($modulosProgramaDisponibles[0] ?? '');

// Igual que instituciones: con varios años se agrupa por programa +
// institución y se promedia ponderando por cantidad_evaluados.
if ($moduloProg !== '') {
    $stmt = $connResultados->prepare("
        SELECT p.programa, p.institucion, COALESCE(r.region, 'SIN CLASIFICAR') AS region,
               SUM(p.promedio_puntaje * p.cantidad_evaluados) / SUM(p.cantidad_evaluados) AS promedio_puntaje,
               SUM(p.cantidad_evaluados) AS cantidad_evaluados
        FROM vista_resultados_programa p
        LEFT JOIN tabla_departamento_region r ON r.departamento = p.departamento
        WHERE p.anio IN ($aniosProgSql) AND p.tipo_prueba = ? AND p.tipo_modulo = ? AND p.modulo = ?
        GROUP BY p.programa, p.institucion, r.region
        HAVING SUM(p.cantidad_evaluados) >= 20
        ORDER BY promedio_puntaje DESC
        LIMIT 10
    ");
    $stmt->bind_param('sss', $tipoProg, $tipoModuloProg, $moduloProg);
    $stmt->execute();
    $mejoresProgramas = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

    $stmt = $connResultados->prepare("
        SELECT p.programa, p.institucion, COALESCE(r.region, 'SIN CLASIFICAR') AS region,
               SUM(p.promedio_puntaje * p.cantidad_evaluados) / SUM(p.cantidad_evaluados) AS promedio_puntaje,
               SUM(p.cantidad_evaluados) AS cantidad_evaluados
        FROM vista_resultados_programa p
        LEFT JOIN tabla_departamento_region r ON r.departamento = p.departamento
        WHERE p.anio IN ($aniosProgSql) AND p.tipo_prueba = ? AND p.tipo_modulo = ? AND p.modulo = ?
        GROUP BY p.programa, p.institucion, r.region
        HAVING SUM(p.cantidad_evaluados) >= 20
        ORDER BY promedio_puntaje ASC
        LIMIT 10
    ");
    $stmt->bind_param('sss', $tipoProg, $tipoModuloProg, $moduloProg);
    $stmt->execute();
    $peoresProgramas = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
}

} // fin if ($ambito === 'nacional') — Top de instituciones / Top de programas

// ---------------------------------------------------------------------
// Conclusiones — a diferencia del resto del dashboard (que varía con el
// ámbito elegido), esta sección se limita SIEMPRE a la Universidad
// Distrital Francisco José de Caldas y a los programas de Ingeniería en
// Telemática (Saber Pro) y Tecnología en Sistematización de Datos
// (Saber T&T), sin importar el ámbito activo. $tendenciaDistrital,
// $filasTelematica, $filasSistematizacion, $filasTelematicaGenerica y
// $filasSistematizacionGenerica ya se calcularon arriba (las usa también
// el ámbito 'universidad'/'programas' del resto del dashboard). Reutiliza
// promedioGeneral() y moduloExtremos() ya definidas arriba.
// ---------------------------------------------------------------------

// Universidad completa: mismos años que las KPI nacionales (2016→2018
// para Saber Pro, 2016→2024 para Saber T&T) para comparar manzanas con
// manzanas; 2015 queda fuera por su escala distinta.
$distritalProReciente = promedioGeneral($tendenciaDistrital, 2018, 'Saber Pro');
$distritalProInicial  = promedioGeneral($tendenciaDistrital, 2016, 'Saber Pro');
$distritalTytReciente = promedioGeneral($tendenciaDistrital, 2024, 'Saber TyT');
$distritalTytInicial  = promedioGeneral($tendenciaDistrital, 2016, 'Saber TyT');
$distritalTyt2018     = promedioGeneral($tendenciaDistrital, 2018, 'Saber TyT');

$variacionProDistrital = ($distritalProReciente !== null && $distritalProInicial !== null) ? round($distritalProReciente - $distritalProInicial, 1) : null;
$variacionTytDistrital = ($distritalTytReciente !== null && $distritalTytInicial !== null) ? round($distritalTytReciente - $distritalTytInicial, 1) : null;

[$moduloMejorProDistrital, $moduloPeorProDistrital] = moduloExtremos($tendenciaDistrital, 'Saber Pro');
[$moduloMejorTytDistrital, $moduloPeorTytDistrital] = moduloExtremos($tendenciaDistrital, 'Saber TyT');

// Universidad vs. promedio nacional, mismo año y misma prueba ($proReciente
// y $tytReciente ya están calculados arriba a nivel nacional).
$diffProVsNacional = ($distritalProReciente !== null && $proRecienteNacional !== null) ? round($distritalProReciente - $proRecienteNacional, 1) : null;
$diffTytVsNacional = ($distritalTytReciente !== null && $tytRecienteNacional !== null) ? round($distritalTytReciente - $tytRecienteNacional, 1) : null;

// Ingeniería en Telemática (solo tiene datos en Saber Pro)
$telematica2018 = promedioGeneral($filasTelematicaGenerica, 2018, 'Saber Pro');
$telematica2016 = promedioGeneral($filasTelematicaGenerica, 2016, 'Saber Pro');
$variacionTelematica = ($telematica2018 !== null && $telematica2016 !== null) ? round($telematica2018 - $telematica2016, 1) : null;
[$moduloMejorTelematica, $moduloPeorTelematica] = moduloExtremos($filasTelematicaGenerica, 'Saber Pro');
$diffTelematicaVsUniversidad = ($telematica2018 !== null && $distritalProReciente !== null) ? round($telematica2018 - $distritalProReciente, 1) : null;

// Módulo específico (propio de la carrera) con mejor/peor promedio en el
// año más reciente con datos específicos (2018).
$moduloEspecificoMejorTelematica = null;
$moduloEspecificoPeorTelematica = null;
$especificasTelematica2018 = array_filter($filasTelematica, fn($f) => $f['tipo_modulo'] === 'ESPECIFICA' && (int) $f['anio'] === 2018 && $f['tipo_prueba'] === 'Saber Pro');
if ($especificasTelematica2018) {
    $porModuloEsp = [];
    foreach ($especificasTelematica2018 as $f) $porModuloEsp[$f['modulo']] = (float) $f['promedio_puntaje'];
    arsort($porModuloEsp);
    $moduloEspecificoMejorTelematica = array_key_first($porModuloEsp);
    $moduloEspecificoPeorTelematica = array_key_last($porModuloEsp);
}

// Tecnología en Sistematización de Datos (solo tiene datos en Saber T&T)
$sistematizacion2018 = promedioGeneral($filasSistematizacionGenerica, 2018, 'Saber TyT');
$sistematizacion2016 = promedioGeneral($filasSistematizacionGenerica, 2016, 'Saber TyT');
$variacionSistematizacion = ($sistematizacion2018 !== null && $sistematizacion2016 !== null) ? round($sistematizacion2018 - $sistematizacion2016, 1) : null;
[$moduloMejorSistematizacion, $moduloPeorSistematizacion] = moduloExtremos($filasSistematizacionGenerica, 'Saber TyT');
$diffSistematizacionVsUniversidad = ($sistematizacion2018 !== null && $distritalTyt2018 !== null) ? round($sistematizacion2018 - $distritalTyt2018, 1) : null;
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<title>Dashboard de Resultados</title>
<link rel="stylesheet" href="../estilos.css" />
<link rel="icon" href="../favicon.svg" type="image/svg+xml">
<link rel="alternate icon" href="../favicon.ico">
<link rel="apple-touch-icon" href="../apple-touch-icon.png">
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
<?php require __DIR__ . '/../sidebar.php'; ?>

<div class="content">
    <div class="contenedor-derecho">
        <h2>Dashboard de Resultados — Saber Pro y Saber T&T (ICFES)</h2>
      
        <div class="panel-dashboard panel-filtro-principal">
            <div class="campo-form" style="min-width:280px;margin-bottom:0;">
                <label for="filtroAmbito">Filtro principal · Ámbito</label>
                <select id="filtroAmbito" onchange="cambiarAmbito(this)">
                    <option value="programas" <?= $ambito === 'programas' ? 'selected' : '' ?>>Programas UD (Telemática y Sistematización de Datos)</option>
                    <option value="universidad" <?= $ambito === 'universidad' ? 'selected' : '' ?>>Toda la Universidad Distrital</option>
                    <option value="nacional" <?= $ambito === 'nacional' ? 'selected' : '' ?>>Todas las instituciones y programas</option>
                </select>

                <label for="multiselectAnioBoton">Año(s)</label>
                <div class="multiselect" id="multiselectAnio">
                    <button type="button" class="multiselect-boton" id="multiselectAnioBoton" onclick="toggleMultiselectAnio()">
                        <span id="multiselectAnioResumen"><?= htmlspecialchars(resumenAnios(array_map('strval', $aniosSeleccionados), array_map('strval', $aniosDisponibles))) ?></span>
                        <span class="multiselect-flecha">▾</span>
                    </button>
                    <div class="multiselect-panel" id="multiselectAnioPanel">
                        <label class="multiselect-opcion multiselect-opcion-todos">
                            <input type="checkbox" id="checkAnioTodos" <?= count($aniosSeleccionados) === count($aniosDisponibles) ? 'checked' : '' ?> onchange="onCambioTodosAnios(this)">
                            <span>Todos</span>
                        </label>
                        <div class="multiselect-separador"></div>
                        <?php foreach ($aniosDisponibles as $a): ?>
                            <label class="multiselect-opcion">
                                <input type="checkbox" class="check-anio" value="<?= $a ?>" <?= in_array($a, $aniosSeleccionados, true) ? 'checked' : '' ?> onchange="onCambioAnio(this)">
                                <span><?= $a ?></span>
                            </label>
                        <?php endforeach; ?>
                    </div>
                </div>
            </div>
            <p style="color:#777;font-size:13px;margin:0;flex:1;min-width:260px;">
                <strong>Ámbito actual:</strong> <?= htmlspecialchars($ambitoEtiquetas[$ambito]) ?>. El ámbito recorta todo el dashboard (KPIs, gráficos, tablas y conclusiones); con 'Programas UD' o 'Universidad Distrital' se ocultan los rankings "Top de instituciones"/"Top de programas" (dejan de tener sentido con 1-2 elementos) y el panel de tendencia por programa (ya lo cubre la Tendencia de arriba). El año(s) filtra además, al instante, los cuadros que dependen de un año específico (comparación por región<?= $ambito === 'nacional' ? ', top de instituciones y top de programas académicos' : '' ?>); con varios años esos promedian ponderando por la cantidad de evaluados de cada año. Tendencia (varios años a la vez) y Áreas (sin año en sus datos) no cambian con el filtro de año.
            </p>
            <button type="button" class="btn-secundario" onclick="limpiarFiltros()">Limpiar filtros</button>
        </div>

        <div class="info-simulacro" style="flex-wrap:wrap;">
            <div class="info-stat">
                <span class="info-stat-label">Saber Pro 2018 (promedio)</span>
                <span class="info-stat-valor"><?= $proReciente !== null ? number_format($proReciente, 1) : '—' ?></span>
            </div>
            <div class="info-stat">
                <span class="info-stat-label">Saber T&T <?= $tytAnioReciente ?> (promedio)</span>
                <span class="info-stat-valor"><?= $tytReciente !== null ? number_format($tytReciente, 1) : '—' ?></span>
            </div>
            <div class="info-stat">
                <span class="info-stat-label">Variación Saber Pro (2016→2018)</span>
                <span class="info-stat-valor"><?= $variacionPro !== null ? ($variacionPro >= 0 ? '+' : '') . number_format($variacionPro, 1) : '—' ?></span>
            </div>
            <div class="info-stat">
                <span class="info-stat-label">Variación Saber T&T (2016→<?= $tytAnioReciente ?>)</span>
                <span class="info-stat-valor"><?= $variacionTyt !== null ? ($variacionTyt >= 0 ? '+' : '') . number_format($variacionTyt, 1) : '—' ?></span>
            </div>
            <div class="info-stat">
                <span class="info-stat-label">Total de registros (histórico conocido)</span>
                <span class="info-stat-valor"><?= number_format($totalEvaluados, 0, ',', '.') ?></span>
            </div>
        </div>

        <div class="panel-dashboard">
            <h2 style="margin-top:0;">Conclusiones — Universidad Distrital Francisco José de Caldas</h2>
            <p style="color:#777;font-size:14px;margin-top:-8px;">
                Limitadas a esta universidad y a los programas de Ingeniería en Telemática (Saber Pro) y Tecnología en Sistematización de Datos (Saber T&T), sin importar el ámbito elegido arriba. El resto del dashboard, más abajo, está limitado a: <strong><?= htmlspecialchars($ambitoEtiquetas[$ambito]) ?></strong>.
            </p>
            <div class="resultado-info">
                <p><strong>Tendencia Saber Pro (universidad):</strong> <?= htmlspecialchars(textoTendencia($variacionProDistrital, 'La universidad en Saber Pro')) ?></p>
                <p><strong>Tendencia Saber T&T (universidad):</strong> <?= htmlspecialchars(textoTendencia($variacionTytDistrital, 'La universidad en Saber T&T')) ?></p>
                <?php if ($diffProVsNacional !== null): ?>
                    <p><strong>Frente al promedio nacional (Saber Pro 2018):</strong> la universidad quedó <?= $diffProVsNacional >= 0 ? number_format($diffProVsNacional, 1) . ' pts por encima' : number_format(abs($diffProVsNacional), 1) . ' pts por debajo' ?> del promedio nacional (<?= number_format($proRecienteNacional, 1) ?> pts).</p>
                <?php endif; ?>
                <?php if ($diffTytVsNacional !== null): ?>
                    <p><strong>Frente al promedio nacional (Saber T&T 2024):</strong> la universidad quedó <?= $diffTytVsNacional >= 0 ? number_format($diffTytVsNacional, 1) . ' pts por encima' : number_format(abs($diffTytVsNacional), 1) . ' pts por debajo' ?> del promedio nacional (<?= number_format($tytRecienteNacional, 1) ?> pts).</p>
                <?php endif; ?>
                <?php if ($moduloMejorProDistrital): ?>
                    <p><strong>En Saber Pro</strong>, el módulo con mejor promedio histórico de la universidad es <em><?= htmlspecialchars(ucwords(mb_strtolower($moduloMejorProDistrital))) ?></em> y el más débil es <em><?= htmlspecialchars(ucwords(mb_strtolower($moduloPeorProDistrital))) ?></em>.</p>
                <?php endif; ?>
                <?php if ($moduloMejorTytDistrital): ?>
                    <p><strong>En Saber T&T</strong>, el módulo con mejor promedio histórico de la universidad es <em><?= htmlspecialchars(ucwords(mb_strtolower($moduloMejorTytDistrital))) ?></em> y el más débil es <em><?= htmlspecialchars(ucwords(mb_strtolower($moduloPeorTytDistrital))) ?></em>.</p>
                <?php endif; ?>
                <?php if ($variacionTelematica !== null): ?>
                    <p><strong>Ingeniería en Telemática (Saber Pro):</strong> <?= htmlspecialchars(textoTendencia($variacionTelematica, 'El programa')) ?><?php if ($diffTelematicaVsUniversidad !== null): ?> En 2018 quedó <?= $diffTelematicaVsUniversidad >= 0 ? number_format($diffTelematicaVsUniversidad, 1) . ' pts por encima' : number_format(abs($diffTelematicaVsUniversidad), 1) . ' pts por debajo' ?> del promedio general de la universidad ese mismo año.<?php endif; ?></p>
                <?php endif; ?>
                <?php if ($moduloEspecificoMejorTelematica): ?>
                    <p><strong>Ingeniería en Telemática — módulo específico (2018):</strong> el mejor promedio fue en <em><?= htmlspecialchars(ucwords(mb_strtolower($moduloEspecificoMejorTelematica))) ?></em> y el más débil en <em><?= htmlspecialchars(ucwords(mb_strtolower($moduloEspecificoPeorTelematica))) ?></em>.</p>
                <?php endif; ?>
                <?php if ($variacionSistematizacion !== null): ?>
                    <p><strong>Tecnología en Sistematización de Datos (Saber T&T):</strong> <?= htmlspecialchars(textoTendencia($variacionSistematizacion, 'El programa')) ?><?php if ($diffSistematizacionVsUniversidad !== null): ?> En 2018 quedó <?= $diffSistematizacionVsUniversidad >= 0 ? number_format($diffSistematizacionVsUniversidad, 1) . ' pts por encima' : number_format(abs($diffSistematizacionVsUniversidad), 1) . ' pts por debajo' ?> del promedio general de la universidad ese mismo año.<?php endif; ?></p>
                <?php endif; ?>
                <?php if ($moduloMejorSistematizacion): ?>
                    <p><strong>Tecnología en Sistematización de Datos — módulo genérico:</strong> el mejor promedio histórico es <em><?= htmlspecialchars(ucwords(mb_strtolower($moduloMejorSistematizacion))) ?></em> y el más débil es <em><?= htmlspecialchars(ucwords(mb_strtolower($moduloPeorSistematizacion))) ?></em>.</p>
                <?php endif; ?>
            </div>
        </div>

        <div class="panel-dashboard">
            <div class="panel-dashboard-grid">
                <div class="panel-dashboard-info">
                    <h2><?= htmlspecialchars($tituloTendencia) ?></h2>
                    <p style="color:#777;font-size:14px;">
                        <?php if ($ambito === 'nacional'): ?>
                            Tendencia nacional por año (2015-2024). El filtro de abajo solo afecta este gráfico.
                        <?php elseif ($ambito === 'universidad'): ?>
                            Tendencia de toda la Universidad Distrital por año. El filtro de abajo solo afecta este gráfico.
                        <?php else: ?>
                            Ingeniería en Telemática (Saber Pro) vs. Tecnología en Sistematización de Datos (Saber T&T), solo módulos genéricos. El filtro de abajo solo afecta este gráfico.
                        <?php endif; ?>
                        Se muestra el % del puntaje máximo oficial de cada prueba (Saber Pro: 300 pts · Saber T&T: 200 pts), para poder comparar ambas de forma equitativa aunque usan escalas distintas; el detalle en puntos aparece al pasar el cursor. 2015 queda fuera por tener una escala antigua sin máximo oficial.
                    </p>
                    <div class="panel-dashboard-filtros">
                        <div class="campo-form">
                            <label for="filtroModuloTendencia">Módulo / competencia</label>
                            <select id="filtroModuloTendencia">
                                <option value="">Todos (promedio)</option>
                                <?php foreach ($modulosDisponibles as $m): ?>
                                    <option value="<?= htmlspecialchars($m) ?>"><?= htmlspecialchars(ucwords(mb_strtolower($m))) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                    </div>
                    <div class="info-simulacro" style="flex-wrap:wrap;">
                        <div class="info-stat">
                            <span class="info-stat-label">Mínimo mostrado</span>
                            <span class="info-stat-valor" id="kpiTendenciaMin">—</span>
                        </div>
                        <div class="info-stat">
                            <span class="info-stat-label">Máximo mostrado</span>
                            <span class="info-stat-valor" id="kpiTendenciaMax">—</span>
                        </div>
                    </div>
                </div>
                <div class="panel-dashboard-grafico" onclick="abrirModalGrafico('tendencia')" title="Clic para ampliar">
                    <canvas id="graficoTendencia"></canvas>
                    <span class="grafico-ampliar-icono">⤢</span>
                </div>
            </div>
        </div>

        <?php if ($ambito === 'nacional'): ?>
        <div class="panel-dashboard">
            <div class="panel-dashboard-grid">
                <div class="panel-dashboard-info">
                    <h2>Tendencia por programa — Universidad Distrital</h2>
                    <p style="color:#777;font-size:14px;">
                        Ingeniería en Telemática (Saber Pro) vs. Tecnología en Sistematización de Datos (Saber T&T), solo módulos genéricos. El filtro de abajo solo afecta este gráfico.
                        Igual que en la tendencia nacional, se muestra el % del puntaje máximo oficial de cada prueba (Saber Pro: 300 pts · Saber T&T: 200 pts) para comparar ambos programas de forma equitativa; el puntaje crudo aparece en el tooltip. 2015 queda fuera por tener una escala antigua sin máximo oficial (solo afecta a Telemática, la única con datos ese año).
                    </p>
                    <div class="panel-dashboard-filtros">
                        <div class="campo-form">
                            <label for="filtroModuloProgramaDistrital">Módulo / competencia</label>
                            <select id="filtroModuloProgramaDistrital">
                                <option value="">Todos (promedio)</option>
                                <?php foreach ($modulosDisponibles as $m): ?>
                                    <option value="<?= htmlspecialchars($m) ?>"><?= htmlspecialchars(ucwords(mb_strtolower($m))) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                    </div>
                    <div class="info-simulacro" style="flex-wrap:wrap;">
                        <div class="info-stat">
                            <span class="info-stat-label">Mínimo mostrado</span>
                            <span class="info-stat-valor" id="kpiProgramaDistritalMin">—</span>
                        </div>
                        <div class="info-stat">
                            <span class="info-stat-label">Máximo mostrado</span>
                            <span class="info-stat-valor" id="kpiProgramaDistritalMax">—</span>
                        </div>
                    </div>
                </div>
                <div class="panel-dashboard-grafico" onclick="abrirModalGrafico('programaDistrital')" title="Clic para ampliar">
                    <canvas id="graficoProgramaDistrital"></canvas>
                    <span class="grafico-ampliar-icono">⤢</span>
                </div>
            </div>
        </div>
        <?php endif; ?>

        <div class="panel-dashboard">
            <div class="panel-dashboard-grid">
                <div class="panel-dashboard-info">
                    <h2>Comparación por área (Saber T&T vs. Saber Pro)</h2>
                    <p style="color:#777;font-size:14px;">
                        El cruce entre las categorías de T&T y de Pro es un criterio propio (no existe en los datos originales) — ver <code>tabla_equivalencia_areas</code>. Los filtros de abajo solo afectan este gráfico.
                        Los valores se muestran como % del puntaje máximo oficial de cada prueba (Saber Pro: 300 pts · Saber T&T: 200 pts): al no compartir escala, comparar el puntaje crudo exageraría la brecha entre ambas. El puntaje crudo original queda disponible en el tooltip.
                    </p>
                    <div class="panel-dashboard-filtros">
                        <div class="campo-form">
                            <label for="filtroTipoModuloArea">Tipo de módulo</label>
                            <select id="filtroTipoModuloArea">
                                <option value="generica">Genérica (5 competencias comunes a todos)</option>
                                <option value="especifica">Específica (propia de cada carrera)</option>
                            </select>
                        </div>
                        <div class="campo-form">
                            <label for="filtroModuloArea">Módulo / competencia</label>
                            <select id="filtroModuloArea">
                                <option value="">Todos (promedio)</option>
                                <?php foreach ($modulosDisponibles as $m): ?>
                                    <option value="<?= htmlspecialchars($m) ?>"><?= htmlspecialchars(ucwords(mb_strtolower($m))) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                    </div>
                    <p style="color:#777;font-size:13px;" id="notaModuloEspecifica">
                        Al elegir "Específica" el filtro de módulo no aplica: cada carrera tiene sus propios módulos específicos, así que se promedian todos los de cada área.
                    </p>
                    <div class="info-simulacro" style="flex-wrap:wrap;">
                        <div class="info-stat">
                            <span class="info-stat-label">Mínimo mostrado</span>
                            <span class="info-stat-valor" id="kpiAreasMin">—</span>
                        </div>
                        <div class="info-stat">
                            <span class="info-stat-label">Máximo mostrado</span>
                            <span class="info-stat-valor" id="kpiAreasMax">—</span>
                        </div>
                    </div>
                </div>
                <div class="panel-dashboard-grafico" onclick="abrirModalGrafico('areas')" title="Clic para ampliar">
                    <canvas id="graficoAreas"></canvas>
                    <span class="grafico-ampliar-icono">⤢</span>
                </div>
            </div>
        </div>

        <?php if ($ambito === 'universidad'): ?>
        <div class="panel-dashboard">
            <h2>Detalle por programa académico (Saber T&T vs. Saber Pro) — Universidad Distrital</h2>
            <p style="color:#777;font-size:14px;margin-top:-8px;">
                Mismo cruce que "Comparación por área" de arriba, pero sin agrupar por área homologada: cada barra es un programa académico de la universidad, con el nombre tal como está registrado en los resultados del ICFES (sin pasar por <code>tabla_equivalencia_areas</code>). Los filtros de abajo solo afectan este gráfico.
                Igual que en Áreas, se muestra el % del puntaje máximo oficial de cada prueba (Saber Pro: 300 pts · Saber T&T: 200 pts); el puntaje crudo aparece en el tooltip.
            </p>
            <div class="fila-horizontal" style="max-width:600px;">
                <div class="campo-form">
                    <label for="filtroTipoModuloProgramaDetalle">Tipo de módulo</label>
                    <select id="filtroTipoModuloProgramaDetalle">
                        <option value="generica">Genérica (5 competencias comunes a todos)</option>
                        <option value="especifica">Específica (propia de cada carrera)</option>
                    </select>
                </div>
                <div class="campo-form">
                    <label for="filtroModuloProgramaDetalle">Módulo / competencia</label>
                    <select id="filtroModuloProgramaDetalle">
                        <option value="">Todos (promedio)</option>
                        <?php foreach ($modulosDisponibles as $m): ?>
                            <option value="<?= htmlspecialchars($m) ?>"><?= htmlspecialchars(ucwords(mb_strtolower($m))) ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
            </div>
            <p style="color:#777;font-size:13px;" id="notaModuloEspecificaProgramaDetalle">
                Al elegir "Específica" el filtro de módulo no aplica: cada carrera tiene sus propios módulos específicos, así que se promedian todos los de cada programa.
            </p>
            <div class="info-simulacro" style="flex-wrap:wrap;">
                <div class="info-stat">
                    <span class="info-stat-label">Mínimo mostrado</span>
                    <span class="info-stat-valor" id="kpiProgramaDetalleMin">—</span>
                </div>
                <div class="info-stat">
                    <span class="info-stat-label">Máximo mostrado</span>
                    <span class="info-stat-valor" id="kpiProgramaDetalleMax">—</span>
                </div>
            </div>
            <div style="overflow-x:auto;">
                <div id="graficoProgramaDetalleWrap" style="position:relative;height:420px;min-width:900px;">
                    <canvas id="graficoProgramaDetalle"></canvas>
                </div>
            </div>
        </div>
        <?php endif; ?>

        <div class="panel-dashboard">
            <div class="panel-dashboard-grid">
                <div class="panel-dashboard-info">
                    <h2>Comparación por región (Saber T&T vs. Saber Pro)</h2>
                    <p style="color:#777;font-size:14px;">
                        Solo con módulos genéricos (a nivel institución solo se homologaron esos). El año lo controla el filtro principal de arriba; el filtro de módulo de abajo solo afecta este gráfico.
                        Igual que en Áreas, se muestra el % del puntaje máximo oficial de cada prueba (Saber Pro: 300 pts · Saber T&T: 200 pts) para que la comparación entre pruebas sea equitativa; el puntaje crudo aparece en el tooltip.
                        <?php if ($ambito !== 'nacional'): ?>
                            Con el ámbito actual (<?= htmlspecialchars($ambitoEtiquetas[$ambito]) ?>) es normal ver una sola región (Andina/Bogotá): la Universidad Distrital está en un solo departamento.
                        <?php endif; ?>
                    </p>
                    <div class="panel-dashboard-filtros">
                        <div class="campo-form">
                            <label for="filtroModuloRegion">Módulo / competencia</label>
                            <select id="filtroModuloRegion">
                                <option value="">Todos (promedio)</option>
                                <?php foreach ($modulosDisponibles as $m): ?>
                                    <option value="<?= htmlspecialchars($m) ?>"><?= htmlspecialchars(ucwords(mb_strtolower($m))) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                    </div>
                    <div class="info-simulacro" style="flex-wrap:wrap;">
                        <div class="info-stat">
                            <span class="info-stat-label">Mínimo mostrado</span>
                            <span class="info-stat-valor" id="kpiRegionesMin">—</span>
                        </div>
                        <div class="info-stat">
                            <span class="info-stat-label">Máximo mostrado</span>
                            <span class="info-stat-valor" id="kpiRegionesMax">—</span>
                        </div>
                    </div>
                </div>
                <div class="panel-dashboard-grafico" onclick="abrirModalGrafico('regiones')" title="Clic para ampliar">
                    <canvas id="graficoRegiones"></canvas>
                    <span class="grafico-ampliar-icono">⤢</span>
                </div>
            </div>
        </div>

        <?php if ($ambito === 'nacional'): ?>
        <div class="panel-dashboard">
            <h2>Top de instituciones</h2>
            <p style="color:#777;font-size:14px;margin-top:-8px;">
                Solo instituciones con al menos 30 registros en esa combinación. El/los año(s) lo controla el filtro principal de arriba (año(s) actual(es): <strong><?= implode(', ', $aniosInst) ?></strong>); los filtros de abajo solo afectan las dos tablas de este recuadro.
            </p>
            <form method="get" class="fila-horizontal" style="align-items:flex-end;">
                <input type="hidden" name="ambito" value="nacional">
                <?php foreach ($aniosSeleccionados as $a): ?>
                    <input type="hidden" name="anio[]" value="<?= $a ?>">
                <?php endforeach; ?>
                <div class="campo-form">
                    <label for="tipo_inst">Tipo de prueba</label>
                    <select id="tipo_inst" name="tipo_inst" onchange="enviarFiltro(this.form)">
                        <option value="Saber Pro" <?= $tipoInst === 'Saber Pro' ? 'selected' : '' ?>>Saber Pro</option>
                        <option value="Saber TyT" <?= $tipoInst === 'Saber TyT' ? 'selected' : '' ?>>Saber T&T</option>
                    </select>
                </div>
                <div class="campo-form">
                    <label for="modulo_inst">Módulo / competencia</label>
                    <select id="modulo_inst" name="modulo_inst" onchange="enviarFiltro(this.form)">
                        <?php foreach ($modulosDisponibles as $m): ?>
                            <option value="<?= htmlspecialchars($m) ?>" <?= $m === $moduloInst ? 'selected' : '' ?>><?= htmlspecialchars(ucwords(mb_strtolower($m))) ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <noscript><button type="submit" class="btn">Filtrar</button></noscript>
            </form>

            <div class="resultado-grid resultado-grid-igual" style="align-items:start;">
                <div>
                    <h2 style="font-size:1.2rem;">🏆 Mejores 10</h2>
                    <table class="tabla-indicadores">
                        <thead><tr><th>Institución</th><th>Región</th><th>Promedio</th><th>Cantidad de registros</th></tr></thead>
                        <tbody>
                            <?php foreach ($mejoresInstituciones as $i): ?>
                                <tr>
                                    <td><?= htmlspecialchars(ucwords(mb_strtolower($i['institucion']))) ?></td>
                                    <td><?= htmlspecialchars(ucwords(mb_strtolower($i['region']))) ?></td>
                                    <td><?= number_format((float) $i['promedio_puntaje'], 1) ?></td>
                                    <td><?= number_format((int) $i['cantidad_evaluados'], 0, ',', '.') ?></td>
                                </tr>
                            <?php endforeach; ?>
                            <?php if (!$mejoresInstituciones): ?>
                                <tr><td colspan="4">Sin datos suficientes para esta combinación.</td></tr>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
                <div>
                    <h2 style="font-size:1.2rem;">⚠️ Peores 10</h2>
                    <table class="tabla-indicadores">
                        <thead><tr><th>Institución</th><th>Región</th><th>Promedio</th><th>Cantidad de registros</th></tr></thead>
                        <tbody>
                            <?php foreach ($peoresInstituciones as $i): ?>
                                <tr>
                                    <td><?= htmlspecialchars(ucwords(mb_strtolower($i['institucion']))) ?></td>
                                    <td><?= htmlspecialchars(ucwords(mb_strtolower($i['region']))) ?></td>
                                    <td><?= number_format((float) $i['promedio_puntaje'], 1) ?></td>
                                    <td><?= number_format((int) $i['cantidad_evaluados'], 0, ',', '.') ?></td>
                                </tr>
                            <?php endforeach; ?>
                            <?php if (!$peoresInstituciones): ?>
                                <tr><td colspan="4">Sin datos suficientes para esta combinación.</td></tr>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <div class="panel-dashboard">
            <h2>Top de programas académicos</h2>
            <p style="color:#777;font-size:14px;margin-top:-8px;">
                Nivel de agregación más fino: institución + programa específico (no solo la institución completa). Solo programas con al menos 20 registros en esa combinación. El/los año(s) lo controla el filtro principal de arriba (año(s) usado(s) aquí: <strong><?= $anioProgDisponible ? implode(', ', $aniosProg) : '—' ?></strong>); los filtros de abajo solo afectan las dos tablas de este recuadro.
            </p>
            <?php
                $aniosProgExcluidos = array_diff($aniosSeleccionados, $aniosProgramaDisponibles);
            ?>
            <?php if (!$anioProgDisponible): ?>
                <p style="color:#e74c3c;font-size:14px;">
                    Este cuadro no tiene datos para <?= implode(', ', $aniosSeleccionados) ?>: solo cubre <?= implode(', ', $aniosProgramaDisponibles) ?>. Cambia el filtro principal de año para ver resultados aquí.
                </p>
            <?php elseif ($aniosProgExcluidos): ?>
                <p style="color:#e08600;font-size:13px;">
                    <?= implode(', ', $aniosProgExcluidos) ?> no <?= count($aniosProgExcluidos) === 1 ? 'tiene' : 'tienen' ?> datos aquí (este cuadro solo cubre <?= implode(', ', $aniosProgramaDisponibles) ?>); se muestran solo con <?= implode(', ', $aniosProg) ?>.
                </p>
            <?php endif; ?>
            <form method="get" class="fila-horizontal" style="align-items:flex-end;">
                <input type="hidden" name="ambito" value="nacional">
                <?php foreach ($aniosSeleccionados as $a): ?>
                    <input type="hidden" name="anio[]" value="<?= $a ?>">
                <?php endforeach; ?>
                <div class="campo-form">
                    <label for="tipo_prog">Tipo de prueba</label>
                    <select id="tipo_prog" name="tipo_prog" onchange="enviarFiltro(this.form)">
                        <option value="Saber Pro" <?= $tipoProg === 'Saber Pro' ? 'selected' : '' ?>>Saber Pro</option>
                        <option value="Saber TyT" <?= $tipoProg === 'Saber TyT' ? 'selected' : '' ?>>Saber T&T</option>
                    </select>
                </div>
                <div class="campo-form">
                    <label for="tipomodulo_prog">Tipo de módulo</label>
                    <select id="tipomodulo_prog" name="tipomodulo_prog" onchange="enviarFiltro(this.form)">
                        <option value="GENERICA" <?= $tipoModuloProg === 'GENERICA' ? 'selected' : '' ?>>Genérica</option>
                        <option value="ESPECIFICA" <?= $tipoModuloProg === 'ESPECIFICA' ? 'selected' : '' ?>>Específica</option>
                    </select>
                </div>
                <div class="campo-form">
                    <label for="modulo_prog">Módulo / competencia</label>
                    <select id="modulo_prog" name="modulo_prog" onchange="enviarFiltro(this.form)">
                        <?php foreach ($modulosProgramaDisponibles as $m): ?>
                            <option value="<?= htmlspecialchars($m) ?>" <?= $m === $moduloProg ? 'selected' : '' ?>><?= htmlspecialchars(ucwords(mb_strtolower($m))) ?></option>
                        <?php endforeach; ?>
                        <?php if (!$modulosProgramaDisponibles): ?>
                            <option value="">Sin módulos para esta combinación</option>
                        <?php endif; ?>
                    </select>
                </div>
                <noscript><button type="submit" class="btn">Filtrar</button></noscript>
            </form>

            <div class="resultado-grid resultado-grid-igual" style="align-items:start;">
                <div>
                    <h2 style="font-size:1.2rem;">🏆 Mejores 10</h2>
                    <table class="tabla-indicadores">
                        <thead><tr><th>Programa</th><th>Institución</th><th>Región</th><th>Promedio</th><th>Cantidad de registros</th></tr></thead>
                        <tbody>
                            <?php foreach ($mejoresProgramas as $p): ?>
                                <tr>
                                    <td><?= htmlspecialchars(ucwords(mb_strtolower($p['programa']))) ?></td>
                                    <td><?= htmlspecialchars(ucwords(mb_strtolower($p['institucion']))) ?></td>
                                    <td><?= htmlspecialchars(ucwords(mb_strtolower($p['region']))) ?></td>
                                    <td><?= number_format((float) $p['promedio_puntaje'], 1) ?></td>
                                    <td><?= number_format((int) $p['cantidad_evaluados'], 0, ',', '.') ?></td>
                                </tr>
                            <?php endforeach; ?>
                            <?php if (!$mejoresProgramas): ?>
                                <tr><td colspan="5">Sin datos suficientes para esta combinación.</td></tr>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
                <div>
                    <h2 style="font-size:1.2rem;">⚠️ Peores 10</h2>
                    <table class="tabla-indicadores">
                        <thead><tr><th>Programa</th><th>Institución</th><th>Región</th><th>Promedio</th><th>Cantidad de registros</th></tr></thead>
                        <tbody>
                            <?php foreach ($peoresProgramas as $p): ?>
                                <tr>
                                    <td><?= htmlspecialchars(ucwords(mb_strtolower($p['programa']))) ?></td>
                                    <td><?= htmlspecialchars(ucwords(mb_strtolower($p['institucion']))) ?></td>
                                    <td><?= htmlspecialchars(ucwords(mb_strtolower($p['region']))) ?></td>
                                    <td><?= number_format((float) $p['promedio_puntaje'], 1) ?></td>
                                    <td><?= number_format((int) $p['cantidad_evaluados'], 0, ',', '.') ?></td>
                                </tr>
                            <?php endforeach; ?>
                            <?php if (!$peoresProgramas): ?>
                                <tr><td colspan="5">Sin datos suficientes para esta combinación.</td></tr>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
        <?php else: ?>
        <div class="panel-dashboard">
            <p style="color:#777;font-size:14px;margin:0;">
                Los rankings "Top de instituciones" y "Top de programas académicos" solo se muestran con el ámbito "Todas las instituciones y programas": con el ámbito actual (<?= htmlspecialchars($ambitoEtiquetas[$ambito]) ?>) hay muy poca información (1 institución o 1-2 programas) para que un ranking de 10 tenga sentido. Ver la sección Conclusiones, más arriba, para el detalle de esos programas.
            </p>
        </div>
        <?php endif; ?>

    </div>
</div>

<div id="spinnerOverlay" class="spinner-overlay">
    <div class="spinner"></div>
</div>

<div id="modalGrafico" class="modal-overlay">
    <div class="modal-contenido">
        <button type="button" class="modal-cerrar" onclick="cerrarModalGrafico()" aria-label="Cerrar">✕</button>
        <h2 id="modalGraficoTitulo"></h2>
        <div class="modal-grafico-contenedor">
            <canvas id="modalCanvas"></canvas>
        </div>
    </div>
</div>

<script>
const anioPrincipal = <?= json_encode($aniosSeleccionados) ?>;
const datosTendencia = <?= json_encode($tendencia, JSON_UNESCAPED_UNICODE) ?>;
const datosAreas = <?= json_encode($areas, JSON_UNESCAPED_UNICODE) ?>;
const datosAreasEspecificas = <?= json_encode($areasEspecificas, JSON_UNESCAPED_UNICODE) ?>;
const datosRegiones = <?= json_encode($regiones, JSON_UNESCAPED_UNICODE) ?>;
const datosProgramaTelematica = <?= json_encode($filasTelematicaGenerica, JSON_UNESCAPED_UNICODE) ?>;
const datosProgramaSistematizacion = <?= json_encode($filasSistematizacionGenerica, JSON_UNESCAPED_UNICODE) ?>;
const datosProgramaDetalleGenerica = <?= json_encode($programasDetalleGenerica, JSON_UNESCAPED_UNICODE) ?>;
const datosProgramaDetalleEspecifica = <?= json_encode($programasDetalleEspecifica, JSON_UNESCAPED_UNICODE) ?>;

const coloresPro = { linea: '#0056b3', barra: '#0073e6' };
const coloresTyt = { linea: '#e74c3c', barra: '#f4a3a3' };

// ---------------------------------------------------------------------
// Escala porcentual comparable entre pruebas.
//
// Saber Pro y Saber T&T NO usan la misma escala de puntaje, aunque en
// los gráficos de abajo se muestran uno junto al otro: desde 2016 Saber
// Pro reporta cada módulo en una escala oficial de 0 a 300 (media=150,
// DE=30 — Res. ICFES 268 de 2020 / guía de orientación Saber Pro),
// mientras que Saber T&T usa una escala oficial de 0 a 200 (media=100,
// DE=20 — guía de orientación de módulos genéricos Saber T&T). Comparar
// el puntaje crudo de una contra la otra sobrestima la brecha (ej. un
// mismo nivel relativo de desempeño se ve como "más bajo" en T&T solo
// por tener un techo de escala más chico). Por eso Tendencia, Áreas y
// Regiones convierten cada promedio a % de su propio máximo oficial
// antes de graficarlo; el tooltip de cada punto/barra sigue mostrando
// el puntaje crudo original entre paréntesis.
//
// 2015 (Saber Pro, escala_no_comparable=1) queda fuera de este cálculo
// a propósito: esa escala vieja no tiene un máximo oficial acotado (es
// una escala tipo z, media=10 DE=1), así que convertirla a "%" sería
// inventar un techo que el ICFES nunca definió. Sigue excluida de estos
// tres gráficos, igual que antes.
const ESCALA_MAXIMA_OFICIAL = { 'Saber Pro': 300, 'Saber TyT': 200 };

function aPorcentaje(valor, tipoPrueba) {
    if (valor === null || valor === undefined || isNaN(valor)) return null;
    const max = ESCALA_MAXIMA_OFICIAL[tipoPrueba];
    if (!max) return null;
    return Number((valor / max * 100).toFixed(1));
}

// Callback de tooltip compartido por los tres gráficos comparables: muestra
// el % (lo que se grafica) y, entre paréntesis, el puntaje crudo original
// sobre su propio máximo oficial (lo que se guardó en dataset._raw / _max
// al armar cada dataset).
function tooltipConPorcentaje(ctx) {
    const pct = ctx.parsed.y;
    if (pct === null || pct === undefined) return `${ctx.dataset.label}: sin datos`;
    const raw = ctx.dataset._raw ? ctx.dataset._raw[ctx.dataIndex] : null;
    const max = ctx.dataset._max;
    const ptsTexto = (raw !== null && raw !== undefined && !isNaN(raw) && max) ? ` (${raw} de ${max} pts)` : '';
    return `${ctx.dataset.label}: ${pct}%${ptsTexto}`;
}

// Registro de instancias de Chart.js por id de canvas: cada gráfico normal
// (graficoTendencia, graficoAreas, graficoRegiones) tiene su versión
// ampliada en el modal (modalCanvas), dibujada con la misma función pero
// apuntando a otro canvas — así no se duplica la lógica de cada gráfico.
const chartsInstancias = {};

function crearOActualizarChart(canvasId, config) {
    if (chartsInstancias[canvasId]) chartsInstancias[canvasId].destroy();
    chartsInstancias[canvasId] = new Chart(document.getElementById(canvasId).getContext('2d'), config);
    return chartsInstancias[canvasId];
}

// ---------------------------------------------------------------------
// Filtro principal de año (multiselección con checkboxes, un clic marca
// o desmarca un año sin necesidad de Ctrl/Cmd). Cada clic aplica el
// filtro de inmediato: cambia la URL (?anio[]=...) preservando el resto
// de filtros ya presentes, y recarga la página — igual que ya hacían los
// filtros de instituciones/programas. El spinner se muestra antes de
// navegar para que quede claro que está cargando. No se permite quedar
// sin ningún año marcado.
// ---------------------------------------------------------------------

function mostrarSpinner() {
    document.getElementById('spinnerOverlay').classList.add('activo');
}

function toggleMultiselectAnio() {
    document.getElementById('multiselectAnio').classList.toggle('abierto');
}

document.addEventListener('click', (ev) => {
    const contenedor = document.getElementById('multiselectAnio');
    if (contenedor && !contenedor.contains(ev.target)) {
        contenedor.classList.remove('abierto');
    }
});

function aplicarAnios(seleccionados) {
    const params = new URLSearchParams(window.location.search);
    params.delete('anio[]');
    seleccionados.forEach(a => params.append('anio[]', a));
    mostrarSpinner();
    window.location.search = params.toString();
}

// Filtro de ámbito: mismo patrón que aplicarAnios (cambia la URL
// preservando el resto de filtros y recarga), pero de selección simple.
function cambiarAmbito(select) {
    const params = new URLSearchParams(window.location.search);
    params.set('ambito', select.value);
    mostrarSpinner();
    window.location.search = params.toString();
}

function onCambioAnio(checkbox) {
    const anio = checkbox.value;
    let seleccionados = anioPrincipal.map(String);
    if (checkbox.checked) {
        if (!seleccionados.includes(anio)) seleccionados.push(anio);
    } else {
        seleccionados = seleccionados.filter(a => a !== anio);
    }
    if (!seleccionados.length) {
        checkbox.checked = true; // no se permite quedar sin ningún año: se revierte
        return;
    }
    aplicarAnios(seleccionados);
}

function onCambioTodosAnios(checkboxTodos) {
    const anios = <?= json_encode(array_map('strval', $aniosDisponibles)) ?>;
    aplicarAnios(checkboxTodos.checked ? anios : [anios[0]]);
}

function limpiarFiltros() {
    mostrarSpinner();
    window.location.href = window.location.pathname;
}

function enviarFiltro(form) {
    mostrarSpinner();
    form.submit();
}

// Actualiza el par de KPIs "Mínimo mostrado" / "Máximo mostrado" que va
// al lado de cada gráfico, a partir de los mismos valores ya graficados
// (no de todo el dataset crudo, para que refleje justo lo que se ve).
// Los tres gráficos que usan esto grafican % del máximo oficial de cada
// prueba (ver ESCALA_MAXIMA_OFICIAL), de ahí el sufijo fijo.
function actualizarKpiMinMax(prefijo, valores) {
    const limpios = valores.filter(v => v !== null && v !== undefined && !isNaN(v));
    const elMin = document.getElementById('kpi' + prefijo + 'Min');
    const elMax = document.getElementById('kpi' + prefijo + 'Max');
    if (!limpios.length) {
        elMin.textContent = '—';
        elMax.textContent = '—';
        return;
    }
    elMin.textContent = Math.min(...limpios).toFixed(1) + '%';
    elMax.textContent = Math.max(...limpios).toFixed(1) + '%';
}

function promedioPorAnioTipo(filas, tipo, modulo) {
    const filtradas = filas.filter(f => f.tipo_prueba === tipo && (!modulo || f.modulo === modulo));
    const porAnio = {};
    filtradas.forEach(f => {
        if (!porAnio[f.anio]) porAnio[f.anio] = [];
        porAnio[f.anio].push(parseFloat(f.promedio_puntaje));
    });
    const anios = Object.keys(porAnio).map(Number).sort((a, b) => a - b);
    return anios.map(anio => ({
        anio,
        promedio: porAnio[anio].reduce((a, b) => a + b, 0) / porAnio[anio].length
    }));
}

function dibujarTendencia(modulo, canvasId, actualizarKpis) {
    canvasId = canvasId || 'graficoTendencia';
    actualizarKpis = actualizarKpis !== false;

    // 2015 se excluye de la línea principal por tener otra escala de puntaje.
    const filas2016enAdelante = datosTendencia.filter(f => f.escala_no_comparable == 0);
    const pro = promedioPorAnioTipo(filas2016enAdelante, 'Saber Pro', modulo);
    const tyt = promedioPorAnioTipo(filas2016enAdelante, 'Saber TyT', modulo);
    const todosLosAnios = [...new Set([...pro.map(p => p.anio), ...tyt.map(t => t.anio)])].sort((a, b) => a - b);

    const mapaValor = (serie) => {
        const m = {};
        serie.forEach(s => m[s.anio] = s.promedio);
        return todosLosAnios.map(a => (a in m) ? Number(m[a].toFixed(1)) : null);
    };

    const rawPro = mapaValor(pro);
    const rawTyt = mapaValor(tyt);
    const pctPro = rawPro.map(v => aPorcentaje(v, 'Saber Pro'));
    const pctTyt = rawTyt.map(v => aPorcentaje(v, 'Saber TyT'));

    crearOActualizarChart(canvasId, {
        type: 'line',
        data: {
            labels: todosLosAnios,
            datasets: [
                { label: 'Saber Pro', data: pctPro, borderColor: coloresPro.linea, backgroundColor: coloresPro.linea, tension: 0.2, spanGaps: true, _raw: rawPro, _max: ESCALA_MAXIMA_OFICIAL['Saber Pro'] },
                { label: 'Saber T&T', data: pctTyt, borderColor: coloresTyt.linea, backgroundColor: coloresTyt.linea, tension: 0.2, spanGaps: true, _raw: rawTyt, _max: ESCALA_MAXIMA_OFICIAL['Saber TyT'] }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: { y: { min: 0, max: 100, ticks: { callback: v => v + '%' } } },
            plugins: { legend: { position: 'top' }, tooltip: { callbacks: { label: tooltipConPorcentaje } } }
        }
    });

    if (actualizarKpis) actualizarKpiMinMax('Tendencia', [...pctPro, ...pctTyt]);
}

function dibujarProgramaDistrital(modulo, canvasId, actualizarKpis) {
    canvasId = canvasId || 'graficoProgramaDistrital';
    actualizarKpis = actualizarKpis !== false;

    // Mismo criterio que dibujarTendencia: se excluye 2015 (escala vieja de
    // Telemática, sin máximo oficial). Sistematización no tiene fila 2015
    // en absoluto (solo existe en Saber T&T).
    const telematica = promedioPorAnioTipo(datosProgramaTelematica.filter(f => f.escala_no_comparable == 0), 'Saber Pro', modulo);
    const sistematizacion = promedioPorAnioTipo(datosProgramaSistematizacion.filter(f => f.escala_no_comparable == 0), 'Saber TyT', modulo);
    const todosLosAnios = [...new Set([...telematica.map(t => t.anio), ...sistematizacion.map(s => s.anio)])].sort((a, b) => a - b);

    const mapaValor = (serie) => {
        const m = {};
        serie.forEach(s => m[s.anio] = s.promedio);
        return todosLosAnios.map(a => (a in m) ? Number(m[a].toFixed(1)) : null);
    };

    const rawTelematica = mapaValor(telematica);
    const rawSistematizacion = mapaValor(sistematizacion);
    const pctTelematica = rawTelematica.map(v => aPorcentaje(v, 'Saber Pro'));
    const pctSistematizacion = rawSistematizacion.map(v => aPorcentaje(v, 'Saber TyT'));

    crearOActualizarChart(canvasId, {
        type: 'line',
        data: {
            labels: todosLosAnios,
            datasets: [
                { label: 'Ingeniería en Telemática (Saber Pro)', data: pctTelematica, borderColor: coloresPro.linea, backgroundColor: coloresPro.linea, tension: 0.2, spanGaps: true, _raw: rawTelematica, _max: ESCALA_MAXIMA_OFICIAL['Saber Pro'] },
                { label: 'Tecnología en Sistematización de Datos (Saber T&T)', data: pctSistematizacion, borderColor: coloresTyt.linea, backgroundColor: coloresTyt.linea, tension: 0.2, spanGaps: true, _raw: rawSistematizacion, _max: ESCALA_MAXIMA_OFICIAL['Saber TyT'] }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: { y: { min: 0, max: 100, ticks: { callback: v => v + '%' } } },
            plugins: { legend: { position: 'top' }, tooltip: { callbacks: { label: tooltipConPorcentaje } } }
        }
    });

    if (actualizarKpis) actualizarKpiMinMax('ProgramaDistrital', [...pctTelematica, ...pctSistematizacion]);
}

function dibujarAreas(modulo, tipoModulo, canvasId, actualizarKpis) {
    canvasId = canvasId || 'graficoAreas';
    actualizarKpis = actualizarKpis !== false;

    // Específica: no hay un módulo fijo común a todas las carreras, así
    // que se ignora el filtro de módulo y se usa la vista ya promediada
    // por área (un valor por área, no varios módulos que combinar).
    const fuente = tipoModulo === 'especifica' ? datosAreasEspecificas : datosAreas;
    const filtradas = (tipoModulo === 'especifica' || !modulo) ? fuente : fuente.filter(a => a.modulo === modulo);

    const porArea = {};
    filtradas.forEach(a => {
        if (!porArea[a.area_homologada]) porArea[a.area_homologada] = { tyt: [], pro: [] };
        if (a.promedio_tyt !== null) porArea[a.area_homologada].tyt.push(parseFloat(a.promedio_tyt));
        if (a.promedio_pro !== null) porArea[a.area_homologada].pro.push(parseFloat(a.promedio_pro));
    });
    const areasNombres = Object.keys(porArea).sort();
    const promedio = (arr) => arr.length ? Number((arr.reduce((a, b) => a + b, 0) / arr.length).toFixed(1)) : null;
    const rawTyt = areasNombres.map(a => promedio(porArea[a].tyt));
    const rawPro = areasNombres.map(a => promedio(porArea[a].pro));
    const pctTyt = rawTyt.map(v => aPorcentaje(v, 'Saber TyT'));
    const pctPro = rawPro.map(v => aPorcentaje(v, 'Saber Pro'));

    crearOActualizarChart(canvasId, {
        type: 'bar',
        data: {
            labels: areasNombres,
            datasets: [
                { label: 'Saber T&T', data: pctTyt, backgroundColor: coloresTyt.barra, _raw: rawTyt, _max: ESCALA_MAXIMA_OFICIAL['Saber TyT'] },
                { label: 'Saber Pro', data: pctPro, backgroundColor: coloresPro.barra, _raw: rawPro, _max: ESCALA_MAXIMA_OFICIAL['Saber Pro'] }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { position: 'top' }, tooltip: { callbacks: { label: tooltipConPorcentaje } } },
            scales: {
                x: { ticks: { autoSkip: false, maxRotation: 40, minRotation: 40 } },
                y: { min: 0, max: 100, ticks: { callback: v => v + '%' } }
            }
        }
    });

    if (actualizarKpis) actualizarKpiMinMax('Areas', [...pctTyt, ...pctPro]);
}

// Contraparte "sin homologar" de dibujarAreas: mismo cruce T&T vs. Pro,
// pero agrupando por programa (nombre original del ICFES) en vez de por
// área homologada. Solo existe en el DOM con ámbito 'universidad' (ver
// guardia más abajo, junto a las demás inicializaciones).
function dibujarProgramaDetalle(modulo, tipoModulo) {
    const fuente = tipoModulo === 'especifica' ? datosProgramaDetalleEspecifica : datosProgramaDetalleGenerica;
    const filtradas = (tipoModulo === 'especifica' || !modulo) ? fuente : fuente.filter(p => p.modulo === modulo);

    const porPrograma = {};
    filtradas.forEach(p => {
        if (!porPrograma[p.programa_legible]) porPrograma[p.programa_legible] = { tyt: [], pro: [] };
        if (p.promedio_tyt !== null) porPrograma[p.programa_legible].tyt.push(parseFloat(p.promedio_tyt));
        if (p.promedio_pro !== null) porPrograma[p.programa_legible].pro.push(parseFloat(p.promedio_pro));
    });
    const programasNombres = Object.keys(porPrograma).sort();
    const promedio = (arr) => arr.length ? Number((arr.reduce((a, b) => a + b, 0) / arr.length).toFixed(1)) : null;
    const rawTyt = programasNombres.map(p => promedio(porPrograma[p].tyt));
    const rawPro = programasNombres.map(p => promedio(porPrograma[p].pro));
    const pctTyt = rawTyt.map(v => aPorcentaje(v, 'Saber TyT'));
    const pctPro = rawPro.map(v => aPorcentaje(v, 'Saber Pro'));

    // Con decenas de programas, 420px fijos amontonarían las etiquetas: el
    // ancho del canvas escala con la cantidad de barras y el contenedor
    // (ver HTML) scrollea horizontalmente en vez de comprimirlas.
    const wrap = document.getElementById('graficoProgramaDetalleWrap');
    if (wrap) wrap.style.minWidth = Math.max(900, programasNombres.length * 55) + 'px';

    crearOActualizarChart('graficoProgramaDetalle', {
        type: 'bar',
        data: {
            labels: programasNombres,
            datasets: [
                { label: 'Saber T&T', data: pctTyt, backgroundColor: coloresTyt.barra, _raw: rawTyt, _max: ESCALA_MAXIMA_OFICIAL['Saber TyT'] },
                { label: 'Saber Pro', data: pctPro, backgroundColor: coloresPro.barra, _raw: rawPro, _max: ESCALA_MAXIMA_OFICIAL['Saber Pro'] }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { position: 'top' }, tooltip: { callbacks: { label: tooltipConPorcentaje } } },
            scales: {
                x: { ticks: { autoSkip: false, maxRotation: 60, minRotation: 60 } },
                y: { min: 0, max: 100, ticks: { callback: v => v + '%' } }
            }
        }
    });

    actualizarKpiMinMax('ProgramaDetalle', [...pctTyt, ...pctPro]);
}

function dibujarRegiones(anios, modulo, canvasId, actualizarKpis) {
    canvasId = canvasId || 'graficoRegiones';
    actualizarKpis = actualizarKpis !== false;

    // Excluye 2015 (escala distinta), igual que la tendencia. anios es un
    // arreglo (filtro principal, multiselección); si viene vacío no filtra
    // por año y promedia todos los disponibles.
    let filtradas = datosRegiones.filter(r => r.escala_no_comparable == 0 && (!modulo || r.modulo === modulo));
    if (anios && anios.length) {
        const aniosStr = anios.map(String);
        filtradas = filtradas.filter(r => aniosStr.includes(String(r.anio)));
    }

    const porRegion = {};
    filtradas.forEach(r => {
        if (!porRegion[r.region]) porRegion[r.region] = { tyt: [], pro: [] };
        const valor = parseFloat(r.promedio_puntaje);
        if (isNaN(valor)) return;
        if (r.tipo_prueba === 'Saber TyT') porRegion[r.region].tyt.push(valor);
        else if (r.tipo_prueba === 'Saber Pro') porRegion[r.region].pro.push(valor);
    });
    const regionesNombres = Object.keys(porRegion).sort();
    const promedio = (arr) => arr.length ? Number((arr.reduce((a, b) => a + b, 0) / arr.length).toFixed(1)) : null;
    const rawTyt = regionesNombres.map(r => promedio(porRegion[r].tyt));
    const rawPro = regionesNombres.map(r => promedio(porRegion[r].pro));
    const pctTyt = rawTyt.map(v => aPorcentaje(v, 'Saber TyT'));
    const pctPro = rawPro.map(v => aPorcentaje(v, 'Saber Pro'));

    crearOActualizarChart(canvasId, {
        type: 'bar',
        data: {
            labels: regionesNombres.map(r => r.charAt(0) + r.slice(1).toLowerCase()),
            datasets: [
                { label: 'Saber T&T', data: pctTyt, backgroundColor: coloresTyt.barra, _raw: rawTyt, _max: ESCALA_MAXIMA_OFICIAL['Saber TyT'] },
                { label: 'Saber Pro', data: pctPro, backgroundColor: coloresPro.barra, _raw: rawPro, _max: ESCALA_MAXIMA_OFICIAL['Saber Pro'] }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { position: 'top' }, tooltip: { callbacks: { label: tooltipConPorcentaje } } },
            scales: {
                x: { ticks: { autoSkip: false, maxRotation: 40, minRotation: 40 } },
                y: { min: 0, max: 100, ticks: { callback: v => v + '%' } }
            }
        }
    });

    if (actualizarKpis) actualizarKpiMinMax('Regiones', [...pctTyt, ...pctPro]);
}

// Cada recuadro tiene su propio filtro (o par de filtros) y su propia
// función de actualización: cambiar uno solo redibuja lo que está en
// ese mismo recuadro, nunca los otros gráficos de la página.

function actualizarTendencia() {
    dibujarTendencia(document.getElementById('filtroModuloTendencia').value);
}

function actualizarProgramaDistrital() {
    dibujarProgramaDistrital(document.getElementById('filtroModuloProgramaDistrital').value);
}

function actualizarArea() {
    const tipoModulo = document.getElementById('filtroTipoModuloArea').value;
    const selectModulo = document.getElementById('filtroModuloArea');
    selectModulo.disabled = (tipoModulo === 'especifica');
    document.getElementById('notaModuloEspecifica').style.display = (tipoModulo === 'especifica') ? '' : 'none';
    dibujarAreas(selectModulo.value, tipoModulo);
}

function actualizarRegion() {
    // El año ya no se elige aquí: lo fija el filtro principal de arriba.
    const modulo = document.getElementById('filtroModuloRegion').value;
    dibujarRegiones(anioPrincipal, modulo);
}

function actualizarProgramaDetalle() {
    const tipoModulo = document.getElementById('filtroTipoModuloProgramaDetalle').value;
    const selectModulo = document.getElementById('filtroModuloProgramaDetalle');
    selectModulo.disabled = (tipoModulo === 'especifica');
    document.getElementById('notaModuloEspecificaProgramaDetalle').style.display = (tipoModulo === 'especifica') ? '' : 'none';
    dibujarProgramaDetalle(selectModulo.value, tipoModulo);
}

// ---------------------------------------------------------------------
// Modal "ampliar gráfico": redibuja el mismo gráfico (con los filtros que
// esté usando en ese momento) en un canvas más grande dentro del modal,
// reutilizando las mismas funciones dibujar* — así no hay dos versiones
// de la lógica de cada gráfico que puedan desincronizarse.
// ---------------------------------------------------------------------

const titulosModalGrafico = {
    tendencia: <?= json_encode($tituloTendencia, JSON_UNESCAPED_UNICODE) ?>,
    programaDistrital: 'Tendencia por programa — Universidad Distrital',
    areas: 'Comparación por área (Saber T&T vs. Saber Pro)',
    regiones: 'Comparación por región (Saber T&T vs. Saber Pro)'
};

function abrirModalGrafico(tipo) {
    if (!titulosModalGrafico[tipo]) return;
    document.getElementById('modalGraficoTitulo').textContent = titulosModalGrafico[tipo];

    // El modal se muestra ANTES de crear el gráfico: Chart.js necesita que
    // el canvas ya tenga tamaño real (con el modal oculto mide 0x0 y el
    // gráfico queda mal dibujado).
    document.getElementById('modalGrafico').classList.add('activo');
    document.body.style.overflow = 'hidden';

    if (tipo === 'tendencia') {
        dibujarTendencia(document.getElementById('filtroModuloTendencia').value, 'modalCanvas', false);
    } else if (tipo === 'programaDistrital') {
        dibujarProgramaDistrital(document.getElementById('filtroModuloProgramaDistrital').value, 'modalCanvas', false);
    } else if (tipo === 'areas') {
        const tipoModulo = document.getElementById('filtroTipoModuloArea').value;
        const modulo = document.getElementById('filtroModuloArea').value;
        dibujarAreas(modulo, tipoModulo, 'modalCanvas', false);
    } else if (tipo === 'regiones') {
        const modulo = document.getElementById('filtroModuloRegion').value;
        dibujarRegiones(anioPrincipal, modulo, 'modalCanvas', false);
    }
}

function cerrarModalGrafico() {
    document.getElementById('modalGrafico').classList.remove('activo');
    document.body.style.overflow = '';
    if (chartsInstancias['modalCanvas']) {
        chartsInstancias['modalCanvas'].destroy();
        delete chartsInstancias['modalCanvas'];
    }
}

document.getElementById('modalGrafico').addEventListener('click', (ev) => {
    if (ev.target.id === 'modalGrafico') cerrarModalGrafico();
});

document.addEventListener('keydown', (ev) => {
    if (ev.key === 'Escape') cerrarModalGrafico();
});

document.getElementById('filtroModuloTendencia').addEventListener('change', actualizarTendencia);
document.getElementById('filtroTipoModuloArea').addEventListener('change', actualizarArea);
document.getElementById('filtroModuloArea').addEventListener('change', actualizarArea);
document.getElementById('filtroModuloRegion').addEventListener('change', actualizarRegion);

// El panel "Tendencia por programa — Universidad Distrital" solo existe
// en el DOM con ámbito 'nacional' (ver PHP más arriba); en los otros dos
// ámbitos ese mismo dato ya lo muestra el gráfico principal de Tendencia.
const filtroProgramaDistritalEl = document.getElementById('filtroModuloProgramaDistrital');
if (filtroProgramaDistritalEl) {
    filtroProgramaDistritalEl.addEventListener('change', actualizarProgramaDistrital);
    actualizarProgramaDistrital();
}

// "Detalle por programa académico" solo existe en el DOM con ámbito
// 'universidad' (ver PHP más arriba).
const filtroTipoModuloProgramaDetalleEl = document.getElementById('filtroTipoModuloProgramaDetalle');
if (filtroTipoModuloProgramaDetalleEl) {
    filtroTipoModuloProgramaDetalleEl.addEventListener('change', actualizarProgramaDetalle);
    document.getElementById('filtroModuloProgramaDetalle').addEventListener('change', actualizarProgramaDetalle);
    actualizarProgramaDetalle();
}

actualizarTendencia();
actualizarArea();
actualizarRegion();
</script>
</body>
</html>
