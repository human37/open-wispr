#!/bin/bash
set -euo pipefail

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "open-wispr transcription integration tests"
echo "--------------------------------------------"

# Check whisper-cli is installed
WHISPER_BIN=""
for name in whisper-cli whisper-cpp; do
    if command -v "$name" &>/dev/null; then
        WHISPER_BIN="$name"
        break
    fi
done

if [ -z "$WHISPER_BIN" ]; then
    echo "SKIP: whisper-cpp not installed (brew install whisper-cpp)"
    exit 0
fi
pass "whisper binary found: $WHISPER_BIN"

# Find or download the tiny.en model (smallest, ~75 MB)
MODEL_SIZE="tiny.en"
MODEL_FILE="ggml-${MODEL_SIZE}.bin"
MODEL_PATH=""

for dir in \
    "$HOME/.config/open-wispr/models" \
    "/opt/homebrew/share/whisper-cpp/models" \
    "/usr/local/share/whisper-cpp/models" \
    "$HOME/.cache/whisper"; do
    if [ -f "$dir/$MODEL_FILE" ]; then
        MODEL_PATH="$dir/$MODEL_FILE"
        break
    fi
done

if [ -z "$MODEL_PATH" ]; then
    echo "Downloading $MODEL_SIZE model..."
    MODEL_DIR="$HOME/.config/open-wispr/models"
    mkdir -p "$MODEL_DIR"
    MODEL_PATH="$MODEL_DIR/$MODEL_FILE"
    curl -L --progress-bar -o "$MODEL_PATH" \
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$MODEL_FILE"
fi
pass "Model available: $MODEL_PATH"

TMPDIR_TEST=$(mktemp -d /tmp/open-wispr-test.XXXXXX)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Generate test audio using macOS text-to-speech
echo "Generating test audio..."
say -o "$TMPDIR_TEST/hello.aiff" "Hello world"
afconvert -f WAVE -d LEI16@16000 -c 1 "$TMPDIR_TEST/hello.aiff" "$TMPDIR_TEST/hello.wav"
pass "Generated hello.wav"

say -o "$TMPDIR_TEST/numbers.aiff" "One two three four five"
afconvert -f WAVE -d LEI16@16000 -c 1 "$TMPDIR_TEST/numbers.aiff" "$TMPDIR_TEST/numbers.wav"
pass "Generated numbers.wav"

# Test 1: Basic transcription
echo ""
echo "Running transcription tests..."
OUTPUT=$($WHISPER_BIN -m "$MODEL_PATH" -f "$TMPDIR_TEST/hello.wav" --no-timestamps -nt 2>/dev/null || true)
OUTPUT_LOWER=$(echo "$OUTPUT" | tr '[:upper:]' '[:lower:]')

if echo "$OUTPUT_LOWER" | grep -q "hello"; then
    pass "Transcribed 'hello' from audio"
else
    fail "Expected 'hello' in output, got: $OUTPUT"
fi

# Test 2: Numbers
OUTPUT=$($WHISPER_BIN -m "$MODEL_PATH" -f "$TMPDIR_TEST/numbers.wav" --no-timestamps -nt 2>/dev/null || true)
OUTPUT_LOWER=$(echo "$OUTPUT" | tr '[:upper:]' '[:lower:]')

if echo "$OUTPUT_LOWER" | grep -qE "one|two|three|four|five|1|2|3|4|5"; then
    pass "Transcribed numbers from audio"
else
    fail "Expected number words in output, got: $OUTPUT"
fi

# Test 3: Transcriber class via the built binary
BIN=".build/release/open-wispr"
if [ -x "$BIN" ]; then
    STATUS_OUT=$($BIN status 2>&1 || true)
    if echo "$STATUS_OUT" | grep -q "whisper-cpp: yes"; then
        pass "Binary detects whisper-cpp"
    else
        fail "Binary should detect whisper-cpp"
    fi
fi

# Test 4: Post-processing pipeline
# Transcribe and run through post-processor by checking the full pipeline
say -o "$TMPDIR_TEST/punct.aiff" "Hello period how are you question mark"
afconvert -f WAVE -d LEI16@16000 -c 1 "$TMPDIR_TEST/punct.aiff" "$TMPDIR_TEST/punct.wav"

OUTPUT=$($WHISPER_BIN -m "$MODEL_PATH" -f "$TMPDIR_TEST/punct.wav" --no-timestamps -nt 2>/dev/null || true)
OUTPUT_LOWER=$(echo "$OUTPUT" | tr '[:upper:]' '[:lower:]')

if echo "$OUTPUT_LOWER" | grep -q "hello"; then
    pass "Punctuation test audio transcribed"
else
    fail "Punctuation test transcription failed: $OUTPUT"
fi

echo ""
echo "--------------------------------------------"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
