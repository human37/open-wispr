# Models

Complete reference for the Whisper models open-wispr supports. For a quick overview see the [README](README.md#models).

## All supported models

| Model | Size | Speed | Accuracy | Notes |
|---|---|---|---|---|
| `tiny.en` | 75 MB | Fastest | Lower | Quick notes, short phrases |
| `tiny.en-q5_1` | 31 MB | Fastest | Lower | Quantized `tiny.en` (5-bit) — ~⅓ disk/RAM, slight quality loss |
| **`base.en`** | 142 MB | **Fast** | **Good** | **Most users (default)** |
| `base.en-q5_1` | 57 MB | Fast | Good | Quantized `base.en` (5-bit) — ~⅓ disk/RAM, slight quality loss |
| `small.en` | 466 MB | Moderate | Better | Longer dictation, technical terms |
| `small.en-q5_1` | 181 MB | Moderate | Better | Quantized `small.en` (5-bit) — ~⅓ disk/RAM, slight quality loss |
| `medium.en` | 1.5 GB | Slower | Great | Maximum accuracy, complex speech |
| `medium.en-q5_0` | 514 MB | Slower | Great | Quantized `medium.en` (5-bit) — ~⅓ disk/RAM, slight quality loss |
| `large-v3-turbo` | 1.6 GB | Moderate | Great | Fast multilingual, near-large accuracy |
| `large-v3-turbo-q8_0` | 834 MB | Moderate | Great | Quantized `large-v3-turbo` (8-bit) — ~½ disk/RAM, near-zero quality loss |
| `large-v3-turbo-q5_0` | 547 MB | Moderate | Great-ish | Quantized `large-v3-turbo` (5-bit) — ~⅓ disk/RAM, slight quality loss |
| `large-v3` | 3 GB | Slowest | Best | Multilingual, highest accuracy (M1 Pro+ recommended) |

## Quantized variants

The `-q5_0`, `-q5_1`, and `-q8_0` rows are not separate models — they're the full model's weights compressed with integer quantization. The compute path is identical, so transcription speed is roughly the same as the corresponding full model, but disk and resident memory drop substantially.

The number after `q` is the bit width per weight: lower = smaller file, more quality loss.

- **`q8_0`** (8-bit) — most conservative. ~½ the size of the full model. Quality loss is barely measurable; safe default if you want a smaller download without thinking about it.
- **`q5_1`** / **`q5_0`** (5-bit) — more aggressive. ~⅓ the size of the full model. Quality cost is small but real; you may notice it on edge cases (proper nouns, accents, ambient noise, long uninterrupted speech). `q5_1` is slightly higher quality than `q5_0`; whisper.cpp ships `q5_1` for the smaller English models and `q5_0` for `medium.en` and the large-tier models.

For everyday dictation the difference between a quantized model and its full counterpart is usually imperceptible. If you start noticing misrecognitions on a quantized variant that don't happen on the full version, switch up — the trade-off isn't worth it for your workload.

## English vs. multilingual

Models ending in `.en` (including the `.en-q…` quantized variants) are English-only. There is no English-only large model upstream — OpenAI never released one, so pick `large-v3-turbo` for the fastest large-tier multilingual option.

To use another language, switch to the equivalent multilingual model (e.g. `base.en` → `base`, or `large-v3-turbo` for the fastest large-tier option) and set the `language` field in `~/.config/open-wispr/config.json` to your [ISO 639-1 code](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes). Multilingual models are slightly less accurate for English but support 99 languages.

## Where these come from

Models are downloaded on demand from [`ggerganov/whisper.cpp`](https://huggingface.co/ggerganov/whisper.cpp/tree/main) on HuggingFace and cached in `~/.config/open-wispr/models/`.
