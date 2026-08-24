<?php
session_start();
require_once __DIR__ . '/../conexion.php';

if (!isset($_SESSION['usuario']) || $_SESSION['rol'] !== 'admin') {
    header("Location: ../auth/login.php");
    exit();
}

$flashOk = $_SESSION['flash_ok'] ?? '';
$flashError = $_SESSION['flash_error'] ?? '';
unset($_SESSION['flash_ok'], $_SESSION['flash_error']);

$listado = $conn->query("
    SELECT cp.id, cp.duracion_minutos, cp.cantidad_preguntas,
           tp.nombre AS tipo_prueba, c.nombre AS competencia,
           (SELECT COUNT(*) FROM preguntas p WHERE p.tipo_prueba_id = cp.tipo_prueba_id AND p.competencia_id = cp.competencia_id) AS preguntas_cargadas
    FROM configuracion_pruebas cp
    INNER JOIN tipos_prueba tp ON tp.id = cp.tipo_prueba_id
    INNER JOIN competencias c ON c.id = cp.competencia_id
    ORDER BY tp.nombre ASC, c.nombre ASC
");
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<title>Configuración de Pruebas</title>
<link rel="stylesheet" href="../estilos.css" />
<link rel="icon" href="../favicon.svg" type="image/svg+xml">
<link rel="alternate icon" href="../favicon.ico">
<link rel="apple-touch-icon" href="../apple-touch-icon.png">
</head>
<body>
    <?php require __DIR__ . '/../sidebar.php'; ?>

    <div class="content">
        <div class="contenedor-derecho">
            <h2 style="margin:0;">Configuración de Pruebas</h2>
            <p style="margin-top:0;color:#555;font-size:14px;">
                Define cuántos minutos y cuántas preguntas se presentan por cada combinación de Tipo de Prueba y Competencia.
                Deja "Cantidad de preguntas" vacío para usar todas las que estén cargadas.
            </p>

            <?php if ($flashOk): ?>
                <p style="color:#1a7f37;font-weight:600;"><?= htmlspecialchars($flashOk) ?></p>
            <?php endif; ?>
            <?php if ($flashError): ?>
                <p class="error"><?= htmlspecialchars($flashError) ?></p>
            <?php endif; ?>

            <table class="tabla-indicadores">
                <thead>
                    <tr>
                        <th>Tipo de Prueba</th>
                        <th>Competencia</th>
                        <th>Duración (min)</th>
                        <th>Cantidad de preguntas</th>
                        <th>Preguntas cargadas</th>
                        <th>Acciones</th>
                    </tr>
                </thead>
                <tbody id="cuerpoTabla">
                    <?php while ($fila = $listado->fetch_assoc()): ?>
                        <tr>
                            <td><?= htmlspecialchars($fila['tipo_prueba']) ?></td>
                            <td><?= htmlspecialchars($fila['competencia']) ?></td>
                            <td><?= (int)$fila['duracion_minutos'] ?></td>
                            <td><?= $fila['cantidad_preguntas'] !== null ? (int)$fila['cantidad_preguntas'] : 'Todas' ?></td>
                            <td><?= (int)$fila['preguntas_cargadas'] ?></td>
                            <td>
                                <button type="button" class="icon-btn icon-editar" title="Editar"
                                        onclick='editarConfiguracion(<?= json_encode([
                                            "id" => (int)$fila['id'],
                                            "tipo_prueba" => $fila['tipo_prueba'],
                                            "competencia" => $fila['competencia'],
                                            "duracion_minutos" => (int)$fila['duracion_minutos'],
                                            "cantidad_preguntas" => $fila['cantidad_preguntas'],
                                        ], JSON_UNESCAPED_UNICODE | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP | JSON_HEX_TAG) ?>)'>✏️</button>
                            </td>
                        </tr>
                    <?php endwhile; ?>
                </tbody>
            </table>
        </div>
    </div>

    <!-- Modal: editar configuración -->
    <div class="modal-overlay" id="modalConfig">
        <div class="modal-box">
            <button type="button" class="modal-close" onclick="cerrarModal()" aria-label="Cerrar">✕</button>
            <h2 style="margin-top:0;">Editar configuración</h2>
            <p id="modalSubtitulo" style="margin-top:0;color:#555;font-size:14px;"></p>

            <form action="admin_configuracion_guardar.php" method="post" id="formConfig">
                <input type="hidden" name="id" id="campoId">

                <label for="duracion_minutos">Duración (minutos)</label>
                <input type="number" id="duracion_minutos" name="duracion_minutos" min="1" required>

                <label for="cantidad_preguntas">
                    Cantidad de preguntas
                    <span style="font-weight:400;color:#777;">(vacío = usar todas las disponibles)</span>
                </label>
                <input type="number" id="cantidad_preguntas" name="cantidad_preguntas" min="1">

                <div style="display:flex; gap:12px;">
                    <button type="submit" class="btn">Guardar cambios</button>
                    <button type="button" class="btn" style="background-color:#6b7280;" onclick="cerrarModal()">Cancelar</button>
                </div>
            </form>
        </div>
    </div>

    <script>
        const modal = document.getElementById('modalConfig');

        function abrirModal() {
            modal.classList.add('open');
        }

        function cerrarModal() {
            modal.classList.remove('open');
        }

        function editarConfiguracion(cfg) {
            document.getElementById('campoId').value = cfg.id;
            document.getElementById('modalSubtitulo').textContent = cfg.tipo_prueba + ' · ' + cfg.competencia;
            document.getElementById('duracion_minutos').value = cfg.duracion_minutos;
            document.getElementById('cantidad_preguntas').value = cfg.cantidad_preguntas ?? '';
            abrirModal();
        }

        modal.addEventListener('click', function (e) {
            if (e.target === modal) cerrarModal();
        });
        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape') cerrarModal();
        });
    </script>
</body>
</html>
