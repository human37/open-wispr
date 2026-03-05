<p align="center">
  <img src="logo.svg" width="80" alt="open-wispr logo">
</p>

<h1 align="center">open-wispr</h1>

<p align="center">
  <strong><a href="https://open-wispr.com">open-wispr.com</a></strong><br>
  Local, private voice dictation for macOS. Hold a key, speak, release — your words appear at the cursor.<br>
  Everything runs on-device. No audio or text ever leaves your machine.
</p>

<p align="center">Powered by <a href="https://github.com/ggml-org/whisper.cpp">whisper.cpp</a> with Metal acceleration on Apple Silicon.</p>

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
  "spokenPunctuation": false,
  "maxRecordings": 10
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
| **maxRecordings** | `10` | Number of recent recordings to keep for reprocessing from the tray menu. Set to `0` for original privacy behavior: temp file, deleted immediately after transcription. Use 1–100 to enable the Recent Recordings feature. |

> **Non-English languages:** Models ending in `.en` are English-only. To use another language, switch to the equivalent model without the `.en` suffix (e.g. `base.en` → `base`) and set the `language` field to your language code.

> **Modifier-only hotkeys:** Left and right modifier keys are matched by physical key. If you set `61` (`rightoption`), left Option (`58`) will not trigger it.

> **Invalid config handling:** If `config.json` contains invalid JSON or unsupported values, open-wispr uses defaults for that run and prints a warning, but does not overwrite your file.

If the Globe key opens the emoji picker: **System Settings → Keyboard → "Press 🌐 key to" → "Do Nothing"**

## Menu bar

Click the waveform icon for status and options. **Recent Recordings** lists your last recordings; click one to re-transcribe and copy the result to the clipboard.

| State | Icon |
|---|---|
| Idle | Waveform outline |
| Recording | Bouncing waveform |
| Transcribing | Wave dots |
| Downloading model | Animated download arrow |
| Waiting for permission | Lock |

## Compare

| | open-wispr | VoiceInk | Wispr Flow | Superwhisper | Apple Dictation |
|---|---|---|---|---|---|
| **Price** | **Free** | $39.99 | $10/mo | $249 | Free |
| **Open source** | MIT | GPLv3 | No | No | No |
| **100% on-device** | Yes | Yes | No | Yes | Partial |
| **Push-to-talk** | Yes | Yes | Yes | Yes | No |
| **AI features** | No | AI assistant | AI rewriting | AI formatting | No |
| **Account required** | No | No | Yes | Yes | Apple ID |

## Privacy

open-wispr is completely local. Set `maxRecordings` to `0` for the original behavior: audio is recorded to a temp file, transcribed by whisper.cpp on your CPU/GPU, and the file is deleted immediately. With `maxRecordings` > 0 (default 10), recordings are stored in `~/.config/open-wispr/recordings/` for reprocessing from the tray menu; old recordings are pruned automatically. No network requests are made except to download the Whisper model on first run. Uninstall removes all recordings.

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
