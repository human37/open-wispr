#!/bin/bash
set -uo pipefail

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

INSTALLER_TRUST_TMPDIR=""

cleanup_installer_trust() {
    if [ -n "$INSTALLER_TRUST_TMPDIR" ]; then
        rm -rf "$INSTALLER_TRUST_TMPDIR"
    fi
}

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

run_stubbed_installer() {
    local failure_mode="$1"

    PATH="$INSTALLER_TRUST_TMPDIR/bin:$PATH" \
    HOME="$INSTALLER_TRUST_TMPDIR/home" \
    OPEN_WISPR_TEST_TAP_DIR="$INSTALLER_TRUST_TMPDIR/tap" \
    OPEN_WISPR_TEST_PREFIX_DIR="$INSTALLER_TRUST_TMPDIR/prefix" \
    OPEN_WISPR_TEST_BREW_FAILURE="$failure_mode" \
    bash scripts/install.sh 2>&1
}

check_trust_failure_output() {
    local description="$1"
    local output="$2"
    local status="$3"

    if [ "$status" -eq 0 ]; then
        fail "$description exits non-zero"
    elif echo "$output" | grep -q "binary not found"; then
        fail "$description does not fall through to binary-not-found"
    elif ! echo "$output" | grep -q "tap is not trusted"; then
        fail "$description explains Homebrew trust"
    elif ! echo "$output" | grep -q -- "brew trust --formula human37/open-wispr/open-wispr"; then
        fail "$description prints remediation command"
    else
        pass "$description prints remediation without binary fallback"
    fi
}

run_installer_trust_test() {
    local output
    local status

    INSTALLER_TRUST_TMPDIR=$(mktemp -d /tmp/open-wispr-installer-trust.XXXXXX)

    mkdir -p "$INSTALLER_TRUST_TMPDIR/bin" "$INSTALLER_TRUST_TMPDIR/home" "$INSTALLER_TRUST_TMPDIR/tap"

    cat > "$INSTALLER_TRUST_TMPDIR/bin/uname" <<'STUB'
#!/bin/bash
if [ "${1:-}" = "-m" ]; then
    echo "arm64"
    exit 0
fi
exec /usr/bin/uname "$@"
STUB

    cat > "$INSTALLER_TRUST_TMPDIR/bin/brew" <<'STUB'
#!/bin/bash
set -u

print_trust_error() {
    echo "Error: Cannot install human37/open-wispr/open-wispr because its tap is not trusted" >&2
    echo "To trust this formula, run:" >&2
    echo "  brew trust --formula human37/open-wispr/open-wispr" >&2
}

case "${1:-}" in
    list)
        exit 1
        ;;
    tap)
        exit 0
        ;;
    --repository)
        if [ "${2:-}" = "human37/open-wispr" ]; then
            echo "${OPEN_WISPR_TEST_TAP_DIR:?}"
            exit 0
        fi
        ;;
    install)
        if [ "${2:-}" = "open-wispr" ]; then
            case "${OPEN_WISPR_TEST_BREW_FAILURE:-install-trust}" in
                install-trust)
                    print_trust_error
                    exit 1
                    ;;
                reinstall-trust)
                    exit 0
                    ;;
                generic)
                    echo "Error: failed to download bottle" >&2
                    exit 1
                    ;;
            esac
        fi
        ;;
    reinstall)
        if [ "${2:-}" = "open-wispr" ]; then
            case "${OPEN_WISPR_TEST_BREW_FAILURE:-install-trust}" in
                reinstall-trust)
                    print_trust_error
                    exit 1
                    ;;
                generic)
                    echo "Error: failed to download bottle" >&2
                    exit 1
                    ;;
                *)
                    exit 0
                    ;;
            esac
        fi
        ;;
    --prefix)
        if [ "${2:-}" = "open-wispr" ]; then
            echo "${OPEN_WISPR_TEST_PREFIX_DIR:?}"
            exit 0
        fi
        ;;
esac

echo "unexpected brew invocation: $*" >&2
exit 1
STUB

    chmod +x "$INSTALLER_TRUST_TMPDIR/bin/uname" "$INSTALLER_TRUST_TMPDIR/bin/brew"

    output=$(run_stubbed_installer install-trust)
    status=$?
    check_trust_failure_output "installer trust error from brew install" "$output" "$status"

    output=$(run_stubbed_installer reinstall-trust)
    status=$?
    check_trust_failure_output "installer trust error from brew reinstall" "$output" "$status"

    output=$(run_stubbed_installer generic)
    status=$?

    if [ "$status" -eq 0 ]; then
        fail "generic installer failure exits non-zero"
    elif ! echo "$output" | grep -q "binary not found"; then
        fail "generic installer failure keeps binary-not-found fallback"
    elif echo "$output" | grep -q "brew trust"; then
        fail "generic installer failure does not print trust remediation"
    else
        pass "generic installer failure keeps binary fallback"
    fi

    cleanup_installer_trust
}

if [ "${1:-}" = "--installer-trust" ]; then
    echo "open-wispr installer trust test"
    echo "-------------------------------"
    run_installer_trust_test
    echo ""
    echo "-------------------------------"
    echo "Results: $PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ] || exit 1
    exit 0
fi

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
echo "Testing installer trust handling..."
run_installer_trust_test

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
check_output "status shows toggle mode" "Toggle:" "$BIN" status
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
    for script in scripts/*.sh; do
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
