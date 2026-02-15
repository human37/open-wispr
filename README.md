# open-wispr

Push-to-talk voice dictation for macOS. Hold a key, speak, release — your words appear at the cursor.

Runs locally using [whisper.cpp](https://github.com/ggml-org/whisper.cpp) with Metal acceleration on Apple Silicon. No data leaves your machine.

## Install

```bash
brew tap human37/open-wispr
brew install open-wispr
```

## Start

```bash
brew services start open-wispr
```

That's it. On first launch:
- macOS prompts for **Microphone** and **Accessibility** — grant both
- The Whisper model downloads automatically (~142 MB)
- Restart the service after granting permissions: `brew services restart open-wispr`

The default hotkey is the **Globe key** (bottom-left on Mac keyboards). Hold it, speak, release.

## Change the hotkey

```bash
open-wispr set-hotkey rightoption    # Right Option key
open-wispr set-hotkey f5             # F5 key
open-wispr set-hotkey ctrl+space     # Ctrl + Space
brew services restart open-wispr     # Restart to apply
```

## Globe key setup

If your Globe key opens the emoji picker, disable that first:

1. **System Settings → Keyboard**
2. Set **"Press 🌐 key to"** → **"Do Nothing"**

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
