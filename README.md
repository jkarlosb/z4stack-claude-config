# Claude Code: configuración y respaldo

Configuración de Claude Code de los servidores de Z4 Studios y copia de lo que no se puede perder si un servidor se formatea.

## Servidores

| Nombre clave | Qué es | Acceso | Proyectos (carpeta en el repo → ruta) |
|---|---|---|---|
| `staging-hz499` | Staging de prnoticias.com | `vps-2b7b2b65.vps.ovh.net`, usuario `akuario`, SSH en el puerto 22400 | `z4` → `/z4` |
| `foros-hz470` | Foros phpBB (producción) | *(pendiente)* | `docker` → `/home/docker` |

## Qué hay en el repo

| En el repo | Original en el servidor | Qué es |
|---|---|---|
| `global/CLAUDE.md` | `~/.claude/CLAUDE.md` | Instrucciones personales, **comunes a todos los servidores** |
| `global/settings.json` | `~/.claude/settings.json` | Ajustes de Claude Code, como `cleanupPeriodDays`, comunes a todos |
| `<servidor>/proyectos.txt` | | Proyectos del servidor: una línea `<carpeta> <ruta>` por proyecto |
| `<servidor>/<carpeta>/CLAUDE.md` | `<ruta>/CLAUDE.md` | Instrucciones del proyecto. En staging, `/z4/CLAUDE.md` está fuera de git a propósito, para que no lo borre la sincronización de prod a staging |
| `<servidor>/<carpeta>/memory/` | `~/.claude/projects/<ruta con / → ->/memory/` | Memoria automática del proyecto (`/z4` → `-z4`) |
| `sync.sh` | | Sincroniza el servidor con el repo (apartado 2) |
| `NUEVO-SERVIDOR.md` | | Primeras instrucciones para el Claude de un servidor nuevo |
| `.servidor` | | Nombre clave de este servidor. Es local: no está en git |

**Las conversaciones no van en este repo.** Están en texto plano y contienen secretos (como mínimo, la clave de PageSpeed). Si quieres guardar alguna, expórtala (apartado 3).

`~/.claude/.credentials.json` (el token de sesión de Claude) **no se copia nunca** a ningún sitio.

**Seguridad:** cada servidor tiene una deploy key con escritura en el repo entero, así que puede leer y cambiar también lo de los demás servidores. Por eso aquí no van secretos, y conviene leer el diff de `sync.sh` antes de aceptar cambios en `global/`.

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

## 2. Sincronizar con `sync.sh`

```bash
~/claude-config/sync.sh                               # enseña qué cambiaría (solo hace git pull)
~/claude-config/sync.sh --si "docs: qué ha cambiado"  # aplica, commit y push
```

Qué hace:

- **`global/`** (común): fusiona a tres bandas (`git merge-file`) la versión de este servidor, la del repo y la de la última sincronización, guardada en `.git/z4-base/`. Así, si dos servidores cambian partes distintas, los dos cambios se conservan. Si cambian la misma línea, avisa de conflicto, enseña el diff y no toca nada. Se resuelve a mano: se edita `~/.claude/CLAUDE.md` y se vuelve a ejecutar.
- **`<servidor>/`** (solo de este servidor): copia el CLAUDE.md y la memoria de cada proyecto de `proyectos.txt` al repo. Si en el servidor faltan (servidor reinstalado), los restaura desde el repo.
- Antes de empezar, `git pull --rebase`. Si el push se rechaza porque otro servidor subió algo entretanto, otra vez `pull --rebase` y push.
- Se niega a empezar si el repo tiene cambios sin commit.

La primera vez en un servidor que ya tenía `~/.claude/CLAUDE.md` o `settings.json` distintos de los del repo no hay versión común con la que fusionar: enseña el diff y se para. Elige una versión, cópiala encima de la otra y vuelve a ejecutarlo.

### Acceso a GitHub (deploy key)

El repo es `git@github.com:jkarlosb/z4stack-claude-config.git` (privado). Cada servidor sube los cambios con su propia *deploy key*: una clave SSH que solo da acceso a este repo, así que no hace falta guardar en el servidor la cuenta personal de GitHub. GitHub no deja usar la misma deploy key en dos repos ni en dos servidores.
La clave está en `~/.ssh-deploy/` y no en `~/.ssh/`, porque en staging `~/.ssh` es de `root`. En GitHub (Settings → Deploy keys), la de staging se llama `pr-staging`. Se revoca borrándola de ahí.

Para crearla en un servidor nuevo:

