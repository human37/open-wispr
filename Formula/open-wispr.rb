class OpenWispr < Formula
  desc "Push-to-talk voice dictation for macOS using Whisper"
  homepage "https://github.com/human37/open-wispr"
  url "https://github.com/human37/open-wispr.git", tag: "v0.7.0"
  license "MIT"

  depends_on "whisper-cpp"
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    system "bash", "scripts/bundle-app.sh", ".build/release/open-wispr", "OpenWispr.app", version.to_s
    bin.install ".build/release/open-wispr"
    prefix.install "OpenWispr.app"
  end

  def post_install
    target = Pathname.new("#{Dir.home}/Applications/OpenWispr.app")
    target.dirname.mkpath
    ln_sf prefix/"OpenWispr.app", target
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
      Run it:
        brew services start open-wispr

      On first launch, macOS will prompt for Accessibility and Microphone.
      Grant both, then restart:
        brew services restart open-wispr

      The Whisper model downloads automatically on first use.
    EOS
  end

  test do
    assert_match "open-wispr", shell_output("#{bin}/open-wispr --help")
  end
end
