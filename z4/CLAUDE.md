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
9. **Guardar el estado.** Propón por tu cuenta guardar aquí (Estado, Hechos comprobados, Pendientes) y en la memoria lo que no esté escrito, y avisa al hacerlo. Hazlo en estos casos:
   - Cuando termine una tarea o el usuario pase a otra distinta.
   - Cuando la conversación se alargue (muchos mensajes, salidas grandes o antes de un `/compact`). Incluye lo que está a medias y el siguiente paso exacto.
   - En cuanto aparezca algo que convenga no perder: un hecho comprobado, un hallazgo tras mucha investigación, una contradicción o algo que no se ve a simple vista, o una conclusión útil para el futuro.

   Enseña el diff y, con OK, aplícalo y súbelo a `claude-config`.
   Después, si la siguiente tarea es distinta, recomienda abrir una sesión nueva en `/z4` y da el primer mensaje listo para copiar (p. ej. «Lee el Estado de CLAUDE.md. Vamos con …»). Si es la misma tarea y la sesión está muy cargada, recomienda «Compactar sesión».

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

## Producción y mantenimiento con swap (hechos comprobados)
- `rsync_z4web` excluye `data/binlog.*`, `logs/`, `cache/`, `wp-content/cache/`, `uploads/` (van con `cp -al`), `updraft/`, `maintenance/backups/` y los backups de iThemes. Tras el swap, eso solo existe en `/z4/web.original`: al borrarla se pierde (24-nov se perdieron así los backups locales y los binlogs).
- Los enlaces duros (`cp -al`) no ocupan espacio extra, y borrar uno no libera nada mientras quede otro.
- MySQL 8.0.29 tiene los binlogs activos (valor por defecto): ficheros de 1 GB y 30 días de retención, porque `binlog_expire_logs_seconds` está comentado en `config/mysql/conf.d/z4stack-mysql.cnf`. Comprobado en prod el 24-nov (`1 2592000 1073741824`). En staging el formato es ROW con imagen FULL y no hay réplicas.
- La imagen `mysql:8.0.29` no trae `mysqlbinlog`. Para saber qué tabla genera el binlog, con el fichero `F` (p. ej. `binlog.000473`):
  `sudo docker exec db sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -NBe "SHOW BINLOG EVENTS IN \"'$F'\""' 2>/dev/null | awk -F'\t' '$3=="Table_map"{t=$6; sub(/.*\(/,"",t); sub(/\).*/,"",t)} {b[t]+=$5-$2} END{for(k in b) printf "%8.1f MB %s\n", b[k]/1048576, k}' | sort -rn | head -12`
  Probado en staging: 9 s con 672 MB.
- Con el disco lleno, MySQL no puede escribir temporales («table … is full», ERROR 1114): las transacciones se quedan abiertas, hay `Lock wait timeout` (en `user_hit_count` de ManageWP y en las metas de visitas), la CPU está casi a 0 y la web cae (24-nov). MySQL no usa el 5 % reservado de ext4.
- Redis en prod: contenedor `ocache`, `redis:7.4.11-alpine`, con `--save "" --appendonly no --maxmemory 4gb --maxmemory-policy allkeys-lru`; solo prefijo `wp`. Drop-in en `httpdocs/wp-content/object-cache.php`.
- Redis Object Cache, según sus desarrolladores: WordPress invalida solo y vaciar la caché al publicar está desaconsejado. Si solo se arregla vaciándola, el tema o un plugin es incompatible, y se mete su grupo en `WP_REDIS_IGNORED_GROUPS`. Último recurso: vaciado horario por WP-Cron. En staging la cadena es WP Rocket + Cloudflare (mu-plugin `z4-cf-bucket-tablet.php`) + Redis; `jnews-view-counter` usa el grupo `jnews-view-counter`.

