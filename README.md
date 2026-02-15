# open-wispr

Local, private voice dictation for macOS. Hold a key, speak, release — your words appear at the cursor. Everything runs on-device. No audio or text ever leaves your machine.

Powered by [whisper.cpp](https://github.com/ggml-org/whisper.cpp) with Metal acceleration on Apple Silicon.

## Install

```bash
brew tap human37/open-wispr
brew install open-wispr
brew services start open-wispr
```

On first launch:
1. Grant **Microphone** access when prompted
2. Enable **OpenWispr** in **System Settings → Privacy & Security → Accessibility**
3. The Whisper model downloads automatically (~142 MB, one time only)

A waveform icon appears in your menu bar when it's running.

The default hotkey is the **Globe key** (🌐, bottom-left). Hold it, speak, release.

## Uninstall

```bash
brew services stop open-wispr
brew uninstall open-wispr
brew untap human37/open-wispr
rm -rf ~/.config/open-wispr ~/Applications/OpenWispr.app
```

## Configuration

### Hotkey

```bash
open-wispr set-hotkey globe          # Globe/fn key (default)
open-wispr set-hotkey rightoption    # Right Option key
open-wispr set-hotkey f5             # F5 key
open-wispr set-hotkey ctrl+space     # Ctrl + Space
brew services restart open-wispr     # Restart to apply
```

If the Globe key opens the emoji picker: **System Settings → Keyboard → "Press 🌐 key to" → "Do Nothing"**

### Model

```bash
open-wispr set-model tiny.en        # 75 MB, fastest
open-wispr set-model base.en        # 142 MB, fast (default)
open-wispr set-model small.en       # 466 MB, more accurate
open-wispr set-model medium.en      # 1.5 GB, slow
brew services restart open-wispr    # Restart to apply
```

### Language

Edit `~/.config/open-wispr/config.json` and set `language` to an [ISO 639-1 code](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes) (`es`, `fr`, `de`, `ja`, etc). Use a non-`.en` model for multilingual support.

## Menu bar

| State | Icon |
|---|---|
| Idle | Waveform outline |
| Recording | Animated waveform (bars dance) |
| Transcribing | Bouncing dots |
| Downloading model | Animated download arrow |

## Privacy

open-wispr is completely local. Audio is recorded to a temp file, transcribed by whisper.cpp on your CPU/GPU, and the temp file is deleted. No network requests are made except to download the Whisper model on first run.

## Build from source

```bash
git clone https://github.com/human37/open-wispr.git
cd open-wispr
brew install whisper-cpp
swift build -c release
.build/release/open-wispr start
```

## License

MIT
