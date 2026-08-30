<?php
/**
 * Menú lateral compartido por toda la aplicación.
 * Requiere que la página que lo incluye ya haya hecho session_start()
 * y tenga en sesión $_SESSION['usuario'] y $_SESSION['rol'].
 *
 * Este archivo vive en la raíz del proyecto, pero lo incluyen páginas
 * que están 1 nivel abajo (admin/, visor/, simulacro/), por eso los
 * href de abajo empiezan con "../".
 *
 * Uso:  require __DIR__ . '/../sidebar.php';
 */

$rolActual     = $_SESSION['rol'] ?? '';
$usuarioActual = $_SESSION['usuario'] ?? '';
$paginaActual  = basename($_SERVER['SCRIPT_NAME']);

// Módulos del menú. 'roles' controla quién ve cada uno.
$sidebarModulos = [
    ['href' => '../visor/dashboard_visor.php',             'icono' => '🏠', 'texto' => 'Dashboard',                'roles' => ['visor']],
    ['href' => '../admin/dashboard_resultados.php',        'icono' => '📈', 'texto' => 'Dashboard de Resultados',  'roles' => ['admin']],
    ['href' => '../admin/admin_cargar_preguntas.php',      'icono' => '📝', 'texto' => 'Cargar Preguntas',         'roles' => ['admin']],
    ['href' => '../admin/admin_usuarios.php',              'icono' => '👥', 'texto' => 'Gestión de Usuarios',     'roles' => ['admin']],
    ['href' => '../admin/admin_configuracion_pruebas.php', 'icono' => '⚙️', 'texto' => 'Configuración de Pruebas', 'roles' => ['admin']],
    ['href' => '../simulacro/simulacro_inicio.php',        'icono' => '🧪', 'texto' => 'Simulacro',                'roles' => ['admin', 'visor']],
    ['href' => '../simulacro/simulacro_historial.php',     'icono' => '📜', 'texto' => 'Historial',                'roles' => ['admin', 'visor']],
    ['href' => '../admin/admin_historial_simulacros.php',  'icono' => '🗂️', 'texto' => 'Historial General',        'roles' => ['admin']],
];
?>
<button type="button" class="sidebar-toggle" id="sidebarToggle" aria-label="Abrir menú" aria-controls="sidebar" aria-expanded="false">
    <span class="sidebar-toggle-icon">☰</span>
</button>
<div class="sidebar-overlay" id="sidebarOverlay"></div>

<div class="sidebar" id="sidebar">
    <div class="sidebar-brand">
        <div class="brand-icon">🎓</div>
        <div class="brand-text">
            <div class="brand-name">Universidad</div>
            <div class="brand-sub">Simulacro Saber Pro</div>
        </div>
    </div>

    <nav class="sidebar-nav">
        <?php foreach ($sidebarModulos as $modulo): ?>
            <?php if (in_array($rolActual, $modulo['roles'], true)): ?>
                <a href="<?= htmlspecialchars($modulo['href']) ?>"
                   class="<?= $paginaActual === basename($modulo['href']) ? 'active' : '' ?>">
                    <span class="nav-icon"><?= $modulo['icono'] ?></span><?= htmlspecialchars($modulo['texto']) ?>
                </a>
            <?php endif; ?>
        <?php endforeach; ?>
    </nav>

    <div class="sidebar-user" id="sidebarUser">
        <div class="user-avatar"><?= htmlspecialchars(strtoupper(substr($usuarioActual, 0, 1) ?: '?')) ?></div>
        <div class="user-text">
            <div class="user-name"><?= htmlspecialchars($usuarioActual) ?></div>
            <div class="user-role"><?= $rolActual === 'admin' ? 'Administrador' : 'Visor' ?></div>
        </div>
        <span class="user-chevron">⌄</span>

        <div class="user-menu">
            <div class="user-menu-header">Mi cuenta</div>
            <a href="../auth/logout.php" class="user-menu-logout">🚪 Cerrar sesión</a>
        </div>
    </div>
</div>
<script>
(function () {
    var caja = document.getElementById('sidebarUser');
    if (!caja) return;
    caja.addEventListener('click', function (e) {
        caja.classList.toggle('open');
        e.stopPropagation();
    });
    document.addEventListener('click', function () {
        caja.classList.remove('open');
    });
})();

// Menú lateral deslizable en pantallas angostas (móvil/tablet): el sidebar
// vive fuera de la pantalla (ver CSS) y este botón lo trae/lo esconde.
(function () {
    var sidebar = document.getElementById('sidebar');
    var boton = document.getElementById('sidebarToggle');
    var overlay = document.getElementById('sidebarOverlay');
    var icono = boton ? boton.querySelector('.sidebar-toggle-icon') : null;
    if (!sidebar || !boton || !overlay) return;

    function abrirMenu() {
        sidebar.classList.add('open');
        overlay.classList.add('activo');
        boton.setAttribute('aria-expanded', 'true');
        if (icono) icono.textContent = '✕';
    }

    function cerrarMenu() {
        sidebar.classList.remove('open');
        overlay.classList.remove('activo');
        boton.setAttribute('aria-expanded', 'false');
        if (icono) icono.textContent = '☰';
    }

    boton.addEventListener('click', function (e) {
        e.stopPropagation();
        if (sidebar.classList.contains('open')) {
            cerrarMenu();
        } else {
            abrirMenu();
        }
    });

    overlay.addEventListener('click', cerrarMenu);

    // Al elegir un módulo del menú, ciérralo (si no, tapa la página siguiente).
    var enlaces = sidebar.querySelectorAll('.sidebar-nav a');
    for (var i = 0; i < enlaces.length; i++) {
        enlaces[i].addEventListener('click', cerrarMenu);
    }

    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') cerrarMenu();
    });
})();
</script>
