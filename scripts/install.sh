#!/bin/bash
set -e

# ── Colors & formatting ──────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
APP_BIN="$HOME/Applications/OpenWispr.app/Contents/MacOS/open-wispr"
LOG=$(mktemp /tmp/open-wispr-install.XXXXXX)
APP_PID=""

cleanup() {
    [ -n "$APP_PID" ] && kill "$APP_PID" 2>/dev/null && wait "$APP_PID" 2>/dev/null
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
    local msg="$1"
    local i=0
    while true; do
        printf "\r\033[K  ${YELLOW}${SPINNER_FRAMES[$((i % 10))]}${NC} %b" "$msg"
        i=$((i + 1))
        sleep 0.1
    done
}

wait_for_log() {
    local pattern="$1"
    local timeout="${2:-30}"
    local msg="$3"
    local spin_pid=""

    if [ -n "$msg" ]; then
        spin "$msg" &
        spin_pid=$!
    fi

    local elapsed=0
    while [ $elapsed -lt "$timeout" ]; do
        if grep -q "$pattern" "$LOG" 2>/dev/null; then
            [ -n "$spin_pid" ] && kill "$spin_pid" 2>/dev/null && wait "$spin_pid" 2>/dev/null
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    [ -n "$spin_pid" ] && kill "$spin_pid" 2>/dev/null && wait "$spin_pid" 2>/dev/null
    return 1
}

# ── Header ────────────────────────────────────────────────────────────
printf "\n"
printf "  ${BOLD}open-wispr${NC} ${DIM}— local voice dictation for macOS${NC}\n"
printf "  ${DIM}────────────────────────────────────────────${NC}\n"

# ── Step 1: Clean up ─────────────────────────────────────────────────
step "Removing previous installation"

spin "Cleaning up..." &
SPIN_PID=$!

brew services stop open-wispr 2>/dev/null || true
brew uninstall open-wispr 2>/dev/null || true
brew untap human37/open-wispr 2>/dev/null || true
tccutil reset Accessibility com.human37.open-wispr 2>/dev/null || true
rm -rf ~/Applications/OpenWispr.app

kill "$SPIN_PID" 2>/dev/null && wait "$SPIN_PID" 2>/dev/null
ok "Clean"

# ── Step 2: Install ──────────────────────────────────────────────────
step "Installing"

spin "Tapping human37/open-wispr..." &
SPIN_PID=$!
brew tap human37/open-wispr >/dev/null 2>&1
kill "$SPIN_PID" 2>/dev/null && wait "$SPIN_PID" 2>/dev/null
ok "Tapped ${DIM}human37/open-wispr${NC}"

spin "Building from source (this takes a minute)..." &
SPIN_PID=$!
brew install open-wispr 2>&1 | tail -1 >/dev/null
kill "$SPIN_PID" 2>/dev/null && wait "$SPIN_PID" 2>/dev/null
ok "Installed"

# ── Step 3: Permissions ──────────────────────────────────────────────
step "Setting up permissions"
info "Starting app to request permissions...\n"

"$APP_BIN" start > "$LOG" 2>&1 &
APP_PID=$!

if ! wait_for_log "Microphone:" 20 "Requesting microphone access..."; then
    fail "Timed out waiting for app. Check: $APP_BIN start"
    exit 1
fi

if grep -q "Microphone: granted" "$LOG" 2>/dev/null; then
    ok "Microphone"
elif grep -q "Microphone: denied" "$LOG" 2>/dev/null; then
    fail "Microphone denied"
    info "Grant in ${BOLD}System Settings → Privacy & Security → Microphone${NC}"
    info "Then re-run this script."
    exit 1
else
    ok "Microphone"
fi

if wait_for_log "Accessibility: granted" 3; then
    ok "Accessibility"
else
    printf "\r\033[K"
    info "macOS needs Accessibility permission to detect your hotkey."
    info "System Settings will open — find ${BOLD}OpenWispr${NC} and toggle it ${BOLD}ON${NC}.\n"

    if ! wait_for_log "Accessibility: granted" 300 "Waiting for you to grant Accessibility permission..."; then
        fail "Timed out waiting for Accessibility permission."
        exit 1
    fi
    ok "Accessibility"
fi

# ── Step 4: Model download ───────────────────────────────────────────
if grep -q "Downloading" "$LOG" 2>/dev/null; then
    step "Downloading Whisper model"

    if ! wait_for_log "Model downloaded\|Ready\." 300 "Downloading model (~142 MB, one-time)..."; then
        fail "Download timed out. Check logs: tail -f /opt/homebrew/var/log/open-wispr.log"
        exit 1
    fi
    ok "Model ready"
fi

# ── Step 5: Wait for ready ───────────────────────────────────────────
if ! grep -q "Ready\." "$LOG" 2>/dev/null; then
    if ! wait_for_log "Ready\." 30 "Finishing setup..."; then
        fail "Timed out. Check logs: tail -f /opt/homebrew/var/log/open-wispr.log"
        exit 1
    fi
fi

# ── Step 6: Switch to service ────────────────────────────────────────
kill "$APP_PID" 2>/dev/null && wait "$APP_PID" 2>/dev/null
APP_PID=""

step "Starting background service"

spin "Starting..." &
SPIN_PID=$!
brew services start open-wispr >/dev/null 2>&1
kill "$SPIN_PID" 2>/dev/null && wait "$SPIN_PID" 2>/dev/null
ok "Running as background service"

# ── Done ──────────────────────────────────────────────────────────────
hotkey=$(grep "^Hotkey:" "$LOG" 2>/dev/null | tail -1 | sed 's/^Hotkey: //')
model=$(grep "^Model:" "$LOG" 2>/dev/null | tail -1 | sed 's/^Model: //')
version=$(grep "^open-wispr v" "$LOG" 2>/dev/null | tail -1 | sed 's/^//')

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
