#!/bin/bash
set -e

VERSION="$1"
TAG="v${VERSION}"
TAP_DIR="/tmp/homebrew-open-wispr"
FORMULA="${TAP_DIR}/open-wispr.rb"

if [ -z "$VERSION" ]; then
  echo "Usage: update-bottles.sh <version>"
  exit 1
fi

DL_DIR=$(mktemp -d)
trap "rm -rf ${DL_DIR}" EXIT

echo "==> Downloading bottles from release ${TAG}..."
gh release download "${TAG}" --pattern "*.bottle.tar.gz" --dir "${DL_DIR}" --repo human37/open-wispr

BOTTLE_LINES=""

for file in "${DL_DIR}"/*.bottle.tar.gz; do
  filename=$(basename "$file")
  sha=$(shasum -a 256 "$file" | awk '{print $1}')
  if [[ "$filename" == *"arm64_sequoia"* ]]; then
    BOTTLE_LINES="${BOTTLE_LINES}    sha256 cellar: :any, arm64_sequoia: \"${sha}\"\n"
    echo "    arm64_sequoia: ${sha}"
  elif [[ "$filename" == *"ventura"* ]]; then
    BOTTLE_LINES="${BOTTLE_LINES}    sha256 cellar: :any, ventura: \"${sha}\"\n"
    echo "    ventura: ${sha}"
  elif [[ "$filename" == *"sonoma"* ]]; then
    BOTTLE_LINES="${BOTTLE_LINES}    sha256 cellar: :any, sonoma: \"${sha}\"\n"
    echo "    sonoma: ${sha}"
  elif [[ "$filename" == *"sequoia"* ]]; then
    BOTTLE_LINES="${BOTTLE_LINES}    sha256 cellar: :any, sequoia: \"${sha}\"\n"
    echo "    sequoia: ${sha}"
  fi
done

if [ -z "$BOTTLE_LINES" ]; then
  echo "Error: No bottle files found in release ${TAG}"
  exit 1
fi

echo "==> Updating tap formula with bottle SHAs..."

if [ ! -d "${TAP_DIR}" ]; then
  git clone git@github.com:human37/homebrew-open-wispr.git "${TAP_DIR}"
fi
git -C "${TAP_DIR}" pull --rebase

ruby -e '
  formula = File.read(ARGV[0])
  formula.gsub!(/\n  bottle do.*?  end\n/m, "\n")
  bottle = "\n  bottle do\n" \
           "    root_url \"https://github.com/human37/open-wispr/releases/download/'"${TAG}"'\"\n" \
           "'"${BOTTLE_LINES}"'" \
           "  end\n"
  formula.sub!(/^(  license "MIT"\n)/) { $1 + bottle }
  File.write(ARGV[0], formula)
' "$FORMULA"

git -C "${TAP_DIR}" add open-wispr.rb
git -C "${TAP_DIR}" diff --cached --quiet && echo "Tap already up to date." || \
  git -C "${TAP_DIR}" commit -m "Add bottles for ${TAG}"
git -C "${TAP_DIR}" push origin main

echo "==> Bottle update complete"
