#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUICKAUTH_UNIVERSAL=1
export QUICKAUTH_APP_OUTPUT="$PWD/.build/dmg-app/Quick Auth.app"
bash scripts/build-app.sh
lipo "$QUICKAUTH_APP_OUTPUT/Contents/MacOS/QuickAuth" -verify_arch arm64 x86_64
stage="$(mktemp -d "$PWD/.build/dmg-stage.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
ditto "$QUICKAUTH_APP_OUTPUT" "$stage/Quick Auth.app"
ln -s /Applications "$stage/Applications"
mkdir -p dist
dmg="$PWD/dist/Quick-Auth-macOS-universal.dmg"
hdiutil create -volname "Quick Auth" -srcfolder "$stage" -ov -format UDZO "$dmg"
hdiutil verify "$dmg"
echo "Built: $dmg"
