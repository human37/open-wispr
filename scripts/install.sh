#!/bin/bash

# ── Colors & formatting ──────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPIN_PID=""
LOG=$(mktemp /tmp/open-wispr-install.XXXXXX)
APP_PID=""

cleanup() {
    stop_spin
    if [ -n "$APP_PID" ]; then
        kill "$APP_PID" 2>/dev/null
        wait "$APP_PID" 2>/dev/null
    fi
    rm -f "$LOG"
}
trap cleanup EXIT

step() {
    printf "\n  ${BLUE}${BOLD}%s${NC}\n" "$1"
}

ok() {
    printf "\r\033[K  ${GREEN}✓${NC} %b\n" "$1"
}

info() {
    printf "  ${DIM}%b${NC}\n" "$1"
}

fail() {
    printf "\r\033[K  ${RED}✗${NC} %b\n" "$1"
}

spin() {
    while true; do
        for frame in "${SPINNER_FRAMES[@]}"; do
            printf "\r\033[K  ${YELLOW}%s${NC} %b" "$frame" "$1"
            sleep 0.1
        done
    done
}

start_spin() {
    spin "$1" &
    SPIN_PID=$!
}

stop_spin() {
    if [ -n "$SPIN_PID" ]; then
        kill "$SPIN_PID" 2>/dev/null
        wait "$SPIN_PID" 2>/dev/null
        SPIN_PID=""
    fi
}

wait_for_log() {
    local pattern="$1"
    local timeout="${2:-30}"
    local msg="$3"

    [ -n "$msg" ] && start_spin "$msg"

    local elapsed=0
    while [ $elapsed -lt "$timeout" ]; do
        if grep -q "$pattern" "$LOG" 2>/dev/null; then
            stop_spin
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    stop_spin
    return 1
}

die() {
    stop_spin
    fail "$1"
    exit 1
}

# ── Header ────────────────────────────────────────────────────────────
printf "\n"
printf "  ${BOLD}open-wispr${NC} ${DIM}— local voice dictation for macOS${NC}\n"
printf "  ${DIM}────────────────────────────────────────────${NC}\n"

# ── Step 1: Clean up ─────────────────────────────────────────────────
step "Removing previous installation"
start_spin "Cleaning up..."

brew services stop open-wispr </dev/null >/dev/null 2>&1 || true
brew uninstall --force open-wispr </dev/null >/dev/null 2>&1 || true
brew untap human37/open-wispr </dev/null >/dev/null 2>&1 || true
tccutil reset Accessibility com.human37.open-wispr </dev/null >/dev/null 2>&1 || true
rm -rf ~/Applications/OpenWispr.app

stop_spin
ok "Clean"

# ── Step 2: Install ──────────────────────────────────────────────────
step "Installing"

start_spin "Tapping human37/open-wispr..."
if ! brew tap human37/open-wispr </dev/null >/dev/null 2>&1; then
    die "Failed to tap. Check your internet connection."
fi
stop_spin
ok "Tapped ${DIM}human37/open-wispr${NC}"

start_spin "Building from source (this takes a minute)..."
brew install open-wispr </dev/null >/dev/null 2>&1 || true
brew reinstall open-wispr </dev/null >/dev/null 2>&1 || true
stop_spin

BREW_PREFIX="$(brew --prefix open-wispr 2>/dev/null)"
CELLAR_BIN="${BREW_PREFIX}/OpenWispr.app/Contents/MacOS/open-wispr"

if [ ! -x "$CELLAR_BIN" ]; then
    die "Installation failed — binary not found. Run 'brew install open-wispr' manually."
fi
ok "Installed"

mkdir -p ~/Applications
rm -rf ~/Applications/OpenWispr.app
cp -R "${BREW_PREFIX}/OpenWispr.app" ~/Applications/OpenWispr.app
codesign --force --sign - ~/Applications/OpenWispr.app/Contents/MacOS/open-wispr 2>/dev/null || true
APP_BIN=~/Applications/OpenWispr.app/Contents/MacOS/open-wispr

# ── Step 3: Permissions ──────────────────────────────────────────────
step "Setting up permissions"
info "Starting app to request permissions...\n"

"$APP_BIN" start </dev/null > "$LOG" 2>&1 &
APP_PID=$!

sleep 1
if ! kill -0 "$APP_PID" 2>/dev/null; then
    fail "App crashed on startup"
    die "Check: $APP_BIN start"
fi

if ! wait_for_log "Microphone:" 30 "Requesting microphone access..."; then
    fail "Timed out waiting for microphone prompt"
    die "Logs: tail -f $LOG"
fi

if grep -q "Microphone: granted" "$LOG" 2>/dev/null; then
    ok "Microphone"
elif grep -q "Microphone: denied" "$LOG" 2>/dev/null; then
    fail "Microphone denied"
    info "Grant in ${BOLD}System Settings → Privacy & Security → Microphone${NC}"
    die "Then re-run this script."
else
    ok "Microphone"
fi

if wait_for_log "Accessibility: granted" 5; then
    ok "Accessibility"
else
    printf "\r\033[K"
    info "macOS needs Accessibility permission to detect your hotkey."
    info "System Settings will open — find ${BOLD}OpenWispr${NC} and toggle it ${BOLD}ON${NC}.\n"

    if ! wait_for_log "Accessibility: granted" 300 "Waiting for you to grant Accessibility permission..."; then
        die "Timed out waiting for Accessibility permission."
    fi
    ok "Accessibility"
fi

# ── Step 4: Model download ───────────────────────────────────────────
if grep -q "Downloading" "$LOG" 2>/dev/null; then
    step "Downloading Whisper model"

    if ! wait_for_log "Ready\." 300 "Downloading model (~142 MB, one-time)..."; then
        die "Download timed out. Check: tail -f $LOG"
    fi
    ok "Model ready"
fi

# ── Step 5: Wait for ready ───────────────────────────────────────────
if ! grep -q "Ready\." "$LOG" 2>/dev/null; then
    if ! wait_for_log "Ready\." 30 "Finishing setup..."; then
        die "Timed out. Check: tail -f $LOG"
    fi
fi

# ── Step 6: Switch to service ────────────────────────────────────────
kill "$APP_PID" 2>/dev/null
wait "$APP_PID" 2>/dev/null
APP_PID=""

step "Starting background service"
start_spin "Starting..."
brew services start open-wispr </dev/null >/dev/null 2>&1 || true
stop_spin

sleep 1
if brew services list 2>/dev/null | grep -q "open-wispr.*started"; then
    ok "Running as background service"
else
    ok "Service registered"
    info "If not running, start manually: brew services start open-wispr"
fi

# ── Done ──────────────────────────────────────────────────────────────
hotkey=$(grep "^Hotkey:" "$LOG" 2>/dev/null | tail -1 | sed 's/^Hotkey: //')
model=$(grep "^Model:" "$LOG" 2>/dev/null | tail -1 | sed 's/^Model: //')
version=$(grep "^open-wispr v" "$LOG" 2>/dev/null | tail -1)

printf "\n"
printf "  ${DIM}────────────────────────────────────────────${NC}\n"
printf "  ${GREEN}${BOLD}Ready!${NC}\n"
printf "\n"
[ -n "$version" ] && printf "  ${DIM}%s${NC}\n" "$version"
[ -n "$hotkey" ]  && printf "  Hotkey  ${BOLD}%s${NC}\n" "$hotkey"
[ -n "$model" ]   && printf "  Model   ${BOLD}%s${NC}\n" "$model"
printf "\n"
printf "  Hold your hotkey, speak, release — text appears at cursor.\n"
printf "\n"
