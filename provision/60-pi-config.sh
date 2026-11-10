#!/usr/bin/env bash
# pi configuration from this repo's pi/ directory, which ./factory provision
# copies to ~/.factory/pi first. Safe to re-run.
#
# - pi/settings.json is merged into ~/.pi/agent/settings.json: keys in the
#   repo win, keys pi wrote itself (last model, etc.) are kept. "packages" is
#   replaced whole, so the repo is the source of truth for what is installed.
# - Everything else in pi/ (AGENTS.md, extensions/, skills/, ...) is copied
#   over the matching path in ~/.pi/agent.
set -euo pipefail
src="$HOME/.factory/pi"
dst="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
[ -d "$src" ] || { echo "no $src: run this via ./factory provision" >&2; exit 1; }
mkdir -p "$dst"

if [ -f "$src/settings.json" ]; then
    cur="$dst/settings.json"
    [ -f "$cur" ] || echo '{}' > "$cur"
    tmp="$(mktemp)"
    jq -s '.[0] * .[1]' "$cur" "$src/settings.json" > "$tmp"
    mv "$tmp" "$cur"
fi
(cd "$src" && find . -mindepth 1 -maxdepth 1 ! -name settings.json -exec cp -R {} "$dst/" \;)

# Install each declared package. `pi update` alone only reconciles packages
# already on disk, so it would skip new ones; `pi install` of an installed
# source is quick and leaves settings.json as is.
jq -r '.packages[]? | if type == "string" then . else .source end' "$dst/settings.json" |
    while read -r pkg; do pi install "$pkg" </dev/null; done
pi list

# herdr's pi extension: reports each pi pane's session to herdr, which Ovis
# needs to show pi as a chat (without it, Ovis shows only the terminal).
# Restart running pi sessions to load it.
export PATH="$HOME/.local/bin:$PATH"
if command -v herdr >/dev/null; then
    herdr integration install pi
fi
