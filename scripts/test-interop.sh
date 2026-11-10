#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUICKAUTH_INTEROP_DIR="$PWD/.build/interop"
mkdir -p "$QUICKAUTH_INTEROP_DIR"
node windows/test/interop.cjs create
bash scripts/swift.sh test --filter CrossPlatformTests
node windows/test/interop.cjs verify
