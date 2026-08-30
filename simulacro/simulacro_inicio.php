<?php
session_start();
require_once __DIR__ . '/../conexion.php';

if (!isset($_SESSION['usuario']) || !in_array($_SESSION['rol'], ['admin', 'visor'])) {
    header("Location: ../auth/login.php");
    exit();
}

$rol = $_SESSION['rol'];
$usuario = $_SESSION['usuario'];

$tiposPrueba = $conn->query("SELECT id, nombre FROM tipos_prueba ORDER BY nombre ASC");
$competencias = $conn->query("SELECT id, nombre FROM competencias ORDER BY nombre ASC");
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Simulacro - Inicio</title>
<link rel="stylesheet" href="../estilos.css" />
<link rel="icon" href="../favicon.svg" type="image/svg+xml">
<link rel="alternate icon" href="../favicon.ico">
<link rel="apple-touch-icon" href="../apple-touch-icon.png">
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
document.addEventListener("DOMContentLoaded", function () {
    const tipoSelect = document.getElementById("tipo_prueba_id");
    const competenciaSelect = document.getElementById("competencia_id");
    const infoSimulacro = document.getElementById("infoSimulacro");
    const infoCantidad = document.getElementById("infoCantidad");
    const infoTiempo = document.getElementById("infoTiempo");
    const avisoSinPreguntas = document.getElementById("avisoSinPreguntas");
    const botonIniciar = document.getElementById("botonIniciar");
    const formSeleccion = document.getElementById("formSeleccion");
    const panel = document.getElementById("panelSimulacro");

    let timerHandle = null;

    // --- Paso 1: mostrar cantidad/tiempo apenas se elige tipo + competencia ---
    function consultarDisponibilidad() {
        infoSimulacro.style.display = "none";
        avisoSinPreguntas.style.display = "none";
        botonIniciar.disabled = true;

        if (!tipoSelect.value || !competenciaSelect.value) {
            return;
        }

        fetch("obtener_cantidad_max.php?tipo_prueba_id=" + encodeURIComponent(tipoSelect.value) + "&competencia_id=" + encodeURIComponent(competenciaSelect.value))
            .then(res => res.json())
            .then(data => {
                if (data.max && data.max > 0) {
                    infoCantidad.textContent = data.max;
                    infoTiempo.textContent = data.duracion_minutos + " minutos";
                    infoSimulacro.style.display = "flex";
                    botonIniciar.disabled = false;
                } else {
                    avisoSinPreguntas.style.display = "block";
                }
            });
    }

    tipoSelect.addEventListener("change", consultarDisponibilidad);
    competenciaSelect.addEventListener("change", consultarDisponibilidad);

    // --- Utilidades para mostrar el simulacro debajo, sin cambiar de página ---

    // De la página completa que devuelve el servidor, nos quedamos solo con
    // el contenido real (el sidebar y el resto se descartan).
    function extraerContenedor(html) {
        const doc = new DOMParser().parseFromString(html, "text/html");
        const contenedor = doc.querySelector(".contenedor-derecho");
        return contenedor ? contenedor.innerHTML : null;
    }

    function detenerTemporizador() {
        if (timerHandle) {
            clearInterval(timerHandle);
            timerHandle = null;
        }
    }

    // Si el fragmento mostrado es una pregunta con tiempo, arranca el conteo
    // regresivo. Al llegar a 0, vuelve a pedir la misma pregunta: el servidor
    // ya detecta que el tiempo se acabó y redirige solo a los resultados.
    function iniciarTemporizadorSiAplica() {
        const cajaTiempo = panel.querySelector("[data-tiempo-restante]");
        if (!cajaTiempo) return;

        let restante = parseInt(cajaTiempo.dataset.tiempoRestante, 10) || 0;
        const intentoId = cajaTiempo.dataset.intentoId;
        const preguntaIndex = cajaTiempo.dataset.preguntaIndex;
        const spanTimer = document.getElementById("timer");

        function pintar() {
            if (!spanTimer) return;
            const minutos = Math.floor(restante / 60);
            const segundos = restante % 60;
            spanTimer.innerText = (minutos < 10 ? "0" : "") + minutos + ":" + (segundos < 10 ? "0" : "") + segundos;
        }

        pintar();
        detenerTemporizador();
        timerHandle = setInterval(function () {
            restante--;
            if (restante <= 0) {
                detenerTemporizador();
                fetch("simulacro_pregunta.php?intento_id=" + encodeURIComponent(intentoId) + "&pregunta_index=" + encodeURIComponent(preguntaIndex))
                    .then(res => res.text())
                    .then(mostrarFragmento);
            } else {
                pintar();
            }
        }, 1000);
    }

    // Si el fragmento mostrado son los resultados, dibuja el gráfico.
    function dibujarGraficoSiAplica() {
        const cajaResultado = panel.querySelector("[data-correctas]");
        if (!cajaResultado) return;

        const correctas = parseInt(cajaResultado.dataset.correctas, 10) || 0;
        const incorrectas = parseInt(cajaResultado.dataset.incorrectas, 10) || 0;
        const canvas = cajaResultado.querySelector("canvas");
        if (!canvas) return;

        new Chart(canvas.getContext("2d"), {
            type: "pie",
            data: {
                labels: ["Correctas", "Incorrectas"],
                datasets: [{
                    data: [correctas, incorrectas],
                    backgroundColor: ["#4CAF50", "#F44336"]
                }]
            },
            options: { responsive: true, maintainAspectRatio: false }
        });
    }

    function bloquearSeleccion(bloqueada) {
        tipoSelect.disabled = bloqueada;
        competenciaSelect.disabled = bloqueada;
        botonIniciar.disabled = bloqueada;
    }

    function mostrarFragmento(html) {
        const contenido = extraerContenedor(html);
        if (!contenido) {
            panel.innerHTML = '<p class="error">Ocurrió un problema al cargar el simulacro. Intenta de nuevo.</p>';
            panel.scrollIntoView({ behavior: "smooth", block: "start" });
            return;
        }
        panel.innerHTML = contenido;
        iniciarTemporizadorSiAplica();
        dibujarGraficoSiAplica();

        // Si ya llegamos a los resultados, el simulacro terminó: se puede
        // volver a elegir tipo de prueba / competencia.
        if (panel.querySelector("[data-correctas]")) {
            tipoSelect.disabled = false;
            competenciaSelect.disabled = false;
            consultarDisponibilidad();
        }

        panel.scrollIntoView({ behavior: "smooth", block: "start" });
    }

    // --- Iniciar simulacro (sin salir de esta página) ---
    formSeleccion.addEventListener("submit", function (e) {
        e.preventDefault();
        const datos = new FormData(formSeleccion);
        bloquearSeleccion(true);

        fetch(formSeleccion.action, { method: "POST", body: datos })
            .then(function (res) {
                // Si el servidor no pudo iniciar el intento, redirige de vuelta
                // a esta misma página en vez de a la primera pregunta.
                if (res.url.indexOf("simulacro_inicio.php") !== -1) {
                    tipoSelect.disabled = false;
                    competenciaSelect.disabled = false;
                    panel.innerHTML = '<p class="error">No se pudo iniciar el simulacro. Verifica que haya preguntas cargadas para esa combinación.</p>';
                    panel.scrollIntoView({ behavior: "smooth", block: "start" });
                    return null;
                }
                return res.text();
            })
            .then(function (html) {
                if (html === null) return;
                mostrarFragmento(html);
            });
    });

    // --- Responder / guardar / finalizar (el formulario se inyecta dinámicamente) ---
    panel.addEventListener("submit", function (e) {
        const form = e.target;
        if (!form.classList.contains("form-pregunta")) return;
        e.preventDefault();

        detenerTemporizador();

        const datos = new FormData(form);
        if (e.submitter && e.submitter.name) {
            datos.set(e.submitter.name, e.submitter.value);
        }

        fetch(form.action, { method: "POST", body: datos })
            .then(res => res.text())
            .then(mostrarFragmento);
    });
});
</script>
</head>
<body>
<?php require __DIR__ . '/../sidebar.php'; ?>

