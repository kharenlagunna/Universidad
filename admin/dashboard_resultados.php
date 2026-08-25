<?php
session_start();
require_once __DIR__ . '/../conexion_resultados.php';

if (!isset($_SESSION['usuario']) || $_SESSION['rol'] !== 'admin') {
    header("Location: ../auth/login.php");
    exit();
}

// --- Datos base: tendencia nacional por año/prueba/módulo ---
$tendencia = [];
$res = $connResultados->query("
    SELECT anio, tipo_prueba, modulo, cantidad_evaluados, promedio_puntaje, escala_no_comparable
    FROM vista_promedio_nacional_anual
    ORDER BY anio, tipo_prueba, modulo
");
while ($row = $res->fetch_assoc()) {
    $tendencia[] = $row;
}

// --- Datos base: comparación T&T vs Pro por región y módulo ---
$regiones = [];
$res = $connResultados->query("
    SELECT anio, tipo_prueba, region, modulo, cantidad_evaluados, promedio_puntaje, escala_no_comparable
    FROM vista_resultados_region
    ORDER BY region, anio, tipo_prueba, modulo
");
while ($row = $res->fetch_assoc()) {
    $regiones[] = $row;
}

// --- Datos base: comparación T&T vs Pro por área homologada y módulo ---
$areas = [];
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
    $areas[] = $row;
}

// --- Datos base: lo mismo, pero con módulos ESPECÍFICOS (propios de cada
// carrera, no los 5 genéricos) — ver vista_resultados_especificas_grupo_referencia.
// No se agrupa por módulo porque el vocabulario de módulos específicos
// cambia según la carrera; el área homologada sí sigue aplicando (el
// cruce es por grupo_referencia, no por nombre de módulo).
$areasEspecificas = [];
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
    $areasEspecificas[] = $row;
}

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

$proReciente = promedioGeneral($tendencia, 2018, 'Saber Pro');
$proInicial  = promedioGeneral($tendencia, 2016, 'Saber Pro');
$tytReciente = promedioGeneral($tendencia, 2024, 'Saber TyT');
$tytInicial  = promedioGeneral($tendencia, 2016, 'Saber TyT');

$variacionPro = ($proReciente !== null && $proInicial !== null) ? round($proReciente - $proInicial, 1) : null;
$variacionTyt = ($tytReciente !== null && $tytInicial !== null) ? round($tytReciente - $tytInicial, 1) : null;

$totalEvaluados = 0;
foreach ($tendencia as $f) {
    $totalEvaluados += (int) ($f['cantidad_evaluados'] ?? 0);
}

// Brecha por área (Pro - T&T), promediando los módulos disponibles de cada área
$acumuladoPorArea = [];
foreach ($areas as $a) {
    if ($a['promedio_tyt'] === null || $a['promedio_pro'] === null) continue;
    $area = $a['area_homologada'];
    $acumuladoPorArea[$area]['pro'][] = (float) $a['promedio_pro'];
    $acumuladoPorArea[$area]['tyt'][] = (float) $a['promedio_tyt'];
}
$brechas = [];
foreach ($acumuladoPorArea as $area => $d) {
    $promPro = array_sum($d['pro']) / count($d['pro']);
    $promTyt = array_sum($d['tyt']) / count($d['tyt']);
    $brechas[$area] = round($promPro - $promTyt, 1);
}
arsort($brechas);
$areaMayorBrecha = $brechas ? array_key_first($brechas) : null;
$areaMenorBrecha = $brechas ? array_key_last($brechas) : null;

[$moduloMejorPro, $moduloPeorPro] = moduloExtremos($tendencia, 'Saber Pro');
[$moduloMejorTyt, $moduloPeorTyt] = moduloExtremos($tendencia, 'Saber TyT');

$evaluadosPorAnio = [];
foreach ($tendencia as $f) {
    if ($f['cantidad_evaluados'] === null) continue;
    $evaluadosPorAnio[$f['anio']] = ($evaluadosPorAnio[$f['anio']] ?? 0) + (int) $f['cantidad_evaluados'];
}
arsort($evaluadosPorAnio);
$anioMasEvaluados = $evaluadosPorAnio ? array_key_first($evaluadosPorAnio) : null;

