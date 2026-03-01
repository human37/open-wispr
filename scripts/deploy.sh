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

echo "==> Generating release notes..."
PREV_TAG=$(git -C "${REPO_DIR}" describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
if [ -n "$PREV_TAG" ]; then
  COMMITS=$(git -C "${REPO_DIR}" log "${PREV_TAG}..HEAD" --pretty=format:"- %s" --no-merges)
else
  COMMITS=$(git -C "${REPO_DIR}" log --pretty=format:"- %s" --no-merges -20)
fi

NOTES=$(claude -p "You are writing release notes for open-wispr ${TAG}, a local voice dictation app for macOS. Here are the commits since the last release:

${COMMITS}

Write concise GitHub release notes in markdown. Use these sections only if relevant: ### What's New, ### Bug Fixes, ### Other Changes. Use bullet points. Don't include commit hashes. Keep it short and user-facing — skip internal/dev-only changes. End with a one-liner upgrade instruction: brew update && brew upgrade open-wispr")

echo "==> Creating GitHub Release..."
gh release create "${TAG}" --repo human37/open-wispr --notes "${NOTES}"

echo "==> Waiting for bottle builds..."
sleep 15
RUN_ID=""
for i in $(seq 1 30); do
  RUN_ID=$(gh run list --workflow=build-bottle.yml --event=release --limit=1 --json databaseId --jq '.[0].databaseId' --repo human37/open-wispr 2>/dev/null)
  if [ -n "$RUN_ID" ]; then
    break
  fi
  sleep 5
done

if [ -z "$RUN_ID" ]; then
  echo "Warning: Could not find bottle build workflow. Skipping bottle update."
  echo "Run 'bash scripts/update-bottles.sh ${VERSION}' manually after bottles are built."
else
  echo "==> Watching bottle build (run ${RUN_ID})..."
  gh run watch "$RUN_ID" --repo human37/open-wispr
  bash "${REPO_DIR}/scripts/update-bottles.sh" "$VERSION"
fi

echo ""
echo "==> Deployed ${TAG}"
echo "Users can update with: brew update && brew upgrade open-wispr"
