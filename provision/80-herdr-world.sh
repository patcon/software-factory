#!/usr/bin/env bash
# Herdr World (https://herdr.world): a browser control plane for herdr, showing
# which agents need you. A third-party project (IvoryHeart/herdr-world), not
# herdr itself. Pinned below; bump VERSION and re-run to update.
#
# Reachable from your tailnet only. World listens on 127.0.0.1:8787, and
# `tailscale serve` publishes that to the tailnet over HTTPS on port 8443
# (Ovis has 443). Serve, not funnel: nothing is public. World also wants its
# own login token on top, in ~/.config/herdr-world/auth-token on the VM.
#
# Its installer is told to leave herdr alone (20-herdr.sh owns it) and not to
# sync harness skills: that sync writes into every agent config folder it
# finds, including ~/.factory, which is this repo's, not Droid's.
#
# Needs 20-herdr.sh and 40-tailscale.sh first, and herdr running.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
VERSION=0.3.0
PORT=8787
TS_PORT=8443

herdr status server >/dev/null || { echo "herdr is not running: connect once with ./factory herdr, then re-run" >&2; exit 1; }

if [ "$(herdr-world --version 2>/dev/null)" = "herdr-world $VERSION" ]; then
    echo "herdr-world $VERSION already installed"
else
    curl -fsSL "https://github.com/IvoryHeart/herdr-world/releases/download/v$VERSION/install-herdr-world.sh" \
        | HERDR_WORLD_VERSION="$VERSION" HERDR_WORLD_SKIP_HERDR=1 HERDR_WORLD_SKIP_INTEGRATIONS=1 sh
fi

# A user service, so it runs without anyone logged in (hence linger).
sudo loginctl enable-linger "$USER"

# The service defaults to 0.0.0.0. Pin loopback before it ever starts.
env_file="$(herdr-world config path)"
before="$(cat "$env_file" 2>/dev/null || true)"
herdr-world config set HOST=127.0.0.1 PORT="$PORT"
[ "$(herdr-world config get HOST)" = 127.0.0.1 ] || { echo "herdr-world: HOST is not 127.0.0.1, not starting it" >&2; exit 1; }

# Behind a proxy, World refuses logins (403) unless told the one external
# origin browsers use. `config set` won't take HERDR_WORLD_PUBLIC_ORIGIN in
# 0.3.0, so it goes in a systemd drop-in, which survives `service install`.
host="$(tailscale status --self --json | jq -r '.Self.DNSName | rtrimstr(".")')"
dropin="$HOME/.config/systemd/user/herdr-world.service.d/public-origin.conf"
want="$(printf '[Service]\nEnvironment=HERDR_WORLD_PUBLIC_ORIGIN=https://%s:%s' "$host" "$TS_PORT")"
mkdir -p "$(dirname "$dropin")"
if [ "$(cat "$dropin" 2>/dev/null)" != "$want" ]; then
    echo "$want" > "$dropin"
    systemctl --user daemon-reload
    before=changed
fi

if ! herdr-world service status >/dev/null 2>&1; then
    herdr-world service install >/dev/null
elif [ "$before" != "$(cat "$env_file")" ]; then
    herdr-world service restart >/dev/null
fi

for _ in $(seq 30); do
    curl -fs "http://127.0.0.1:$PORT/healthz" >/dev/null && break
    sleep 1
done
curl -fsS "http://127.0.0.1:$PORT/healthz" >/dev/null
ss -ltn "sport = :$PORT" | grep -q "127.0.0.1:$PORT" || { echo "herdr-world is not on 127.0.0.1:$PORT" >&2; exit 1; }

if sudo tailscale serve status 2>/dev/null | grep -q "127.0.0.1:$PORT"; then
    echo "already served to the tailnet"
else
    sudo tailscale serve --bg --https="$TS_PORT" "http://127.0.0.1:$PORT"
fi
# `herdr-world url --address` builds a broken link behind a proxy, so say
# where the token is instead of printing it.
echo "herdr world: https://$host:$TS_PORT/?token=\$(cat ~/.config/herdr-world/auth-token)"
