#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

step() { printf "\n  ${BLUE}${BOLD}%s${NC}\n" "$1"; }
ok()   { printf "  ${GREEN}✓${NC} %s\n" "$1"; }

printf "\n"
printf "  ${BOLD}open-wispr${NC} ${DIM}— uninstall${NC}\n"
printf "  ${DIM}────────────────────────────────────────────${NC}\n"

step "Stopping service"
brew services stop open-wispr 2>/dev/null || true
pkill -f "open-wispr start" 2>/dev/null || true
sleep 1
ok "Stopped"

step "Removing formula and tap"
brew uninstall --force open-wispr 2>/dev/null || true
brew untap human37/open-wispr 2>/dev/null || true
ok "Removed"

step "Removing app bundle"
rm -rf ~/Applications/OpenWispr.app
rm -rf /Applications/OpenWispr.app 2>/dev/null || true
ok "Removed"

step "Removing config, model, and logs"
rm -rf ~/.config/open-wispr
rm -f /opt/homebrew/var/log/open-wispr.log 2>/dev/null || true
defaults delete com.human37.open-wispr 2>/dev/null || true
rm -f ~/Library/Preferences/com.human37.open-wispr.plist 2>/dev/null || true
ok "Removed"

step "Resetting privacy permissions"
tccutil reset Accessibility com.human37.open-wispr 2>/dev/null || true
tccutil reset Microphone com.human37.open-wispr 2>/dev/null || true
tccutil reset ScreenCapture com.human37.open-wispr 2>/dev/null || true
ok "Reset"

step "Unregistering from LaunchServices"
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -u ~/Applications/OpenWispr.app 2>/dev/null || true
ok "Unregistered"

printf "\n"
printf "  ${DIM}────────────────────────────────────────────${NC}\n"
printf "  ${GREEN}${BOLD}Uninstalled.${NC}\n"
printf "\n"
printf "  To reinstall:\n"
printf "  ${BOLD}curl -fsSL https://raw.githubusercontent.com/human37/open-wispr/main/scripts/install.sh | bash${NC}\n"
printf "\n"
