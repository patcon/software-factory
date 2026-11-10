#!/usr/bin/env bash
# Ovis (https://github.com/devswha/ovis): browser and phone client for herdr,
# as a herdr plugin. Safe to re-run: skips what is already there. Updates go
# through the app (Settings -> About).
#
# Reachable from your tailnet only. Ovis listens on 127.0.0.1:7317 (its
# default, never changed here), and `tailscale serve` publishes that to the
# tailnet over HTTPS. Serve, not funnel: nothing is public. Ovis lets in your
# own Tailscale login and refuses other people's.
#
# Needs 20-herdr.sh and 40-tailscale.sh first, and herdr running (it is, once
# you have connected with ./factory herdr).
set -euo pipefail
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
PLUGIN=devswha.ovis

# Bun builds and runs the plugin. herdr runs the build with its own PATH, so
# link bun into ~/.local/bin, which every shell here already has.
if ! command -v bun >/dev/null; then
    curl -fsSL https://bun.sh/install | bash
fi
ln -sf "$HOME/.bun/bin/bun" "$HOME/.local/bin/bun"
bun --version

herdr status server >/dev/null || { echo "herdr is not running: connect once with ./factory herdr, then re-run" >&2; exit 1; }

if herdr plugin list | grep -q "$PLUGIN"; then
    echo "ovis already installed"
else
    herdr plugin install devswha/ovis --yes
    herdr plugin action invoke "$PLUGIN.start" >/dev/null
fi

# Usage counts: SF_OVIS_TELEMETRY from factory.env, into the plugin's env file
# (plugin settings don't come from the shell). Restart only on a change.
env_file="$(herdr plugin config-dir "$PLUGIN")/env"
want="OVIS_TELEMETRY=${SF_OVIS_TELEMETRY:-1}"
touch "$env_file" && chmod 600 "$env_file"
if ! grep -qx "$want" "$env_file"; then
    { grep -v '^OVIS_TELEMETRY=' "$env_file" || true; echo "$want"; } > "$env_file.tmp"
    mv "$env_file.tmp" "$env_file"
    herdr plugin action invoke "$PLUGIN.stop" >/dev/null
    sleep 2
    herdr plugin action invoke "$PLUGIN.start" >/dev/null
    echo "ovis: set $want"
fi

for _ in $(seq 30); do
    curl -fs http://127.0.0.1:7317/api/health >/dev/null && break
    sleep 1
done
curl -fs http://127.0.0.1:7317/api/health | jq -c '{ok, herdr: .herdr.version}'

if sudo tailscale serve status 2>/dev/null | grep -q '127.0.0.1:7317'; then
    echo "already served to the tailnet"
else
    sudo tailscale serve --bg --https=443 http://127.0.0.1:7317
fi
echo "ovis: https://$(tailscale status --self --json | jq -r '.Self.DNSName | rtrimstr(".")')"
