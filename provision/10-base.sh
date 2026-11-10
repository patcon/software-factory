#!/usr/bin/env bash
# Base packages. Runs as the login user over SSH; safe to re-run.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update -q
sudo apt-get install -yq git curl ca-certificates build-essential unzip jq ripgrep tmux

# Fresh Ubuntu cloud images may queue unattended upgrades; finish them now.
sudo apt-get upgrade -yq

mkdir -p "$HOME/.local/bin"
grep -q 'HOME/.local/bin' "$HOME/.bashrc" \
    || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
