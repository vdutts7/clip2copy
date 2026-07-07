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

tui_error() {
  local msg="$1"
  local hint="${2:-try again or press Ctrl+C to cancel}"
  MSG="$msg" HINT="$hint" python3 - <<'PY' | tui
import json, os
print(json.dumps({"boxes": [{"title": "ERROR", "title_color": "red", "fields": [
    {"id": "error", "value": os.environ.get("MSG", "unknown error"), "role": "error"},
    {"id": "note", "label": "note", "value": os.environ.get("HINT", ""), "role": "note"},
]}]}))
PY
}

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

validate_or_error() {
  local key="$1" value="$2"
  local err
  if err="$($CLIP config validate "$key" "$value" 2>&1)"; then
    return 0
  fi
  tui_error "$err"
  return 1
}

MACOS_LOC="$($CLIP config get macos-location 2>/dev/null || echo "$HOME/Desktop")"
VERSION="$($CLIP --version 2>/dev/null | awk 'NR==1{print $2}')"
CONFIG_PATH="$($CLIP config get config-path 2>/dev/null || echo "$HOME/.config/clip2copy/config.json")"
EXISTING_LOC="$($CLIP config get location 2>/dev/null || true)"
EXISTING_PREFIX="$($CLIP config get prefix 2>/dev/null || echo ss)"

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
    {"prefix": "3) ", "label": "Custom path", "description": "validated + created"},
]}]}))
PY

CHOICE="$(prompt "Choice" "1")"
LOCATION=""
case "$CHOICE" in
  2) LOCATION="desktop" ;;
  3)
    while true; do
      LOCATION="$(prompt "Folder path" "${EXISTING_LOC:-$HOME/Downloads}")"
      [[ "${LOCATION:l}" == "back" ]] && {
        CHOICE="$(prompt "Choice" "1")"
        case "$CHOICE" in
          2) LOCATION="desktop"; break ;;
          *) LOCATION="downloads"; break ;;
        esac
        continue
      }
      validate_or_error location "$LOCATION" && break
    done
    ;;
  *) LOCATION="downloads" ;;
esac

export CLIP2COPY_QUIET=1
while true; do
  if "$CLIP" config set location "$LOCATION"; then
    break
  fi
  tui_error "failed to save location"
  if [[ "$CHOICE" != "3" ]]; then
    unset CLIP2COPY_QUIET
    exit 1
  fi
  LOCATION="$(prompt "Folder path (retry)" "${EXISTING_LOC:-$HOME/Downloads}")"
done

RENAME="off"
PREFIX="$EXISTING_PREFIX"
if prompt_yn "Rename screenshots" "y"; then
  RENAME="on"
  python3 - <<'PY' | tui
import json
print(json.dumps({"boxes": [{"type": "list", "title": "RENAME", "title_color": "cyan", "items": [
    {"prefix": "● ", "label": "prefix-random.png", "description": "e.g. ss-a1b2c3.png"},
    {"prefix": "● ", "label": "keep off", "description": "macOS Screenshot name"},
]}]}))
PY
  while true; do
    PREFIX="$(prompt "Filename prefix" "$EXISTING_PREFIX")"
    validate_or_error prefix "$PREFIX" && break
  done
fi

"$CLIP" config set rename "$RENAME"
[[ "$RENAME" == "on" ]] && "$CLIP" config set prefix "$PREFIX"
prompt_yn "Drop window shadow" "y" && SHADOW="on" || SHADOW="off"
"$CLIP" config set shadow "$SHADOW"
unset CLIP2COPY_QUIET

FINAL_LOC="$($CLIP config get location)"
RENAME_L="$($CLIP config get rename)"
PREFIX_L="$($CLIP config get prefix)"
SHADOW_L="$($CLIP config get shadow)"

export FINAL_LOC RENAME_L PREFIX_L SHADOW_L CONFIG_PATH

python3 - <<'PY' | tui
import json, os
rename_on = os.environ.get("RENAME_L") == "1"
prefix = os.environ.get("PREFIX_L", "ss")
rename_val = f"on ({prefix}-<hex>.png)" if rename_on else "off"
fields = [
    {"id": "location", "value": os.environ.get("FINAL_LOC", "")},
    {"id": "rename", "value": rename_val},
    {"id": "shadow", "value": "on" if os.environ.get("SHADOW_L") == "1" else "off"},
    {"id": "config", "value": os.environ.get("CONFIG_PATH", ""), "role": "output"},
    {"id": "status", "level": "ok", "message": "run: brew services restart clip2copy"},
]
print(json.dumps({"boxes": [{"title": "CONFIGURED", "title_color": "green", "fields": fields}]}))
PY
