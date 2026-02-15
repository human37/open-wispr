#!/bin/bash
set -euo pipefail

echo "Uninstalling OpenWispr..."

echo "  Stopping service..."
brew services stop open-wispr 2>/dev/null || true

echo "  Removing formula..."
brew uninstall open-wispr 2>/dev/null || true

echo "  Removing tap..."
brew untap human37/open-wispr 2>/dev/null || true

echo "  Removing config and model..."
rm -rf ~/.config/open-wispr

echo "  Removing app bundle..."
rm -f ~/Applications/OpenWispr.app
rm -f /Applications/OpenWispr.app 2>/dev/null || true

echo "  Removing logs..."
rm -f /opt/homebrew/var/log/open-wispr.log

echo ""
echo "OpenWispr has been completely uninstalled."
