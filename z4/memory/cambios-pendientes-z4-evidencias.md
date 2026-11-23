---
name: cambios-pendientes-z4-evidencias
description: Cambios 21, 22 y 23 de z4-evidencias.sh/screenshots.js aprobados para después del mantenimiento de prod del 23-nov-2026
metadata:
  type: project
---

Aprobados por el usuario el 23-nov-2026 para hacerlos **después** del mantenimiento de producción (no antes):

- **21** (z4-evidencias.sh): con `sudo`, `testweb/` y `screenshots/` pasan a ser de `SUDO_UID:SUDO_GID` (quien lanzó sudo), no de root, para que `git pull` no falle por permisos. Diff ya preparado en el scratchpad de la sesión 72ff6900 (`cambio21.diff`). Después, en prod: `sudo chown -R akuario:sudo /z4/web/maintenance`.
- **22** (screenshots.js): si falla el login del admin («Login sin confirmar: puede ser una pantalla 2FA»), guardar una captura de la pantalla que vio el navegador, para diagnosticar. En prod (23-nov) falló y no quedó evidencia.
- **23** (screenshots.js): subir el timeout de navegación (hoy 30 s, el de Puppeteer por defecto) a 60-90 s y/o usar `networkidle2` + la espera de imágenes existente. En prod (23-nov) dieron timeout categoria-comunicacion (desktop+tablet), categoria-marketing (desktop+tablet) y latam (desktop).

**Why:** el usuario pidió expresamente que no se olvidaran; hoy hizo esas capturas a mano.
**How to apply:** al acabar el mantenimiento, proponer cada uno con diff numerado y esperar el «sí» (regla 1 de /z4/CLAUDE.md); probar en staging, commit, y luego pull en prod. Documentarlos en [[doc-z4-evidencias-fuente-verdad]].
