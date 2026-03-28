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

read_hotkey() {
    if [ -f "$CONFIG_FILE" ]; then
        local kc mods
        kc=$(grep -o '"keyCode"[[:space:]]*:[[:space:]]*[0-9]*' "$CONFIG_FILE" | head -1 | sed 's/.*:[[:space:]]*//')
        mods=$(grep -o '"modifiers"[[:space:]]*:[[:space:]]*\[[^]]*\]' "$CONFIG_FILE" | head -1 | sed 's/.*\[//;s/\]//;s/"//g;s/[[:space:]]//g')
        echo "${kc:-63}|${mods:-}"
    else
        echo "63|"
    fi
}

keycode_to_name() {
    local code="$1"
    case "$code" in
        0) echo "a" ;; 1) echo "s" ;; 2) echo "d" ;; 3) echo "f" ;;
        4) echo "h" ;; 5) echo "g" ;; 6) echo "z" ;; 7) echo "x" ;;
        8) echo "c" ;; 9) echo "v" ;; 11) echo "b" ;; 12) echo "q" ;;
        13) echo "w" ;; 14) echo "e" ;; 15) echo "r" ;; 16) echo "y" ;;
        17) echo "t" ;; 18) echo "1" ;; 19) echo "2" ;; 20) echo "3" ;;
        21) echo "4" ;; 22) echo "6" ;; 23) echo "5" ;; 24) echo "=" ;;
        25) echo "9" ;; 26) echo "7" ;; 27) echo "-" ;; 28) echo "8" ;;
        29) echo "0" ;; 30) echo "]" ;; 31) echo "o" ;; 32) echo "u" ;;
        33) echo "[" ;; 34) echo "i" ;; 35) echo "p" ;; 36) echo "return" ;;
        37) echo "l" ;; 38) echo "j" ;; 39) echo "'" ;; 40) echo "k" ;;
        41) echo ";" ;; 42) echo "\\" ;; 43) echo "," ;; 44) echo "/" ;;
        45) echo "n" ;; 46) echo "m" ;; 47) echo "." ;; 48) echo "tab" ;;
        49) echo "space" ;; 50) echo "\`" ;; 51) echo "delete" ;; 53) echo "escape" ;;
        54) echo "rightcmd" ;; 55) echo "cmd" ;; 56) echo "shift" ;;
        57) echo "capslock" ;; 58) echo "option" ;; 59) echo "ctrl" ;;
        60) echo "rightshift" ;; 61) echo "rightoption" ;; 62) echo "rightctrl" ;;
        63) echo "fn" ;;
        96) echo "f5" ;; 97) echo "f6" ;; 98) echo "f7" ;; 99) echo "f3" ;;
        100) echo "f8" ;; 101) echo "f9" ;; 103) echo "f11" ;; 105) echo "f13" ;;
        107) echo "f14" ;; 109) echo "f10" ;; 111) echo "f12" ;; 113) echo "f15" ;;
        118) echo "f4" ;; 120) echo "f2" ;; 122) echo "f1" ;;
        *) echo "key($code)" ;;
    esac
}

