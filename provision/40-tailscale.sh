#!/usr/bin/env bash
# Tailscale, joined to your tailnet as "$(hostname)". Safe to re-run: skips the
# install if present (10-base.sh's apt upgrade keeps it current) and skips the
# login if already connected.
#
# Login: set TS_AUTHKEY in scripts/local.env for a hands-off join. Without it,
# this prints a login URL to open in your browser and waits for you.
set -euo pipefail

if ! command -v tailscale >/dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
fi
sudo systemctl enable --now tailscaled

if tailscale status >/dev/null 2>&1; then
    echo "tailscale already connected: $(tailscale ip -4)"
    exit 0
fi

UP=(sudo tailscale up --hostname="$(hostname)" --timeout=10m)
if [ -n "${TS_AUTHKEY:-}" ]; then
    "${UP[@]}" --auth-key="$TS_AUTHKEY"
else
    echo ">>> open the login URL below to add this VM to your tailnet"
    "${UP[@]}"
fi
echo "tailscale connected: $(tailscale ip -4)"
