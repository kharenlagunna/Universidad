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

// ¿Estamos editando a alguien? (?editar=ID) -> el modal se abre solo al cargar.
$usuarioEditar = null;
if (isset($_GET['editar'])) {
    $idEditar = intval($_GET['editar']);
    $stmt = $conn->prepare("SELECT id, usuario, rol, email FROM usuarios WHERE id = ?");
    $stmt->bind_param("i", $idEditar);
    $stmt->execute();
    $usuarioEditar = $stmt->get_result()->fetch_assoc();
    if (!$usuarioEditar) {
        $flashError = "El usuario que intentas editar ya no existe.";
    }
}

$listado = $conn->query("SELECT id, usuario, rol, email FROM usuarios ORDER BY usuario ASC");
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Gestión de Usuarios</title>
<link rel="stylesheet" href="../estilos.css" />
<link rel="icon" href="../favicon.svg" type="image/svg+xml">
<link rel="alternate icon" href="../favicon.ico">
<link rel="apple-touch-icon" href="../apple-touch-icon.png">
</head>
<body>
    <?php require __DIR__ . '/../sidebar.php'; ?>

    <div class="content">
        <div class="contenedor-derecho">
            <h2 style="margin:0;">Usuarios del sistema</h2>

            <?php if ($flashOk): ?>
                <p style="color:#1a7f37;font-weight:600;"><?= htmlspecialchars($flashOk) ?></p>
            <?php endif; ?>
            <?php if ($flashError): ?>
                <p class="error"><?= htmlspecialchars($flashError) ?></p>
            <?php endif; ?>

            <div class="usuarios-toolbar">
                <div class="buscador-usuarios">
                    <span class="buscador-icono">🔍</span>
                    <input type="text" id="buscador" placeholder="Buscar por usuario, correo o rol...">
                </div>
                <button type="button" class="btn" style="white-space:nowrap;" onclick="nuevoUsuario()">➕ Nuevo Usuario</button>
            </div>

            <table class="tabla-indicadores">
                <thead>
                    <tr>
                        <th>Usuario</th>
                        <th>Rol</th>
                        <th>Acciones</th>
                    </tr>
                </thead>
                <tbody id="cuerpoTabla">
                    <?php while ($u = $listado->fetch_assoc()): ?>
                        <tr class="fila-usuario">
                            <td>
                                <div class="usuario-nombre"><?= htmlspecialchars($u['usuario']) ?></div>
                                <div class="usuario-correo"><?= htmlspecialchars($u['email'] ?? '—') ?></div>
                            </td>
                            <td>
                                <span class="rol-badge <?= $u['rol'] === 'admin' ? 'rol-admin' : '' ?>">
                                    <?= $u['rol'] === 'admin' ? 'Administrador' : 'Visor' ?>
                                </span>
                            </td>
                            <td>
                                <div style="display:flex; gap:8px;">
                                    <button type="button" class="icon-btn icon-editar" title="Editar"
                                            onclick='editarUsuario(<?= json_encode([
                                                "id" => (int)$u['id'],
                                                "usuario" => $u['usuario'],
                                                "email" => $u['email'] ?? '',
                                                "rol" => $u['rol'],
                                            ], JSON_UNESCAPED_UNICODE | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP | JSON_HEX_TAG) ?>)'>✏️</button>
                                    <form action="admin_usuario_eliminar.php" method="post"
                                          onsubmit="return confirm('¿Eliminar al usuario &quot;<?= htmlspecialchars($u['usuario'], ENT_QUOTES) ?>&quot;? Esta acción no se puede deshacer.');">
                                        <input type="hidden" name="id" value="<?= (int)$u['id'] ?>">
                                        <button type="submit" class="icon-btn icon-eliminar" title="Eliminar">🗑️</button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    <?php endwhile; ?>
                </tbody>
            </table>

            <p id="sinResultados" style="display:none;color:#777;text-align:center;padding:20px 0;">
                No se encontraron usuarios que coincidan con la búsqueda.
            </p>

            <div class="tabla-paginacion" id="paginacion">
                <span id="resumenPaginacion">Mostrando 0 de 0 usuarios</span>
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

    <!-- Modal: crear / editar usuario -->
    <div class="modal-overlay" id="modalUsuario">
        <div class="modal-box">
            <button type="button" class="modal-close" onclick="cerrarModal()" aria-label="Cerrar">✕</button>
            <h2 id="modalTitulo" style="margin-top:0;">➕ Nuevo Usuario</h2>

            <form action="admin_usuario_guardar.php" method="post" id="formUsuario">
                <input type="hidden" name="id" id="campoId" value="<?= $usuarioEditar ? (int)$usuarioEditar['id'] : '' ?>">

                <label for="usuario">Usuario</label>
                <input type="text" id="usuario" name="usuario" required
                       value="<?= htmlspecialchars($usuarioEditar['usuario'] ?? '') ?>">

                <label for="email">Correo electrónico</label>
                <input type="email" id="email" name="email"
                       value="<?= htmlspecialchars($usuarioEditar['email'] ?? '') ?>">

                <label for="rol">Rol</label>
                <select id="rol" name="rol" required>
                    <?php $rolActual = $usuarioEditar['rol'] ?? ''; ?>
                    <option value="admin" <?= $rolActual === 'admin' ? 'selected' : '' ?>>Administrador</option>
                    <option value="visor" <?= $rolActual === 'visor' ? 'selected' : '' ?>>Visor</option>
                </select>

                <label for="contrasena">
                    Contraseña
                    <span id="ayudaContrasena" style="font-weight:400;color:#777; <?= $usuarioEditar ? '' : 'display:none;' ?>">(déjala en blanco para no cambiarla)</span>
                </label>
                <input type="password" id="contrasena" name="contrasena"
                       minlength="8" <?= $usuarioEditar ? '' : 'required' ?>>

                <div style="display:flex; gap:12px;">
                    <button type="submit" class="btn" id="botonGuardar"><?= $usuarioEditar ? 'Guardar cambios' : 'Crear usuario' ?></button>
                    <button type="button" class="btn" style="background-color:#6b7280;" onclick="cerrarModal()">Cancelar</button>
                </div>
            </form>
        </div>
    </div>

    <script>
        const modal = document.getElementById('modalUsuario');
        const formUsuario = document.getElementById('formUsuario');
        const campoContrasena = document.getElementById('contrasena');
        const ayudaContrasena = document.getElementById('ayudaContrasena');

        function abrirModal() {
            modal.classList.add('open');
        }

        function cerrarModal() {
            modal.classList.remove('open');
        }

        function nuevoUsuario() {
            formUsuario.reset();
            document.getElementById('campoId').value = '';
            document.getElementById('modalTitulo').textContent = '➕ Nuevo Usuario';
            document.getElementById('botonGuardar').textContent = 'Crear usuario';
            campoContrasena.required = true;
            ayudaContrasena.style.display = 'none';
            abrirModal();
        }

        function editarUsuario(u) {
            document.getElementById('campoId').value = u.id;
            document.getElementById('usuario').value = u.usuario;
            document.getElementById('email').value = u.email;
            document.getElementById('rol').value = u.rol;
            campoContrasena.value = '';
            campoContrasena.required = false;
            ayudaContrasena.style.display = '';
            document.getElementById('modalTitulo').textContent = '✏️ Editar Usuario';
            document.getElementById('botonGuardar').textContent = 'Guardar cambios';
            abrirModal();
        }

        // Cerrar al hacer clic fuera de la tarjeta o con la tecla Escape.
        modal.addEventListener('click', function (e) {
            if (e.target === modal) cerrarModal();
        });
        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape') cerrarModal();
        });

        <?php if ($usuarioEditar): ?>
        document.addEventListener('DOMContentLoaded', function () {
            document.getElementById('modalTitulo').textContent = '✏️ Editar Usuario';
            document.getElementById('botonGuardar').textContent = 'Guardar cambios';
            abrirModal();
        });
        <?php endif; ?>

        // --- Búsqueda y paginación (100% en el navegador, sin recargar) ---
        const TAMANO_PAGINA = 5;
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
                ? 'Mostrando 0 de 0 usuarios'
                : `Mostrando ${inicio + 1}-${finVisible} de ${totalFilas} usuarios`;

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