$modulosDisponibles = ['COMPETENCIAS CIUDADANAS', 'COMUNICACIÓN ESCRITA', 'INGLÉS', 'LECTURA CRÍTICA', 'RAZONAMIENTO CUANTITATIVO'];
$aniosDisponibles = [2015, 2016, 2017, 2018, 2024];

// Región con mejor/peor promedio histórico (excluye 2015 por la escala distinta)
$acumuladoPorRegion = [];
foreach ($regiones as $r) {
    if ((int) $r['escala_no_comparable'] === 1 || $r['promedio_puntaje'] === null) continue;
    $acumuladoPorRegion[$r['region']][] = (float) $r['promedio_puntaje'];
}
$promedioPorRegion = [];
foreach ($acumuladoPorRegion as $region => $vals) {
    $promedioPorRegion[$region] = array_sum($vals) / count($vals);
}
arsort($promedioPorRegion);
$regionMejor = $promedioPorRegion ? array_key_first($promedioPorRegion) : null;
$regionPeor = $promedioPorRegion ? array_key_last($promedioPorRegion) : null;

// ---------------------------------------------------------------------
// Top de instituciones (requiere año específico + prueba + módulo:
// es demasiada información para mandar toda al navegador, se filtra
// aquí mismo con GET y se recalcula al enviar el formulario).
// ---------------------------------------------------------------------
$anioInstCrudo = (int) ($_GET['anio_inst'] ?? 2018);
$anioInst = in_array($anioInstCrudo, $aniosDisponibles, true) ? $anioInstCrudo : 2018;
$tipoInst = in_array($_GET['tipo_inst'] ?? '', ['Saber Pro', 'Saber TyT']) ? $_GET['tipo_inst'] : 'Saber Pro';
$moduloInst = in_array($_GET['modulo_inst'] ?? '', $modulosDisponibles) ? $_GET['modulo_inst'] : 'RAZONAMIENTO CUANTITATIVO';