<div class="content">
    <div class="contenedor-derecho">
        <h2>Simulacro Saber Pro y T&T</h2>
        <p>Elige el tipo de prueba y la competencia que quieres presentar. El sistema te mostrará cuántas preguntas y cuánto tiempo tendrás antes de iniciar.</p>

        <form id="formSeleccion" action="procesar_simulacro.php" method="post">
            <div class="fila-horizontal">
                <div class="campo-form">
                    <label for="tipo_prueba_id">Tipo de prueba</label>
                    <select id="tipo_prueba_id" name="tipo_prueba_id" required>
                        <option value="">-- Seleccione --</option>
                        <?php while ($tipo = $tiposPrueba->fetch_assoc()): ?>
                            <option value="<?= (int)$tipo['id'] ?>"><?= htmlspecialchars($tipo['nombre']) ?></option>
                        <?php endwhile; ?>
                    </select>
                </div>

                <div class="campo-form">
                    <label for="competencia_id">Competencia</label>
                    <select id="competencia_id" name="competencia_id" required>
                        <option value="">-- Seleccione --</option>
                        <?php while ($competencia = $competencias->fetch_assoc()): ?>
                            <option value="<?= (int)$competencia['id'] ?>"><?= htmlspecialchars($competencia['nombre']) ?></option>
                        <?php endwhile; ?>
                    </select>
                </div>

                <button type="submit" class="btn" id="botonIniciar" disabled>Iniciar simulacro</button>
            </div>

            <div class="info-simulacro" id="infoSimulacro" style="display:none;">
                <div class="info-stat">
                    <span class="info-stat-label">Cantidad de preguntas</span>
                    <span class="info-stat-valor" id="infoCantidad">—</span>
                </div>
                <div class="info-stat">
                    <span class="info-stat-label">Tiempo asignado</span>
                    <span class="info-stat-valor" id="infoTiempo">—</span>
                </div>
            </div>

            <p id="avisoSinPreguntas" class="error" style="display:none;">
                Todavía no hay preguntas cargadas para esa combinación de tipo de prueba y competencia.
            </p>
        </form>

        <div id="panelSimulacro"></div>
    </div>
</div>
</body>
</html>
