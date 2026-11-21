# CLAUDE.md — Script de evidencias de mantenimiento Z4 (servidor de STAGING)

## Qué es esto
Este archivo vive en `/z4/CLAUDE.md`, fuera de `/z4/web`, para que no lo borre la sincronización de prod a staging. Todas las rutas son absolutas. `testweb/` significa `/z4/web/maintenance/testweb/`.

Estamos sacando de `auto-maint.sh` un script independiente, `z4-evidencias.sh`, que hace **capturas de pantalla, PageSpeed, comparación de capturas y subida a Google Drive** para los mantenimientos web en z4stack. Se trabaja en el servidor de **staging** (lo identifica el archivo `/z4/staging/docker-compose.staging.yml`).

Además existe `z4-drive.sh`, que solo sube a Drive lo que se le indique, reutilizando la subida de `z4-evidencias.sh` (19-nov-2026).

**Ojo:** el dominio no cambia. Desde este servidor, y desde sus contenedores, `prnoticias.com` apunta a **PRODUCCIÓN**. Las capturas y PageSpeed miden producción, y eso es aceptado.

## Archivos
| Ruta | Qué es | ¿Se puede tocar? |
|---|---|---|
| `/z4/web/maintenance/auto-maint.sh` | Script **original**, la referencia de cómo deben funcionar las cosas | **NO** |
| `/z4/web/maintenance/z4-evidencias.sh` | Script nuevo (v10) | Solo con aprobación |
| `/z4/web/maintenance/z4-drive.sh` | Sube archivos o carpetas a Drive, tal cual o en `.tar.gz` (`--help`) | Solo con aprobación |
| `/z4/web/maintenance/testweb/screenshots.js` | Capturador Puppeteer (ya modificado; el original está en `screenshots.js.bak`, si existe) | Solo con aprobación |
| `/z4/web/maintenance/testweb/compare.js` | Comparador (modificado; el original está en `compare.js.bak`) | Solo con aprobación |
| `/z4/web/maintenance/testweb/screenshots_urls.json`, `package.json`, `package-lock.json` | Lista de URLs y dependencias | **NO** |
| `/z4/web/maintenance/testweb/screenshots/{antes,despues}/{capturas,velocidad}/`, `diff/` | Salida del script | Las borra el propio script |
| `/z4/web/maintenance/rclone/rclone.conf` | Credenciales de Drive (remoto `z4maint:`) | **NO. No mostrar nunca su contenido** |
| `/z4/web/config/.env` | Configuración de la web | **NO.** Para leer una variable: `grep '^Z4_DOMAIN=' …` |

## Reglas obligatorias
1. **Cambios mínimos.** No cambies ningún comportamiento sin aprobación explícita del usuario. Antes de editar: explica qué cambias y por qué, enseña el diff y espera el "sí". Numera los cambios; el último aprobado es el 20, más los cambios A–G. Commits en `/z4/web` (rama `prnoticias.com`): `6ad86a5`, `7b96164`, `1ed0634`, `90a4cd4` (prompt), `ebad449` (19), `9f24bf6` (20).
   - `z4-drive.sh` (sin numerar): `74f268e`, `f8a1ee8`, `f40fe9b`, `456a937`, `55e95d9`, `0796ca2`, `8494762` (registro de las 19 pruebas).
   - Este CLAUDE.md, `~/.claude/CLAUDE.md` y la memoria (`~/.claude/projects/-z4/memory/`) están respaldados en el repo `~/claude-config` (GitHub privado `jkarlosb/z4stack-claude-config`). Después de cada cambio en cualquiera de ellos, súbelo al repo: copia, commit y push, con el bloque "Actualizar el repo" de su README. Ya no se hacen copias `-bck-`.
