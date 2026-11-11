#!/usr/bin/env bash
# T3 Office (https://github.com/felixgollnhuber/t3-office): T3 Code's threads
# as pixel-art coworkers in a three.js office. An unofficial fan project, read
# only: it reads ~/.t3 (SQLite, opened read-only) and the Claude and Codex
# transcripts for its cost view, and writes nothing to T3. Pinned to a commit
# (it has no releases); bump COMMIT and re-run to update.
#
# Reachable from your tailnet only. Its Vite preview server listens on
# localhost:5173 (with its own bridge on 127.0.0.1), and `tailscale serve`
# publishes that on port 10001. Vite refuses requests for hosts it doesn't
# know, so the tailnet name is allowed through Vite's
# __VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS. No login: anyone on your tailnet who
# can reach the port sees thread titles and costs, nothing more.
#
# Installed with npm, as its lockfile is npm's, without dev dependencies
# (Playwright and TypeScript are only for its own tests and typecheck) and
# without install scripts. Its browser page fetches weather from Open-Meteo
# (turn off in its settings) and fonts are bundled.
#
# Needs 30-pi.sh (Node 22.13+), 40-tailscale.sh and 75-t3code.sh.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
REPO=https://github.com/felixgollnhuber/t3-office.git
COMMIT=b14eb1c1f02933df071f62f32f79ed954dceadd8
PORT=5173
TS_PORT=10001
app="$HOME/.local/share/t3-office"

if [ "$(git -C "$app" rev-parse HEAD 2>/dev/null)" = "$COMMIT" ] && [ -f "$app/dist/index.html" ]; then
    echo "t3-office ${COMMIT:0:7} already built"
else
    [ -d "$app/.git" ] || git clone -q "$REPO" "$app"
    git -C "$app" fetch -q origin
    git -C "$app" -c advice.detachedHead=false checkout -q "$COMMIT"
    (cd "$app" && npm ci --omit=dev --ignore-scripts --no-audit --no-fund --loglevel=error)
    rm -rf "$app/dist"
    (cd "$app" && node --input-type=module -e "const { build } = await import('vite'); await build({ root: '.', logLevel: 'warn' })")
    echo "t3-office: built ${COMMIT:0:7}"
    updated=1
fi

host="$(tailscale status --self --json | jq -r '.Self.DNSName | rtrimstr(".")')"

# A user service, so it runs without anyone logged in (hence linger). PATH has
# ~/.local/bin for gh, which its optional GitHub Projects pinboard uses.
sudo loginctl enable-linger "$USER"
unit="$HOME/.config/systemd/user/t3-office.service"
want="[Unit]
Description=T3 Office (pixel-art view of T3 Code threads)
After=t3code.service

[Service]
WorkingDirectory=$app
Environment=PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin
Environment=__VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS=$host
ExecStart=$(command -v node) bin/t3-office.mjs --port $PORT --no-open
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target"
mkdir -p "$(dirname "$unit")"
if [ "$(cat "$unit" 2>/dev/null)" != "$want" ]; then
    echo "$want" > "$unit"
    systemctl --user daemon-reload
    updated=1
fi
systemctl --user enable -q t3-office.service
if [ -n "${updated:-}" ]; then
    systemctl --user restart t3-office.service
else
    systemctl --user start t3-office.service
fi

for _ in $(seq 30); do
    curl -fs -o /dev/null "http://127.0.0.1:$PORT/" && break
    sleep 1
done
curl -fsS -o /dev/null "http://127.0.0.1:$PORT/"
# Vite takes the next free port if 5173 is busy; serve would then miss it.
ss -ltn "sport = :$PORT" | grep -q "127.0.0.1:$PORT" || { echo "t3-office is not on 127.0.0.1:$PORT" >&2; exit 1; }
# And on nothing but loopback (127.0.0.1 and ::1).
if ss -ltnH "sport = :$PORT" | awk '{print $4}' | grep -qvE '^(127\.0\.0\.1|\[::1\]):'; then
    echo "t3-office listens beyond loopback on :$PORT" >&2; exit 1
fi

served="$(sudo tailscale serve status --json 2>/dev/null | jq -r --arg w "$host:$TS_PORT" '.Web[$w].Handlers["/"].Proxy // empty')"
if [ "$served" = "http://127.0.0.1:$PORT" ]; then
    echo "already served to the tailnet"
else
    sudo tailscale serve --bg --https="$TS_PORT" "http://127.0.0.1:$PORT"
fi
echo "t3 office: https://$host:$TS_PORT/"
