# open-wispr

Push-to-talk voice dictation for macOS. Hold a key, speak, release — your words appear at the cursor.

Uses [whisper.cpp](https://github.com/ggml-org/whisper.cpp) for fast, local speech-to-text with Metal acceleration on Apple Silicon.

## Install

```bash
brew tap human37/open-wispr
brew install open-wispr
```

Or build from source:

```bash
git clone https://github.com/human37/open-wispr.git
cd open-wispr
swift build -c release
cp .build/release/open-wispr /usr/local/bin/
```

### Dependencies

- **whisper-cpp** — installed automatically via Homebrew, or install manually: `brew install whisper-cpp`
- **macOS 13+** (Ventura or later)

## Setup

### 1. Download a Whisper model

```bash
open-wispr download-model base.en
```

Available models (smaller = faster, larger = more accurate):

| Model | Size | Speed |
|---|---|---|
| `tiny.en` | 75 MB | Fastest |
| `base.en` | 142 MB | Fast (recommended) |
| `small.en` | 466 MB | Moderate |
| `medium.en` | 1.5 GB | Slow |
| `large` | 2.9 GB | Slowest |

### 2. Set your hotkey

```bash
open-wispr set-hotkey globe        # Globe/fn key (bottom-left on Mac keyboards)
open-wispr set-hotkey rightoption   # Right Option key (default)
open-wispr set-hotkey f5            # F5 key
open-wispr set-hotkey ctrl+space    # Ctrl + Space
```

### 3. Grant Accessibility permissions

open-wispr needs Accessibility access to capture global hotkeys and type text.

**System Settings → Privacy & Security → Accessibility** → add your terminal app (or the `open-wispr` binary).

### 4. Start

```bash
open-wispr start
```

Hold your hotkey, speak, release. The transcribed text is typed at your cursor position.

## Using the Globe key

The Globe key (🌐) on Mac keyboards can be used as your push-to-talk key. First, prevent macOS from intercepting it:

1. Open **System Settings → Keyboard**
2. Set **"Press 🌐 key to"** → **"Do Nothing"**
3. Then: `open-wispr set-hotkey globe`

## Commands

| Command | Description |
|---|---|
| `open-wispr start` | Start the dictation daemon |
| `open-wispr set-hotkey <key>` | Set the push-to-talk hotkey |
| `open-wispr get-hotkey` | Show current hotkey |
| `open-wispr download-model [size]` | Download a Whisper model |
| `open-wispr status` | Show config and dependency status |

## Configuration

Config is stored at `~/.config/open-wispr/config.json` and created automatically on first run.

```json
{
  "hotkey": {
    "keyCode": 63,
    "modifiers": []
  },
  "modelSize": "base.en",
  "language": "en"
}
```

## How it works

1. A global event tap listens for your configured hotkey
2. On key down, audio recording starts via AVAudioEngine (16kHz mono)
3. On key up, the recording is saved and passed to whisper-cpp for transcription
4. The transcribed text is placed on the clipboard and pasted at the cursor (Cmd+V), then the previous clipboard contents are restored

## License

MIT
