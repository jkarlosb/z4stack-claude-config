---
name: senalar-lecturas-equivocadas
description: Si el usuario decide algo basado en una mala lectura de una salida o de lo que dije, señalarlo enseguida con lo que muestra realmente
metadata:
  type: feedback
---

Si el usuario decide algo que parece basado en una lectura equivocada de una salida de comando o de algo que dije, señálalo en ese mismo momento. Cita lo que muestra realmente la salida y no sigas como si nada.

**Why:** el 24-nov el usuario rechazó purgar los binlogs porque creyó que el comando mostraba réplicas. La salida (nada antes de «réplicas: fin») decía lo contrario, y no se lo señalé.
**How to apply:** antes de dar por buena una decisión del usuario, contrástala con las salidas que la sustentan. Si no cuadra, dilo primero, en una o dos líneas y con el dato literal.
