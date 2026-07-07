#!/bin/zsh
# clip2copy-watch - fswatch loop: detect screenshot PNGs, rename, copy to clipboard

FSWATCH="${CLIP2COPY_FSWATCH:-$(command -v fswatch)}"
CLIP="${CLIP2COPY_BIN:-$(command -v clip2copy)}"

[[ -x "$FSWATCH" ]] || { echo "clip2copy-watch: fswatch not found" >&2; exit 1; }
[[ -x "$CLIP" ]] || { echo "clip2copy-watch: clip2copy not found" >&2; exit 1; }

WATCH="$($CLIP config get location 2>/dev/null)"
RENAME="$($CLIP config get rename 2>/dev/null)"
PREFIX="$($CLIP config get prefix 2>/dev/null)"
WATCH="${WATCH:-$HOME/Downloads}"
RENAME="${RENAME:-1}"
PREFIX="${PREFIX:-ss}"

"$FSWATCH" "$WATCH" | while read -r f; do
  [[ "$f" == *Screenshot*.png ]] || continue
  [[ "$(basename "$f")" == .* ]] && continue

  prev=0
  cur=1
  while [[ "$prev" != "$cur" ]]; do
    prev=$cur
    sleep 0.1
    cur=$(/usr/bin/stat -f%z "$f" 2>/dev/null || echo 0)
  done

  if [[ "$RENAME" == "1" ]]; then
    newf="$WATCH/${PREFIX}-$(/usr/bin/openssl rand -hex 6).png"
    /bin/mv "$f" "$newf" || continue
    "$CLIP" "$newf"
  else
    "$CLIP" "$f"
  fi
done
