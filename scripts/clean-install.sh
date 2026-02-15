#!/bin/bash
set -e

echo "==> Stopping open-wispr service..."
brew services stop open-wispr 2>/dev/null || true

echo "==> Uninstalling open-wispr..."
brew uninstall open-wispr 2>/dev/null || true

echo "==> Removing tap..."
brew untap human37/open-wispr 2>/dev/null || true

echo "==> Resetting Accessibility permission for open-wispr..."
tccutil reset Accessibility com.human37.open-wispr 2>/dev/null || true

echo "==> Removing OpenWispr.app symlink..."
rm -rf ~/Applications/OpenWispr.app

echo "==> Tapping human37/open-wispr..."
brew tap human37/open-wispr

echo "==> Installing open-wispr..."
brew install open-wispr

echo "==> Starting open-wispr service..."
brew services start open-wispr

echo ""
echo "Done! Grant Accessibility permission when prompted."
echo "Logs: tail -f /opt/homebrew/var/log/open-wispr.log"