```bash
D=~/.ssh-deploy
mkdir -m 700 "$D"
ssh-keygen -q -t ed25519 -f "$D/z4stack-claude-config" -N "" -C "$(hostname) deploy key z4stack-claude-config"
ssh-keyscan -t ed25519 github.com 2>/dev/null > "$D/known_hosts"
ssh-keygen -lf "$D/known_hosts"   # debe salir SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU
cat "$D/z4stack-claude-config.pub"
```

Comprueba la huella en https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints.
Después añade la clave pública en https://github.com/jkarlosb/z4stack-claude-config/settings/keys, con el nombre clave del servidor y la opción **Allow write access** marcada.

---

## 3. Exportar una conversación concreta

Sirve para protegerla de un borrado accidental o para poder leerla con el servidor apagado.

### Buscar el ID (en el servidor)

Lista las conversaciones de `/z4` (en otro proyecto, cambia `-z4` por su carpeta), de la más reciente a la más antigua, con fecha, tamaño y el primer mensaje:

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

---

## 4. Añadir un servidor nuevo (o reinstalar uno)

Todo como el usuario que va a usar Claude, no como root. Sustituye los valores de la primera línea.

```bash
S=foros-hz470; CARPETA=docker; PROYECTO=/home/docker

# 1. Dependencias
sudo apt install -y git tmux rsync curl

# 2. Claude Code (instalador oficial, canal estable). Queda en ~/.local/bin/claude
curl -fsSL https://claude.ai/install.sh | bash -s stable
export PATH="$HOME/.local/bin:$PATH"   # en los siguientes inicios de sesión lo pone ~/.profile
claude --version && claude doctor

# 3. Login con la cuenta de claude.ai. Remote Control no funciona con API key ni con setup-token.
#    Por SSH: copia la URL que muestra, ábrela en tu navegador y pega el código.
claude auth login
```

4. Deploy key: apartado 2, «Acceso a GitHub». Añádela en GitHub antes de seguir.

```bash
# 5. Clonar y registrar el servidor
R=~/claude-config
SSHCMD="ssh -i ~/.ssh-deploy/z4stack-claude-config -o IdentitiesOnly=yes -o UserKnownHostsFile=~/.ssh-deploy/known_hosts"
GIT_SSH_COMMAND="$SSHCMD" git clone git@github.com:jkarlosb/z4stack-claude-config.git "$R"
git -C "$R" config core.sshCommand "$SSHCMD"
echo "$S" > "$R/.servidor"
mkdir -p "$R/$S"
[ -f "$R/$S/proyectos.txt" ] || echo "$CARPETA $PROYECTO" > "$R/$S/proyectos.txt"

# 6. Instalar el CLAUDE.md global y settings.json (y, si el servidor se reinstala, restaurar sus proyectos)
"$R/sync.sh"
"$R/sync.sh" --si "chore($S): alta del servidor"

# 7. Confiar en la carpeta del proyecto (pregunta «Trust …?» → sí) y activar Remote Control
#    («Enable Remote Control?» → y). Sal de cada uno con Ctrl-C o /exit.
cd "$PROYECTO" && claude
cd "$PROYECTO" && claude remote-control --remote-control-session-name-prefix "$S"

# 8. Remote Control como servicio: arranca con el servidor y se reinicia si se cae
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/claude-rc.service <<UNIT
[Unit]
Description=Claude Code Remote Control ($PROYECTO)

[Service]
Type=forking
WorkingDirectory=$PROYECTO
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/tmux -L claude-rc new-session -d -s rc -c $PROYECTO %h/.local/bin/claude remote-control --remote-control-session-name-prefix $S
ExecStop=/usr/bin/tmux -L claude-rc kill-server
Restart=always
RestartSec=30

[Install]
WantedBy=default.target
UNIT
sudo loginctl enable-linger "$USER"     # que los servicios del usuario corran sin sesión abierta
systemctl --user daemon-reload
systemctl --user enable --now claude-rc
systemctl --user status claude-rc --no-pager
```

9. Abre `claude.ai/code`, entra en el servidor nuevo y escribe como primer mensaje:
   «Lee `~/claude-config/NUEVO-SERVIDOR.md` y sigue sus pasos.»

Notas:

- **No uses como proyecto el directorio home del usuario:** Remote Control no guarda la confianza en el home, y sin ella el servicio falla con `Workspace not trusted` (documentación de Remote Control).
- Para ver la consola de Remote Control: `tmux -L claude-rc attach -t rc` (sal con `Ctrl-b d`). Para pararlo: `systemctl --user stop claude-rc`. Para quitarlo: `systemctl --user disable --now claude-rc && rm ~/.config/systemd/user/claude-rc.service`.
- Fuentes: https://code.claude.com/docs/en/setup, https://code.claude.com/docs/en/authentication y https://code.claude.com/docs/en/remote-control
