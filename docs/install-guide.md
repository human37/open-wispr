# Installation Guide

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/human37/open-wispr/main/scripts/install.sh | bash
```

The installer handles everything automatically — Homebrew tap, formula install, permissions, model download, and service startup.

## What the installer does

1. **Installs via Homebrew** — taps `human37/open-wispr` and installs the formula
2. **Copies the app bundle** to `~/Applications/OpenWispr.app`
3. **Requests permissions** — Microphone and Accessibility
4. **Downloads the Whisper model** (~142 MB, one-time)
5. **Starts the background service** via `brew services`

## Granting Permissions

open-wispr needs two macOS permissions to work:

### Microphone

A system dialog will appear automatically during install. Click **Allow**.

### Accessibility

Accessibility permission lets open-wispr detect your hotkey globally. During install, a pop-up like this will appear:

<p align="center">
  <img width="465" alt="Accessibility permission prompt" src="https://github.com/user-attachments/assets/9a0533ae-c174-4395-9533-46b55c3cb592" />
</p>

Click it to jump directly to the Accessibility settings. Find **OpenWispr** in the list and toggle it **ON**:

<p align="center">
  <img width="711" alt="Accessibility settings with OpenWispr toggled on" src="https://github.com/user-attachments/assets/f8243e28-4fae-4aba-a030-5c4c66c3cf07" />
</p>

If you missed the pop-up, navigate there manually:

> **System Settings → Privacy & Security → Accessibility**

If `OpenWispr` doesn't appear in the list, click the **+** button and add it from `~/Applications/OpenWispr.app`.

### Non-English macOS

The permission steps are the same regardless of your system language. macOS translates the Settings UI automatically — only the app name **OpenWispr** stays the same.

For reference, here's the path in a few languages:

| Language | Path |
|---|---|
| English | System Settings → Privacy & Security → Accessibility |
| Italian | Impostazioni di Sistema → Privacy e sicurezza → Accessibilità |
| French | Réglages du système → Confidentialité et sécurité → Accessibilité |
| German | Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen |
| Spanish | Ajustes del Sistema → Privacidad y seguridad → Accesibilidad |
| Portuguese | Ajustes do Sistema → Privacidade e Segurança → Acessibilidade |

## Troubleshooting

### "Timed out waiting for Accessibility permission"

The installer waits up to 5 minutes for you to grant Accessibility. If it times out:

1. Uninstall first:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/human37/open-wispr/main/scripts/uninstall.sh | bash
   ```
2. Re-run the installer. Watch for the Accessibility pop-up and grant it promptly.

### App not appearing in Accessibility list

1. Open **System Settings → Privacy & Security → Accessibility**
2. Click the **+** button
3. Navigate to `~/Applications/` and select `OpenWispr.app`
4. Toggle it **ON**

### Microphone denied

If you accidentally denied microphone access:

1. Go to **System Settings → Privacy & Security → Microphone**
2. Find **OpenWispr** and toggle it **ON**
3. Re-run the installer

### Globe key opens emoji picker

If the Globe key (🌐) triggers the emoji picker instead of open-wispr:

> **System Settings → Keyboard → "Press 🌐 key to" → "Do Nothing"**

### Right Option hotkey also triggers from left Option

If you set right Option (`keyCode: 61`) as the hotkey, open-wispr should only trigger from the physical right Option key. If left Option also triggers, update to the latest build.

### Config resets to default after editing `config.json`

If `config.json` has invalid JSON or unsupported values, open-wispr now prints a warning and falls back to defaults for that run, without overwriting your file. Fix the JSON and restart the service:

```bash
brew services restart open-wispr
```

## Language Support

open-wispr defaults to English, but Whisper supports many languages. To dictate in a different language, edit `~/.config/open-wispr/config.json`:

1. Switch to a **multilingual model** (remove the `.en` suffix)
2. Set the **language** to your [ISO 639-1 code](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes)

For example, to use Italian:

```json
{
  "language": "it",
  "modelSize": "base"
}
```

Then restart: `brew services restart open-wispr`

The multilingual model will be downloaded automatically on next use.

### Available models

| Model | English-only | Multilingual | Size |
|---|---|---|---|
| tiny | `tiny.en` | `tiny` | ~75 MB |
| base | `base.en` | `base` | ~142 MB |
| small | `small.en` | `small` | ~466 MB |
| medium | `medium.en` | `medium` | ~1.5 GB |
| large (turbo) | — | `large-v3-turbo` | ~1.6 GB |
| large (v3) | — | `large-v3` | ~3 GB |

Larger models are more accurate but slower. `base` is a good starting point for most languages. There is no English-only large model upstream — pick `large-v3-turbo` for the fastest large-tier option (multilingual, near-large quality).

Each model also has quantized variants at ~⅓–½ the size with minimal quality loss. See [MODELS.md](https://github.com/human37/open-wispr/blob/main/MODELS.md) for the complete list and tradeoffs.

### Common language codes

| Language | Code |
|---|---|
| English | `en` |
| Italian | `it` |
| French | `fr` |
| German | `de` |
| Spanish | `es` |
| Portuguese | `pt` |
| Japanese | `ja` |
| Chinese | `zh` |
| Korean | `ko` |

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/human37/open-wispr/main/scripts/uninstall.sh | bash
```

This removes the service, formula, tap, config, models, app bundle, logs, and resets Accessibility permissions.

## Build from Source

```bash
git clone https://github.com/human37/open-wispr.git
cd open-wispr
brew install whisper-cpp
swift build -c release
.build/release/open-wispr start
```
