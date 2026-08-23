<?php
/**
 * Menú lateral compartido por toda la aplicación.
 * Requiere que la página que lo incluye ya haya hecho session_start()
 * y tenga en sesión $_SESSION['usuario'] y $_SESSION['rol'].
 *
 * Uso:  require __DIR__ . '/sidebar.php';
 */

$rolActual     = $_SESSION['rol'] ?? '';
$usuarioActual = $_SESSION['usuario'] ?? '';
$paginaActual  = basename($_SERVER['SCRIPT_NAME']);

// Módulos del menú. 'roles' controla quién ve cada uno.
$sidebarModulos = [
    ['href' => 'dashboard_admin.php',        'icono' => '🏠', 'texto' => 'Dashboard',            'roles' => ['admin']],
    ['href' => 'dashboard_visor.php',        'icono' => '🏠', 'texto' => 'Dashboard',            'roles' => ['visor']],
    ['href' => 'cargar_informacion.php',     'icono' => '📂', 'texto' => 'Cargar Información',   'roles' => ['admin']],
    ['href' => 'admin_cargar_preguntas.php', 'icono' => '📝', 'texto' => 'Cargar Preguntas',     'roles' => ['admin']],
    ['href' => 'admin_usuarios.php',         'icono' => '👥', 'texto' => 'Gestión de Usuarios', 'roles' => ['admin']],
    ['href' => 'analisis_grafico.php',       'icono' => '📊', 'texto' => 'Análisis Gráfico',     'roles' => ['admin', 'visor']],
    ['href' => 'simulacro_inicio.php',       'icono' => '🧪', 'texto' => 'Simulacro',            'roles' => ['admin', 'visor']],
    ['href' => 'simulacro_historial.php',    'icono' => '📜', 'texto' => 'Historial',            'roles' => ['admin', 'visor']],
];
?>
<div class="sidebar">
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
                   class="<?= $paginaActual === $modulo['href'] ? 'active' : '' ?>">
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
            <a href="logout.php" class="user-menu-logout">🚪 Cerrar sesión</a>
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
</script>
