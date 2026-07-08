class Clip2copy < Formula
  desc "Auto-copy macOS screenshots to clipboard when saved"
  homepage "https://github.com/vdutts7/clip2copy"
  url "https://github.com/vdutts7/clip2copy.git", tag: "v1.3.4"
  license "MIT"
  head "https://github.com/vdutts7/clip2copy.git", branch: "main"

  depends_on :macos
  depends_on "fswatch"

  def install
    system "make", "build-fast"
    bin.install "bin/clip2copy"

    rm_f libexec/"clip2copy-watch"
    libexec.install "scripts/clip2copy-watch.sh" => "clip2copy-watch"
    chmod 0755, libexec/"clip2copy-watch"
    # launchd PATH is empty — bake brew paths at install time
    inreplace libexec/"clip2copy-watch",
              'FSWATCH="${CLIP2COPY_FSWATCH:-$(command -v fswatch 2>/dev/null)}"',
              "FSWATCH=\"${CLIP2COPY_FSWATCH:-#{Formula["fswatch"].opt_bin}/fswatch}\""
    inreplace libexec/"clip2copy-watch",
              'CLIP="${CLIP2COPY_BIN:-$(command -v clip2copy 2>/dev/null)}"',
              "CLIP=\"${CLIP2COPY_BIN:-#{bin}/clip2copy}\""
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
    assert_predicate bin/"clip2copy", :exist?
    assert_predicate libexec/"clip2copy-watch", :exist?
  end
end
