# Universidad — Simulacro Saber Pro y T&T

Plataforma web para que estudiantes practiquen exámenes tipo **Saber Pro / T&T**: un administrador carga el banco de preguntas, y los usuarios (agentes/estudiantes) presentan simulacros cronometrados y ven sus resultados e historial.

PHP plano (sin framework) + MySQL. Cada página es un archivo `.php` que se abre directo por su nombre (sin router).

---

## Requisitos

- **XAMPP** (Apache + MySQL + PHP) — probado con **PHP 8.0**.
- No necesitas Composer: la única librería externa (PHPMailer, para el correo de recuperación de contraseña) ya está incluida en [`vendor/phpmailer/`](vendor/phpmailer/), instalada manualmente.

---

## Instalación (para un dev nuevo)

1. **Clona el repo** dentro de tu carpeta de XAMPP:
   ```
   htdocs/universidad/
   ```

2. **Crea las bases de datos** ejecutando el script incluido — es el **único** paso de base de datos que necesitas, no hay migraciones separadas que correr:
   ```bash
   mysql -u root < database/schema.sql
   ```
   Esto crea **dos** bases de datos:
   - `proyecto_saber_pro_tyt` — la de la app (simulacros, usuarios, etc.), con todas las tablas y un usuario administrador de arranque:
     - **Usuario:** `admin`
     - **Contraseña:** `changeme123`

     ⚠️ Cámbiala apenas entres, desde *Gestión de Usuarios* dentro de la app.

   - `resultados_saber_pro_tyt` — datos agregados oficiales del ICFES (Saber Pro/T&T 2015-2024), de solo lectura, usados para comparar resultados desde el dashboard. `schema.sql` solo crea su **estructura** (51 tablas/vistas); los datos (~456 MB) no se versionan en git. Para cargarlos:
     ```bash
     mysql -u root resultados_saber_pro_tyt < database/resultados_saber_pro_tyt_dump_completo.sql
     ```
     Ese archivo está en `.gitignore` por su tamaño — consíguelo con quien te compartió el proyecto si no lo tienes en `database/`.
     O accede a este link en drive https://drive.google.com/drive/folders/1dRp2_FKdBxngmDdrQnEFfndZtxanjpnK?usp=drive_link 

     Después de cargar los datos, ejecuta también las vistas del Dashboard de Resultados (homologan las tablas del ICFES, que tienen esquemas distintos entre años, a columnas comunes):
     ```bash
     mysql -u root resultados_saber_pro_tyt < database/vistas_dashboard_resultados.sql
     ```

3. **Configura la conexión a las bases de datos** si tu MySQL no usa `root` sin contraseña (por defecto de XAMPP):
   - [`conexion.php`](conexion.php) → `proyecto_saber_pro_tyt` (la app):
     ```php
     $servername = "localhost";
     $username_db = "root";
     $password_db = "";
     $dbname = "proyecto_saber_pro_tyt";
     ```
   - [`conexion_resultados.php`](conexion_resultados.php) → `resultados_saber_pro_tyt` (datos ICFES). Mismo patrón, variable de conexión distinta (`$connResultados`, no `$conn`) para poder incluir ambos archivos en una misma página sin que se pisen.

4. **Configura el envío de correo** (necesario solo para "Olvidé mi contraseña"):
   ```bash
   cp mail_config.example.php mail_config.php
   ```
   Edita `mail_config.php` con credenciales SMTP reales (el archivo trae instrucciones para Gmail con "contraseña de aplicación"). **Este archivo no se sube a git** (está en `.gitignore`) porque contendrá credenciales reales.

5. Abre `http://localhost/universidad/auth/login.php` e ingresa con el usuario semilla.

---

## Estructura del proyecto

Los archivos están agrupados **por módulo/función** (no por rol estricto, porque casi todo el simulacro lo usan tanto admin como visor):

