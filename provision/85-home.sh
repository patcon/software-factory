#!/usr/bin/env bash
# A home page on the VM's plain tailnet address, https://<name>.<tailnet>.ts.net
# (port 443), linking to the web apps on their own ports. Each dot on it shows
# whether that app answers right now, checked from your browser. Each app, and
# the page itself, has a QR code to open it on a phone (which needs Tailscale
# connected).
#
# A static file served by `tailscale serve` itself: no web server to run. The
# QR codes are drawn here with qrencode, so the page loads nothing from outside.
# They hold plain URLs, never a login: Herdr World's token stays out of a file
# the whole tailnet can load (./factory status shows a QR with it).
#
# Apps get their own ports, not subpaths, because they load assets from
# absolute paths (/assets/...) that break under a prefix. Ports: 8443 Ovis
# (70-ovis.sh), 9443 Herdr World (80-herdr-world.sh), 10000 T3 Code
# (75-t3code.sh), 10001 T3 Office (77-t3-office.sh). Add an app: a line in APPS below, then re-run.
#
# Needs 40-tailscale.sh. Replaces whatever 443 served before (Herdr World, on
# VMs set up before it moved to 9443).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
TS_PORT=443
dir="$HOME/.local/share/software-factory/home"

# port|name|what it is|how a new device gets in
APPS='8443|Ovis|herdr in the browser and on your phone|your Tailscale login lets you in
9443|Herdr World|which agents need you, and what they cost|asks for its token once per browser (QR in ./factory status)
10000|T3 Code|a GUI for coding agents (trial)|pair each device: t3 pair --tailscale --tailscale-serve-port 10000
10001|T3 Office|T3 Code threads as pixel-art coworkers|no login: open to your tailnet, read only'

command -v qrencode >/dev/null || { sudo apt-get update -q && sudo apt-get install -yq qrencode; }

host="$(tailscale status --self --json | jq -r '.Self.DNSName | rtrimstr(".")')"
name="${host%%.*}"

esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'; }
# An inline SVG QR code, without the XML prolog (not allowed inside HTML).
qr() { qrencode -t SVG --svg-path -m 2 -o - "$1" | sed '/^<?xml/d; /^<!DOCTYPE/d'; }

items=""
qrs=""
i=0
# A small QR-code glyph for the buttons.
icon='<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3h-3zM20 14v.01M14 20v.01M17 20h4v-3" stroke-linecap="round"/></svg>'
while IFS='|' read -r port title desc login; do
    i=$((i + 1))
    url="https://$host:$port/"
    t="$(esc <<<"$title")"
    items+="    <li>
      <a href=\"$url\"><span class=\"dot\" data-check=\"$url\"></span><span class=\"t\">$t</span><span class=\"p\">:$port</span><span class=\"d\">$(esc <<<"$desc")</span></a>
      <button type=\"button\" data-qr=\"qr$i\" aria-label=\"QR code for $t\" title=\"QR code\">$icon</button>
    </li>
"
    qrs+="<template id=\"qr$i\" data-title=\"$t\" data-url=\"$url\" data-login=\"$(esc <<<"$login")\">$(qr "$url")</template>
"
done <<<"$APPS"
qrs+="<template id=\"qr0\" data-title=\"This page\" data-url=\"https://$host/\" data-login=\"\">$(qr "https://$host/")</template>
"

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
  header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 2rem; }
  h1 { font-size: 1.4rem; margin: 0 0 .25rem; }
  .mono { font: .85rem ui-monospace, SFMono-Regular, Menlo, monospace; }
  .host { color: var(--muted); margin: 0; word-break: break-all; }
  ul { list-style: none; margin: 0; padding: 0; display: grid; gap: .6rem; }
  li { display: flex; gap: .5rem; }
  li a { flex: 1; min-width: 0; display: grid; grid-template-columns: auto 1fr auto; column-gap: .7rem; align-items: center;
         padding: .9rem 1rem; color: inherit; text-decoration: none;
         background: var(--card); border: 1px solid var(--line); border-radius: 10px; }
  li a:hover, li a:focus-visible { border-color: var(--muted); }
  .t { font-weight: 600; }
  .p { color: var(--muted); font: .85rem ui-monospace, SFMono-Regular, Menlo, monospace; }
  .d { grid-column: 2 / 4; color: var(--muted); font-size: .9rem; }
  .dot { width: .6rem; height: .6rem; border-radius: 50%; background: var(--down); }
  .dot.up { background: var(--up); }
  button { font: 600 .9rem system-ui, sans-serif; color: var(--muted); background: var(--card); cursor: pointer;
           border: 1px solid var(--line); border-radius: 10px; }
  button:hover, button:focus-visible { color: var(--fg); border-color: var(--muted); }
  button[data-qr] { flex: none; width: 2.75rem; display: grid; place-items: center; padding: 0; }
  header button[data-qr] { height: 2.75rem; }
  dialog { border: 1px solid var(--line); border-radius: 14px; background: var(--card); color: var(--fg);
           padding: 1.25rem; width: min(22rem, calc(100vw - 32px)); text-align: center; }
  dialog::backdrop { background: rgb(0 0 0 / .5); }
  dialog h2 { font-size: 1.05rem; margin: 0 0 .9rem; }
  .code { background: #fff; border-radius: 8px; padding: .5rem; line-height: 0; }
  .code svg { width: 100%; height: auto; }
  dialog p { margin: .8rem 0 0; color: var(--muted); font-size: .9rem; word-break: break-all; }
  dialog button { margin-top: 1rem; border-radius: 8px; padding: .5rem 1.2rem; }
</style>
</head>
<body>
<main>
  <header>
    <div>
      <h1>$name</h1>
      <p class="host mono">$host</p>
    </div>
    <button type="button" data-qr="qr0" aria-label="QR code for this page" title="QR code for this page">$icon</button>
  </header>
  <ul>
$items  </ul>
</main>
<dialog id="qr">
  <h2></h2>
  <div class="code"></div>
  <p class="url mono"></p>
  <p class="login"></p>
  <button type="button" autofocus>Close</button>
</dialog>
$qrs<script>
  // Opaque (no-cors) fetch: resolves if the port answers, rejects if nothing listens.
  document.querySelectorAll("[data-check]").forEach(function (dot) {
    var ctl = new AbortController();
    setTimeout(function () { ctl.abort(); }, 4000);
    fetch(dot.dataset.check, { mode: "no-cors", signal: ctl.signal, cache: "no-store" })
      .then(function () { dot.classList.add("up"); dot.title = "answering"; })
      .catch(function () { dot.title = "not answering"; });
  });

  var dlg = document.getElementById("qr");
  document.querySelectorAll("[data-qr]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var tpl = document.getElementById(btn.dataset.qr);
      dlg.querySelector("h2").textContent = tpl.dataset.title;
      dlg.querySelector(".code").replaceChildren(tpl.content.cloneNode(true));
      dlg.querySelector(".url").textContent = tpl.dataset.url;
      var login = dlg.querySelector(".login");
      login.textContent = tpl.dataset.login;
      login.hidden = !tpl.dataset.login;
      dlg.showModal();
    });
  });
  dlg.querySelector("button").addEventListener("click", function () { dlg.close(); });
  dlg.addEventListener("click", function (e) { if (e.target === dlg) dlg.close(); });
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
