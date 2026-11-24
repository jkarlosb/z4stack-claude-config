---
name: senalar-lecturas-equivocadas
description: "Si el usuario decide algo basado en una mala lectura de una salida o de lo que dije, señalarlo enseguida con lo que muestra realmente"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 72ff6900-95e2-4e07-bac9-bc163ce49eaf
  modified: 2026-11-24T12:40:05.141Z
---

Si el usuario decide algo que parece basado en una lectura equivocada de una salida de comando o de algo que dije, señálalo en ese mismo momento. Cita lo que muestra realmente la salida y no sigas como si nada.

**Why:** el 24-nov el usuario rechazó purgar los binlogs porque creyó que el comando mostraba réplicas. La salida (nada antes de «réplicas: fin») decía lo contrario, y no se lo señalé.
**How to apply:** antes de dar por buena una decisión del usuario, contrástala con las salidas que la sustentan. Si no cuadra, dilo primero, en una o dos líneas y con el dato literal.

**Lección relacionada (24-nov):** los cambios a CLAUDE.md o a la memoria se aplican editando el fichero actual (Edit), nunca copiando un borrador encima: puede haber otra sesión editándolo. Ese día una copia pisó la regla 9 que había añadido la sesión 822d1596.
