---
name: cambios-pendientes-z4-evidencias
description: Cambios 21, 22, 23 y otros de z4-evidencias.sh/screenshots.js aprobados para después del mantenimiento de prod del 23-nov-2026
metadata:
  type: project
---

Aprobados por el usuario el 23-nov-2026 para hacerlos **después** del mantenimiento de producción (no antes):

- **21** (z4-evidencias.sh): con `sudo`, `testweb/` y `screenshots/` pasan a ser de `SUDO_UID:SUDO_GID` (quien lanzó sudo), no de root, para que `git pull` no falle por permisos. Diff ya preparado en el scratchpad de la sesión 72ff6900 (`cambio21.diff`). Después, en prod: `sudo chown -R akuario:sudo /z4/web/maintenance`.
- **22** (screenshots.js): si falla el login del admin («Login sin confirmar: puede ser una pantalla 2FA»), guardar una captura de la pantalla que vio el navegador, para diagnosticar. En prod (23-nov) falló y no quedó evidencia.
- **23** (screenshots.js): subir el timeout de navegación (hoy 30 s, el de Puppeteer por defecto) a 60-90 s y/o usar `networkidle2` + la espera de imágenes existente. En prod (23-nov) dieron timeout categoria-comunicacion (desktop+tablet), categoria-marketing (desktop+tablet) y latam (desktop).

- **rsync_z4web permanente** (z4-functions.sh, propuesto 23-nov, pendiente de OK): añadir la función a `maintenance/z4-functions.sh`, que `/etc/bash.bashrc` carga en cada shell interactiva (en staging, línea duplicada 74-75; en prod NO se carga: comprobado 23-nov, hay que añadir la línea con guarda `[ -r … ] && source …`). Motivo: en prod la función se definió el día anterior y al día siguiente no existía; se pararon los contenedores y falló el rsync. Diff en el scratchpad de la sesión 72ff6900 (`z4-functions.diff`). Después, cambiar en el protocolo el bloque de la función de «Copia inicial» por «comprueba con `type rsync_z4web`» y mantener la guarda de la pasada final.
- **Protocolo, paso de Git**: sugerir `git fetch` + `git log HEAD..@{u}` + `sudo git merge --ff-only @{u}`.
- **Parada lenta**: `server`, `certs`, `cron` y `backups` ignoran SIGTERM (`sh start.sh` como PID 1); raíz: `exec` en sus scripts de arranque. Ya está sugerido en el protocolo el `kill` de esos 4 antes del `stop -t 120`.

- **Mantenimiento PR 23-nov, revisar después** (la web funciona, comprobado por el usuario):
  - `wp plugin update --all`: los 33 plugins se actualizaron, pero al final dio un fatal de FluentSMTP (`BulkSendSessionHandler` not found) al enviar WSAL su email de aviso: código viejo en memoria y nuevo en disco. Ese email no salió. Comprobar «Send Test Email» de FluentSMTP.
  - Por el `set -e` de `is_z4staging`, el fatal cortó el resto del bloque (restart web, transients, cache flush, rm cache, plugin list): confirmar que se ejecutó después.
  - `duplicate-post` y `wordpress-seo` piden WP 7.0: actualizarlos tras el core.
  - Tras las actualizaciones de `redis-cache` 3.0.1 y `w3-total-cache`, confirmar `wp redis status` → Drop-in: Valid. W3TC sigue instalado: valorar quitarlo.
  - `is_z4staging` deja `set -e` activo en la shell que la llama: arreglarlo (p. ej. `local -` o sin `set -e`).
  - Historial de staging (doc 1uD6BcJF…, apartado Redis): la ruta `/z4/web/config/object-cache.php` está mal; es `/z4/web/httpdocs/wp-content/object-cache.php`.
  - En prod hizo falta `sudo chmod -R g+w /z4/maints/` para que `z4log` pudiera escribir.

**Why:** el usuario pidió expresamente que no se olvidaran; hoy hizo esas capturas a mano.
**How to apply:** al acabar el mantenimiento, proponer cada uno con diff numerado y esperar el «sí» (regla 1 de /z4/CLAUDE.md); probar en staging, commit, y luego pull en prod. Documentarlos en [[doc-z4-evidencias-fuente-verdad]].
