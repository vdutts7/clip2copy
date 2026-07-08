#!/bin/zsh
# regression: setup prompt must not leak prompt text into captured values
set -euo pipefail

ROOT="${0:A:h:h}"
CLIP="$ROOT/bin/clip2copy"
[[ -x "$CLIP" ]] || { echo "test-setup-prompt: run make build-fast first" >&2; exit 1 }

# fifo stands in for /dev/tty
fifo=$(mktemp -u "${TMPDIR:-/tmp}/clip2copy-tty.XXXXXX")
mkfifo "$fifo"
exec {TTY_FD}<>"$fifo"
rm -f "$fifo"
TTY="/dev/fd/$TTY_FD"

prompt() {
  local msg="$1" default="$2" reply=""
  if [[ -r $TTY && -w $TTY ]]; then
    printf '> %s [%s]: ' "$msg" "$default" >"$TTY"
    read -r reply <"$TTY" || true
  else
    printf '> %s [%s]: ' "$msg" "$default" >&2
    read -r reply || true
  fi
  if [[ "$reply" == '>'*': '* ]]; then
    reply="${reply##*: }"
  fi
  [[ -n "${reply// /}" ]] || reply="$default"
  REPLY="$reply"
}

printf 'cap\n' >&$TTY_FD
capture="$(prompt "Filename prefix" ss; print -r -- "$REPLY")"

[[ "$capture" == cap ]] || {
  echo "test-setup-prompt: FAIL capture=|$capture| (expected cap)" >&2
  exit 1
}

"$CLIP" config validate prefix "$capture" >/dev/null || {
  echo "test-setup-prompt: FAIL validate prefix '$capture'" >&2
  exit 1
}

exec {TTY_FD}>&-
echo "test-setup-prompt: ok"
