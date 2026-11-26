---
name: rewind-claude-code-servidor
description: Dónde funciona el rewind de Claude Code en el servidor z4 (comprobado 24-nov-2026)
metadata:
  node_type: memory
  type: reference
  originSessionId: 0becd449-03eb-4a44-8e2d-92f90455b330
  modified: 2026-11-24T16:39:51.505Z
---

- Web/móvil (Remote Control): NO hay rewind en ninguna sesión. Las creadas desde la app (`claude remote-control`, modo `--print`) ni guardan checkpoints; las de `claude --rc` en tmux sí, pero la web responde «Esta sesión no admite la función de retroceso» (probado 24-nov).
- Alternativa en la web: Fork desde un mensaje anterior (solo conversación, no deshace archivos).
- Rewind de código: VS Code (botón al pasar el ratón) o terminal (`Esc Esc` / `/rewind`). No deshace cambios hechos con Bash.
- Las sesiones tmux que lanza Claude van al socket `claude-rc`: `tmux -L claude-rc attach -t <nombre>`.