name_to_keycode() {
    local name="${1,,}"
    case "$name" in
        a) echo 0 ;; s) echo 1 ;; d) echo 2 ;; f) echo 3 ;;
        h) echo 4 ;; g) echo 5 ;; z) echo 6 ;; x) echo 7 ;;
        c) echo 8 ;; v) echo 9 ;; b) echo 11 ;; q) echo 12 ;;
        w) echo 13 ;; e) echo 14 ;; r) echo 15 ;; y) echo 16 ;;
        t) echo 17 ;; 1) echo 18 ;; 2) echo 19 ;; 3) echo 20 ;;
        4) echo 21 ;; 6) echo 22 ;; 5) echo 23 ;; =) echo 24 ;;
        9) echo 25 ;; 7) echo 26 ;; -) echo 27 ;; 8) echo 28 ;;
        0) echo 29 ;; ]) echo 30 ;; o) echo 31 ;; u) echo 32 ;;
        [) echo 33 ;; i) echo 34 ;; p) echo 35 ;; return) echo 36 ;;
        l) echo 37 ;; j) echo 38 ;; \') echo 39 ;; k) echo 40 ;;
        \;) echo 41 ;; \\) echo 42 ;; ,) echo 43 ;; /) echo 44 ;;
        n) echo 45 ;; m) echo 46 ;; .) echo 47 ;; tab) echo 48 ;;
        space) echo 49 ;; \`) echo 50 ;; delete) echo 51 ;; escape) echo 53 ;;
        rightcmd) echo 54 ;; cmd|leftcmd|command) echo 55 ;; shift|leftshift) echo 56 ;;
        capslock) echo 57 ;; option|leftoption|alt|leftalt) echo 58 ;; ctrl|leftctrl|control) echo 59 ;;
        rightshift) echo 60 ;; rightoption|rightalt) echo 61 ;; rightctrl|rightcontrol) echo 62 ;;
        fn|globe) echo 63 ;;
        f1) echo 122 ;; f2) echo 120 ;; f3) echo 99 ;; f4) echo 118 ;;
        f5) echo 96 ;; f6) echo 97 ;; f7) echo 98 ;; f8) echo 100 ;;
        f9) echo 101 ;; f10) echo 109 ;; f11) echo 103 ;; f12) echo 111 ;;
        f13) echo 105 ;; f14) echo 107 ;; f15) echo 113 ;;
        *) echo "" ;;
    esac
}

parse_hotkey_input() {
    local input="$1"
    local IFS='+' parts
    read -ra parts <<< "$input"
    local key="${parts[-1]}"
    local mods=()
    for ((i=0; i<${#parts[@]}-1; i++)); do
        mods+=("$(echo "${parts[$i]}" | tr -d ' ' | tr '[:upper:]' '[:lower:]')")
    done
    local code
    code=$(name_to_keycode "$key")
    if [ -z "$code" ]; then
        echo ""
        return
    fi
    local mods_json="[]"
    if [ ${#mods[@]} -gt 0 ]; then
        mods_json="["
        for ((i=0; i<${#mods[@]}; i++)); do
            [ $i -gt 0 ] && mods_json+=", "
            mods_json+="\"${mods[$i]}\""
        done
        mods_json+="]"
    fi
    echo "${code}|${mods_json}"
}

echo "open-wispr dev build"
echo "────────────────────"

# Read current config values
cur_model=$(read_config modelSize base.en)
cur_lang=$(read_config language en)
cur_punct=$(read_config spokenPunctuation false)
cur_max_recordings=$(read_config maxRecordings 0)
cur_toggle=$(read_config toggleMode false)
cur_input_method=$(read_config inputMethod cgevent)

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

# Max recordings (0=privacy/temp+delete, 1-100=keep for reprocessing)
printf "  Max recordings (0=privacy, 1-100) [%s]: " "$cur_max_recordings"
read -r max_rec_choice
case "$max_rec_choice" in
    "") max_recordings="$cur_max_recordings" ;;
    *) max_recordings="$max_rec_choice" ;;
esac

# Toggle mode
printf "  Toggle mode (y/n) [%s]: " "$([ "$cur_toggle" = "true" ] && echo "y" || echo "n")"
read -r toggle_choice
case "$toggle_choice" in
    y|Y|yes) toggle="true" ;;
    n|N|no) toggle="false" ;;
    "") toggle="$cur_toggle" ;;
    *) toggle="$cur_toggle" ;;
esac

# Input method
echo ""
echo "  Input methods:"
echo "    1) cgevent      (default, fast)"
echo "    2) applescript   (fallback if text not inserting)"
printf "  Input method [%s]: " "$cur_input_method"
read -r input_method_choice
case "$input_method_choice" in
    1) input_method="cgevent" ;;
    2) input_method="applescript" ;;
    "") input_method="$cur_input_method" ;;
    *) input_method="$input_method_choice" ;;
esac

# Hotkey
hotkey_raw=$(read_hotkey)
cur_keycode="${hotkey_raw%%|*}"
cur_mods="${hotkey_raw##*|}"
cur_keyname=$(keycode_to_name "$cur_keycode")
if [ -n "$cur_mods" ]; then
    cur_hotkey_display="${cur_mods}+${cur_keyname}"
else
    cur_hotkey_display="$cur_keyname"
fi
printf "  Hotkey [%s]: " "$cur_hotkey_display"
read -r hotkey_input
if [ -z "$hotkey_input" ]; then
    hotkey_code="$cur_keycode"
    if [ -n "$cur_mods" ]; then
        hotkey_mods_json="[$(echo "$cur_mods" | sed 's/\([^,]*\)/"\1"/g')]"
    else
        hotkey_mods_json="[]"
    fi
else
    parsed=$(parse_hotkey_input "$hotkey_input")
    if [ -z "$parsed" ]; then
        echo "  Invalid key name, using default (fn)"
        hotkey_code=63
        hotkey_mods_json="[]"
    else
        hotkey_code="${parsed%%|*}"
        hotkey_mods_json="${parsed##*|}"
    fi
fi

# Write config
mkdir -p "$(dirname "$CONFIG_FILE")"
cat > "$CONFIG_FILE" << EOF
{
  "language": "$lang",
  "modelSize": "$model",
  "spokenPunctuation": $punct,
  "maxRecordings": $max_recordings,
  "toggleMode": $toggle,
  "inputMethod": "$input_method",
  "hotkey": { "keyCode": $hotkey_code, "modifiers": $hotkey_mods_json }
}
EOF

echo ""
hotkey_name=$(keycode_to_name "$hotkey_code")
if [ "$hotkey_mods_json" != "[]" ]; then
    hotkey_display="$(echo "$hotkey_mods_json" | sed 's/\[//;s/\]//;s/"//g;s/ //g')+${hotkey_name}"
else
    hotkey_display="$hotkey_name"
fi
echo "  Config: model=$model  lang=$lang  punctuation=$punct  maxRecordings=$max_recordings  toggle=$toggle  inputMethod=$input_method  hotkey=$hotkey_display"
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

if ! brew list whisper-cpp &>/dev/null; then
    echo "  Reinstalling whisper-cpp..."
    brew install whisper-cpp
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
