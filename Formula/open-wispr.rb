class OpenWispr < Formula
  desc "Push-to-talk voice dictation for macOS using Whisper"
  homepage "https://github.com/human37/open-wispr"
  url "https://github.com/human37/open-wispr.git", tag: "v0.9.1"
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
    keep_alive successful_exit: false
    log_path var/"log/open-wispr.log"
    error_log_path var/"log/open-wispr.log"
    process_type :interactive
  end

  def caveats
    <<~EOS
      Recommended: use the install script for guided setup:
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/human37/open-wispr/main/scripts/install.sh)"

      Or start manually:
        brew services start open-wispr

      Grant Accessibility and Microphone when prompted.
      The Whisper model downloads automatically (~142 MB).
    EOS
  end

  test do
    assert_match "open-wispr", shell_output("#{bin}/open-wispr --help")
  end
end
