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

WATCH="$("$CLIP" config get location 2>/dev/null || true)"
RENAME="$("$CLIP" config get rename 2>/dev/null || true)"
PREFIX="$("$CLIP" config get prefix 2>/dev/null || true)"
WATCH="${WATCH:-$HOME/Downloads}"
RENAME="${RENAME:-1}"

"$FSWATCH" "$WATCH" | while read -r f; do
  [[ "$f" == *Screenshot*.png ]] || continue
  [[ "$(basename "$f")" == .* ]] && continue

  prev=0
  cur=1
  while [[ "$prev" != "$cur" ]]; do
    prev=$cur
    sleep 0.1
    cur=$(/usr/bin/stat -f%z "$f" 2>/dev/null || print -r -- 0)
  done

  if [[ "$RENAME" == "1" ]]; then
    hex="$(/usr/bin/openssl rand -hex 6)"
    if [[ -n "$PREFIX" ]]; then
      newf="$WATCH/${PREFIX}-${hex}.png"
    else
      newf="$WATCH/${hex}.png"
    fi
    /bin/mv "$f" "$newf" || continue
    "$CLIP" "$newf" || true
  else
    "$CLIP" "$f" || true
  fi
done
