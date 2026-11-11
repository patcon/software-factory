#!/usr/bin/env bash
# T3 Code (https://t3.codes, pingdotgg/t3code): a web GUI for coding agents
# (Claude Code, pi, Codex and others), run as a user service. Separate from
# herdr: it starts its own agent sessions, so they don't show in herdr, Ovis or
# Herdr World. Pinned below; bump VERSION and re-run to update (`t3 update`
# would drift from the pin).
#
# Reachable from your tailnet only. T3 listens on 127.0.0.1:3773, pinned in
# ~/.t3/service.env, and `tailscale serve` publishes that on port 10000 (443 is
# the home page, 8443 Ovis, 9443 Herdr World). Don't use T3's own ways out:
# `--tailscale-serve` takes 443 by default, `--lan` listens on every interface,
# and `t3 up --yes` turns on T3 Connect, its cloud relay.
#
# Each device pairs once: `t3 pair --tailscale --tailscale-serve-port 10000`
# on the VM prints a link and QR code that last 5 minutes. Sessions last 30
# days. Agents must be installed and logged in on the VM (50-claude-code.sh,
# 30-pi.sh); the service finds them through your login shell's PATH.
#
# Not done here, needs a decision: `sudo env "PATH=$PATH" t3 browser setup`
# (changes the host's sandbox policy) for T3's browser tabs and previews.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
VERSION=0.1.9
PORT=3773
TS_PORT=10000

if [ "$(t3 --version 2>/dev/null)" = "t3 v$VERSION" ]; then
    echo "t3 $VERSION already installed"
else
    # Checksummed release download; links t3 into ~/.local/bin.
    curl -fsSL https://t3.codes/install.sh | T3CODE_VERSION="$VERSION" sh
    updated=1
fi
t3 --version

# A user service, so it runs without anyone logged in (hence linger).
sudo loginctl enable-linger "$USER"

# Loopback only. T3CODE_HOST overrides the LAN setting from `t3 up`. Other
# lines in the file are kept.
env_file="$HOME/.t3/service.env"
mkdir -p "$(dirname "$env_file")"
touch "$env_file" && chmod 600 "$env_file"
want="$(printf 'T3CODE_HOST=127.0.0.1\nT3CODE_PORT=%s' "$PORT")"
current="$(grep -E '^T3CODE_(HOST|PORT)=' "$env_file" | sort || true)"
if [ "$current" != "$want" ]; then
    { grep -vE '^T3CODE_(HOST|PORT)=' "$env_file" || true; echo "$want"; } > "$env_file.tmp"
    mv "$env_file.tmp" "$env_file"
    echo "t3: pinned to 127.0.0.1:$PORT"
    updated=1
fi

if ! systemctl --user cat t3code.service >/dev/null 2>&1; then
    t3 service install
elif [ -n "${updated:-}" ]; then
    t3 service restart
fi

for _ in $(seq 30); do
    curl -fs -o /dev/null "http://127.0.0.1:$PORT/" && break
    sleep 1
done
curl -fsS -o /dev/null "http://127.0.0.1:$PORT/"
ss -ltn "sport = :$PORT" | grep -q "127.0.0.1:$PORT" || { echo "t3 is not on 127.0.0.1:$PORT" >&2; exit 1; }

host="$(tailscale status --self --json | jq -r '.Self.DNSName | rtrimstr(".")')"
served="$(sudo tailscale serve status --json 2>/dev/null | jq -r --arg w "$host:$TS_PORT" '.Web[$w].Handlers["/"].Proxy // empty')"
if [ "$served" = "http://127.0.0.1:$PORT" ]; then
    echo "already served to the tailnet"
else
    sudo tailscale serve --bg --https="$TS_PORT" "http://127.0.0.1:$PORT"
fi
echo "t3 code: https://$host:$TS_PORT/"
echo "  pair a device: t3 pair --tailscale --tailscale-serve-port $TS_PORT"
