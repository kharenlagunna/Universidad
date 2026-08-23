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

2. **Crea la base de datos** ejecutando el script incluido:
   ```bash
   mysql -u root < database/schema.sql
   ```
   Esto crea la base `proyecto_saber_pro_tyt` con todas las tablas y un usuario administrador de arranque:
   - **Usuario:** `admin`
   - **Contraseña:** `changeme123`

   ⚠️ Cámbiala apenas entres, desde *Gestión de Usuarios* dentro de la app.

3. **Configura la conexión a la base de datos** en [`conexion.php`](conexion.php) si tu MySQL no usa `root` sin contraseña (por defecto de XAMPP):
   ```php
   $servername = "localhost";
   $username_db = "root";
   $password_db = "";
   $dbname = "proyecto_saber_pro_tyt";
   ```

4. **Configura el envío de correo** (necesario solo para "Olvidé mi contraseña"):
   ```bash
   cp mail_config.example.php mail_config.php
   ```
   Edita `mail_config.php` con credenciales SMTP reales (el archivo trae instrucciones para Gmail con "contraseña de aplicación"). **Este archivo no se sube a git** (está en `.gitignore`) porque contendrá credenciales reales.

5. Abre `http://localhost/universidad/login.php` e ingresa con el usuario semilla.

---

## Estructura del proyecto

```
universidad/
├── database/
│   └── schema.sql              # Estructura completa de la BD + usuario admin semilla
├── vendor/phpmailer/           # PHPMailer instalado a mano (sin Composer)
├── templates/                  # Plantillas .xlsx/.csv para cargar preguntas/datos
├── img/                        # Imágenes estáticas
├── conexion.php                # Configuración de conexión a MySQL
├── mail_config.example.php     # Plantilla pública de configuración SMTP
├── mail_config.php             # Configuración SMTP real (NO se versiona)
├── sidebar.php                 # Menú lateral compartido por todas las páginas
├── estilos.css                 # Hoja de estilos única de todo el proyecto
└── *.php                       # Una página/endpoint por archivo (ver tabla abajo)
```

No hay build step ni framework: cada `.php` de la raíz es una página que se abre directamente por su URL.

---

## Roles

| Rol | Puede hacer |
|---|---|
| `admin` | Todo lo del visor, más: cargar banco de preguntas, cargar información general, gestionar usuarios (crear/editar/eliminar) |
| `visor` | Presentar simulacros, ver su propio historial y resultados, ver análisis gráfico |

El rol se guarda en `usuarioss.rol` y se valida en cada página (`if ($_SESSION['rol'] !== 'admin') { ... }`).

---

## Mapa de módulos

### Autenticación y cuenta
| Archivo | Qué hace |
|---|---|
| `login.php` | Inicio de sesión. Migra automáticamente contraseñas viejas en texto plano a hash la primera vez que alguien entra. |
| `logout.php` | Cierra la sesión. |
| `completar_perfil.php` | Pide el correo la primera vez que un usuario sin email entra (lo necesita para poder recuperar su contraseña). |
| `recuperar_contrasena.php` | Pide el correo y envía un enlace de recuperación de un solo uso (válido 1 hora). |
| `restablecer_contrasena.php` | Valida el enlace y permite definir una nueva contraseña. |
| `enviar_correo.php` | Función que arma y envía los correos vía PHPMailer/SMTP. |

### Panel y navegación
| Archivo | Qué hace |
|---|---|
| `dashboard_admin.php` / `dashboard_visor.php` | Pantalla de bienvenida según el rol. |
| `sidebar.php` | Menú lateral (marca, módulos según rol, usuario + cerrar sesión). Se incluye con `require` en cada página. |

### Gestión de usuarios (solo admin)
| Archivo | Qué hace |
|---|---|
| `admin_usuarios.php` | Lista, busca y pagina usuarios; botón para crear y editar (modal). |
| `admin_usuario_guardar.php` | Procesa crear/actualizar (valida duplicados, hashea contraseña). |
| `admin_usuario_eliminar.php` | Procesa eliminar (no permite borrar tu propia cuenta ni al último admin). |

### Banco de preguntas (solo admin)
| Archivo | Qué hace |
|---|---|
| `admin_cargar_preguntas.php` / `procesar_carga_preguntas.php` | Sube un Excel con preguntas y las inserta en la BD. |
| `cargar_preguntas.php` | Reemplaza *todo* el banco de preguntas desde `templates/preguntas.csv`. Uso puntual/manual. |
| `descargar_plantilla_preguntas.php` | Descarga la plantilla Excel de preguntas. |
| `cargar_informacion.php` / `procesar_carga.php` | Carga general de datos vía Excel. **`procesar_carga.php` está incompleto** (inserta en una tabla llamada literalmente `tu_tabla`, ver Limitaciones). |
| `descargar_plantilla.php` | Descarga la plantilla Excel general. |

### Simulacro
| Archivo | Qué hace |
|---|---|
| `simulacro_inicio.php` / `procesar_simulacro.php` | Elige filtros (grupo, módulo, tipo de prueba) e inicia un intento. |
| `simulacro_pregunta.php` / `guardar_respuesta.php` | Muestra cada pregunta con temporizador y guarda la respuesta elegida. |
| `simulacro_resultados.php` | Resultado final de un intento (correctas/incorrectas, gráfico). |
| `simulacro_historial.php` | Historial de todos los intentos del usuario logueado. |
| `obtener_opciones.php` / `obtener_cantidad_max.php` | Endpoints AJAX que alimentan los `<select>` en cascada de `simulacro_inicio.php`. |
| `analisis_grafico.php` | Gráfico de ejemplo (Chart.js). |

---

## Seguridad — cosas ya resueltas que vale la pena conocer

- Las contraseñas se guardan con `password_hash`/`password_verify` (no en texto plano).
- Cada endpoint de simulacro valida que el `intento_id` pertenezca al usuario en sesión (evita ver/editar intentos de otra persona).
- `cargar_preguntas.php` y `obtener_cantidad_max.php` exigen sesión activa.
- El token de recuperación de contraseña se guarda **hasheado** (`SHA-256`) y expira en 1 hora.
- `mail_config.php` está en `.gitignore`: nunca debe subirse con credenciales reales.

---

## Limitaciones conocidas / pendientes

- **`procesar_carga.php`** inserta en una tabla llamada `tu_tabla`, que no existe — es un placeholder que quedó sin terminar. El botón "Cargar Archivo" en `cargar_informacion.php` fallará hasta que se complete.
- **`preguntas_old`, `resultados`, `calendario`** son tablas heredadas que ningún código activo usa hoy. Se conservan en `schema.sql` solo por si tienen datos históricos de valor; son candidatas a eliminarse en una limpieza futura.
- No hay una suite de tests automatizados.

---

## Notas para quien siga desarrollando

- El repo vive en `universidad/.git` (no en la raíz de `htdocs`), con remoto en GitHub. Revisa `git remote -v` y `git branch` antes de hacer push.
- PHPMailer está vendorizado a mano en `vendor/phpmailer/` (sin Composer). Si necesitas actualizarlo, reemplaza los 3 archivos en `vendor/phpmailer/src/` por los de la versión que quieras desde el repo oficial de PHPMailer.
- `estilos.css` es la única hoja de estilos del proyecto; todas las páginas la comparten. Antes de crear una clase nueva, revisa si ya existe algo parecido (`.btn`, `.btn-peligro`, `.tabla-indicadores`, `.modal-*`, etc.) para mantener la interfaz uniforme.
