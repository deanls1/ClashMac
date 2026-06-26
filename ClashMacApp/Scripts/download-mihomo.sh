#!/bin/bash
# 下载 Mihomo 内核到 Resources/Core/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_DIR="$ROOT/ClashMac/Resources/Core"
mkdir -p "$CORE_DIR"

ARCH="$(uname -m)"
case "$ARCH" in
  arm64) ASSET="mihomo-darwin-arm64" ;;
  x86_64) ASSET="mihomo-darwin-amd64" ;;
  *) echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  VERSION=$(curl -fsSL "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest" | grep '"tag_name"' | head -1 | sed 's/.*"v\(.*\)".*/\1/')
fi

URL="https://github.com/MetaCubeX/mihomo/releases/download/v${VERSION}/${ASSET}-v${VERSION}.gz"
TMP=$(mktemp)
echo "Downloading $URL ..."
curl -fL "$URL" -o "$TMP"
gunzip -c "$TMP" > "$CORE_DIR/mihomo-darwin-${ARCH}"
chmod +x "$CORE_DIR/mihomo-darwin-${ARCH}"
rm -f "$TMP"
echo "Installed: $CORE_DIR/mihomo-darwin-${ARCH}"
"$CORE_DIR/mihomo-darwin-${ARCH}" -v || true
