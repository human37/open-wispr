#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: deploy.sh <version>"
  echo "Example: deploy.sh 0.9.1"
  exit 1
fi

VERSION="$1"
TAG="v${VERSION}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TAP_DIR="/tmp/homebrew-open-wispr"

echo "==> Deploying open-wispr ${TAG}"

current=$(grep 'static let version' "${REPO_DIR}/Sources/OpenWispr/main.swift" | sed 's/.*"\(.*\)".*/\1/')
if [ "$current" != "$VERSION" ]; then
  echo "Error: main.swift version is ${current}, expected ${VERSION}"
  echo "Update Sources/OpenWispr/main.swift first."
  exit 1
fi

echo "==> Building release..."
swift build --package-path "${REPO_DIR}" -c release --disable-sandbox

echo "==> Committing, tagging, and pushing main repo..."
git -C "${REPO_DIR}" add -A
git -C "${REPO_DIR}" diff --cached --quiet && echo "Nothing to commit in main repo." || \
  git -C "${REPO_DIR}" commit -m "${TAG}: $(git -C "${REPO_DIR}" log -1 --format=%s)"
git -C "${REPO_DIR}" tag -f "${TAG}"
git -C "${REPO_DIR}" push origin main --tags

echo "==> Updating tap formula..."
if [ ! -d "${TAP_DIR}" ]; then
  git clone git@github.com:human37/homebrew-open-wispr.git "${TAP_DIR}"
fi
git -C "${TAP_DIR}" pull --rebase
sed -i '' "s|tag: \"v[^\"]*\"|tag: \"${TAG}\"|" "${TAP_DIR}/open-wispr.rb"
git -C "${TAP_DIR}" add open-wispr.rb
git -C "${TAP_DIR}" diff --cached --quiet && echo "Tap already up to date." || \
  git -C "${TAP_DIR}" commit -m "Bump to ${TAG}"
git -C "${TAP_DIR}" push origin main

echo ""
echo "==> Deployed ${TAG}"
echo "Users can update with: brew update && brew upgrade open-wispr"
