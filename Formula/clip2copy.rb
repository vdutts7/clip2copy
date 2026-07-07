class Clip2copy < Formula
  desc "Auto-copy macOS screenshots to clipboard when saved"
  homepage "https://github.com/vdutts7/clip2copy"
  url "https://github.com/vdutts7/clip2copy.git", tag: "v1.2.2"
  license "MIT"
  head "https://github.com/vdutts7/clip2copy.git", branch: "main"

  depends_on :macos
  depends_on "fswatch"

  def install
    system "make", "build-fast"
    bin.install "bin/clip2copy"
    libexec.install "scripts/tui_render.py"
    libexec.install "scripts/clip2copy-setup.sh"
    chmod 0755, libexec/"clip2copy-setup.sh"
    chmod 0755, libexec/"tui_render.py"

    (libexec/"clip2copy-watch").write <<~SCRIPT
      #!/bin/zsh
      FSWATCH="#{Formula["fswatch"].opt_bin}/fswatch"
      CLIP="#{bin}/clip2copy"
      [[ -x "$FSWATCH" ]] || { echo "fswatch not found" >&2; exit 1; }
      [[ -x "$CLIP" ]] || { echo "clip2copy not found" >&2; exit 1; }
      WATCH="$($CLIP config get location 2>/dev/null)"
      RENAME="$($CLIP config get rename 2>/dev/null)"
      PREFIX="$($CLIP config get prefix 2>/dev/null)"
      WATCH="${WATCH:-$HOME/Downloads}"
      RENAME="${RENAME:-1}"
      PREFIX="${PREFIX:-ss}"
      "$FSWATCH" "$WATCH" | while read -r f; do
        [[ "$f" == *Screenshot*.png ]] || continue
        [[ "$(basename "$f")" == .* ]] && continue
        prev=0; cur=1
        while [[ "$prev" != "$cur" ]]; do
          prev=$cur; sleep 0.1
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
    SCRIPT
    chmod 0755, libexec/"clip2copy-watch"
  end

  service do
    run [opt_libexec/"clip2copy-watch"]
    keep_alive true
    log_path var/"log/clip2copy.log"
    error_log_path var/"log/clip2copy.err"
  end

  def caveats
    <<~EOS
      Run the setup wizard (sets screenshot save location + clip2copy config):
        clip2copy setup

      Start / restart the watcher:
        brew services start clip2copy
        brew services restart clip2copy   # after config changes

      CLI config anytime:
        clip2copy config show
        clip2copy config set location downloads
        clip2copy config set location desktop
        clip2copy config set location ~/Pictures/Screenshots
        clip2copy config set rename off
        clip2copy config set prefix ss
        clip2copy config set shadow on
        clip2copy config validate location ~/Desktop

      macOS factory default (when unset): ~/Desktop
    EOS
  end

  test do
    assert_match "clip2copy", shell_output("#{bin}/clip2copy --version")
    assert_predicate libexec/"clip2copy-setup.sh", :exist?
    assert_predicate libexec/"tui_render.py", :exist?
    assert_predicate bin/"clip2copy", :exist?
  end
end