```
universidad/
├── admin/          # Exclusivo de admin: dashboard, usuarios, preguntas, configuración, historial general
├── visor/          # Exclusivo de visor: dashboard_visor.php
├── simulacro/      # Compartido admin+visor: presentar el simulacro, resultados, historial propio
├── auth/           # Login, logout, recuperación de contraseña
├── database/
│   ├── schema.sql                                  # Estructura de AMBAS bases + usuario admin semilla
│   ├── vistas_dashboard_resultados.sql              # Vistas homologadas + cruce T&T↔Pro para el Dashboard de Resultados
│   └── resultados_saber_pro_tyt_dump_completo.sql  # Dump completo (datos) de resultados_saber_pro_tyt.
│                                                    # NO se versiona (472 MB, ver .gitignore)
├── vendor/phpmailer/           # PHPMailer instalado a mano (sin Composer)
├── templates/                  # Plantillas .xlsx/.csv para cargar preguntas
├── img/                        # Imágenes estáticas
├── conexion.php                # Conexión a proyecto_saber_pro_tyt (la app)
├── conexion_resultados.php     # Conexión a resultados_saber_pro_tyt (datos ICFES, de solo lectura)
├── mail_config.example.php     # Plantilla pública de configuración SMTP
├── mail_config.php             # Configuración SMTP real (NO se versiona)
├── sidebar.php                 # Menú lateral compartido por todas las páginas
├── lector_xlsx.php             # Lector de .xlsx propio (sin librerías externas)
└── estilos.css                 # Hoja de estilos única de todo el proyecto
```

No hay build step ni framework. La infraestructura transversal (`conexion.php`, `sidebar.php`, `estilos.css`, `lector_xlsx.php`, `mail_config.php`, favicons, `vendor/`, `templates/`, `img/`) vive en la raíz; todo lo demás vive 1 nivel abajo, en su carpeta de módulo. Por eso cada archivo dentro de `admin/`, `visor/`, `simulacro/` o `auth/` referencia esos archivos compartidos como `__DIR__ . '/../conexion.php'`, etc. Si algún día agregas un archivo nuevo dentro de una de estas carpetas, sigue ese mismo patrón (`../` para lo que está en la raíz; sin `../` para otro archivo de su misma carpeta).

---

## Roles

| Rol | Puede hacer |
|---|---|
| `admin` | Todo lo del visor, más: cargar banco de preguntas, gestionar usuarios (crear/editar/eliminar), configurar tiempo/cantidad por Tipo de Prueba × Competencia, y ver el historial de simulacros de todos los usuarios |
| `visor` | Presentar simulacros, ver su propio historial y resultados, ver análisis gráfico |

El rol se guarda en `usuarios.rol` y se valida en cada página (`if ($_SESSION['rol'] !== 'admin') { ... }`).

---

## Mapa de módulos

### Autenticación y cuenta — `auth/`
| Archivo | Qué hace |
|---|---|
| `auth/login.php` | Inicio de sesión. Migra automáticamente contraseñas viejas en texto plano a hash la primera vez que alguien entra. |
| `auth/logout.php` | Cierra la sesión. |
| `auth/completar_perfil.php` | Pide el correo la primera vez que un usuario sin email entra (lo necesita para poder recuperar su contraseña). |
| `auth/recuperar_contrasena.php` | Pide el correo y envía un enlace de recuperación de un solo uso (válido 1 hora). |
| `auth/restablecer_contrasena.php` | Valida el enlace y permite definir una nueva contraseña. |
| `auth/enviar_correo.php` | Función que arma y envía los correos vía PHPMailer/SMTP. |

### Panel y navegación
| Archivo | Qué hace |
|---|---|
| `visor/dashboard_visor.php` | Pantalla de bienvenida para el rol visor. El admin no tiene una pantalla de bienvenida separada: al iniciar sesión entra directo a `admin/dashboard_resultados.php` (ver más abajo). |
| `sidebar.php` (en la raíz) | Menú lateral (marca, módulos según rol, usuario + cerrar sesión). Se incluye con `require __DIR__ . '/../sidebar.php'` en cada página. |

