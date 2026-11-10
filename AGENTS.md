# AGENTS.md

Guidance for coding agents working in this repository.

## What this is

Bash tooling that runs one GCP VM per person as a remote workstation for coding agents (herdr, pi, Claude Code, Ovis, Herdr World). There is no build, lint config or test suite. `./factory` on the laptop does everything, and its settings come from the gitignored `factory.env`.

## Commands

```
bash -n factory provision/*.sh scripts/*.sh   # syntax check (the only static check; files carry shellcheck directives, but shellcheck isn't installed)
./factory status                              # VM state, access, addresses, Ovis and Herdr World URLs + QR
./factory provision                           # all provision/*.sh, in name order
./factory provision 60-pi-config.sh           # one step: the way to test a change to a provision script
ssh <SF_NAME> '<cmd>'                          # run something on the VM
```

Testing a change means running it against the real VM. Re-run a provision script a second time to check it is idempotent. Over plain `ssh <name> 'cmd'`, `~/.local/bin` is not on PATH (Ubuntu's `.bashrc` returns early in non-interactive shells), so export it or use full paths.

## How the pieces fit

- **Config layering:** `scripts/config.sh` sets the defaults, then sources `factory.env`. Every new setting goes in three places: a default in `config.sh`, a commented, explained entry in `factory.env.example`, and the README if users need to know about it.
- **Preflight:** `scripts/checks.sh` holds the `check_*` functions. Each one prints a single line with the problem and its fix, then returns 1. `preflight` runs before every command except `setup`. `check_env` and `check_gcloud` are fatal; the others only warn.
- **Provisioning:** `cmd_provision` pipes each `provision/NN-*.sh` to `ssh … bash -s`, so a script runs as the login user with only stdin. Values from `factory.env` (`TS_AUTHKEY`, `SF_OVIS_TELEMETRY`) are prepended to stdin as `export` lines, never put on a command line. Before the scripts run, the repo's `pi/` directory is tarred to `~/.factory/pi` on the VM. Any other repo files a script needs must be shipped the same way.
- **pi config (`pi/` → `~/.pi/agent`):** `60-pi-config.sh` merges `pi/settings.json` into the VM's file with `jq '.[0] * .[1]'`. Repo keys win, keys pi wrote itself survive, and `packages` is replaced whole (the repo is authoritative). It then runs `pi install` for each package, because `pi update --extensions` skips packages that aren't installed yet. Pin packages to exact versions and use plain string entries: the `{ "source": … }` form makes `pi list` show them as "filtered". Never put `auth.json` in `pi/`.
- **Access model:** `SF_ACCESS=ssh|tailscale`. Two firewall rules per VM: a deny on port 22 at priority 1000 and an allow for your IP at 900. In tailscale mode, `provision` deletes the allow rule once the VM has joined the tailnet. The VM has no service account and blocks project-wide SSH keys. Keep those properties.
- **Services on the VM:** bind to `127.0.0.1` and expose them with `tailscale serve` (tailnet only), never `funnel` or `0.0.0.0`. `70-ovis.sh` is the example.

## Gotchas learned on the live VM

- Ovis shows a pi pane as a chat only when herdr's pi integration (`herdr integration install pi`, done in `60-pi-config.sh`) reports the pane's session. A running pi has to be restarted (`pi -c` continues the session) to load it.
- Ovis plugin settings come from `$(herdr plugin config-dir devswha.ovis)/env`, not the shell environment. `70-ovis.sh` exits early unless the herdr server is running.
- pi-claude-bridge (`claude-bridge/*` models) uses Claude Code's own login (`claude auth login` on the VM), not pi's `/login`. Claude Code sends those requests itself, so pi-redact never sees them.
- Ovis and Herdr World show Claude Code as a chat only with herdr's Claude integration (`herdr integration install claude`, in `50-claude-code.sh`). Restart a running Claude (`claude -c`) to load it, as with pi.
- Herdr World's service defaults to `0.0.0.0`; `80-herdr-world.sh` pins `HOST=127.0.0.1` before installing it. Behind `tailscale serve` it returns 403 on login unless `HERDR_WORLD_PUBLIC_ORIGIN` matches the tailnet URL. `herdr-world config set` refuses that key in 0.3.0, so it lives in a systemd drop-in. `herdr-world url --address` builds a broken URL behind a proxy.
- Herdr World reads `settings.json` once and rewrites it from memory, so `80-herdr-world.sh` stops the service before merging in the price table (`custom.world_usage_prices_v1`). Prices apply only to exact model names from the session logs.
- `90-hardening.sh` turns off SSH agent forwarding, so anything on the VM that needs a git key needs its own (a deploy key or a token), not your laptop's. ufw drops incoming traffic except port 22, `tailscale0` and Tailscale's UDP 41641: serve new services over `tailscale serve`, don't open ufw ports. Port 22 stays open in ufw on purpose, so `./factory allow-ip` keeps working as the way back in.
- Herdr World's installer runs `integration sync` unless `HERDR_WORLD_SKIP_INTEGRATIONS=1`. Sync would treat the VM's `~/.factory` (this repo's files) as Droid's config folder.

## Conventions

- Provision scripts: numbered, `set -euo pipefail`, safe to re-run (skip what is already done), and a header comment saying what the script installs and why. Add each one to the table in the README.
- Comments and README explain the *why*, in plain short sentences, matching the existing style.
- Node on the VM is only pi's runtime (`30-pi.sh`: `sudo npm install -g --ignore-scripts`). pi's own packages install under `~/.pi/agent/npm/`, not globally.
