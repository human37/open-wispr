class OpenWispr < Formula
  desc "Push-to-talk voice dictation for macOS using Whisper"
  homepage "https://github.com/human37/open-wispr"
  url "https://github.com/human37/open-wispr.git", tag: "v0.2.0"
  license "MIT"

  depends_on "whisper-cpp"
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/open-wispr"
  end

  service do
    run [opt_bin/"open-wispr", "start"]
    keep_alive true
    log_path var/"log/open-wispr.log"
    error_log_path var/"log/open-wispr.log"
    process_type :interactive
  end

  def caveats
    <<~EOS
      open-wispr requires Accessibility permissions for global hotkey capture.
      Go to System Settings → Privacy & Security → Accessibility
      and add the open-wispr binary:
        #{opt_bin}/open-wispr

      Quick start:
        open-wispr download-model base.en
        open-wispr set-hotkey globe
        brew services start open-wispr

      Or run manually:
        open-wispr start
    EOS
  end

  test do
    assert_match "open-wispr", shell_output("#{bin}/open-wispr --help")
  end
end