2. **El original es la referencia.** Si algo funcionaba en `auto-maint.sh`, no se rompe. Ante la duda, compara con el original y dilo. No "mejores" nada que no se haya pedido; proponlo y espera.
3. **Honestidad.** Distingue lo comprobado de lo deducido. Verifica en el servidor con comandos de solo lectura antes de proponer una solución. Si una hipótesis falla, dilo claramente.
4. **Orden de pruebas, de menos a más riesgo:** `bash -n` / `node --check` → comandos de solo lectura → ejecución real.
5. **Pide permiso antes de ejecutar:**
   - `z4-evidencias.sh --capturas`: crea un usuario en WordPress y en producción puede desactivar el 2FA.
   - `auto-maint.sh`.
   - Cualquier `wp` que escriba.
   - `docker-compose`, `rsync`, `apt`, reinicios.
   - `chown`/`chmod` fuera de `testweb/`.
   - `rm -rf` fuera de `testweb/screenshots/`.
6. **Secretos:** no imprimas `rclone.conf`, el `.env` completo ni la clave de PageSpeed.
7. **Versiones siempre fijas** en imágenes y dependencias. Nunca `latest`.
8. Respuestas en español, directas, con los comandos listos para copiar.

## Hechos ya comprobados (no hay que volver a descubrirlos)
- **El script se ejecuta con `sudo`**, igual que el original. Sin root falla el montaje de Drive (`/z4/remote/maint/mount` es de `root:root`) y también `umount`.
- **Imágenes Docker:** `node:16.16.0-alpine3.15` (trae Chromium 99) y `rclone/rclone:1.58.1`. Puppeteer es la 15.5.0 (versión del lock).
  - `node:22.16.0-alpine3.21` (Chromium 136) **no funciona** con Puppeteer 15: falla con `Target.setAutoAttach: Target closed`.
  - Actualizar Node exige actualizar también Puppeteer y el lock, y es una tarea aparte.
- **npm 8 (Node 16)** ejecuta `npm run` con el **UID del propietario de `testweb/`**, aunque el contenedor corra como root. Por eso `testweb/` debe pertenecer a quien lanza el script (cambio 1).
- **Usa `npm install`, no `npm ci`:** `npm ci` borra `node_modules` y vuelve a descargar el Chromium de Puppeteer en cada ejecución.
- **`docker run` debe llevar `-it`:** con solo `-i`, Ctrl-C no detiene el contenedor.
- **WP-CLI** `wp user get … --fields=roles --format=json` devuelve los roles como **texto** (`"editor"` o `"editor, author"`), no como lista.
- **En staging, el login de admin siempre falla.** El usuario temporal se crea en el WordPress de staging, pero el navegador va a producción. Es lo esperado y queda anotado en `errores-manual.txt`.
  - Riesgo: cada intento es un login fallido contra producción. Solid Security podría bloquear la IP del staging. No lances `--capturas` en bucle.
