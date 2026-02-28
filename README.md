# open-wispr

**[open-wispr.com](https://open-wispr.com)**

Local, private voice dictation for macOS. Hold a key, speak, release — your words appear at the cursor. Everything runs on-device. No audio or text ever leaves your machine.

Powered by [whisper.cpp](https://github.com/ggml-org/whisper.cpp) with Metal acceleration on Apple Silicon.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/human37/open-wispr/main/scripts/install.sh | bash
```

The script handles everything: installs via Homebrew, walks you through granting permissions, downloads the Whisper model, and starts the service. You'll see live feedback as each step completes.

A waveform icon appears in your menu bar when it's running.

The default hotkey is the **Globe key** (🌐, bottom-left). Hold it, speak, release.

> **[Full installation guide](docs/install-guide.md)** — permissions walkthrough with screenshots, non-English macOS instructions, and troubleshooting.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/human37/open-wispr/main/scripts/uninstall.sh | bash
```

This stops the service, removes the formula, tap, config, models, app bundle, logs, and permissions.

## Configuration

Edit `~/.config/open-wispr/config.json`:

```json
{
  "hotkey": { "keyCode": 63, "modifiers": [] },
  "modelSize": "base.en",
  "language": "en"
}
```

Then restart: `brew services restart open-wispr`

| Option | Default | Values |
|---|---|---|
| **hotkey** | `63` | Globe (`63`), Right Option (`61`), F5 (`96`), or any key code |
| **modifiers** | `[]` | `"cmd"`, `"ctrl"`, `"shift"`, `"opt"` — combine for chords |
| **modelSize** | `"base.en"` | `tiny.en` · `base.en` · `small.en` · `medium.en` (English-only) or `tiny` · `base` · `small` · `medium` (multilingual) |
| **language** | `"en"` | Any [ISO 639-1 code](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes) — e.g. `it`, `fr`, `de`, `es`. Requires a multilingual model (without `.en` suffix). |

If the Globe key opens the emoji picker: **System Settings → Keyboard → "Press 🌐 key to" → "Do Nothing"**

## Menu bar

| State | Icon |
|---|---|
| Idle | Waveform outline |
| Recording | Bouncing waveform |
| Transcribing | Wave dots |
| Downloading model | Animated download arrow |
| Waiting for permission | Lock |

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
