class OpenWispr < Formula
  desc "Push-to-talk voice dictation for macOS using Whisper"
  homepage "https://github.com/human37/open-wispr"
  url "https://github.com/human37/open-wispr.git", tag: "v0.3.0"
  license "MIT"

  depends_on "whisper-cpp"
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/open-wispr"
    system "bash", "scripts/bundle-app.sh", ".build/release/open-wispr", "OpenWispr.app", version.to_s
    prefix.install "OpenWispr.app"
  end

  def post_install
    ln_sf prefix/"OpenWispr.app", "/Applications/OpenWispr.app"
  end

  service do
    run [opt_prefix/"OpenWispr.app/Contents/MacOS/open-wispr", "start"]
    keep_alive true
    log_path var/"log/open-wispr.log"
    error_log_path var/"log/open-wispr.log"
    process_type :interactive
  end

  def caveats
    <<~EOS
      OpenWispr.app has been linked to /Applications.
      On first run, macOS will prompt for Accessibility and Microphone permissions.
      Grant both, then restart the service.

      Quick start:
        open-wispr download-model base.en
        open-wispr set-hotkey globe
        brew services start open-wispr
    EOS
  end

  test do
    assert_match "open-wispr", shell_output("#{bin}/open-wispr --help")
  end
end