### Gestión de usuarios — `admin/` (solo admin)
| Archivo | Qué hace |
|---|---|
| `admin/admin_usuarios.php` | Lista, busca y pagina usuarios; botón para crear y editar (modal). |
| `admin/admin_usuario_guardar.php` | Procesa crear/actualizar (valida duplicados, hashea contraseña). |
| `admin/admin_usuario_eliminar.php` | Procesa eliminar (no permite borrar tu propia cuenta ni al último admin). |

### Banco de preguntas — `admin/` (solo admin)
| Archivo | Qué hace |
|---|---|
| `admin/cargar_preguntas.php` | Reemplaza *todo* el banco de preguntas desde `templates/preguntas.csv` (columnas: Enunciado, TipoPrueba, Competencia, OpcionA-D, Correcta, Puntaje). Para una recarga masiva completa. |
| `admin/admin_cargar_preguntas.php` / `admin/procesar_carga_preguntas.php` | Carga por Excel, **por competencia**: el admin elige Tipo de Prueba + Competencia y sube un `.xlsx` (columnas: Enunciado, OpcionA-D, Correcta); reemplaza solo las preguntas de esa combinación, sin tocar las demás. Usa `lector_xlsx.php` (raíz), no PhpSpreadsheet. |
| `lector_xlsx.php` (en la raíz) | Lector de `.xlsx` propio y sin dependencias (usa `ZipArchive` + `SimpleXML`, ambas extensiones nativas de PHP). Un `.xlsx` es un `.zip` con XML adentro; esta función solo lee valores de celdas de la primera hoja — no fórmulas, estilos ni múltiples hojas. Se eligió en vez de instalar PhpSpreadsheet a mano porque esa librería tiene ~150 archivos interdependientes y un autoload generado por Composer, difícil de recrear de forma confiable sin Composer. |
| `admin/descargar_plantilla_preguntas.php` | Descarga `templates/plantilla_preguntas.xlsx` (encabezados: Enunciado, OpcionA-D, Correcta). |

### Configuración de pruebas — `admin/` (solo admin)
| Archivo | Qué hace |
|---|---|
| `admin/admin_configuracion_pruebas.php` / `admin/admin_configuracion_guardar.php` | Define cuántos minutos y cuántas preguntas se presentan por cada combinación Tipo de Prueba × Competencia (10 combinaciones fijas: 2 tipos × 5 competencias). |

### Dashboard de Resultados — `admin/` (solo admin)
Usa `conexion_resultados.php` (la base `resultados_saber_pro_tyt`, datos reales del ICFES), no `conexion.php`.

| Archivo | Qué hace |
|---|---|
| `admin/dashboard_resultados.php` | Compara los resultados históricos reales de Saber Pro y Saber T&T (2015-2024): tendencia por año, comparación por área homologada (genérica o específica), comparación por región (con filtro de año), ranking de mejores/peores 10 instituciones y de mejores/peores 10 programas académicos (filtrables por año, tipo de prueba, tipo de módulo y módulo), KPIs de mínimo/máximo al lado de cada gráfico, y conclusiones calculadas a partir de los datos. Ver `database/vistas_dashboard_resultados.sql` para cómo se homologan las tablas del ICFES (que cambian de esquema entre años) antes de graficarlas. |

### Simulacro — `simulacro/` (compartido admin + visor)
El simulacro se organiza en dos dimensiones: **Tipo de Prueba** (Saber Pro / Saber TyT) y **Competencia** (Razonamiento cuantitativo, Lectura crítica, Competencias ciudadanas, Comunicación escrita, Inglés) — catálogos en las tablas `tipos_prueba` y `competencias`.