- **2FA:** el protocolo de staging lo deja desactivado, así que aquí el script no lo toca. En producción lo desactiva para todo el sitio y lo reactiva después; esa reactivación está garantizada por `trap`, por una verificación con 3 reintentos y por un tiempo máximo del navegador de 1200 s.
- **`compare.js`:** si antes y después tienen distinta altura, falla con "Image sizes do not match" y aun así termina con código 0. En julio de 2025 se quedaron sin comparar 8 de 16 capturas. Está apuntado como mejora pendiente.
- **`rclone_log.txt`** tiene errores antiguos ("Shared drive not found"), pero la subida del 17-nov a las 15:00 funcionó.
- **Enlace de Drive:** `rclone lsjson --stat z4maint:<dominio>/<fecha>` trata esa carpeta como raíz y **no devuelve ID**. Para obtenerlo hay que listar la carpeta padre: `lsjson --dirs-only z4maint:<dominio>` y coger la entrada cuyo `Name` es la fecha (cambio 16).
- **Lazy load (WP Rocket):** `fullPage` no hace scroll, así que las imágenes fuera de la primera pantalla salían vacías. Esperar más no sirve: hay que recorrer la página antes de capturar (cambio 13).
- **Cookies en prnoticias:** el plugin actual usa `button.wcc-btn-accept[data-tag="accept-button"]`. El selector antiguo, `#wt-cli-accept-btn`, ya no existe como botón, pero se mantiene para otras webs (cambio 14). El navegador comparte cookies entre pestañas: para capturar el banner hace falta un contexto de incógnito.
- **PageSpeed (web):** con el user-agent "HeadlessChrome", Google responde **429 "Sorry..."** al lanzar un análisis, y la web lo muestra como *"Unable to resolve"*. Con el user-agent normal funciona. El formato actual de la URL es `https://pagespeed.web.dev/analysis?url=<url codificada>&form_factor=mobile`, que redirige a `/analysis/<web>/<id>`; cambiando `form_factor=desktop` se ve el mismo informe en escritorio (cambio 15). La API sin clave tiene la cuota diaria agotada; la que usamos lleva clave.
- **PageSpeed (web), informe listo:** los gauges existen en el HTML con ancho 0 mientras sigue analizando, y el de escritorio llega antes. Hay que esperar al gauge "Performance" pintado (ancho > 0) y sin barra de carga visible (cambio 20).
- **Pingdom:** no bloquea el navegador automatizado. La ubicación por defecto cambia entre cargas, así que hay que elegir Germany en `app-select` (`div.option`) y verificarlo. El resultado sale en unos 15 s (cambio 19).
- **Timeout de navegación:** algunas páginas de producción tardan más de 30 s (`categoria-marketing` el 17-nov). El límite de 30 s es el que Puppeteer trae por defecto; no está cambiado.
- **Claude no tiene `sudo` sin contraseña.** Las pruebas reales las ejecuta el usuario; Claude da cada prueba con lo esperado y revisa la salida. Claude sí puede hacer la validación en seco (`bash -n`, `shellcheck`, resumen respondiendo `n`) y las consultas de rclone de solo lectura con `docker run` (el usuario `akuario` está en el grupo `docker`).
- **Drive:** `z4maint:` es la unidad compartida **«Mantenimientos»** (`team_drive` en `rclone.conf`; `root_folder_id` vacío). `rclone backend drives z4maint:` devuelve su nombre.
- **rclone 1.58.1 no da el nombre de una carpeta a partir de su ID:** `lsjson --stat` devuelve `Name` vacío y no existe `backend query`. Listar toda la unidad (`lsjson -R --dirs-only`) tarda unos 5 s con 500 carpetas; se descartó.
- **`--drive-root-folder-id ID`** al montar hace que esa carpeta sea la raíz. Funciona dentro de «Mantenimientos» y fuera, si la carpeta está compartida con la cuenta de servicio (prueba 19, 19-nov).
- **Zip en el montaje de rclone (sin caché):** no se puede escribir directamente (deducido, sin probar); necesitaría un temporal local. Por eso `z4-drive.sh` solo tiene `--tar`. `zip` no está instalado.
- **`read -p`** no muestra la pregunta si la entrada no viene de una terminal; con `echo |` o `< /dev/null`, `z4-drive.sh` cancela con código 1.

## Estado a 17-nov-2026 (tarde)
- La v10 está probada con `sudo`: capturas y subida a Drive OK; fallaban las imágenes con lazy load, el banner, `pagespeed.png` y el enlace de Drive.
- 18-nov: **v11 (cambios 13–18) instalada, probada y con commit.** `--fase antes --capturas --pagespeed` funciona entero: 23 capturas, PageSpeed por API y web (móvil y escritorio), Drive con enlace. Solo falla el admin, que en staging es lo esperado.
- La fase DESPUÉS está probada y funciona (mismo código; solo cambia la carpeta).
- **Enfoque de comparación (decidido):** el técnico baja los tar de antes y después, los pasa a `.zip` y se los da a una IA (Claude o ChatGPT) con el prompt de `/z4/web/maintenance/prompt-comparacion-ia.md`. No se hace comparación automática por píxeles nueva; `--comparar` sigue como estaba. Drive no cambia: el técnico busca las carpetas.
- `--pagespeed` incluye PageSpeed (API y web, móvil y escritorio) y Pingdom desde Alemania.
- **Pendiente de decisión (anterior):**
  - **H:** que el script se relance solo con `sudo` si no se ejecuta como root.
  - Quitar los cambios 2, 5, 6 y 10, que sobran ahora que se ejecuta como root. El 1 se queda.
