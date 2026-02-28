# Contributing

Thanks for your interest in contributing to open-wispr.

## Getting started

1. Fork the repo and clone it
2. Install dependencies:
   ```bash
   brew install whisper-cpp
   ```
3. Build and run:
   ```bash
   swift build -c release
   .build/release/open-wispr start
   ```

## Project structure

```
Sources/OpenWispr/
├── AppDelegate.swift    # App lifecycle, hotkey listener, menu bar
├── Config.swift         # Config loading/saving (~/.config/open-wispr/config.json)
├── Transcriber.swift    # Whisper CLI wrapper
├── AudioRecorder.swift  # Microphone recording
└── ...
scripts/
├── install.sh           # Guided installer
├── uninstall.sh         # Clean removal
└── deploy.sh            # Release automation
```

## Making changes

1. Create a branch off `main`
2. Make your changes
3. Test locally with `swift build -c release && .build/release/open-wispr start`
4. Open a pull request against `main`

## What to work on

Check the [open issues](https://github.com/human37/open-wispr/issues) for bugs and feature requests. If you want to work on something not listed, open an issue first to discuss it.

## Guidelines

- Keep it simple. open-wispr is intentionally minimal.
- No cloud dependencies. Everything must run on-device.
- Test on Apple Silicon. Intel Macs are not supported.
- Match the existing code style.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