| Archivo | Qué hace |
|---|---|
| `simulacro/simulacro_inicio.php` / `simulacro/procesar_simulacro.php` | Elige Tipo de Prueba y Competencia, muestra cuántas preguntas y cuánto tiempo (según `configuracion_pruebas`) e inicia el intento. |
| `simulacro/simulacro_pregunta.php` / `simulacro/guardar_respuesta.php` | Muestra cada pregunta con temporizador; al guardar cada respuesta calcula si es correcta y su puntaje. Marca `fecha_fin` al finalizar (manual, por tiempo agotado, o al responder la última pregunta). |
| `simulacro/simulacro_resultados.php` | Resultado del intento: tipo de prueba, competencia, tiempo utilizado, correctas/incorrectas, gráfico y una retroalimentación según el % de aciertos. |
| `simulacro/simulacro_historial.php` | Historial propio del usuario logueado. |
| `admin/admin_historial_simulacros.php` | Historial de **todos** los usuarios (solo admin), con buscador y paginación. |
| `simulacro/obtener_cantidad_max.php` | Endpoint AJAX: dado un Tipo de Prueba + Competencia, devuelve cuántas preguntas hay disponibles y la duración configurada. |
| `simulacro/analisis_grafico.php` | Gráfico de ejemplo (Chart.js). |

---

## Seguridad — cosas ya resueltas que vale la pena conocer

- Las contraseñas se guardan con `password_hash`/`password_verify` (no en texto plano).
- Cada endpoint de simulacro valida que el `intento_id` pertenezca al usuario en sesión (evita ver/editar intentos de otra persona).
- `admin/cargar_preguntas.php` y `simulacro/obtener_cantidad_max.php` exigen sesión activa.
- El token de recuperación de contraseña se guarda **hasheado** (`SHA-256`) y expira en 1 hora.
- `mail_config.php` está en `.gitignore`: nunca debe subirse con credenciales reales.

---

## Limitaciones conocidas / pendientes

