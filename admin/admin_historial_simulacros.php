<?php
session_start();
require_once __DIR__ . '/../conexion.php';

if (!isset($_SESSION['usuario']) || $_SESSION['rol'] !== 'admin') {
    header("Location: ../auth/login.php");
    exit();
}

$listado = $conn->query("
    SELECT si.id, si.usuario, si.fecha_inicio, si.fecha_fin, si.finalizado_manual,
           tp.nombre AS tipo_prueba, c.nombre AS competencia,
           COUNT(sr.id) AS total_preguntas,
           SUM(CASE WHEN o.es_correcta = 1 AND sr.opcion_elegida = o.etiqueta THEN 1 ELSE 0 END) AS correctas
    FROM simulacros_intentos si
    LEFT JOIN simulacros_respuestas sr ON si.id = sr.intento_id
    LEFT JOIN opciones o ON o.pregunta_id = sr.pregunta_id AND o.etiqueta = sr.opcion_elegida
    LEFT JOIN tipos_prueba tp ON tp.id = si.tipo_prueba_id
    LEFT JOIN competencias c ON c.id = si.competencia_id
    GROUP BY si.id
    ORDER BY si.fecha_inicio DESC
");
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Historial General de Simulacros</title>
<link rel="stylesheet" href="../estilos.css" />
<link rel="icon" href="../favicon.svg" type="image/svg+xml">
<link rel="alternate icon" href="../favicon.ico">
<link rel="apple-touch-icon" href="../apple-touch-icon.png">
</head>
<body>
    <?php require __DIR__ . '/../sidebar.php'; ?>

    <div class="content">
        <div class="contenedor-derecho">
            <h2 style="margin:0;">Historial General de Simulacros</h2>

            <div class="usuarios-toolbar">
                <div class="buscador-usuarios">
                    <span class="buscador-icono">🔍</span>
                    <input type="text" id="buscador" placeholder="Buscar por usuario, tipo de prueba o competencia...">
                </div>
            </div>

            <table class="tabla-indicadores">
                <thead>
                    <tr>
                        <th>Usuario</th>
                        <th>Tipo de Prueba</th>
                        <th>Competencia</th>
                        <th>Fecha</th>
                        <th>Correctas</th>
                        <th>Incorrectas</th>
                        <th>Resultado</th>
                        <th>Estado</th>
                        <th>Ver</th>
                    </tr>
                </thead>
                <tbody id="cuerpoTabla">
                    <?php while ($fila = $listado->fetch_assoc()):
                        $total = (int)$fila['total_preguntas'];
                        $correctas = (int)$fila['correctas'];
                        $incorrectas = $total - $correctas;
                        $porcentaje = $total > 0 ? round(($correctas / $total) * 100) : 0;

                        $tiempoUtilizado = '—';
                        if (!empty($fila['fecha_fin'])) {
                            $segundos = max(0, strtotime($fila['fecha_fin']) - strtotime($fila['fecha_inicio']));
                            $tiempoUtilizado = sprintf('%d min %02d seg', intdiv($segundos, 60), $segundos % 60);
                        }
                    ?>
                        <tr class="fila-usuario">
                            <td>
                                <div class="usuario-nombre"><?= htmlspecialchars($fila['usuario']) ?></div>
                                <div class="usuario-correo">Tiempo utilizado: <?= htmlspecialchars($tiempoUtilizado) ?></div>
                            </td>
                            <td><?= htmlspecialchars($fila['tipo_prueba'] ?? '—') ?></td>
                            <td><?= htmlspecialchars($fila['competencia'] ?? '—') ?></td>
                            <td><?= htmlspecialchars($fila['fecha_inicio']) ?></td>
                            <td><?= $correctas ?></td>
                            <td><?= $incorrectas ?></td>
                            <td><?= $porcentaje ?>%</td>
                            <td>
                                <?php if ($fila['finalizado_manual']): ?>
                                    <span class="estado-badge estado-manual">Finalizado manualmente</span>
                                <?php else: ?>
                                    <span class="estado-badge estado-normal">Completado</span>
                                <?php endif; ?>
                            </td>
                            <td>
                                <a href="../simulacro/simulacro_resultados.php?intento_id=<?= (int)$fila['id'] ?>" class="btn" style="padding:8px 14px;font-size:13px;">Ver</a>
                            </td>
                        </tr>
                    <?php endwhile; ?>
                </tbody>
            </table>

            <p id="sinResultados" style="display:none;color:#777;text-align:center;padding:20px 0;">
                No se encontraron simulacros que coincidan con la búsqueda.
            </p>

            <div class="tabla-paginacion" id="paginacion">
                <span id="resumenPaginacion">Mostrando 0 de 0 simulacros</span>
                <div class="controles">
                    <button type="button" class="paginacion-btn" id="btnPrimero" title="Primera página">«</button>
                    <button type="button" class="paginacion-btn" id="btnAnterior" title="Página anterior">‹</button>
                    <span>Página <input type="text" class="pagina-actual" id="paginaActual" value="1"> de <span id="totalPaginas">1</span></span>
                    <button type="button" class="paginacion-btn" id="btnSiguiente" title="Página siguiente">›</button>
                    <button type="button" class="paginacion-btn" id="btnUltimo" title="Última página">»</button>
                    <button type="button" class="btn" id="btnIr" style="padding:8px 16px;font-size:13px;">Ir</button>
                </div>
            </div>
        </div>
    </div>

    <script>
        // --- Búsqueda y paginación (mismo patrón que admin_usuarios.php) ---
        const TAMANO_PAGINA = 10;
        const todasLasFilas = Array.from(document.querySelectorAll('#cuerpoTabla .fila-usuario'));
        const buscador = document.getElementById('buscador');
        const sinResultados = document.getElementById('sinResultados');
        const resumenPaginacion = document.getElementById('resumenPaginacion');
        const totalPaginasSpan = document.getElementById('totalPaginas');
        const inputPaginaActual = document.getElementById('paginaActual');
        let paginaActual = 1;

        function filasFiltradas() {
            const q = buscador.value.trim().toLowerCase();
            if (!q) return todasLasFilas;
            return todasLasFilas.filter(fila => fila.textContent.toLowerCase().includes(q));
        }

        function renderizarTabla() {
            const filas = filasFiltradas();
            const totalFilas = filas.length;
            const totalPaginas = Math.max(1, Math.ceil(totalFilas / TAMANO_PAGINA));
            paginaActual = Math.min(Math.max(1, paginaActual), totalPaginas);

            const inicio = (paginaActual - 1) * TAMANO_PAGINA;
            const finVisible = Math.min(inicio + TAMANO_PAGINA, totalFilas);

            todasLasFilas.forEach(fila => fila.style.display = 'none');
            filas.slice(inicio, finVisible).forEach(fila => fila.style.display = '');

            sinResultados.style.display = totalFilas === 0 ? 'block' : 'none';
            resumenPaginacion.textContent = totalFilas === 0
                ? 'Mostrando 0 de 0 simulacros'
                : `Mostrando ${inicio + 1}-${finVisible} de ${totalFilas} simulacros`;

            totalPaginasSpan.textContent = totalPaginas;
            inputPaginaActual.value = paginaActual;

            document.getElementById('btnPrimero').disabled = paginaActual === 1;
            document.getElementById('btnAnterior').disabled = paginaActual === 1;
            document.getElementById('btnSiguiente').disabled = paginaActual === totalPaginas;
            document.getElementById('btnUltimo').disabled = paginaActual === totalPaginas;
        }

        function irAPagina(pagina) {
            paginaActual = pagina;
            renderizarTabla();
        }

        buscador.addEventListener('input', function () {
            paginaActual = 1;
            renderizarTabla();
        });

        document.getElementById('btnPrimero').addEventListener('click', () => irAPagina(1));
        document.getElementById('btnAnterior').addEventListener('click', () => irAPagina(paginaActual - 1));
        document.getElementById('btnSiguiente').addEventListener('click', () => irAPagina(paginaActual + 1));
        document.getElementById('btnUltimo').addEventListener('click', () => irAPagina(Infinity));
        document.getElementById('btnIr').addEventListener('click', () => irAPagina(parseInt(inputPaginaActual.value, 10) || 1));
        inputPaginaActual.addEventListener('keydown', function (e) {
            if (e.key === 'Enter') irAPagina(parseInt(inputPaginaActual.value, 10) || 1);
        });

        renderizarTabla();
    </script>
</body>
</html>
