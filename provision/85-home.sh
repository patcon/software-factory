#!/usr/bin/env bash
# A home page on the VM's plain tailnet address, https://<name>.<tailnet>.ts.net
# (port 443), linking to the web apps on their own ports. Each dot on it shows
# whether that app answers right now, checked from your browser.
#
# A static file served by `tailscale serve` itself: no web server to run. Apps
# get their own ports, not subpaths, because they load assets from absolute
# paths (/assets/...) that break under a prefix. Ports: 8443 Ovis (70-ovis.sh),
# 9443 Herdr World (80-herdr-world.sh), 10000 T3 Code (not provisioned yet).
# Add an app: a line in APPS below, then re-run.
#
# Needs 40-tailscale.sh. Replaces whatever 443 served before (Herdr World, on
# VMs set up before it moved to 9443).
set -euo pipefail
TS_PORT=443
dir="$HOME/.local/share/software-factory/home"

# port|name|what it is
APPS='8443|Ovis|herdr in the browser and on your phone
9443|Herdr World|which agents need you, and what they cost
10000|T3 Code|a GUI for coding agents (trial)'

host="$(tailscale status --self --json | jq -r '.Self.DNSName | rtrimstr(".")')"
name="${host%%.*}"

esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }
items=""
while IFS='|' read -r port title desc; do
    url="https://$host:$port/"
    items+="    <li><a href=\"$url\"><span class=\"dot\" data-check=\"$url\"></span><span class=\"t\">$(esc <<<"$title")</span><span class=\"p\">:$port</span><span class=\"d\">$(esc <<<"$desc")</span></a></li>
"
done <<<"$APPS"

mkdir -p "$dir"
cat > "$dir/index.html.tmp" <<EOF
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$name</title>
<style>
  :root { --bg: #f6f5f2; --fg: #1d1d1b; --muted: #6b6a66; --card: #fff; --line: #e3e1db; --up: #2f9e5a; --down: #c4c2bb; }
  @media (prefers-color-scheme: dark) {
    :root { --bg: #151514; --fg: #ecebe7; --muted: #9a9892; --card: #1f1f1d; --line: #30302d; --up: #4cc27a; --down: #4a4945; }
  }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--bg); color: var(--fg); font: 16px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; }
  main { max-width: 34rem; margin: 0 auto; padding: 3rem 16px; }
  h1 { font-size: 1.4rem; margin: 0 0 .25rem; }
  .host { color: var(--muted); font: .85rem ui-monospace, SFMono-Regular, Menlo, monospace; margin: 0 0 2rem; word-break: break-all; }
  ul { list-style: none; margin: 0; padding: 0; display: grid; gap: .6rem; }
  a { display: grid; grid-template-columns: auto 1fr auto; column-gap: .7rem; align-items: center;
      padding: .9rem 1rem; background: var(--card); border: 1px solid var(--line); border-radius: 10px;
      color: inherit; text-decoration: none; }
  a:hover, a:focus-visible { border-color: var(--muted); }
  .t { font-weight: 600; }
  .p { color: var(--muted); font: .85rem ui-monospace, SFMono-Regular, Menlo, monospace; }
  .d { grid-column: 2 / 4; color: var(--muted); font-size: .9rem; }
  .dot { width: .6rem; height: .6rem; border-radius: 50%; background: var(--down); }
  .dot.up { background: var(--up); }
</style>
</head>
<body>
<main>
  <h1>$name</h1>
  <p class="host">$host</p>
  <ul>
$items  </ul>
</main>
<script>
  // Opaque (no-cors) fetch: resolves if the port answers, rejects if nothing listens.
  document.querySelectorAll("[data-check]").forEach(function (dot) {
    var ctl = new AbortController();
    setTimeout(function () { ctl.abort(); }, 4000);
    fetch(dot.dataset.check, { mode: "no-cors", signal: ctl.signal, cache: "no-store" })
      .then(function () { dot.classList.add("up"); dot.title = "answering"; })
      .catch(function () { dot.title = "not answering"; });
  });
</script>
</body>
</html>
EOF
mv "$dir/index.html.tmp" "$dir/index.html"
echo "home page: $dir/index.html"

served="$(sudo tailscale serve status --json 2>/dev/null | jq -r --arg w "$host:$TS_PORT" '.Web[$w].Handlers["/"].Path // empty')"
if [ "$served" = "$dir" ]; then
    echo "already served to the tailnet"
else
    sudo tailscale serve --bg --https="$TS_PORT" "$dir"
fi
echo "home: https://$host/"
