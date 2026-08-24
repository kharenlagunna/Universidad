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

2. **Crea las bases de datos** ejecutando el script incluido:
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
│   ├── schema.sql                                # Estructura de AMBAS bases + usuario admin semilla
│   ├── migracion_competencias.sql                # Migración ya aplicada: agrega tipos_prueba/competencias/
│   │                                              # configuracion_pruebas y archiva el banco de preguntas viejo
│   └── resultados_saber_pro_tyt_dump_completo.sql  # Dump completo (datos) de resultados_saber_pro_tyt.
│                                                  # NO se versiona (472 MB, ver .gitignore)
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

El rol se guarda en `usuarioss.rol` y se valida en cada página (`if ($_SESSION['rol'] !== 'admin') { ... }`).

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
| `admin/dashboard_admin.php` / `visor/dashboard_visor.php` | Pantalla de bienvenida según el rol. |
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

- **`preguntas_old`, `resultados`, `calendario`** son tablas heredadas que ningún código activo usa hoy. Se conservan en `schema.sql` solo por si tienen datos históricos de valor; son candidatas a eliminarse en una limpieza futura.
- **`preguntas_legado`, `opciones_legado`** son el banco de preguntas anterior (clasificado por grupo/módulo), archivado al migrar a Tipo de Prueba + Competencia. Nadie los consulta hoy; se conservan solo como respaldo histórico.
- Los 45 intentos de simulacro anteriores a esta migración no tienen Tipo de Prueba ni Competencia asociados (columnas `NULL`) — se muestran como "—" en los historiales.
- No hay una suite de tests automatizados.
- **`resultados_saber_pro_tyt`** (datos ICFES) está creada e importada, con `conexion_resultados.php` listo para usarse, pero **todavía ningún dashboard la consulta** — es infraestructura preparada para una funcionalidad futura de comparar resultados. Sus 51 tablas/vistas vienen con nombres tal como los generó el import original del ICFES (con espacios, paréntesis e incluso `.csv` en el nombre); revisa `database/schema.sql` para la lista completa antes de construir algo sobre ellas.

---

## Notas para quien siga desarrollando

- El repo vive en `universidad/.git` (no en la raíz de `htdocs`), con remoto en GitHub. Revisa `git remote -v` y `git branch` antes de hacer push.
- PHPMailer está vendorizado a mano en `vendor/phpmailer/` (sin Composer). Si necesitas actualizarlo, reemplaza los 3 archivos en `vendor/phpmailer/src/` por los de la versión que quieras desde el repo oficial de PHPMailer.
- `estilos.css` es la única hoja de estilos del proyecto; todas las páginas la comparten. Antes de crear una clase nueva, revisa si ya existe algo parecido (`.btn`, `.btn-peligro`, `.tabla-indicadores`, `.modal-*`, etc.) para mantener la interfaz uniforme.
