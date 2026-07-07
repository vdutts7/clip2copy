#!/bin/zsh
# clip2copy-setup — z7z-style TUI wizard
set -euo pipefail

CLIP="${CLIP2COPY_BIN:-$(command -v clip2copy)}"
[[ -x "$CLIP" ]] || { echo "clip2copy-setup: clip2copy not found" >&2; exit 1; }

DIR="${0:A:h}"
TUI_PY="${CLIP2COPY_TUI_PY:-$DIR/tui_render.py}"
[[ -f "$TUI_PY" ]] || TUI_PY="${DIR:h}/Scripts/tui_render.py"
[[ -f "$TUI_PY" ]] || { echo "clip2copy-setup: tui_render.py not found" >&2; exit 1; }

tui() { python3 "$TUI_PY" render; }

prompt() {
  local msg="$1" default="$2"
  if [[ -t 1 ]]; then
    print -n $'\033[2m\033[3m> '"${msg}"$' \033[1;96m['"${default}"$']\033[0m\033[2m: \033[0m'
  else
    printf '> %s [%s]: ' "$msg" "$default"
  fi
  read -r _reply
  [[ -n "${_reply// /}" ]] && print -r -- "$_reply" || print -r -- "$default"
}

prompt_yn() {
  local msg="$1" default="$2" hint
  [[ "$default" == "y" ]] && hint="Y/n" || hint="y/N"
  local ans
  ans="$(prompt "$msg ($hint)" "$default")"
  [[ "$ans" == [yY]* ]] && return 0
  [[ "$ans" == [nN]* ]] && return 1
  [[ "$default" == "y" ]]
}

MACOS_LOC="$($CLIP config get macos-location 2>/dev/null || echo "$HOME/Desktop")"
VERSION="$($CLIP --version 2>/dev/null | awk 'NR==1{print $2}')"
CONFIG_PATH="$($CLIP config get config-path 2>/dev/null || echo "$HOME/.config/clip2copy/config.json")"
EXISTING_LOC="$($CLIP config get location 2>/dev/null || true)"

export VERSION MACOS_LOC

python3 - <<'PY' | tui
import json, os
print(json.dumps({"boxes": [{"title": "CLIP2COPY SETUP", "title_color": "cyan", "fields": [
    {"id": "version", "label": "version", "value": os.environ.get("VERSION", "")},
    {"id": "macos", "label": "macos saves", "value": os.environ.get("MACOS_LOC", "")},
    {"id": "note", "label": "note", "value": "clip2copy overrides screenshot save location", "role": "note"},
]}]}))
PY

python3 - <<'PY' | tui
import json
print(json.dumps({"boxes": [{"type": "list", "title": "SAVE LOCATION", "title_color": "cyan", "items": [
    {"prefix": "1) ", "label": "Downloads", "description": "recommended"},
    {"prefix": "2) ", "label": "Desktop", "description": "macOS factory default"},
    {"prefix": "3) ", "label": "Custom path", "description": "any folder"},
]}]}))
PY

CHOICE="$(prompt "Choice" "1")"
LOCATION=""
case "$CHOICE" in
  2) LOCATION="desktop" ;;
  3) LOCATION="$(prompt "Folder path" "${EXISTING_LOC:-$HOME/Downloads}")" ;;
  *) LOCATION="downloads" ;;
esac

RENAME="on"
SHADOW="on"
prompt_yn "Rename to ss-random.png" "y" && RENAME="on" || RENAME="off"
prompt_yn "Drop window shadow" "y" && SHADOW="on" || SHADOW="off"

export CLIP2COPY_QUIET=1
"$CLIP" config set location "$LOCATION"
"$CLIP" config set rename "$RENAME"
"$CLIP" config set shadow "$SHADOW"
unset CLIP2COPY_QUIET

FINAL_LOC="$($CLIP config get location)"
RENAME_L="$($CLIP config get rename)"
SHADOW_L="$($CLIP config get shadow)"

export FINAL_LOC RENAME_L SHADOW_L CONFIG_PATH

python3 - <<'PY' | tui
import json, os
fields = [
    {"id": "location", "value": os.environ.get("FINAL_LOC", "")},
    {"id": "rename", "value": "on" if os.environ.get("RENAME_L") == "1" else "off"},
    {"id": "shadow", "value": "on" if os.environ.get("SHADOW_L") == "1" else "off"},
    {"id": "config", "value": os.environ.get("CONFIG_PATH", ""), "role": "output"},
    {"id": "status", "level": "ok", "message": "run: brew services restart clip2copy"},
]
print(json.dumps({"boxes": [{"title": "CONFIGURED", "title_color": "green", "fields": fields}]}))
PY
