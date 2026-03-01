<p align="center">
  <img src="logo.svg" width="80" alt="open-wispr logo">
</p>

<h1 align="center">open-wispr</h1>

<p align="center">
  <strong><a href="https://open-wispr.com">open-wispr.com</a></strong><br>
  Local, private voice dictation for macOS. Hold a key, speak, release — your words appear at the cursor.<br>
  Everything runs on-device. No audio or text ever leaves your machine.
</p>

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
  "language": "en",
  "spokenPunctuation": false
}
```

Then restart: `brew services restart open-wispr`

| Option | Default | Values |
|---|---|---|
| **hotkey** | `63` | Globe (`63`), Right Option (`61`), F5 (`96`), or any key code |
| **modifiers** | `[]` | `"cmd"`, `"ctrl"`, `"shift"`, `"opt"` — combine for chords |
| **modelSize** | `"base.en"` | `tiny.en` · `base.en` · `small.en` · `medium.en` (English-only) or `tiny` · `base` · `small` · `medium` (multilingual) |
| **language** | `"en"` | Any [ISO 639-1 code](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes) — e.g. `it`, `fr`, `de`, `es` |
| **spokenPunctuation** | `false` | Say "comma", "period", etc. to insert punctuation instead of auto-punctuation |

> **Non-English languages:** Models ending in `.en` are English-only. To use another language, switch to the equivalent model without the `.en` suffix (e.g. `base.en` → `base`) and set the `language` field to your language code.

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

## Support

open-wispr is free and always will be. If you find it useful, you can [leave a tip](https://buy.stripe.com/4gM5kC2AU0Ssd4l6Hqd7q00).

## License

MIT