$stmt = $connResultados->prepare("
    SELECT i.institucion, COALESCE(r.region, 'SIN CLASIFICAR') AS region, i.promedio_puntaje, i.cantidad_evaluados
    FROM vista_resultados_institucion i
    LEFT JOIN tabla_departamento_region r ON r.departamento = i.departamento
    WHERE i.anio = ? AND i.tipo_prueba = ? AND i.modulo = ? AND i.cantidad_evaluados >= 30
    ORDER BY i.promedio_puntaje DESC
    LIMIT 10
");
$stmt->bind_param('iss', $anioInst, $tipoInst, $moduloInst);
$stmt->execute();
$mejoresInstituciones = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

$stmt = $connResultados->prepare("
    SELECT i.institucion, COALESCE(r.region, 'SIN CLASIFICAR') AS region, i.promedio_puntaje, i.cantidad_evaluados
    FROM vista_resultados_institucion i
    LEFT JOIN tabla_departamento_region r ON r.departamento = i.departamento
    WHERE i.anio = ? AND i.tipo_prueba = ? AND i.modulo = ? AND i.cantidad_evaluados >= 30
    ORDER BY i.promedio_puntaje ASC
    LIMIT 10
");
$stmt->bind_param('iss', $anioInst, $tipoInst, $moduloInst);
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
$aniosProgramaDisponibles = [2015, 2016, 2017, 2018];

$anioProgCrudo = (int) ($_GET['anio_prog'] ?? 2018);
$anioProg = in_array($anioProgCrudo, $aniosProgramaDisponibles, true) ? $anioProgCrudo : 2018;
$tipoProg = in_array($_GET['tipo_prog'] ?? '', ['Saber Pro', 'Saber TyT']) ? $_GET['tipo_prog'] : 'Saber Pro';
$tipoModuloProg = in_array($_GET['tipomodulo_prog'] ?? '', ['GENERICA', 'ESPECIFICA']) ? $_GET['tipomodulo_prog'] : 'GENERICA';

// El módulo depende de tipo_prueba + tipo_modulo (los específicos varían
// por carrera), así que la lista de opciones se calcula en vivo.
$stmt = $connResultados->prepare("
    SELECT DISTINCT modulo
    FROM vista_resultados_programa
    WHERE anio = ? AND tipo_prueba = ? AND tipo_modulo = ?
    ORDER BY modulo
");
$stmt->bind_param('iss', $anioProg, $tipoProg, $tipoModuloProg);
$stmt->execute();
$modulosProgramaDisponibles = array_column($stmt->get_result()->fetch_all(MYSQLI_ASSOC), 'modulo');

$moduloProgCrudo = $_GET['modulo_prog'] ?? '';
$moduloProg = in_array($moduloProgCrudo, $modulosProgramaDisponibles, true)
    ? $moduloProgCrudo
    : ($modulosProgramaDisponibles[0] ?? '');

$mejoresProgramas = [];
$peoresProgramas = [];
if ($moduloProg !== '') {
    $stmt = $connResultados->prepare("
        SELECT p.programa, p.institucion, COALESCE(r.region, 'SIN CLASIFICAR') AS region, p.promedio_puntaje, p.cantidad_evaluados
        FROM vista_resultados_programa p
        LEFT JOIN tabla_departamento_region r ON r.departamento = p.departamento
        WHERE p.anio = ? AND p.tipo_prueba = ? AND p.tipo_modulo = ? AND p.modulo = ? AND p.cantidad_evaluados >= 20
        ORDER BY p.promedio_puntaje DESC
        LIMIT 10
    ");
    $stmt->bind_param('isss', $anioProg, $tipoProg, $tipoModuloProg, $moduloProg);
    $stmt->execute();
    $mejoresProgramas = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

    $stmt = $connResultados->prepare("
        SELECT p.programa, p.institucion, COALESCE(r.region, 'SIN CLASIFICAR') AS region, p.promedio_puntaje, p.cantidad_evaluados
        FROM vista_resultados_programa p
        LEFT JOIN tabla_departamento_region r ON r.departamento = p.departamento
        WHERE p.anio = ? AND p.tipo_prueba = ? AND p.tipo_modulo = ? AND p.modulo = ? AND p.cantidad_evaluados >= 20
        ORDER BY p.promedio_puntaje ASC
        LIMIT 10
    ");
    $stmt->bind_param('isss', $anioProg, $tipoProg, $tipoModuloProg, $moduloProg);
    $stmt->execute();
    $peoresProgramas = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
}
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
        <p style="color:#555;">
            Comparación de los resultados históricos reales aplicados en Colombia (datos agregados del ICFES, 2015-2024).
        </p>

        <div class="info-simulacro" style="flex-wrap:wrap;">
            <div class="info-stat">
                <span class="info-stat-label">Saber Pro 2018 (promedio)</span>
                <span class="info-stat-valor"><?= $proReciente !== null ? number_format($proReciente, 1) : '—' ?></span>
            </div>
            <div class="info-stat">
                <span class="info-stat-label">Saber T&T 2024 (promedio)</span>
                <span class="info-stat-valor"><?= $tytReciente !== null ? number_format($tytReciente, 1) : '—' ?></span>
            </div>
            <div class="info-stat">
                <span class="info-stat-label">Variación Saber Pro (2016→2018)</span>
                <span class="info-stat-valor"><?= $variacionPro !== null ? ($variacionPro >= 0 ? '+' : '') . number_format($variacionPro, 1) : '—' ?></span>
            </div>
            <div class="info-stat">
                <span class="info-stat-label">Variación Saber T&T (2016→2024)</span>
                <span class="info-stat-valor"><?= $variacionTyt !== null ? ($variacionTyt >= 0 ? '+' : '') . number_format($variacionTyt, 1) : '—' ?></span>
            </div>
            <div class="info-stat">
                <span class="info-stat-label">Total de registros (histórico conocido)</span>
                <span class="info-stat-valor"><?= number_format($totalEvaluados, 0, ',', '.') ?></span>
            </div>
        </div>

        <p style="color:#777;font-size:13px;">
            Cada recuadro de abajo tiene sus propios filtros: solo afectan el gráfico o la tabla que está dentro de ese mismo recuadro, ninguno cambia el resto de la página.
        </p>

        <div class="panel-dashboard">
            <h2>¿Mejoran los resultados con el tiempo?</h2>
            <p style="color:#777;font-size:14px;margin-top:-8px;">
                Tendencia nacional por año (2015-2024). El filtro de abajo solo afecta este gráfico.
            </p>
            <div class="fila-horizontal" style="align-items:flex-end;">
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
            <div class="info-simulacro" style="flex-wrap:wrap;max-width:700px;">
                <div class="info-stat">
                    <span class="info-stat-label">Mínimo mostrado</span>
                    <span class="info-stat-valor" id="kpiTendenciaMin">—</span>
                </div>
                <div class="info-stat">
                    <span class="info-stat-label">Máximo mostrado</span>
                    <span class="info-stat-valor" id="kpiTendenciaMax">—</span>
                </div>
            </div>
            <div style="max-width:700px;">
                <canvas id="graficoTendencia" height="280"></canvas>
            </div>
        </div>

        <div class="panel-dashboard">
            <h2>Comparación por área (Saber T&T vs. Saber Pro)</h2>
            <p style="color:#777;font-size:14px;margin-top:-8px;">
                El cruce entre las categorías de T&T y de Pro es un criterio propio (no existe en los datos originales) — ver <code>tabla_equivalencia_areas</code>. Los filtros de abajo solo afectan este gráfico.
            </p>
            <div class="fila-horizontal" style="align-items:flex-end;">
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
            <p style="color:#777;font-size:13px;margin-top:-6px;" id="notaModuloEspecifica">
                Al elegir "Específica" el filtro de módulo no aplica: cada carrera tiene sus propios módulos específicos, así que se promedian todos los de cada área.
            </p>
            <div class="info-simulacro" style="flex-wrap:wrap;max-width:820px;">
                <div class="info-stat">
                    <span class="info-stat-label">Mínimo mostrado</span>
                    <span class="info-stat-valor" id="kpiAreasMin">—</span>
                </div>
                <div class="info-stat">
                    <span class="info-stat-label">Máximo mostrado</span>
                    <span class="info-stat-valor" id="kpiAreasMax">—</span>
                </div>
            </div>
            <div style="max-width:820px;">
                <canvas id="graficoAreas" height="300"></canvas>
            </div>
        </div>

        <div class="panel-dashboard">
            <h2>Comparación por región (Saber T&T vs. Saber Pro)</h2>
            <p style="color:#777;font-size:14px;margin-top:-8px;">
                Solo con módulos genéricos (a nivel institución solo se homologaron esos). Los filtros de abajo solo afectan este gráfico.
            </p>
            <div class="fila-horizontal" style="align-items:flex-end;">
                <div class="campo-form">
                    <label for="filtroAnioRegion">Año</label>
                    <select id="filtroAnioRegion">
                        <option value="">Todos los años (promedio)</option>
                        <?php foreach ($aniosDisponibles as $a): ?>
                            <option value="<?= $a ?>"><?= $a ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
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
            <div class="info-simulacro" style="flex-wrap:wrap;max-width:820px;">
                <div class="info-stat">
                    <span class="info-stat-label">Mínimo mostrado</span>
                    <span class="info-stat-valor" id="kpiRegionesMin">—</span>
                </div>
                <div class="info-stat">
                    <span class="info-stat-label">Máximo mostrado</span>
                    <span class="info-stat-valor" id="kpiRegionesMax">—</span>
                </div>
            </div>
            <div style="max-width:820px;">
                <canvas id="graficoRegiones" height="280"></canvas>
            </div>
        </div>

        <div class="panel-dashboard">
            <h2>Top de instituciones</h2>
            <p style="color:#777;font-size:14px;margin-top:-8px;">
                Solo instituciones con al menos 30 registros en esa combinación. Los filtros de abajo solo afectan las dos tablas de este recuadro.
            </p>
            <form method="get" class="fila-horizontal" style="align-items:flex-end;">
                <div class="campo-form">
                    <label for="anio_inst">Año</label>
                    <select id="anio_inst" name="anio_inst" onchange="this.form.submit()">
                        <?php foreach ($aniosDisponibles as $a): ?>
                            <option value="<?= $a ?>" <?= $a === $anioInst ? 'selected' : '' ?>><?= $a ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="campo-form">
                    <label for="tipo_inst">Tipo de prueba</label>
                    <select id="tipo_inst" name="tipo_inst" onchange="this.form.submit()">
                        <option value="Saber Pro" <?= $tipoInst === 'Saber Pro' ? 'selected' : '' ?>>Saber Pro</option>
                        <option value="Saber TyT" <?= $tipoInst === 'Saber TyT' ? 'selected' : '' ?>>Saber T&T</option>
                    </select>
                </div>
                <div class="campo-form">
                    <label for="modulo_inst">Módulo / competencia</label>
                    <select id="modulo_inst" name="modulo_inst" onchange="this.form.submit()">
                        <?php foreach ($modulosDisponibles as $m): ?>
                            <option value="<?= htmlspecialchars($m) ?>" <?= $m === $moduloInst ? 'selected' : '' ?>><?= htmlspecialchars(ucwords(mb_strtolower($m))) ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <noscript><button type="submit" class="btn">Filtrar</button></noscript>
            </form>

            <div class="resultado-grid" style="align-items:start;">
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
                Nivel de agregación más fino: institución + programa específico (no solo la institución completa). Solo programas con al menos 20 registros en esa combinación. Los filtros de abajo solo afectan las dos tablas de este recuadro.
            </p>
            <form method="get" class="fila-horizontal" style="align-items:flex-end;">
                <div class="campo-form">
                    <label for="anio_prog">Año</label>
                    <select id="anio_prog" name="anio_prog" onchange="this.form.submit()">
                        <?php foreach ($aniosProgramaDisponibles as $a): ?>
                            <option value="<?= $a ?>" <?= $a === $anioProg ? 'selected' : '' ?>><?= $a ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="campo-form">
                    <label for="tipo_prog">Tipo de prueba</label>
                    <select id="tipo_prog" name="tipo_prog" onchange="this.form.submit()">
                        <option value="Saber Pro" <?= $tipoProg === 'Saber Pro' ? 'selected' : '' ?>>Saber Pro</option>
                        <option value="Saber TyT" <?= $tipoProg === 'Saber TyT' ? 'selected' : '' ?>>Saber T&T</option>
                    </select>
                </div>
                <div class="campo-form">
                    <label for="tipomodulo_prog">Tipo de módulo</label>
                    <select id="tipomodulo_prog" name="tipomodulo_prog" onchange="this.form.submit()">
                        <option value="GENERICA" <?= $tipoModuloProg === 'GENERICA' ? 'selected' : '' ?>>Genérica</option>
                        <option value="ESPECIFICA" <?= $tipoModuloProg === 'ESPECIFICA' ? 'selected' : '' ?>>Específica</option>
                    </select>
                </div>
                <div class="campo-form">
                    <label for="modulo_prog">Módulo / competencia</label>
                    <select id="modulo_prog" name="modulo_prog" onchange="this.form.submit()">
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

            <div class="resultado-grid" style="align-items:start;">
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

        <h2 style="margin-top:10px;">Conclusiones</h2>
        <div class="resultado-info">
            <p><strong>Tendencia Saber Pro:</strong> <?= htmlspecialchars(textoTendencia($variacionPro, 'Saber Pro')) ?></p>
            <p><strong>Tendencia Saber T&T:</strong> <?= htmlspecialchars(textoTendencia($variacionTyt, 'Saber T&T')) ?></p>
            <?php if ($areaMayorBrecha): ?>
                <p><strong>Mayor brecha T&T → Pro:</strong> <?= htmlspecialchars(ucwords(mb_strtolower($areaMayorBrecha))) ?> (+<?= number_format($brechas[$areaMayorBrecha], 1) ?> pts a favor de Pro).</p>
            <?php endif; ?>
            <?php if ($areaMenorBrecha): ?>
                <p><strong>Menor brecha T&T → Pro:</strong> <?= htmlspecialchars(ucwords(mb_strtolower($areaMenorBrecha))) ?> (+<?= number_format($brechas[$areaMenorBrecha], 1) ?> pts).</p>
            <?php endif; ?>
            <?php if ($moduloMejorPro): ?>
                <p><strong>En Saber Pro</strong>, el módulo con mejor promedio histórico es <em><?= htmlspecialchars(ucwords(mb_strtolower($moduloMejorPro))) ?></em> y el más débil es <em><?= htmlspecialchars(ucwords(mb_strtolower($moduloPeorPro))) ?></em>.</p>
            <?php endif; ?>
            <?php if ($moduloMejorTyt): ?>
                <p><strong>En Saber T&T</strong>, el módulo con mejor promedio histórico es <em><?= htmlspecialchars(ucwords(mb_strtolower($moduloMejorTyt))) ?></em> y el más débil es <em><?= htmlspecialchars(ucwords(mb_strtolower($moduloPeorTyt))) ?></em>.</p>
            <?php endif; ?>
            <?php if ($anioMasEvaluados): ?>
                <p><strong>Año con mayor cantidad de registros:</strong> <?= htmlspecialchars($anioMasEvaluados) ?> (<?= number_format($evaluadosPorAnio[$anioMasEvaluados], 0, ',', '.') ?> registros).</p>
            <?php endif; ?>
            <?php if ($regionMejor): ?>
                <p><strong>Región con mejor promedio histórico:</strong> <?= htmlspecialchars(ucwords(mb_strtolower($regionMejor))) ?> (<?= number_format($promedioPorRegion[$regionMejor], 1) ?> pts).</p>
            <?php endif; ?>
            <?php if ($regionPeor): ?>
                <p><strong>Región con menor promedio histórico:</strong> <?= htmlspecialchars(ucwords(mb_strtolower($regionPeor))) ?> (<?= number_format($promedioPorRegion[$regionPeor], 1) ?> pts). Excluye 2015 por su escala distinta.</p>
            <?php endif; ?>
        </div>
    </div>
</div>

<script>
const datosTendencia = <?= json_encode($tendencia, JSON_UNESCAPED_UNICODE) ?>;
const datosAreas = <?= json_encode($areas, JSON_UNESCAPED_UNICODE) ?>;
const datosAreasEspecificas = <?= json_encode($areasEspecificas, JSON_UNESCAPED_UNICODE) ?>;
const datosRegiones = <?= json_encode($regiones, JSON_UNESCAPED_UNICODE) ?>;

const coloresPro = { linea: '#0056b3', barra: '#0073e6' };
const coloresTyt = { linea: '#e74c3c', barra: '#f4a3a3' };

let graficoTendencia = null;
let graficoAreas = null;
let graficoRegiones = null;

// Actualiza el par de KPIs "Mínimo mostrado" / "Máximo mostrado" que va
// al lado de cada gráfico, a partir de los mismos valores ya graficados
// (no de todo el dataset crudo, para que refleje justo lo que se ve).
function actualizarKpiMinMax(prefijo, valores) {
    const limpios = valores.filter(v => v !== null && v !== undefined && !isNaN(v));
    const elMin = document.getElementById('kpi' + prefijo + 'Min');
    const elMax = document.getElementById('kpi' + prefijo + 'Max');
    if (!limpios.length) {
        elMin.textContent = '—';
        elMax.textContent = '—';
        return;
    }
    elMin.textContent = Math.min(...limpios).toFixed(1);
    elMax.textContent = Math.max(...limpios).toFixed(1);
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

function dibujarTendencia(modulo) {
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

    if (graficoTendencia) graficoTendencia.destroy();
    graficoTendencia = new Chart(document.getElementById('graficoTendencia').getContext('2d'), {
        type: 'line',
        data: {
            labels: todosLosAnios,
            datasets: [
                { label: 'Saber Pro', data: mapaValor(pro), borderColor: coloresPro.linea, backgroundColor: coloresPro.linea, tension: 0.2, spanGaps: true },
                { label: 'Saber T&T', data: mapaValor(tyt), borderColor: coloresTyt.linea, backgroundColor: coloresTyt.linea, tension: 0.2, spanGaps: true }
            ]
        },
        options: { responsive: true, plugins: { legend: { position: 'top' } } }
    });

    actualizarKpiMinMax('Tendencia', [...mapaValor(pro), ...mapaValor(tyt)]);
}

function dibujarAreas(modulo, tipoModulo) {
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
    const valoresTyt = areasNombres.map(a => promedio(porArea[a].tyt));
    const valoresPro = areasNombres.map(a => promedio(porArea[a].pro));

    if (graficoAreas) graficoAreas.destroy();
    graficoAreas = new Chart(document.getElementById('graficoAreas').getContext('2d'), {
        type: 'bar',
        data: {
            labels: areasNombres,
            datasets: [
                { label: 'Saber T&T', data: valoresTyt, backgroundColor: coloresTyt.barra },
                { label: 'Saber Pro', data: valoresPro, backgroundColor: coloresPro.barra }
            ]
        },
        options: {
            responsive: true,
            plugins: { legend: { position: 'top' } },
            scales: { x: { ticks: { autoSkip: false, maxRotation: 40, minRotation: 40 } } }
        }
    });

    actualizarKpiMinMax('Areas', [...valoresTyt, ...valoresPro]);
}

function dibujarRegiones(anio, modulo) {
    // Excluye 2015 (escala distinta), igual que la tendencia. Si no hay año
    // seleccionado, promedia todos los años disponibles (2016-2024).
    let filtradas = datosRegiones.filter(r => r.escala_no_comparable == 0 && (!modulo || r.modulo === modulo));
    if (anio) filtradas = filtradas.filter(r => String(r.anio) === String(anio));

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
    const valoresTyt = regionesNombres.map(r => promedio(porRegion[r].tyt));
    const valoresPro = regionesNombres.map(r => promedio(porRegion[r].pro));

    if (graficoRegiones) graficoRegiones.destroy();
    graficoRegiones = new Chart(document.getElementById('graficoRegiones').getContext('2d'), {
        type: 'bar',
        data: {
            labels: regionesNombres.map(r => r.charAt(0) + r.slice(1).toLowerCase()),
            datasets: [
                { label: 'Saber T&T', data: valoresTyt, backgroundColor: coloresTyt.barra },
                { label: 'Saber Pro', data: valoresPro, backgroundColor: coloresPro.barra }
            ]
        },
        options: {
            responsive: true,
            plugins: { legend: { position: 'top' } },
            scales: { x: { ticks: { autoSkip: false, maxRotation: 40, minRotation: 40 } } }
        }
    });

    actualizarKpiMinMax('Regiones', [...valoresTyt, ...valoresPro]);
}

// Cada recuadro tiene su propio filtro (o par de filtros) y su propia
// función de actualización: cambiar uno solo redibuja lo que está en
// ese mismo recuadro, nunca los otros gráficos de la página.

function actualizarTendencia() {
    dibujarTendencia(document.getElementById('filtroModuloTendencia').value);
}

function actualizarArea() {
    const tipoModulo = document.getElementById('filtroTipoModuloArea').value;
    const selectModulo = document.getElementById('filtroModuloArea');
    selectModulo.disabled = (tipoModulo === 'especifica');
    document.getElementById('notaModuloEspecifica').style.display = (tipoModulo === 'especifica') ? '' : 'none';
    dibujarAreas(selectModulo.value, tipoModulo);
}

function actualizarRegion() {
    const anio = document.getElementById('filtroAnioRegion').value;
    const modulo = document.getElementById('filtroModuloRegion').value;
    dibujarRegiones(anio, modulo);
}

document.getElementById('filtroModuloTendencia').addEventListener('change', actualizarTendencia);
document.getElementById('filtroTipoModuloArea').addEventListener('change', actualizarArea);
document.getElementById('filtroModuloArea').addEventListener('change', actualizarArea);
document.getElementById('filtroAnioRegion').addEventListener('change', actualizarRegion);
document.getElementById('filtroModuloRegion').addEventListener('change', actualizarRegion);

actualizarTendencia();
actualizarArea();
actualizarRegion();
</script>
</body>
</html>
