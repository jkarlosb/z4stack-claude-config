---
name: documentos-solo-como-comentarista
description: "En documentos del usuario (Google Docs, Claude Docs u otros a los que dé acceso) proponer cambios solo como comentarios o sugerencias, nunca editar directamente"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 72ff6900-95e2-4e07-bac9-bc163ce49eaf
  modified: 2026-11-21T16:49:41.550Z
---

En cualquier documento al que el usuario me dé acceso (Google Docs, el protocolo de mantenimiento, Claude Docs, etc.), los cambios se proponen siempre como comentarista: comentarios o sugerencias que él acepta, nunca como edición directa.

**Why:** lo pidió explícitamente el 21-nov-2026 al pasarme el protocolo de mantenimiento en Google Docs ("hazlo siempre, en cualquier docu que te dé acceso en el futuro y en este, como comentarista, nunca como editor"). Quiere revisar y aceptar cada cambio él mismo.

**How to apply:** en Claude Docs usar `"suggest": true` en las operaciones; en Google Docs, `update_doc` con `writeControl.writeMode: "SUGGEST"` (el conector de Google Docs no puede crear comentarios, solo leerlos). Los conectores de Google de claude.ai solo aparecen en sesiones arrancadas después de activarlos (`/mcp` no los recarga). Solo editar directamente si lo pide expresamente para un cambio concreto. Ver también [[tabla-cambios-una-fila-por-archivo]].
