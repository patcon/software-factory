#!/usr/bin/env bash
# herdr: terminal workspace manager for coding agents (https://herdr.dev).
# The TUI installer, not the desktop app one at releases.herdr.dev.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

if command -v herdr >/dev/null; then
    herdr update || true
else
    curl -fsSL https://herdr.dev/install.sh | sh
fi
herdr --version
