# CLAUDE.md — Script de evidencias de mantenimiento Z4 (servidor de STAGING)

## Qué es esto
Este archivo vive en `/z4/CLAUDE.md`, fuera de `/z4/web`, para que no lo borre la sincronización de prod a staging. Todas las rutas son absolutas. `testweb/` significa `/z4/web/maintenance/testweb/`.

Estamos sacando de `auto-maint.sh` un script independiente, `z4-evidencias.sh`, que hace **capturas de pantalla, PageSpeed, comparación de capturas y subida a Google Drive** para los mantenimientos web en z4stack. Se trabaja en el servidor de **staging**, cuyo nombre clave en Z4 Studios es **`staging-hz499`** (lo identifica también el archivo `/z4/staging/docker-compose.staging.yml`).

Además existe `z4-drive.sh`, que solo sube a Drive lo que se le indique, reutilizando la subida de `z4-evidencias.sh` (19-nov-2026).

**Ojo:** el dominio no cambia. Desde este servidor, y desde sus contenedores, `prnoticias.com` apunta a **PRODUCCIÓN**. Las capturas y PageSpeed miden producción, y eso es aceptado.

## Documentos del cliente (prnoticias.com)
- Historial: «Historial web PR parte 2», https://docs.google.com/document/d/1uD6BcJF0Yk4E7A6LxIo-hlcr4ufPfq0VwZEr4zHMXuQ (entradas por técnico; lo de Claude va bajo «Carlos»).
- Ficha técnica: «Ficha y antes de actualizar», https://docs.google.com/document/d/1a3Rqp44obFhFRw1PsjxYMiWDIlBhctUtidgDpwk1Sm4 (los hardcodeos van en Intervención → Harcodeos).

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
   - Este CLAUDE.md y la memoria (`~/.claude/projects/-z4/memory/`) se respaldan en `claude-config` (`staging-hz499/z4/`) con `sync.sh`: sección P del CLAUDE.md global. Ya no se hacen copias `-bck-`.
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
9. **Guardar el estado:** sección P del CLAUDE.md global. Aquí van el Estado, los Hechos comprobados y los Pendientes de este proyecto.

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
- **Correo del stack:** `send-email.sh` (backups) y `check-certs.sh` (certificados) envían con `openssl s_client -starttls smtp` a `ssl0.ovh.net:587` y no leen las respuestas SMTP: un fallo pasa desapercibido. Para probar una credencial sin enviar nada: `curl --ssl-reqd -K - -X NOOP smtp://ssl0.ovh.net:587` (250 = correcta, 535 / exit 67 = rechazada). En `origin/master` existe `scripts/check-disk-space.sh` (aviso por bytes libres, sin uso). Ojo: la rama `master` **local** está desactualizada (sigue con `no-reply@`); comparar siempre con `origin/master`.
  - Ese envío a ciegas no muestra si llega: `s_client` cierra al acabarse la entrada, antes de las respuestas tras el login, y sale con 0. Con `servidor@` sí llega (prueba a tech@ desde staging, 26-nov, confirmada por Carlos).
  - Sin `-quiet`, `s_client` interpreta `Q` (cerrar) y `R` (renegociar) al principio de un bloque de entrada; `k`/`K` solo con TLS 1.3, y OVH negocia TLS 1.2. El cuerpo de los avisos de backups lleva hasta 1000 líneas de log: riesgo bajo.
  - Contenedores en prod: `backups` (cron generado por `docker-entrypoint.sh` desde los `Z4_BCK_*_CRON` del `.env`; keepalive el día 1 a las 03:00, sin log), `certs` (`check-certs.sh` a las 08:00, avisa con 10 días o menos) y `cron`. En staging no corren.
  - `check-certs.sh` se monta en `certs` como **archivo suelto**: tras un `git pull` el contenedor sigue viendo el archivo viejo hasta `docker restart certs` (comprobado con un contenedor de prueba). `backups` monta `/z4/web` entero y no tiene ese problema.
  - `shellcheck` marca como error la línea `let DIFF_DAYS=(…)` de `check-certs.sh`, pero bash la ejecuta bien (comprobado).
  - Compose (v2.30.2 en staging, v2.27.0 en prod) lee bien los comentarios en línea del `.env` (`VAR="valor" # comentario`); comprobado en staging con un `.env` de prueba.
  - El shell de `akuario` tiene `COMPOSE_FILE` definido: `docker compose config` sin `-f` carga la config real (con secretos).
  - **Staging no deja salir correo desde los contenedores** (a propósito): las reglas `DOCKER-USER` de `/etc/ufw/after.rules` solo dejan conexiones TCP nuevas a 80 y 443 desde `br+`/`docker0` hacia `ens3`; el resto, `REJECT` (tcp-reset). Desde el host sí sale. Documentado en el doc del servidor de staging (https://docs.google.com/document/d/1vUOxaM31luQRZmC9eXhtAg7JsOFPkOkkH9m5RfZCI6U, «UFW e iptables»). En prod, `backups` y `certs` sí llegan a `ssl0.ovh.net:587` (26-nov).

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

## Estado (27-nov-2026)
El historial detallado (del 17 al 26-nov) y la tabla de cambios 1–20 y A–G están en la memoria, en `historial-estado-z4.md`. Léelo solo cuando la tarea toque esos temas.

### Prod PR (`hz492`)
- **Redis desactivado** (`wp redis disable`; drop-in sin instalar; `ocache` sigue en marcha). Con Redis, las noticias nuevas no aparecían. La causa está sin encontrar. El mu-plugin que vacía la caché al publicar está descartado (no se quieren parches).
- **Elementor y binlogs, cerrado (24-nov):** el mu-plugin `z4-elementor-popup-cache-nowrite.php` impide reescribir `elementor_atomic_cache_validity__popup-trigger-styles-related-posts`, y la opción está borrada. El binlog crece ~1,4 MB/min.
  - Retención: `SET PERSIST binlog_expire_logs_seconds=604800` (7 días). Está en `/z4/web/data/mysqld-auto.cnf`, que manda sobre `z4stack-mysql.cnf`. Para deshacerlo: `RESET PERSIST binlog_expire_logs_seconds`.
  - Los 131 binlogs de antes del arreglo se purgan solos hacia el 1-2 dic.
  - En cada mantenimiento hay que revisar los bugs elementor#37781, #37016 y #35268 (lo dice la ficha).
  - Para identificar opciones así: tamaño de los eventos `Update_rows` de `wp_options` + las opciones más grandes medidas dos veces, con 60 s entre una y otra.

### Pendientes
- **Seguridad de Claude en varios servidores** (27-nov): el plan está en el doc «Agentes IA» → Historial, entrada del 27-nov. Siguiente: Fase 1 en staging (política de root en `/etc/claude-code` y probar que Claude cierra su propia sesión `rc`). El push del global lo hace Carlos desde su Mac (`z4-global <servidor>`), nunca desde un servidor.
- **Alerta de disco** (`z4-alerta-disco.sh`, umbral por defecto 75 %, primer argumento `${1:-75}`): funciona en staging (prueba cerrada el 26-nov) y en prod (cerrada el 27-nov). Archivos: credencial en `/etc/z4/alertas-smtp.conf`, cron en `/etc/cron.d/z4-alerta-disco`, log en `/var/log/z4-alerta-disco.log`, estado en `/var/lib/z4-alerta-disco`.
  - **Prod:** con umbral 1 en el cron avisó a las 22:00, 04:15, 10:30 y 16:45 (26-27-nov) y llegaron todos los correos. Desde el 27-nov el cron lleva `z4-alerta-disco.sh 50` (umbral 50 %, decisión de Carlos: disco estable al 38 %, `/dev/md3` de 878G). Script con sha256 `e7ac253d…` igual que staging. Anotado (sugerencias) en la documentación de uso, la ficha de PR y z4stack → Historial.
  - Si el disco baja del umbral, el script borra solo el estado (no hace falta `rm`). Solo escribe en el log cuando avisa o falla.
  - Siguiente: fase 2 (valorar healthchecks.io) y fase 3 (Telegram).
  - Documentación de uso: https://docs.google.com/document/d/1-QoYI1P1aXvNQfysgoWO1KSW3AVZL59vaMI9WypbHY4. Registro en z4stack → Historial.
- **Avisos de backups y certificados** (en prod desde el 26-nov; commits `2fdaddf` y `9baadf4`).
  - Queda comprobar el siguiente backup con el `do-backup.sh` nuevo (lo mira Carlos el 27-nov): `grep -cF -- '-p***'` > 0, `grep -cE -- '-u root -p[^*]|pass:[^*]'` en 0 y dump nuevo en Drive.
  - Queda que llegue el keepalive automático del **1-dic a las 03:00**.
  - Para deshacer: `git reset --keep b46e931` + `docker restart certs`. Lo que queda sin arreglar está en el historial.
- En prod, `git status` muestra `D config/redis/Dockerfile` y `D config/redis/redis.conf` (borrados sin commit). Sin investigar.
- Decidir si se rotan las credenciales de correo que hay en git (`z4stackweb`): `send-email.sh`, `check-certs.sh`, `scripts/check-disk-space.sh` (master) y `deploy/z4-wp-init.sh:151`. Afecta a todos los servidores del stack.
- Decidir si se cambian la contraseña root de MySQL de prod y la de cifrado de los dumps (salieron en el chat del 26-nov). Si se cambia la de cifrado, hay que guardar la anterior para abrir los dumps antiguos.
- Decidir si se borran `/z4/web.backup-eliminarmastarde` y `/z4/web.backup2` (16G cada una).
- Redis: reproducir el fallo en staging (pide OK: `wp` que escribe). Faltan dos datos: qué bloque o página salía sin actualizar, y si las noticias eran programadas o manuales.
- Protocolo (como sugerencias): comprobar `df` antes de la copia inicial y añadir un paso para lo excluido antes de borrar la original.
- Bots (SQLi en `?amp=`, paginación profunda) → bloquear en Cloudflare. `user_hit_count` (ManageWP) y `_eael_post_view_count` escriben en cada visita.

### `z4-evidencias.sh` y `z4-drive.sh`
- v11 (cambios 1–20 y A–G) probada en las dos fases y con commit. Para comparar, el técnico pasa los tar a una IA con `/z4/web/maintenance/prompt-comparacion-ia.md`.
- `z4-drive.sh` está probado (19 de 19). Documentación: https://claude.ai/artifact/WAAYDQeK1ysT5PMCmDMCMU.
- Las decisiones del 18-nov (Chromium con `apk`, credenciales de Drive en git, los `.bak*` se dejan) y la lista de mejoras (no hacerlas sin que se pidan) están en el historial.
- Pendiente de decisión: H (que el script se relance solo con `sudo` si no es root) y quitar los cambios 2, 5, 6 y 10. Los cambios 21-23 están aprobados para después del mantenimiento (memoria).
- Pendiente: borrar de Drive lo subido en las pruebas de `z4-drive.sh` y `rm -rf /tmp/z4p`; revisar si `akuario` necesita el grupo `docker`.
