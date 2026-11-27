---
name: historial-estado-z4
description: "Historial detallado del proyecto /z4 (17-nov a 26-nov-2026) y tabla de cambios 1-20 y A-G de z4-evidencias.sh; leer cuando la tarea toque Elementor/binlogs, alerta de disco, avisos de correo o z4-evidencias"
metadata:
  node_type: memory
  type: project
  originSessionId: 006565e6-8887-50b9-b578-f3afa0daca0d
  modified: 2026-11-27T16:18:11.710Z
---

Movido tal cual desde /z4/CLAUDE.md el 27-nov-2026 para que no se cargue en cada llamada. El estado vivo y los pendientes siguen en /z4/CLAUDE.md.

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
  - **Aplicado en prod el 24-nov:** filtro activo y opción borrada. **Comprobado a las 14:30:**
    - La opción no existe.
    - El último binlog (`binlog.000549`) crece ~1 MB/min; antes era ~1 GB/min.
    - Quedan 131 ficheros: la purga automática al rotar funciona, porque sin ella habría más de 200.
  - **Comprobado a las 17:01:** `binlog.000549` (desde las 14:28) va por 232 MB (~1,5 MB/min) y no ha vuelto a rotar. **Retención subida a 24 h** (`SET PERSIST binlog_expire_logs_seconds=86400`), unos 2,2 GB a este ritmo. Lo de Elementor queda cerrado; en cada mantenimiento hay que revisar los bugs (lo dice la ficha).
  - **Retención subida a 7 días** (24-nov, tras las 18:13; `SET PERSIST binlog_expire_logs_seconds=604800`). Ritmo medido de 14:28 a 18:13: ~1,4 MB/min (~2 GB/día, ~14 GB en 7 días). Los 131 ficheros (131G) de antes del arreglo se purgan solos al rotar, hacia el 1-2 dic.
  - Documentado como sugerencias en el historial (bajo «Carlos», 24-nov) y en la ficha técnica (Intervención → Harcodeos → Elementor Pro), que se revisa en cada mantenimiento; también la subida a 7 días.
- **Orden de las próximas tareas:** 1) en un chat nuevo, la alerta de disco; 2) Redis (noticias nuevas que no aparecen).
  - Para identificar opciones como esta: tamaño de los eventos `Update_rows` de `wp_options` + las opciones más grandes medidas dos veces, con 60 s entre una y otra.
