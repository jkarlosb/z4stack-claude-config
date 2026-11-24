---
name: formato-google-docs
description: "Al escribir en Google Docs, un párrafo vacío entre párrafos y entre puntos, y sangría en las listas que cuelgan de un título"
metadata:
  node_type: memory
  type: feedback
  originSessionId: b2408fc6-4ec0-59b5-b7e3-e5cdfdd5b1a3
  modified: 2026-11-24T20:43:53.336Z
---

En Google Docs (historial, ficha, z4stack): deja un párrafo vacío después de cada párrafo y de cada punto de una lista. Las listas que cuelgan de una línea de título («Qué hemos decidido:») van con sangría (indentStart e indentFirstLine de 36 pt). Una lista nueva nunca empieza pegada al último punto de la anterior.
**Why:** el 24-nov el usuario tuvo que dar formato a mano a la entrada de la alerta de disco porque no se entendía; sobre todo, la segunda lista empezaba pegada al punto 7 de la primera.
**How to apply:** separa con `\n\n` en `insertText` y aplica la sangría con `updateParagraphStyle`. Comprueba el resultado con `read_doc` antes de dar el trabajo por terminado. Ver [[documentos-solo-como-comentarista]].
