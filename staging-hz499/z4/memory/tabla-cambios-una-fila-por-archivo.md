---
name: tabla-cambios-una-fila-por-archivo
description: "En la tabla final de cambios en archivos, una fila por cada archivo, nunca agrupar por carpeta o por commit"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 72ff6900-95e2-4e07-bac9-bc163ce49eaf
  modified: 2026-11-20T12:29:59.005Z
---

En la tabla «Archivo/carpeta | Acción | Qué y por qué» del final de cada respuesta, cada archivo creado, modificado, borrado, renombrado o movido lleva su propia fila. No vale una fila para una carpeta con varios archivos dentro, ni una fila "commit X" que resuma varios archivos.

**Why:** el usuario lo corrigió el 20-nov-2026 tras una tabla con una fila "/z4/web (commit 92a71c4)" que escondía 6 archivos; quiere ver exactamente qué archivo cambió.

**How to apply:** desglosar siempre archivo por archivo (incluidos los de un commit). Una carpeta solo tiene fila propia si la propia carpeta se crea/borra/mueve; en ese caso, además, una fila por cada archivo de dentro.