- **Pendientes:**
  - **Red de seguridad contra el disco lleno** (en un chat nuevo, justo después de Elementor). Decidido: **alerta cuando `df /` pase del 75 %**, con datos de qué ocupa (`df` y las carpetas más grandes). Se prefiere a un tope de binlogs por cron (más de 150G → `PURGE BINARY LOGS TO`):
    - Hoy hubo dos causas distintas (`web.original` y los binlogs) y solo la alerta cubre las dos.
    - La alerta no borra nada ni esconde a quien escribe sin control.
    - La retención por tiempo ya pone límite a los binlogs.
    - Canal (decidido 24-nov), por fases; cada una solo después de comprobar que la anterior funciona:
      1. Correo a `tech@z4studios.com` desde `servidor@z4studios.es` (SMTP de OVH, `ssl0.ovh.net:587`), con `curl`; credencial en un archivo de root (600) fuera de git. Descartados: relay de Workspace por IP (si entran en el servidor, envían como @z4studios.com y pasa SPF/DMARC), cuenta de servicio con delegación, OAuth y entrega directa al MX.
      2. Explicar al detalle healthchecks.io (avisa también si el cron deja de ejecutarse) y valorarlo.
      3. Bot de Telegram.
    - Registro: documentación de z4stack → Historial (movido allí el 24-nov; el historial de PR lo enlaza).
    - **Staging, funciona (25-nov):** script `z4-alerta-disco.sh` en `/z4/web/scripts/` (commit `205551e`, rama `prnoticias.com`), credenciales en `/etc/z4/alertas-smtp.conf` y cron cada 15 min en `/etc/cron.d/z4-alerta-disco` (log en `/var/log/z4-alerta-disco.log`, estado en `/var/lib/z4-alerta-disco`).
      - Prueba real: relleno de 12 GiB (`fallocate`) en `/home/akuario/relleno-alerta-disco.bin` → 76 %. A las 21:30:34 el cron envió el aviso y **llegó a tech@ y a carlos@** (lo confirmó Carlos).
      - **Repetición comprobada (26-nov):** avisos a las 03:45:25, 10:00:25 y 16:15:24, cada ~6 h 15 min (`touch` tras el envío + cron en :00/:15/:30/:45; cada ejecución tarda ~25 s). **Llegaron los 4 correos** (lo confirmó Carlos).
      - **Limpieza comprobada:** relleno borrado a las 20:28:59; a las 20:30:03 el cron borró el estado y `df` volvió al 68 %. **Prueba de staging cerrada.** Siguiente: prod (abajo).
      - **Push:** `205551e` ya está subido (26-nov). Ojo: si se sincroniza `/z4/web` de prod a staging antes de que el script esté en prod, desaparece de staging y el cron falla en silencio (solo queda en el log).
      - **Prod (`hz492`), instalado el 26-nov:** el script entró con el `git pull` de los avisos de backups; credencial, prueba sin aviso, aviso forzado con umbral 1 (correo recibido) y cron cada 15 min. Documentado (sugerencias) en la documentación de uso y en el historial de z4stack.
      - **Prod, cerrado (27-nov):** con `z4-alerta-disco.sh 1` en el cron avisó a las 22:00, 04:15, 10:30 y 16:45 y llegaron todos los correos. A las 16:59 Carlos dejó el cron en `z4-alerta-disco.sh 50` (umbral 50 % en vez del 75 % por defecto: disco estable al 38 %, `/dev/md3` 878G, 316G usados, 518G libres). sha256 del script en prod = staging (`e7ac253d…`). El umbral se pasa como argumento (`UMBRAL=${1:-75}`); el script no se edita. Documentado (sugerencias, 27-nov) en la documentación de uso, la ficha de PR («A tener en cuenta») y z4stack → Historial (entrada del 24-nov).
        - `tune2fs` (27-nov): `Reserved block count: 11693260` en `/dev/md3` (= 44,6 GiB con bloques de 4K, el 5 %). `-m 1` no está aplicado; pendiente cerrado.
      - **Documentado (25-nov, como sugerencias):** documentación de uso en «Docu sobre funcionalidad alerta», https://docs.google.com/document/d/1-QoYI1P1aXvNQfysgoWO1KSW3AVZL59vaMI9WypbHY4 (qué hace, instalación, cron, parámetros, desinstalar, limitaciones, dónde está instalado: prod «pendiente»). En el historial de z4stack, la línea «Estado: falta…» pasa a ser el estado de staging, con enlaces a esa documentación y a gitweb. Al instalar en prod, actualizar los dos.
      - Enlace al script: `http://hz401.z4st.com:22923/?p=z4stackweb.git;a=blob;f=scripts/z4-alerta-disco.sh;hb=refs/heads/prnoticias.com` (gitweb pide usuario; desde aquí da 401). `resources.z4studios.com` y `hz401.z4st.com` son la misma IP.
      - En staging, `usados + disponibles ≈ tamaño` en `df`: parece que ext4 no tiene bloques reservados (deducido; se confirma con `sudo tune2fs -l /dev/sda1 | grep -i 'reserved block count'`).
    - MySQL 8.0 no tiene límite de tamaño total de binlog: `binlog_space_limit` es de Percona, `max_binlog_total_size` es de MariaDB, y el bug de MySQL #66733 sigue abierto. Comprobado en el manual de MySQL 8.0 el 24-nov.
  - **Avisos de backups y certificados (26-nov): en prod y probados.** La rama usaba `no-reply@` (535); `origin/master` pasó a `servidor@` en `d774ec2`.
    - Commits en `prnoticias.com`: `2fdaddf` (trae de `origin/master` `send-email.sh` y `check-certs.sh`; solo remitente y credencial) y `9baadf4` (`do-backup.sh` deja de escribir en `backups.log` la contraseña root de MySQL y la de cifrado: `send-email.sh` adjunta 1000 líneas de ese log a cada aviso). Subidos.
    - Prod (26-nov): log limpiado con `sed -i` (34 líneas con contraseñas → 0). Los backups funcionan: dump cada 4 h en Drive (`z4remote:prnoticias.com`), último del 26-nov 16:30 (~760 MB); 17 ejecuciones sin ERROR. Certificado válido hasta el 30-ene-2027.
    - **Prod, 19:56:** `git pull --ff-only` `b46e931..9baadf4` (entran también `205551e`, `z4-alerta-disco.sh`, inactivo sin cron ni credencial) + `docker restart certs`. Pruebas forzadas en los contenedores reales, las dos llegaron a tech@: keepalive (`docker exec backups bash -l …/send-email.sh --keepalive tech@…`, 19:58; log sin contraseñas, 34 enmascaradas) y `check-certs.sh` sobre una copia con `CHECK_DAYS=100` y asunto «PRUEBA (ignorar)» (19:59; 64 días, interna y externa coinciden). Para deshacer: `git reset --keep b46e931` + `docker restart certs`.
    - En prod, `git status` muestra `D config/redis/Dockerfile` y `D config/redis/redis.conf` (borrados sin commit, de antes). Sin investigar.
    - **Queda:** comprobar el siguiente backup con el `do-backup.sh` nuevo (`grep -cF -- '-p***'` > 0, el `grep -cE -- '-u root -p[^*]|pass:[^*]'` sigue en 0 y hay dump nuevo en Drive); Carlos lo mira el 27-nov. Keepalive automático del **1-dic a las 03:00** (el cron mensual de `backups`, igual que la prueba de las 19:58): que llegue.
    - Documentado como sugerencia en z4stack → Historial (entrada del 26-nov), enlazada desde el historial de PR (entrada del 26-nov, también como sugerencia).
    - Sin arreglar (solo si se pide): pasar los dos scripts a `curl` con la credencial en `/etc/z4/alertas-smtp.conf` (hay que reconstruir las imágenes, que no traen `curl`); la espera al montaje de Drive en `do-backup.sh` hace 1 reintento en vez de 10 (el contador empieza en 10); `check-certs.sh` no avisa si `certbot` falla o devuelve varios certificados; nada avisa si `backups` se cae (healthchecks.io lo cubriría).
  - Credenciales de correo en git (`z4stackweb`): `send-email.sh`, `check-certs.sh`, `scripts/check-disk-space.sh` (master) y `deploy/z4-wp-init.sh:151` (`admin@z4studios.es`, en claro). Decidir si se rotan; afecta a todos los servidores del stack.
  - La contraseña root de MySQL de prod y la de cifrado de los dumps del cliente estuvieron en `backups.log` y salieron en el chat del 26-nov. Decidir si se cambian; si se cambia la de cifrado, guardar la anterior para abrir los dumps antiguos.
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
