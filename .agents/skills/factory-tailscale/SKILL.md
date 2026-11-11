---
name: factory-tailscale
description: How this repo wires up Tailscale. Use when changing this repo to publish a VM service to the tailnet or to change tailnet access (SF_ACCESS, 40-tailscale.sh, ./factory access), or when the VM or a tailnet URL won't answer.
---

# Tailscale in software-factory

For Tailscale itself (CLI flags, serve and funnel, error messages), use the `tailscale` skill. This one covers only how this repo uses it.

Tailscale does two jobs here. It is a way in (`SF_ACCESS=tailscale`), and it is the only way to reach web services on the VM. Both rest on one rule: nothing on the VM is public except port 22, which the GCP firewall restricts.

The code is in `provision/40-tailscale.sh` (install and join), the `ts_ip`, `target`, `cmd_access` and `cmd_status` functions in `factory`, `check_tailscale` in `scripts/checks.sh`, and the ufw rules in `provision/90-hardening.sh`.

## Publishing a service

1. Bind it to `127.0.0.1:<port>`, then confirm with `ss -ltn "sport = :<port>"`. Installers often default to `0.0.0.0` (Herdr World did), so check what actually listens.
2. Pick a free HTTPS port on the VM's tailnet name. 443 is the home page (`85-home.sh`), 8443 Ovis, 9443 Herdr World and 10000 is kept for T3 Code. Add the new app to `APPS` in `85-home.sh` so the home page links it. `sudo tailscale serve status` lists what's taken.
3. Serve it with the same idempotent pattern as `70-ovis.sh` and `80-herdr-world.sh`:
   ```bash
   if sudo tailscale serve status 2>/dev/null | grep -q "127.0.0.1:$PORT"; then
       echo "already served to the tailnet"
   else
       sudo tailscale serve --bg --https="$TS_PORT" "http://127.0.0.1:$PORT"
   fi
   ```
   Always `serve`, which is tailnet only. `funnel` puts it on the public internet. ufw needs no new rule: it already allows everything on `tailscale0`.
4. If the app checks its own origin (logins, CSRF, redirects), give it the public URL `https://<dnsname>:<TS_PORT>`. Get the name with `tailscale status --self --json | jq -r '.Self.DNSName | rtrimstr(".")'`. Herdr World returns 403 on login without this.

Not subpaths: `--set-path` strips the prefix, but these apps load assets from absolute paths (`/assets/...`), so they break under one.
5. Add it to the apps in `cmd_status` in `factory`, and to the README table.

Done when the URL answers from the laptop (`curl -s -o /dev/null -w '%{http_code}' https://<dnsname>:<TS_PORT>/`), and `./factory status` lists it.

## Identity

On requests from a tailnet user, `tailscale serve` adds `Tailscale-User-Login` and `Tailscale-User-Name` headers. Ovis uses them to let in only your login. Requests from tagged devices carry no user headers. These headers are trustworthy only because the app listens on `127.0.0.1`, behind the proxy.

## Access mode

A new VM always bootstraps over port 22, because Tailscale isn't on it yet. In tailscale mode, `./factory provision` and `./factory access` delete the GCP rule that allows port 22 only after an SSH login over the tailnet succeeds. Keep that order in any change, or the VM becomes unreachable.

## Gotchas

- The first HTTPS request to a new serve port can fail while the certificate is issued. Retry after a few seconds before debugging.
- tailscaled keeps its own `ts-input` iptables chain ahead of ufw's. Leave both in place: flushing iptables cuts the tailnet.
- Over plain `ssh <name> 'cmd'`, `tailscale` is on PATH (`/usr/bin`), unlike herdr and pi.
- `./factory destroy` leaves the machine in the tailnet. Remove it in the admin console.

## Debugging

Work from the outside in:

1. Laptop: `tailscale status` (connected?), then `tailscale ping <name>`.
2. VM: `sudo tailscale serve status` (is the port mapped?), then `curl -s 127.0.0.1:<port>` (is the app up?). This tells an app fault from a serve fault.
3. No tailnet at all: `./factory allow-ip` reopens port 22 to your IP. Fix Tailscale, then `./factory access` closes it again.
