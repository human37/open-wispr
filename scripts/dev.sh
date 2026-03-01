#!/bin/bash
set -euo pipefail

CONFIG_FILE="$HOME/.config/open-wispr/config.json"

# Read a JSON value using grep/sed (no python dependency)
read_config() {
    local key="$1" default="$2"
    if [ -f "$CONFIG_FILE" ]; then
        local val
        val=$(grep -o "\"$key\"[[:space:]]*:[[:space:]]*[^,}]*" "$CONFIG_FILE" | head -1 | sed "s/\"$key\"[[:space:]]*:[[:space:]]*//;s/\"//g;s/[[:space:]]//g")
        echo "${val:-$default}"
    else
        echo "$default"
    fi
}

echo "open-wispr dev build"
echo "────────────────────"

# Read current config values
cur_model=$(read_config modelSize base.en)
cur_lang=$(read_config language en)
cur_punct=$(read_config spokenPunctuation false)

# Model
echo ""
echo "  Model sizes:"
echo "    1) tiny.en    (75 MB)"
echo "    2) base.en    (142 MB)"
echo "    3) small.en   (466 MB)"
echo "    4) medium.en  (1.5 GB)"
echo "    5) tiny       (multilingual)"
echo "    6) base       (multilingual)"
echo "    7) small      (multilingual)"
echo "    8) medium     (multilingual)"
printf "  Model [%s]: " "$cur_model"
read -r model_choice
case "$model_choice" in
    1) model="tiny.en" ;;
    2) model="base.en" ;;
    3) model="small.en" ;;
    4) model="medium.en" ;;
    5) model="tiny" ;;
    6) model="base" ;;
    7) model="small" ;;
    8) model="medium" ;;
    "") model="$cur_model" ;;
    *) model="$model_choice" ;;
esac

# Language
printf "  Language [%s]: " "$cur_lang"
read -r lang
lang="${lang:-$cur_lang}"

# Spoken punctuation
printf "  Spoken punctuation (y/n) [%s]: " "$([ "$cur_punct" = "true" ] && echo "y" || echo "n")"
read -r punct_choice
case "$punct_choice" in
    y|Y|yes) punct="true" ;;
    n|N|no) punct="false" ;;
    "") punct="$cur_punct" ;;
    *) punct="$cur_punct" ;;
esac

# Write config
mkdir -p "$(dirname "$CONFIG_FILE")"
cat > "$CONFIG_FILE" << EOF
{
  "language": "$lang",
  "modelSize": "$model",
  "spokenPunctuation": $punct,
  "hotkey": $(grep -o '"hotkey"[[:space:]]*:[[:space:]]*{[^}]*}' "$CONFIG_FILE" 2>/dev/null || echo '{ "keyCode": 63, "modifiers": [] }')
}
EOF

echo ""
echo "  Config: model=$model  lang=$lang  punctuation=$punct"
echo "────────────────────"

# Kill any running instances
echo "  Stopping running instances..."
pkill -f "open-wispr start" 2>/dev/null || true
brew services stop open-wispr 2>/dev/null || true
sleep 1

# Uninstall brew version
if brew list open-wispr &>/dev/null; then
    echo "  Removing brew installation..."
    brew uninstall --force open-wispr 2>/dev/null || true
fi

# Build from source
echo "  Building from source..."
swift build -c release 2>&1 | tail -1

# Bundle the app
echo "  Bundling app..."
bash scripts/bundle-app.sh .build/release/open-wispr OpenWispr.app dev

# Copy to ~/Applications so macOS recognizes it for permissions
rm -rf ~/Applications/OpenWispr.app
cp -R OpenWispr.app ~/Applications/OpenWispr.app
rm -rf OpenWispr.app

# Run
echo "  Starting..."
~/Applications/OpenWispr.app/Contents/MacOS/open-wispr start
