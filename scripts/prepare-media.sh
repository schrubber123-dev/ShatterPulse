#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rm -rf "$ROOT/ShatterPulse/Media"
unzip -q "$ROOT/media-src/Media.zip" -d "$ROOT/ShatterPulse"
echo "ShatterPulse media prepared in ShatterPulse/Media"
