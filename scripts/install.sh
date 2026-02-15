#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

step()  { printf "\n${BLUE}==>${NC} ${BOLD}%s${NC}\n" "$1"; }
ok()    { printf "  ${GREEN}✓${NC} %s\n" "$1"; }
info()  { printf "  ${YELLOW}→${NC} %s\n" "$1"; }
fail()  { printf "  ${RED}✗${NC} %s\n" "$1"; }

LOG="/opt/homebrew/var/log/open-wispr.log"

step "Cleaning up previous installation"
brew services stop open-wispr 2>/dev/null && ok "Stopped service" || true
brew uninstall open-wispr 2>/dev/null && ok "Uninstalled formula" || true
brew untap human37/open-wispr 2>/dev/null && ok "Removed tap" || true
tccutil reset Accessibility com.human37.open-wispr 2>/dev/null && ok "Reset accessibility permission" || true
rm -rf ~/Applications/OpenWispr.app
ok "Cleaned up"

step "Installing open-wispr"
brew tap human37/open-wispr
brew install open-wispr
ok "Installed"

step "Starting service"
: > "$LOG"
brew services start open-wispr
ok "Service started"

step "Checking permissions"
info "Watching log for status..."

wait_for_log() {
    local pattern="$1"
    local timeout="$2"
    local elapsed=0
    while [ $elapsed -lt "$timeout" ]; do
        if grep -q "$pattern" "$LOG" 2>/dev/null; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 1
}

if wait_for_log "Microphone:" 15; then
    if grep -q "Microphone: granted" "$LOG" 2>/dev/null; then
        ok "Microphone permission granted"
    else
        fail "Microphone denied — enable in System Settings → Privacy & Security → Microphone"
    fi
else
    info "Still waiting for microphone prompt..."
fi

if grep -q "Accessibility: not granted" "$LOG" 2>/dev/null; then
    printf "\n"
    info "macOS needs you to grant Accessibility permission."
    info "System Settings should open automatically."
    info "Find ${BOLD}OpenWispr${NC} in the list and toggle it ${BOLD}ON${NC}."
    printf "\n"

    printf "  Waiting for permission"
    while ! grep -q "Accessibility: granted" "$LOG" 2>/dev/null; do
        printf "."
        sleep 2
    done
    printf "\n"
    ok "Accessibility permission granted"
elif grep -q "Accessibility: granted" "$LOG" 2>/dev/null; then
    ok "Accessibility permission granted"
else
    if wait_for_log "Accessibility:" 15; then
        if grep -q "Accessibility: granted" "$LOG" 2>/dev/null; then
            ok "Accessibility permission granted"
        else
            printf "\n"
            info "macOS needs you to grant Accessibility permission."
            info "System Settings should open automatically."
            info "Find ${BOLD}OpenWispr${NC} in the list and toggle it ${BOLD}ON${NC}."
            printf "\n"

            printf "  Waiting for permission"
            while ! grep -q "Accessibility: granted" "$LOG" 2>/dev/null; do
                printf "."
                sleep 2
            done
            printf "\n"
            ok "Accessibility permission granted"
        fi
    else
        fail "Timed out waiting for app to start. Check: tail -f $LOG"
        exit 1
    fi
fi

if grep -q "Downloading" "$LOG" 2>/dev/null; then
    step "Downloading Whisper model"
    info "This is a one-time download (~142 MB)..."
    if wait_for_log "Ready\." 120; then
        ok "Model downloaded"
    else
        fail "Download may still be in progress. Check: tail -f $LOG"
        exit 1
    fi
else
    if ! wait_for_log "Ready\." 30; then
        fail "Timed out waiting for ready state. Check: tail -f $LOG"
        exit 1
    fi
fi

step "open-wispr is running"
hotkey=$(grep "^Hotkey:" "$LOG" 2>/dev/null | tail -1 | sed 's/^Hotkey: //')
model=$(grep "^Model:" "$LOG" 2>/dev/null | tail -1 | sed 's/^Model: //')
version=$(grep "^open-wispr v" "$LOG" 2>/dev/null | tail -1)
[ -n "$version" ] && ok "$version"
[ -n "$hotkey" ] && ok "Hotkey: $hotkey"
[ -n "$model" ] && ok "Model: $model"
printf "\n"
printf "  ${GREEN}Hold your hotkey, speak, release — text appears at cursor.${NC}\n"
printf "\n"
