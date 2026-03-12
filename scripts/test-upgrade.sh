#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

APP_DIR=~/Applications/OpenWispr.app
SERVICE_LOG=/opt/homebrew/var/log/open-wispr.log

step() { printf "\n${BOLD}==> %s${NC}\n" "$1"; }
ok()   { printf "  ${GREEN}✓${NC} %s\n" "$1"; }
info() { printf "  ${DIM}%s${NC}\n" "$1"; }
fail() { printf "  ${RED}✗${NC} %s\n" "$1"; }

build_and_install() {
    local label="$1"
    step "Building ($label)"
    swift build -c release 2>&1 | tail -1

    info "Bundling app..."
    bash scripts/bundle-app.sh .build/release/open-wispr OpenWispr.app dev

    info "Copying to ~/Applications (same as post_install)..."
    mkdir -p ~/Applications
    rm -rf "$APP_DIR"
    cp -R OpenWispr.app "$APP_DIR"
    rm -rf OpenWispr.app

    /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP_DIR"
    ok "Installed to $APP_DIR"
}

wait_for_log() {
    local pattern="$1"
    local timeout="${2:-30}"
    local elapsed=0
    while [ $elapsed -lt "$timeout" ]; do
        if grep -q "$pattern" "$SERVICE_LOG" 2>/dev/null; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 1
}

print_service_log() {
    printf "\n  ${DIM}--- Service log (last 15 lines) ---${NC}\n"
    tail -15 "$SERVICE_LOG" 2>/dev/null | sed 's/^/  /'
    printf "  ${DIM}-----------------------------------${NC}\n"
}

# ── Phase 1: Establish baseline ──────────────────────────────────────
step "Stopping any running instances"
brew services stop open-wispr 2>/dev/null || true
pkill -f "open-wispr start" 2>/dev/null || true
sleep 1
ok "Stopped"

build_and_install "baseline"

step "Starting via brew services (baseline)"
> "$SERVICE_LOG" 2>/dev/null || true
brew services start open-wispr 2>/dev/null || true

if wait_for_log "Ready\." 30; then
    ok "App is ready"
    print_service_log
else
    fail "App did not reach Ready state within 30s"
    print_service_log
    info "If waiting for permissions, grant them now and re-run."
    exit 1
fi

brew services stop open-wispr 2>/dev/null || true
sleep 1

# ── Phase 2: Simulate upgrade ───────────────────────────────────────
step "Simulating upgrade"
info "Modifying source to produce a different binary..."
VERSION_FILE="Sources/OpenWisprLib/Version.swift"
cp "$VERSION_FILE" "${VERSION_FILE}.bak"
printf 'public enum OpenWispr {\n    public static let version = "0.19.0-test"\n}\n' > "$VERSION_FILE"

build_and_install "upgrade"

mv "${VERSION_FILE}.bak" "$VERSION_FILE"

step "Starting via brew services (upgrade)"
> "$SERVICE_LOG" 2>/dev/null || true
brew services start open-wispr 2>/dev/null || true

if wait_for_log "Ready\." 30; then
    ok "App is ready"
else
    fail "App did not reach Ready state within 30s"
    info "Check if it's waiting for permissions — that means the upgrade broke them."
fi

print_service_log

# ── Results ──────────────────────────────────────────────────────────
printf "\n${BOLD}What to check in the upgrade log:${NC}\n"
printf "  - 'Accessibility: granted' without 'Waiting for' = permissions survived\n"
printf "  - 'Waiting for Accessibility' = upgrade broke permissions (bad)\n"
printf "  - 'upgrade detected' = binary hash change was detected\n"
printf "\n"

step "Cleaning up"
brew services stop open-wispr 2>/dev/null || true
ok "Done"
