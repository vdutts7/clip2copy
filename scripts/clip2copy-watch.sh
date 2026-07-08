#!/usr/bin/env zsh
# clip2copy-watch — fswatch loop: detect screenshot PNGs, rename, copy to clipboard

FSWATCH="${CLIP2COPY_FSWATCH:-$(command -v fswatch 2>/dev/null)}"
CLIP="${CLIP2COPY_BIN:-$(command -v clip2copy 2>/dev/null)}"

# launchd has no PATH — fall back to common Homebrew locations
if [[ -z "$FSWATCH" || ! -x "$FSWATCH" ]]; then
  for _p in /opt/homebrew/bin/fswatch /usr/local/bin/fswatch; do
    [[ -x "$_p" ]] && FSWATCH="$_p" && break
  done
fi
if [[ -z "$CLIP" || ! -x "$CLIP" ]]; then
  for _p in /opt/homebrew/bin/clip2copy /usr/local/bin/clip2copy; do
    [[ -x "$_p" ]] && CLIP="$_p" && break
  done
fi

[[ -x "$FSWATCH" ]] || { print -u2 "clip2copy-watch: fswatch not found"; exit 1 }
[[ -x "$CLIP" ]] || { print -u2 "clip2copy-watch: clip2copy not found"; exit 1 }

CONFIG_PATH="$("$CLIP" config get config-path 2>/dev/null || true)"
if [[ -f "$CONFIG_PATH" ]]; then
  WATCH="$("$CLIP" config get location 2>/dev/null || true)"
else
  WATCH="$("$CLIP" config get macos-location 2>/dev/null || true)"
fi
RENAME="$("$CLIP" config get rename 2>/dev/null || true)"
PREFIX="$("$CLIP" config get prefix 2>/dev/null || true)"
WATCH="${WATCH:-$HOME/Desktop}"
RENAME="${RENAME:-1}"

[[ -d "$WATCH" ]] || { print -u2 "clip2copy-watch: watch dir missing: $WATCH"; exit 1 }
print -u2 "clip2copy-watch: watching $WATCH rename=$RENAME prefix=${PREFIX:-none}"

# fswatch often emits regular space; macOS screenshot names use U+202F before AM/PM
resolve_screenshot_path() {
  local f="$1"
  [[ -f "$f" ]] && { print -r -- "$f"; return 0 }

  local alt="$f"
  alt="${alt// PM/$'\u202f'PM}"
  alt="${alt// AM/$'\u202f'AM}"
  [[ -f "$alt" ]] && { print -r -- "$alt"; return 0 }

  return 1
}

screenshot_like() {
  local base="$(basename "$1")"
  [[ "$base" == *.png ]] || return 1
  [[ "$base" == Screenshot* || "$base" == "Screen Shot"* ]] || return 1
  [[ "$base" == .* ]] && return 1
  return 0
}

"$FSWATCH" "$WATCH" | while read -r f; do
  screenshot_like "$f" || continue
  f="$(resolve_screenshot_path "$f")" || continue

  prev=0
  cur=1
  while [[ "$prev" != "$cur" ]]; do
    prev=$cur
    sleep 0.1
    cur=$(/usr/bin/stat -f%z "$f" 2>/dev/null || print -r -- 0)
  done
  [[ -f "$f" ]] || continue

  dir="${f:h}"
  if [[ "$RENAME" == "1" ]]; then
    hex="$(/usr/bin/openssl rand -hex 6)"
    if [[ -n "$PREFIX" ]]; then
      newf="$dir/${PREFIX}-${hex}.png"
    else
      newf="$dir/${hex}.png"
    fi
    /bin/mv -- "$f" "$newf" || {
      print -u2 "clip2copy-watch: rename failed $f"
      continue
    }
    if "$CLIP" "$newf"; then
      print -u2 "clip2copy-watch: copied $newf"
    else
      print -u2 "clip2copy-watch: copy failed $newf"
    fi
  else
    if "$CLIP" "$f"; then
      print -u2 "clip2copy-watch: copied $f"
    else
      print -u2 "clip2copy-watch: copy failed $f"
    fi
  fi
done
