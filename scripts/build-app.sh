#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_args=()
if [[ "${QUICKAUTH_UNIVERSAL:-0}" == "1" ]]; then
  build_args=(--arch arm64 --arch x86_64)
fi
bash scripts/swift.sh build -c release "${build_args[@]}"
binary_dir="$(bash scripts/swift.sh build -c release "${build_args[@]}" --show-bin-path)"
app_dir="${QUICKAUTH_APP_OUTPUT:-$PWD/dist/Quick Auth.app}"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/QuickAuth" "$app_dir/Contents/MacOS/QuickAuth.new"
mv "$app_dir/Contents/MacOS/QuickAuth.new" "$app_dir/Contents/MacOS/QuickAuth"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp Sources/CArgon2/LICENSE "$app_dir/Contents/Resources/Argon2-LICENSE.txt"
if [[ -f Resources/AppIcon.icns ]]; then cp Resources/AppIcon.icns "$app_dir/Contents/Resources/"; fi
codesign --force --sign "${QUICKAUTH_SIGNING_IDENTITY:--}" --identifier local.quickauth.app "$app_dir"
codesign --verify --strict "$app_dir"
echo "Built: $app_dir"
