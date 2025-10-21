#!/usr/bin/env bash
set -euo pipefail
CURR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHS=("arm64" "arm" "386" "amd64")
for GOARCH in "${ARCHS[@]}"; do
    echo "Building for GOARCH=$GOARCH..."
    GOARCH="$GOARCH" bash "$CURR_DIR/builder.sh" all
done
echo "Builds completed. Cleaning up..."
shopt -s extglob
cd "$CURR_DIR"
rm -rf !(*.sh|workflows)
echo "Cleanup done."
