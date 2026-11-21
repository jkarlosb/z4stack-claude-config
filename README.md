# Claude Code: configuración y respaldo

Configuración de Claude Code y copia de lo que no se puede perder si el servidor se formatea.
Servidor de origen: staging z4 (`vps-2b7b2b65.vps.ovh.net`, usuario `akuario`, SSH en el puerto 22400).

| En el repo | Original en el servidor | Qué es |
|---|---|---|
| `global/CLAUDE.md` | `~/.claude/CLAUDE.md` | Instrucciones personales para todos los proyectos |
| `global/settings.json` | `~/.claude/settings.json` | Ajustes de Claude Code, como `cleanupPeriodDays` |
| `z4/CLAUDE.md` | `/z4/CLAUDE.md` | Instrucciones del proyecto z4. Está fuera de git a propósito, para que no lo borre la sincronización de prod a staging |
| `z4/memory/` | `~/.claude/projects/-z4/memory/` | Memoria automática del proyecto `/z4` |

**Las conversaciones no van en este repo.** Están en texto plano y contienen secretos (como mínimo, la clave de PageSpeed). Si quieres guardar alguna, expórtala (apartado 3).

`~/.claude/.credentials.json` (el token de sesión de Claude) **no se copia nunca** a ningún sitio.

---

## 1. Que las conversaciones no caduquen

Claude Code guarda cada conversación en `~/.claude/projects/<proyecto>/<ID>.jsonl` y, **por defecto, la borra a los 30 días sin avisar**.
La opción `cleanupPeriodDays` cambia ese plazo. No admite "nunca": el mínimo es 1 y el 0 da error. Por eso se pone 36500 días (100 años).
La memoria (`projects/<proyecto>/memory/`) no se borra nunca, con o sin este ajuste.

Fuentes: https://code.claude.com/docs/en/settings-reference y https://code.claude.com/docs/en/claude-directory

Para aplicarlo en cualquier servidor (necesita `jq`; crea una copia de seguridad antes de tocar nada):

```bash
f=~/.claude/settings.json
mkdir -p ~/.claude
[ -f "$f" ] || echo '{}' > "$f"
cp -p "$f" "$f-bck-$(date +%Y%m%d)"
jq '.cleanupPeriodDays = 36500' "$f" > "$f.tmp" && cat "$f.tmp" > "$f" && rm "$f.tmp"
jq . "$f"
```

Las conversaciones crecen sin límite, así que conviene vigilar el espacio y borrar a mano lo que sobre:

```bash
du -sh ~/.claude/projects/*                    # espacio por proyecto
ID=<id-de-la-conversacion>
rm -i ~/.claude/projects/-z4/"$ID".jsonl       # la conversación
rm -ri ~/.claude/projects/-z4/"$ID"            # sus subagentes y resultados, si la carpeta existe
```

Para deshacer el ajuste: `cp -p ~/.claude/settings.json-bck-AAAAMMDD ~/.claude/settings.json`

---

## 2. Guardar los CLAUDE.md y la memoria en git

Las copias son manuales: después de cambiar un CLAUDE.md o la memoria, ejecuta el bloque "Actualizar el repo".

### Actualizar el repo (en el servidor)

```bash
R=~/claude-config
mkdir -p "$R/global" "$R/z4/memory"
cp -p ~/.claude/CLAUDE.md ~/.claude/settings.json "$R/global/"
cp -p /z4/CLAUDE.md "$R/z4/"
rsync -a --delete ~/.claude/projects/-z4/memory/ "$R/z4/memory/"
git -C "$R" status --short
git -C "$R" add global z4
git -C "$R" commit -m "chore: actualiza configuración de Claude Code"
git -C "$R" push
```

### Restaurar en un servidor nuevo

```bash
R=~/claude-config
git clone <URL-del-repo> "$R"
mkdir -p ~/.claude/projects/-z4/memory
cp -p "$R/global/CLAUDE.md" "$R/global/settings.json" ~/.claude/
cp -p "$R/z4/CLAUDE.md" /z4/
rsync -a "$R/z4/memory/" ~/.claude/projects/-z4/memory/
```

El nombre de la carpeta del proyecto sale de su ruta, cambiando `/` por `-`: `/z4` → `-z4`. Si el proyecto está en otra ruta, la carpeta de la memoria también cambia.

---

## 3. Exportar una conversación concreta

Sirve para protegerla de un borrado accidental o para poder leerla con el servidor apagado.

### Buscar el ID (en el servidor)

Lista las conversaciones de `/z4`, de la más reciente a la más antigua, con fecha, tamaño y el primer mensaje:

```bash
# shellcheck disable=SC2045  # los nombres son IDs sin espacios; ls -t ordena por fecha
cd ~/.claude/projects/-z4 && for f in $(ls -t ./*.jsonl); do
  printf '%s  %s  %5s  ' "$(basename "$f" .jsonl)" "$(date -r "$f" '+%F %R')" "$(du -h "$f" | cut -f1)"
  jq -r 'select(.type=="user" and (.isMeta|not)) | .message.content
    | if type=="string" then . else (map(select(.type=="text").text)|join(" ")) end
    | select(length>0 and (startswith("<")|not) and (startswith("[Image")|not)
             and (startswith("This session is being continued")|not))' "$f" 2>/dev/null \
    | head -1 | tr '\n' ' ' | cut -c1-60
  echo
done
```

Cada conversación es `<ID>.jsonl`. Si usó subagentes o guardó resultados largos, además tiene una carpeta `<ID>/`. Exporta las dos.

### Opción A: descargarla a tu ordenador con scp

Desde tu ordenador, no desde el servidor:

```bash
ID=<id-de-la-conversacion>
scp -P 22400 akuario@149.202.42.203:".claude/projects/-z4/$ID.jsonl" .
scp -P 22400 -r akuario@149.202.42.203:".claude/projects/-z4/$ID" .   # solo si existe la carpeta
```

### Opción B: subirla a Google Drive con z4-drive.sh

En el servidor. **No la subas a la unidad compartida «Mantenimientos»**, que es la opción por defecto: la conversación lleva secretos. Usa una carpeta privada compartida con la cuenta de servicio del servidor y pasa su ID con `-c`:

```bash
ID=<id-de-la-conversacion>
CARPETA=<id-de-carpeta-privada-de-drive>   # la última parte de https://drive.google.com/drive/folders/ID
P=~/.claude/projects/-z4
QUE=("$P/$ID.jsonl"); [ -d "$P/$ID" ] && QUE+=("$P/$ID")
sudo /z4/web/maintenance/z4-drive.sh --tar -n "chat-$ID" -c "$CARPETA" "${QUE[@]}"
```

Se sube como `chat-<ID>.tar.gz`. El script enseña lo que va a hacer y pide confirmación. Ayuda: `/z4/web/maintenance/z4-drive.sh --help`.

### Volver a abrir una conversación exportada

*(Deducido, sin probar.)* Copia `<ID>.jsonl`, y su carpeta si la tiene, a `~/.claude/projects/-z4/` y ejecuta `claude --resume` desde `/z4`.
