# open-wispr

Push-to-talk voice dictation for macOS. Hold a key, speak, release — your words appear at the cursor.

Runs locally using [whisper.cpp](https://github.com/ggml-org/whisper.cpp) with Metal acceleration on Apple Silicon. No data leaves your machine.

## Install

```bash
brew tap human37/open-wispr
brew install open-wispr
brew services start open-wispr
```

On first launch, macOS prompts for **Microphone** and **Accessibility** — grant both, then restart:

```bash
brew services restart open-wispr
```

A microphone icon appears in your menu bar. Hold the **Globe key**, speak, release. Done.

## Configuration

All config lives in `~/.config/open-wispr/config.json` and is created automatically on first run.

### Hotkey

The default hotkey is the **Globe key** (bottom-left on Mac keyboards).

```bash
open-wispr set-hotkey globe          # Globe/fn key (default)
open-wispr set-hotkey rightoption    # Right Option key
open-wispr set-hotkey f5             # F5 key
open-wispr set-hotkey ctrl+space     # Ctrl + Space
open-wispr set-hotkey cmd+shift+d    # Cmd + Shift + D
brew services restart open-wispr     # Restart to apply
```

If your Globe key opens the emoji picker instead, disable that first:
**System Settings → Keyboard → "Press 🌐 key to" → "Do Nothing"**

### Model

The default model is `base.en` (~142 MB). It downloads automatically on first use.

```bash
open-wispr set-model small.en       # More accurate, slower
open-wispr set-model tiny.en        # Less accurate, faster
brew services restart open-wispr     # Restart to apply
```

| Model | Size | Speed |
|---|---|---|
| `tiny.en` | 75 MB | Fastest |
| `base.en` | 142 MB | Fast (default) |
| `small.en` | 466 MB | Moderate |
| `medium.en` | 1.5 GB | Slow |
| `large` | 2.9 GB | Slowest |

### Language

Edit `~/.config/open-wispr/config.json` directly to change the language:

```json
{
  "hotkey": { "keyCode": 63, "modifiers": [] },
  "modelSize": "base.en",
  "language": "en"
}
```

Use a non-`.en` model (e.g. `base`, `small`) for multilingual support, and set `language` to the [ISO 639-1 code](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes) (e.g. `es`, `fr`, `de`, `ja`).

## Menu bar

When running, a microphone icon sits in the menu bar:
- **Idle** — mic icon
- **Recording** — animated pulsing mic
- **Transcribing** — spinner icon

Click for status info or to quit.

## Commands

| Command | Description |
|---|---|
| `open-wispr start` | Start the daemon (with menu bar icon) |
| `open-wispr set-hotkey <key>` | Set the push-to-talk hotkey |
| `open-wispr get-hotkey` | Show current hotkey |
| `open-wispr set-model <size>` | Set the Whisper model |
| `open-wispr download-model [size]` | Pre-download a model |
| `open-wispr status` | Show config and dependency status |

## Manage the service

```bash
brew services start open-wispr      # Start + auto-launch on login
brew services stop open-wispr       # Stop
brew services restart open-wispr    # Restart after config changes
```

Logs: `/opt/homebrew/var/log/open-wispr.log`

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
