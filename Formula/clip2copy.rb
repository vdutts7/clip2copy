class Clip2copy < Formula
  desc "Auto-copy macOS screenshots to clipboard when saved"
  homepage "https://github.com/vdutts7/clip2copy"
  url "https://github.com/vdutts7/clip2copy.git", tag: "v1.0.0"
  license "MIT"
  head "https://github.com/vdutts7/clip2copy.git", branch: "main"

  depends_on :macos
  depends_on "fswatch"

  def install
    system "make", "build-fast"
    bin.install "bin/clip2copy"

    (libexec/"clip2copy-watch").write <<~SCRIPT
      #!/bin/zsh
      FSWATCH="#{Formula["fswatch"].opt_bin}/fswatch"
      CLIP="#{bin}/clip2copy"
      WATCH="${CLIP2COPY_DIR:-$HOME/Downloads}"
      RENAME="${CLIP2COPY_RENAME:-1}"

      "$FSWATCH" "$WATCH" | while read -r f; do
        [[ "$f" == *Screenshot*.png ]] || continue
        [[ "$(basename "$f")" == .* ]] && continue
        prev=0; cur=1
        while [[ "$prev" != "$cur" ]]; do
          prev=$cur; sleep 0.1
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
      Start the watcher at login:
        brew services start clip2copy

      Optional — save screenshots to Downloads (no shadow):
        defaults write com.apple.screencapture location "$HOME/Downloads"
        defaults write com.apple.screencapture disable-shadow -bool true
        killall SystemUIServer 2>/dev/null || true

      Config (env vars for the service):
        CLIP2COPY_DIR    watch directory (default: ~/Downloads)
        CLIP2COPY_RENAME set to 0 to keep macOS screenshot filenames
    EOS
  end

  test do
    assert_match "clip2copy", shell_output("#{bin}/clip2copy --version")
  end
end
