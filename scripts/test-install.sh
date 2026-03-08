#!/bin/bash
set -uo pipefail

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

check_output() {
    local description="$1"
    local pattern="$2"
    shift 2
    local output
    output=$("$@" 2>&1 || true)
    if echo "$output" | grep -q "$pattern"; then
        pass "$description"
    else
        fail "$description"
    fi
}

CONFIG_FILE="$HOME/.config/open-wispr/config.json"
CONFIG_BACKUP=""

backup_config() {
    if [ -f "$CONFIG_FILE" ]; then
        CONFIG_BACKUP=$(mktemp /tmp/open-wispr-config-backup.XXXXXX)
        cp "$CONFIG_FILE" "$CONFIG_BACKUP"
    fi
}

restore_config() {
    if [ -n "$CONFIG_BACKUP" ] && [ -f "$CONFIG_BACKUP" ]; then
        cp "$CONFIG_BACKUP" "$CONFIG_FILE"
        rm -f "$CONFIG_BACKUP"
    fi
}

echo "open-wispr install smoke tests"
echo "-------------------------------"

echo ""
echo "Building..."
swift build -c release 2>&1 | tail -1

BIN=".build/release/open-wispr"

if [ -x "$BIN" ]; then
    pass "Binary is executable"
else
    fail "Binary not found at $BIN"
    exit 1
fi

check_output "--help shows usage" "Push-to-talk" "$BIN" --help
check_output "status shows version" "open-wispr v" "$BIN" status
check_output "status shows config path" "Config:" "$BIN" status
check_output "get-hotkey works" "Current hotkey:" "$BIN" get-hotkey

backup_config
trap restore_config EXIT

check_output "set-hotkey f5 works" "Hotkey set to: f5" "$BIN" set-hotkey f5
check_output "set-hotkey ctrl+space works" "Hotkey set to: ctrl+space" "$BIN" set-hotkey ctrl+space
check_output "set-hotkey rejects invalid key" "Unknown key" "$BIN" set-hotkey invalidkey
check_output "set-model rejects invalid model" "Unknown model" "$BIN" set-model fakemodel
check_output "unknown command shows error" "Unknown command" "$BIN" badcommand

restore_config
trap - EXIT

echo ""
echo "Testing app bundle..."
bash scripts/bundle-app.sh "$BIN" /tmp/OpenWisprTest.app 0.0.0-test

if [ -x "/tmp/OpenWisprTest.app/Contents/MacOS/open-wispr" ]; then
    pass "App bundle has executable"
else
    fail "App bundle missing executable"
fi

if [ -f "/tmp/OpenWisprTest.app/Contents/Info.plist" ]; then
    pass "App bundle has Info.plist"
else
    fail "App bundle missing Info.plist"
fi

if grep -q "com.human37.open-wispr" /tmp/OpenWisprTest.app/Contents/Info.plist; then
    pass "Info.plist has correct bundle ID"
else
    fail "Info.plist wrong bundle ID"
fi

rm -rf /tmp/OpenWisprTest.app

if command -v shellcheck &>/dev/null; then
    echo ""
    echo "Shellcheck..."
    SCRIPTS=(scripts/install.sh scripts/uninstall.sh scripts/deploy.sh scripts/dev.sh scripts/bundle-app.sh)
    for script in "${SCRIPTS[@]}"; do
        if [ -f "$script" ]; then
            if shellcheck --severity=warning "$script" 2>&1; then
                pass "shellcheck $script"
            else
                fail "shellcheck $script"
            fi
        fi
    done
else
    echo ""
    echo "Shellcheck not installed, skipping (brew install shellcheck)"
fi

echo ""
echo "-------------------------------"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
