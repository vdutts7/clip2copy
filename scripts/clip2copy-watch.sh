#!/bin/zsh
# clip2copy-watch - fswatch loop: detect screenshot PNGs, rename, copy to clipboard
# Paths are injected by Homebrew formula at install time, or set via env for manual use.

FSWATCH="${CLIP2COPY_FSWATCH:-$(command -v fswatch)}"
CLIP="${CLIP2COPY_BIN:-clip2copy}"
WATCH="${CLIP2COPY_DIR:-$HOME/Downloads}"
RENAME="${CLIP2COPY_RENAME:-1}"

[[ -x "$FSWATCH" ]] || { echo "clip2copy-watch: fswatch not found" >&2; exit 1; }
[[ -x "$CLIP" ]] || CLIP="$(command -v clip2copy)"
[[ -x "$CLIP" ]] || { echo "clip2copy-watch: clip2copy binary not found" >&2; exit 1; }

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
    newf="$WATCH/ss-$(/usr/bin/openssl rand -hex 6).png"
    /bin/mv "$f" "$newf" || continue
    "$CLIP" "$newf"
  else
    "$CLIP" "$f"
  fi
done
