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

ARM64_SHA=""
INTEL_SHA=""

for file in "${DL_DIR}"/*.bottle.tar.gz; do
  filename=$(basename "$file")
  sha=$(shasum -a 256 "$file" | awk '{print $1}')
  if [[ "$filename" == *"arm64_sequoia"* ]]; then
    ARM64_SHA="$sha"
  elif [[ "$filename" == *"ventura"* ]]; then
    INTEL_SHA="$sha"
  fi
done

if [ -z "$ARM64_SHA" ] || [ -z "$INTEL_SHA" ]; then
  echo "Error: Missing bottle files. Found:"
  command ls "${DL_DIR}"
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
           "    sha256 cellar: :any, arm64_sequoia: \"'"${ARM64_SHA}"'\"\n" \
           "    sha256 cellar: :any, ventura: \"'"${INTEL_SHA}"'\"\n" \
           "  end\n"
  formula.sub!(/^(  license "MIT"\n)/) { $1 + bottle }
  File.write(ARGV[0], formula)
' "$FORMULA"

git -C "${TAP_DIR}" add open-wispr.rb
git -C "${TAP_DIR}" diff --cached --quiet && echo "Tap already up to date." || \
  git -C "${TAP_DIR}" commit -m "Add bottles for ${TAG}"
git -C "${TAP_DIR}" push origin main

echo "==> Bottle update complete"
echo "    arm64_sequoia: ${ARM64_SHA}"
echo "    ventura: ${INTEL_SHA}"