- **`calendario`** es una tabla heredada que ningún código activo usa hoy. Se conserva en `schema.sql` solo por si tiene datos históricos de valor; es candidata a eliminarse en una limpieza futura.
- **`preguntas_old`, `resultados`, `preguntas_legado`, `opciones_legado`** ya se eliminaron de la base de datos real y de `schema.sql` (no las usaba ningún código activo).
- Los 45 intentos de simulacro anteriores a esta migración no tienen Tipo de Prueba ni Competencia asociados (columnas `NULL`) — se muestran como "—" en los historiales.
- No hay una suite de tests automatizados.
- Las 51 tablas/vistas originales de `resultados_saber_pro_tyt` vienen con nombres tal como los generó el import original del ICFES (con espacios, paréntesis e incluso `.csv` en el nombre) y muchas son tablas "cubo" (columnas `AGREGACION`/`MEDIDA_AGREGACION` que hay que filtrar). El Dashboard de Resultados no las consulta directo: usa las vistas homologadas de `database/vistas_dashboard_resultados.sql` (ver sección de abajo).
- El cruce Saber T&T → Saber Pro por área (`tabla_equivalencia_areas`) es un criterio propio — no existe ninguna columna en los datos del ICFES que relacione las categorías de una prueba con la otra. Es editable si no calza con tu criterio.
- `tabla_departamento_region` (28 departamentos → 6 regiones: Amazonía, Andina, Caribe, Insular, Orinoquia, Pacífica) se extrajo de la propia columna `NOMBRE_REGION` del cubo `agregados_saber_tyt_2024` del ICFES, no es un criterio inventado. Alimenta `vista_resultados_region` (agrega `vista_resultados_institucion` por región) para la comparación por región del dashboard.
- `vista_resultados_institucion` homologa institución × módulo (colapsando grupo de referencia con `SUM`/promedio ponderado cuando la tabla origen viene más granular) para 2015/2016/2017/2018 Saber Pro y 2016/2017/2018/2024 Saber T&T. El ranking de "Top de instituciones" del dashboard filtra con un mínimo de 30 evaluados para no mostrar casos con muestras estadísticamente irrelevantes.
- Las 51 tablas originales se identificaron y clasificaron por **su propio nombre** (no hay ninguna columna que lo diga explícitamente): "gener"/"generi" = módulos genéricos (las 5 competencias comunes a todos: Lectura Crítica, Razonamiento Cuantitativo, Competencias Ciudadanas, Comunicación Escrita, Inglés) vs. "especif"/"especi" = módulos específicos (propios de cada carrera, ej. "Formulación y Evaluación de Proyectos" en Administración); y por nivel de agregación: "grup_ref"/"grupo referencia" (carrera en general), "insti"/"institución", "prog"/"programa académico". Esa clasificación es la base de los filtros "Tipo de módulo" y "Nivel de agregación" del dashboard.
- `vista_resultados_especificas_grupo_referencia` es la contraparte específica de `vista_resultados_grupo_referencia` (mismo grano, pero módulos propios de cada carrera en vez de los 5 genéricos). No tiene una lista fija de módulos —depende de la carrera— así que en el dashboard el filtro de módulo no aplica cuando se elige "Específica": se promedian todos los módulos específicos de cada área homologada.
- `vista_resultados_programa` es el nivel de agregación más fino (institución × programa académico × módulo), e incluye tanto módulos genéricos como específicos (columna `tipo_modulo`). Cubre Saber Pro 2015-2018 y Saber T&T 2016/2018; no incluye Saber T&T 2017 ni 2024 a este nivel (esas tablas cubo tienen un nivel de programa, pero mezclado con otras dimensiones y sin cantidad de evaluados confiable a ese detalle — queda pendiente). Alimenta el ranking "Top de programas académicos" del dashboard (mínimo 20 evaluados por combinación).
- No hay forma de dar seguimiento al mismo estudiante en el tiempo con estos datos (son agregados, no registros individuales) — el Dashboard de Resultados compara por cohorte/año, no por persona. Ver el aviso dentro de la propia página.
- La tabla cubo de Saber T&T 2017 trae, para algunas carreras, cruces con módulos específicos que no les corresponden (ej. una carrera de "Agropecuario" cruzada con un módulo típico de "Industria y Minas"), con un solo valor y sin cantidad de evaluados. Es un artefacto de la fuente original del ICFES, no un error de las vistas; puede hacer que el promedio de un área para 2017 se vea con un valor atípico puntual. No se filtró para no descartar datos reales sin poder distinguir señal de ruido.
- El ranking "Top de programas académicos" no cubre Saber T&T 2017 ni 2024 (esas tablas cubo sí tienen un nivel de programa, pero mezclado con otras dimensiones y sin cantidad de evaluados confiable a ese detalle).

---

## Notas para quien siga desarrollando

- El repo vive en `universidad/.git` (no en la raíz de `htdocs`), con remoto en GitHub. Revisa `git remote -v` y `git branch` antes de hacer push.
- PHPMailer está vendorizado a mano en `vendor/phpmailer/` (sin Composer). Si necesitas actualizarlo, reemplaza los 3 archivos en `vendor/phpmailer/src/` por los de la versión que quieras desde el repo oficial de PHPMailer.
- `estilos.css` es la única hoja de estilos del proyecto; todas las páginas la comparten. Antes de crear una clase nueva, revisa si ya existe algo parecido (`.btn`, `.btn-peligro`, `.tabla-indicadores`, `.modal-*`, etc.) para mantener la interfaz uniforme.
- **Convención de base de datos:** este proyecto no usa una carpeta de migraciones numeradas — `database/schema.sql` es un único script que siempre refleja el estado final actual de ambas bases de datos. Si necesitas cambiar el esquema (agregar una tabla, una columna, etc.), edita `schema.sql` directamente para que siga siendo "lo único que un dev nuevo corre" y aplica el mismo cambio a mano en la base de datos real con `ALTER`/`CREATE`.