- **Decidido 18-nov:** Chromium se sigue instalando con `apk` en cada ejecución (opción B, sin imagen propia). Las credenciales de Drive se quedan en git como están. Los `.bak*`, `.bck*` y `z4-diag.sh` sin seguimiento se dejan.
- **19-nov: `z4-drive.sh` terminado y probado** (19 de 19 pruebas reales correctas; detalle en el commit `8494762`). Documentado en https://claude.ai/artifact/WAAYDQeK1ysT5PMCmDMCMU.
  - Pendiente: borrar de Drive lo subido en las pruebas y `rm -rf /tmp/z4p`.
  - Pendiente: revisar si `akuario` necesita el grupo `docker` (equivale a root).
- **Mejoras pendientes (no hacerlas sin que se pidan):**
  - `noticia_mobile.png` y `noticia_tablet.png` salen con el popup de cookies (18-nov). Por ahora no es relevante.
  - 17b: que `--comparar` se niegue a ejecutarse si `despues/` es más antiguo que `antes/`.
  - Desactivar el 2FA solo para el usuario temporal, no para todo el sitio.
  - Que el comparador soporte alturas distintas.
  - Actualizar Node y Puppeteer.
  - Restringir o rotar la clave de PageSpeed (está en el código y en chats).
  - Imagen Docker propia con versiones fijas.
  - `--add-host` para capturar staging en vez de producción.
  - Documentar el procedimiento común en el protocolo de mantenimiento.

## Cambios sobre el MVP (resumen)
| # | Cambio |
|---|---|
| 1 | `testweb/` pasa a ser de quien ejecuta el script; comprueba los permisos de rclone y de los logs |
| 2 | `chown` de `screenshots/` al terminar cada contenedor |
| 3 | `npm install` en lugar de `npm ci` |
| 4 | `docker run -it` |
| 5 | Si falla `umount`, se intenta con `sudo umount` |
| 6 | La consulta del enlace de Drive (`lsjson`) se ejecuta con el usuario que lanza el script |
| 7 | Imagen Node original |
| 8 | Carpetas `capturas/` y `velocidad/` con limpieza independiente, más las rutas en `compare.js` |
| 9 | Tiempo máximo del navegador (1200 s) |
| 10 | `--group-add` para rclone |
| 11 | Imagen rclone original |
| 12 | Lectura del rol como texto |
| 13 | Scroll de la página antes de cada captura (lazy load) |
| 14 | Selector nuevo del banner de cookies, más `home_cookies.png` y `home_mobile_cookies.png` (contexto de incógnito) con el banner |
| 15 | PageSpeed web: user-agent normal, URL `/analysis`, se espera a ver el informe, hasta 3 intentos, `pagespeed-mobile.png` + `pagespeed-desktop.png` + `pagespeed-informe-url.txt`; si falla, `pagespeed-ERROR.png` |
| 16 | Enlace de Drive: ID tomado listando la carpeta del dominio |
| 17 | Drive: el tar solo incluye lo generado en la ejecución, como `evidencias-<fase>-HHMMSS.tar.gz` |
| 18 | Mensaje inicial de `screenshots.js` según el modo |
| 19 | Pingdom desde Alemania: `pingdom.png` + `pingdom-resumen.txt` en `velocidad/` (dentro de `--pagespeed`) |
| 20 | PageSpeed: el informe se da por listo solo con el gauge "Performance" pintado y sin barra de carga |
| A | Confirmación con ENTER al empezar |
| B | Contraseña aleatoria; si el usuario temporal ya existe, se recrea solo si tiene nuestro email |
| D | Comparativa PageSpeed antes/después |
| E | Comparación de las capturas de tablet |
| F | `tar` con listado de archivos (`czvf`) |
| G | Mensajes de error precisos |
