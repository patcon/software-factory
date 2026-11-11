#!/usr/bin/env bash
# Herdr World (https://herdr.world): a browser control plane for herdr, showing
# which agents need you. A third-party project (IvoryHeart/herdr-world), not
# herdr itself. Pinned below; bump VERSION and re-run to update.
#
# Reachable from your tailnet only. World listens on 127.0.0.1:8787, and
# `tailscale serve` publishes that to the tailnet over HTTPS on port 9443 (the
# home page from 85-home.sh has 443, Ovis 8443). Serve, not funnel: nothing is
# public. World also wants its own login token on top, in
# ~/.config/herdr-world/auth-token on the VM.
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
TS_PORT=9443

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
# Browsers leave :443 out of the origin, so it must be left out here too.
origin="https://$host"
[ "$TS_PORT" = 443 ] || origin="$origin:$TS_PORT"
want="$(printf '[Service]\nEnvironment=HERDR_WORLD_PUBLIC_ORIGIN=%s' "$origin")"
mkdir -p "$(dirname "$dropin")"
if [ "$(cat "$dropin" 2>/dev/null)" != "$want" ]; then
    echo "$want" > "$dropin"
    systemctl --user daemon-reload
    before=changed
fi

# Price table for the expenses boards: World counts tokens from agent session
# logs but ships no prices, so costs read "no price table" without one.
# Anthropic API list prices, USD per million tokens, from
# https://platform.claude.com/docs/en/about-claude/pricing (2026-11-10).
# These estimate what the usage would cost on the API, not a subscription
# bill. World has one cache_write rate, so this uses the 5-minute write
# price (1-hour writes cost more). Haiku 5.5 uses its up-to-100K-token
# prompt rates. Model names must match the logs exactly. Change a rate:
# edit here, bump "version", re-run.
prices='{
  "version": "anthropic-2026-11-10",
  "models": {
    "claude-fable-5-2":  {"input": 8,   "cache_read": 0.2,  "cache_write": 10,    "output": 40},
    "claude-opus-5-5":   {"input": 4,   "cache_read": 0.2,  "cache_write": 5,     "output": 20},
    "claude-sonnet-5-5": {"input": 2,   "cache_read": 0.1,  "cache_write": 2.5,   "output": 10},
    "claude-haiku-5-5":  {"input": 0.1, "cache_read": 0.01, "cache_write": 0.125, "output": 0.5}
  }
}'
# World reads settings.json once and rewrites it from memory when the UI
# saves, so stop it before merging the table in. Its other settings are kept.
settings="${XDG_CONFIG_HOME:-$HOME/.config}/herdr-world/settings.json"
current="$(cat "$settings" 2>/dev/null || echo '{}')"
merged="$(jq --argjson p "$prices" '.custom.world_usage_prices_v1 = $p' <<<"$current")"
if [ "$(jq -S . <<<"$current")" != "$(jq -S . <<<"$merged")" ]; then
    systemctl --user stop herdr-world 2>/dev/null || true
    (umask 077 && echo "$merged" > "$settings.tmp") && mv "$settings.tmp" "$settings"
    echo "herdr-world: price table $(jq -r .version <<<"$prices")"
    before=changed
fi

if ! systemctl --user cat herdr-world >/dev/null 2>&1; then
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

# Checks the port too, so a VM that had World on 443 moves to 9443 (and
# 85-home.sh then takes 443 over).
served="$(sudo tailscale serve status --json 2>/dev/null | jq -r --arg w "$host:$TS_PORT" '.Web[$w].Handlers["/"].Proxy // empty')"
if [ "$served" = "http://127.0.0.1:$PORT" ]; then
    echo "already served to the tailnet"
else
    sudo tailscale serve --bg --https="$TS_PORT" "http://127.0.0.1:$PORT"
fi
# `herdr-world url --address` builds a broken link behind a proxy, so say
# where the token is instead of printing it.
echo "herdr world: $origin/?token=\$(cat ~/.config/herdr-world/auth-token)"
