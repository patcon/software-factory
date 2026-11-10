#!/usr/bin/env bash
# Claude Code (https://claude.com/claude-code), via the native installer:
# a standalone binary in ~/.local/bin, no Node needed. Safe to re-run: updates
# an existing install instead.
#
# Log in once on the VM: ssh in, run `claude`, and follow the login prompt
# (it gives you a URL to open locally and a code to paste back).
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

if command -v claude >/dev/null; then
    claude update || true
else
    curl -fsSL https://claude.ai/install.sh | bash
fi
claude --version
