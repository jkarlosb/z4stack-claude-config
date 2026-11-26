#!/usr/bin/env bash
# Sincroniza la configuración de Claude Code de este servidor con el repo claude-config.
#   sync.sh                   enseña qué cambiaría (solo hace git pull en el repo)
#   sync.sh --si ["mensaje"]  aplica los cambios, hace commit y push
# global/ es común a todos los servidores: se fusiona a 3 bandas (git merge-file) con
# la versión de la última sincronización, guardada en .git/z4-base/.
# <servidor>/ solo lo escribe este servidor: se copia de aquí al repo, salvo si falta
# aquí (servidor reinstalado), que se restaura desde el repo.
set -euo pipefail

SI=0
MENSAJE=""
case "${1:-}" in
  "") ;;
  --si) SI=1; MENSAJE=${2:-} ;;
  *) echo "Uso: $0 [--si [\"mensaje del commit\"]]" >&2; exit 2 ;;
esac

R=$(cd "$(dirname "$0")" && pwd)
cd "$R"
S=$(cat .servidor 2>/dev/null) || { echo "Falta $R/.servidor (nombre clave del servidor)" >&2; exit 1; }
[ -f "$S/proyectos.txt" ] || { echo "Falta $R/$S/proyectos.txt" >&2; exit 1; }
MENSAJE=${MENSAJE:-"chore($S): actualiza configuración de Claude Code"}
BASE=.git/z4-base
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ -n "$(git status --porcelain)" ]; then
  echo "El repo tiene cambios sin commit; revísalos antes:" >&2
  git status --short >&2
  exit 1
fi
git pull -q --rebase

CAMBIOS_LOCALES=0
# Deja en $1 (archivo del servidor) el contenido de $2. En modo prueba solo enseña el diff.
a_local() {
  if cmp -s "$1" "$2"; then return 0; fi
  CAMBIOS_LOCALES=1
  echo "== Cambia en el servidor: $1"
  diff -uN "$1" "$2" || true
  if [ "$SI" = 1 ]; then
    mkdir -p "$(dirname "$1")"
    cp "$2" "$1"
  fi
}

mkdir -p "$TMP/global"
for f in CLAUDE.md settings.json; do
  l=~/.claude/$f
  r=global/$f
  m=$TMP/global/$f
  if [ ! -f "$l" ] || cmp -s "$l" "$r"; then
    cp "$r" "$m"
  elif [ -f "$BASE/$f" ]; then
    if ! git merge-file -p -L servidor -L base -L repo "$l" "$BASE/$f" "$r" > "$m"; then
      echo "Conflicto en $f: lo han cambiado este servidor y otro a la vez. Diff repo → servidor:" >&2
      diff -u "$r" "$l" >&2 || true
      exit 1
    fi
  else
    echo "$f es distinto aquí y en el repo, y no hay sincronización anterior con la que fusionar." >&2
    echo "Diff repo → servidor:" >&2
    diff -u "$r" "$l" >&2 || true
    echo "Decide qué versión vale y copia una encima de la otra antes de seguir." >&2
    exit 1
  fi
  a_local "$l" "$m"
  cp "$m" "$r"
done

while read -r carpeta ruta; do
  case "$carpeta" in ''|'#'*) continue ;; esac
  d=$S/$carpeta
  mem=~/.claude/projects/$(printf '%s' "$ruta" | sed 's/[^a-zA-Z0-9]/-/g')/memory
  mkdir -p "$d/memory"
  if [ -f "$ruta/CLAUDE.md" ]; then
    cp -p "$ruta/CLAUDE.md" "$d/CLAUDE.md"
  elif [ -f "$d/CLAUDE.md" ]; then
    a_local "$ruta/CLAUDE.md" "$d/CLAUDE.md"
  fi
  if [ -n "$(ls -A "$mem" 2>/dev/null)" ]; then
    rsync -a --delete "$mem/" "$d/memory/"
  elif [ -n "$(ls -A "$d/memory")" ]; then
    CAMBIOS_LOCALES=1
    echo "== Se restaura la memoria en $mem"
    if [ "$SI" = 1 ]; then
      mkdir -p "$mem"
      rsync -a "$d/memory/" "$mem/"
    fi
  fi
done < "$S/proyectos.txt"

git add -A global "$S"
if git diff --cached --quiet; then
  echo "== Repo: sin cambios"
else
  echo "== Cambios en el repo:"
  git diff --cached --stat
  git diff --cached
fi

if [ "$SI" = 0 ]; then
  git reset -q
  git checkout -q -- .
  git clean -fdq -- global "$S"
  [ "$CAMBIOS_LOCALES" = 0 ] && echo "== Servidor: sin cambios"
  echo "Modo prueba: no se ha tocado nada. Para aplicarlo: $0 --si [\"mensaje\"]"
  exit 0
fi

mkdir -p "$BASE"
cp global/CLAUDE.md global/settings.json "$BASE/"
if ! git diff --cached --quiet; then
  git commit -q -m "$MENSAJE"
fi
git push -q || { git pull -q --rebase && git push -q; }
echo "Hecho: $(git log -1 --format='%h %s')"