## Estado a 24-nov-2026 (prod PR, tras el mantenimiento del 23-nov)
- **Redis desactivado en prod** (`wp redis disable`; drop-in sin instalar; `ocache` sigue en marcha). Con Redis, las noticias nuevas no aparecían. La causa está sin encontrar. El borrador de mu-plugin que vacía la caché al publicar está descartado por ahora (no se quieren parches).
- La web cayó por disco al 100 %. Se recuperó con `sudo rm -rf /z4/web.original`, que liberó 226G.
- **Urgente, a medias:** los binlogs ocupan 475G en prod y crecen a ~1 GB por minuto. El 24-nov a las 12:55 quedaban 188G libres: el disco se llena hacia las 16-17 h.
  - **Causa (comprobado):** prácticamente todo es `wp_options` (1030 MB de 1031 en `binlog.000479`).
  - **Ritmo por hora:** 2-3 ficheros/h el 23-nov a las 19-21 h, justo tras el swap; 13 a la 01 h; ~45 a partir de las 05 h; 63 a las 10 h. Empezó antes de desactivar Redis, así que Redis no es la causa.
  - **Culpable (comprobado):** `elementor_atomic_cache_validity__popup-trigger-styles-related-posts`, de la clase `Popup_Trigger_Styles` de Elementor Pro 4.4.1 (Elementor 4.4.1). Ocupaba 4,45 MB y crecía unos 3,4 KB/min. Cada `UPDATE` ocupaba 8,7 MB de binlog (ROW/FULL: valor antes y después), unas 2 por segundo.
  - **Mecanismo (leído en el código):** un nodo de unos 46 B por post. Cada post sin caché reescribe la opción entera. Hay unos 201k posts publicados, así que llegaría a unos 9 MB. Elementor la borra entera al vaciar su caché, y entonces vuelve a crecer desde cero. Por eso **borrarla sin más empeora**: es el apaño que circula. Desactivar el Atomic Editor no afecta a esta clase, que se registra siempre que la Pro está activa.
  - **Bugs abiertos, sin arreglo:** elementor#37781, #37016 y #35268. El PR #37838 solo evita reescribir cuando no hay cambios.
  - **Solución elegida:** el mu-plugin `z4-elementor-popup-cache-nowrite.php` (filtro `pre_update_option_<opción>` que devuelve el valor antiguo) + `wp option delete` de la opción. Así los popups se calculan en cada render, sin caché. En staging ningún post tiene popups con disparador y hay una sola plantilla de popup.
  - **Probado en staging el 24-nov (Elementor 4.3.2/Pro 4.3.0):** sin el mu-plugin, 5 posts crean 5 nodos; con él, la opción no se vuelve a crear y no hay avisos de PHP. La prueba simula el render con `do_action('elementor/post/render')` mediante `wp eval-file`, porque por HTTP staging responde 401.
  - **Medida temporal (24-nov, 13 h):** `SET PERSIST binlog_expire_logs_seconds=10800` (3 h) + `PURGE BINARY LOGS BEFORE NOW() - INTERVAL 3 HOUR`. El disco quedó en 313G usados y 520G libres (38 %). Al principio no se purgó por una mala lectura de la salida («réplicas: fin» sin nada antes = sin réplicas).
  - Cuando se arregle quien escribe: `SET PERSIST binlog_expire_logs_seconds=86400` (24 h). Con el ritmo actual, 24 h serían 1,1-1,5 TB y no caben.
  - `SET PERSIST` se guarda en `/z4/web/data/mysqld-auto.cnf`, que **manda sobre** `z4stack-mysql.cnf` y sobrevive a los reinicios. Para deshacerlo: `RESET PERSIST binlog_expire_logs_seconds`.
  - **Siguiente paso:** el usuario instala el mu-plugin en prod y borra la opción. Después se comprueba que el ritmo de binlogs baja (ficheros por hora) y se sube la retención a 24 h o más.
  - Para identificar opciones como esta: tamaño de los eventos `Update_rows` de `wp_options` + las opciones más grandes medidas dos veces, con 60 s entre una y otra.
- **Pendientes:**
  - **Red de seguridad contra el disco lleno** (cuando se resuelva Elementor). Se recomienda la **alerta cuando `df /` pase del 85 %** antes que un tope de binlogs por cron (más de 150G → `PURGE BINARY LOGS TO`):
    - Hoy hubo dos causas distintas (`web.original` y los binlogs) y solo la alerta cubre las dos.
    - La alerta no borra nada ni esconde a quien escribe sin control.
    - La retención por tiempo ya pone límite a los binlogs.
    - Falta decidir el canal de aviso.
    - MySQL 8.0 no tiene límite de tamaño total de binlog: `binlog_space_limit` es de Percona, `max_binlog_total_size` es de MariaDB, y el bug de MySQL #66733 sigue abierto. Comprobado en el manual de MySQL 8.0 el 24-nov.
  - Comprobar que hay una copia reciente de la BD en la nube.
  - Decidir si se borran `/z4/web.backup-eliminarmastarde` y `/z4/web.backup2` (16G cada una).
  - Averiguar si se ejecutó `tune2fs -m 1`; si se ejecutó, volver a `-m 5`.
  - Redis: reproducir el fallo en staging (pide OK: `wp` que escribe). Faltan dos datos: qué bloque o página salía sin actualizar, y si las noticias eran programadas o manuales.
  - Protocolo (como sugerencias): comprobar `df` antes de la copia inicial y añadir un paso para lo excluido antes de borrar la original.
  - Bots (SQLi en `?amp=`, paginación profunda) → bloquear en Cloudflare. `user_hit_count` (ManageWP) y `_eael_post_view_count` escriben en cada visita.

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
