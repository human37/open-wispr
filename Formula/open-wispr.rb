class OpenWispr < Formula
  desc "Push-to-talk voice dictation for macOS using Whisper"
  homepage "https://github.com/human37/open-wispr"
  url "https://github.com/human37/open-wispr.git", tag: "v0.1.0"
  license "MIT"

  depends_on "whisper-cpp"
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/open-wispr"
  end

  def caveats
    <<~EOS
      open-wispr requires Accessibility permissions for global hotkey capture.
      Go to System Settings → Privacy & Security → Accessibility
      and add your terminal app or the open-wispr binary.

      Quick start:
        open-wispr download-model base.en
        open-wispr set-hotkey rightoption
        open-wispr start
    EOS
  end

  test do
    assert_match "open-wispr", shell_output("#{bin}/open-wispr --help")
  end
end
