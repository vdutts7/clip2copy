#!/bin/zsh
# clip2copy-watch - fswatch loop: detect screenshot PNGs, rename, copy to clipboard
set -euo pipefail

FSWATCH="${CLIP2COPY_FSWATCH:-$(command -v fswatch)}"
CLIP="${CLIP2COPY_BIN:-$(command -v clip2copy)}"
POLL="${CLIP2COPY_POLL_SEC:-0.02}"       # was 0.1s — post-land clipboard delay
STABLE="${CLIP2COPY_STABLE_READS:-2}"  # consecutive identical size reads

[[ -x "$FSWATCH" ]] || { echo "clip2copy-watch: fswatch not found" >&2; exit 1; }
[[ -x "$CLIP" ]] || { echo "clip2copy-watch: clip2copy not found" >&2; exit 1; }

WATCH="$("$CLIP" config get location 2>/dev/null || true)"
RENAME="$("$CLIP" config get rename 2>/dev/null || true)"
PREFIX="$("$CLIP" config get prefix 2>/dev/null || true)"
WATCH="${WATCH:-$HOME/Downloads}"
RENAME="${RENAME:-1}"

# Wait until PNG write finished (size stable). Old loop slept 100ms/step with a
# forced dummy iteration (~200ms+ after file landed). Now 20ms polls, 2 stable reads (~40ms).
wait_file_stable() {
  local f="$1" last=-1 n=0 sz
  while (( n < STABLE )); do
    sz=$(/usr/bin/stat -f%z "$f" 2>/dev/null || echo 0)
    if [[ "$sz" -gt 0 && "$sz" == "$last" ]]; then
      (( n++ )) || true
    else
      n=0
      last=$sz
    fi
    (( n < STABLE )) && sleep "$POLL"
  done
}

# -l 0.01 --no-defer: lower FSEvents latency vs fswatch defaults (post-land detect)
"$FSWATCH" -l 0.01 --no-defer -0 "$WATCH" | while IFS= read -r -d '' f; do
  [[ "$f" == *Screenshot*.png ]] || continue
  [[ "$(basename "$f")" == .* ]] && continue

  wait_file_stable "$f"

  if [[ "$RENAME" == "1" ]]; then
    hex="$(/usr/bin/openssl rand -hex 6)"
    if [[ -n "$PREFIX" ]]; then
      newf="$WATCH/${PREFIX}-${hex}.png"
    else
      newf="$WATCH/${hex}.png"
    fi
    /bin/mv "$f" "$newf" || continue
    "$CLIP" "$newf"
  else
    "$CLIP" "$f"
  fi
done
