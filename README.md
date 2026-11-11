# software-factory

A remote GCP workstation for running coding agents, for when your own machine
is not powerful enough. One VM per person, managed by `./factory`.

## Set up your own

Needs `gcloud`, an SSH key in your agent, and a GCP project you can create
VMs in.

```
./factory setup        # creates factory.env: set SF_ACCOUNT and SF_PROJECT
./factory setup        # again: checks gcloud, SSH key, Tailscale, herdr, and
                       # offers to add the Include line to ~/.ssh/config
./factory create       # VM + firewall + ~/.ssh/<name>.conf
./factory provision    # run provision/*.sh in order
./factory herdr        # herdr --remote <name>, after checking versions match
```

Every other command re-runs the essential checks first and stops if one
fails (no factory.env, gcloud not logged in). It prints a one-line reminder
for the rest (key not in your agent, missing Include line, Tailscale not
connected). Plain `ssh <name>` works too once the Include line is in.

Day to day: `./factory stop` when done, `./factory start` to resume,
`./factory status` to see where things are. `./factory destroy` deletes it.

All settings, explained, are in [`factory.env.example`](factory.env.example).

## Remote access

`SF_ACCESS` in `factory.env` picks how you get in:

- **`ssh`** (default): port 22 open to your current IP only. Run
  `./factory allow-ip` when your IP changes.
- **`tailscale`**: port 22 closed to the internet; you connect over your
  tailnet. A new VM bootstraps over ssh, and `./factory provision` closes
  port 22 once `40-tailscale.sh` has joined it to the tailnet.

Switch by editing `SF_ACCESS` and running `./factory access`. If Tailscale ever
breaks, `./factory allow-ip` reopens port 22 to your IP; `./factory access`
closes it again.

Under the hood each VM gets two firewall rules: `<name>-deny-ssh` blocks
port 22 from everywhere (overriding the default network's allow-all), and
`<name>-ssh` allows your IP through. Closing port 22 deletes the second.

## Security

- The VM has no service account: nothing on it can act as you in GCP.
- Only `SF_PUBKEY` can log in; project-wide SSH keys are blocked.
- The SSH host key is pinned by VM name, so it survives IP changes.

## Provisioning

Each `provision/*.sh` runs on the VM as your user over SSH, in name order.
Keep them safe to re-run. Add a step by dropping in a new numbered script; run
one alone with `./factory provision 30-pi.sh`.

| Script | Installs |
|---|---|
| `10-base.sh` | git, build tools, ripgrep, jq, tmux; `~/.local/bin` on PATH |
| `20-herdr.sh` | [herdr](https://herdr.dev) (TUI), or updates it |
| `30-pi.sh` | Node 22 (NodeSource) and [pi](https://pi.dev) |
| `40-tailscale.sh` | [Tailscale](https://tailscale.com), joined to your tailnet (`TS_AUTHKEY` skips the browser login) |
| `50-claude-code.sh` | [Claude Code](https://claude.com/claude-code), native installer, or updates it |
| `55-github.sh` | [GitHub CLI](https://cli.github.com), logged in with `SF_GH_TOKEN`, and clones of `SF_FACTORY_REPOS` in `~/work` |
| `60-pi-config.sh` | pi settings and packages from [`pi/`](pi) |
| `70-ovis.sh` | [Ovis](https://github.com/devswha/ovis) (herdr in a browser or phone) and Bun, served to your tailnet only |
| `80-herdr-world.sh` | [Herdr World](https://herdr.world) (a browser dashboard of which agents need you), served to your tailnet only |
| `85-home.sh` | A home page at the VM's plain tailnet address, linking to the apps above, served to your tailnet only |
| `90-hardening.sh` | Stricter sshd (your user only, no root, no agent forwarding) and a ufw host firewall (port 22 and the tailnet only) |

Ovis is at `https://<name>.<tailnet>.ts.net:8443`. `./factory status` prints the
address and a QR code to scan with your phone (needs `qrencode` locally). It
listens on `127.0.0.1` only, and `tailscale serve` (not funnel) is the one way
in, so it is not on the internet even in `ssh` access mode. Ovis lets in your
own Tailscale login and refuses everyone else's. It needs herdr running, so
connect with `./factory herdr` before the first provision. Undo with
`sudo tailscale serve --https=8443 off` on the VM.

Herdr World is at `https://<name>.<tailnet>.ts.net:9443`, set up the same way
(`127.0.0.1` plus `tailscale serve`). It always asks for its own login token,
even on your tailnet: it has no way to trust Tailscale instead. `./factory
status` shows a QR code with the token in it, and the link with the token
hidden; you need it once per browser. Treat the QR as a secret. `herdr-world auth rotate`
on the VM replaces the token. Undo with `sudo tailscale serve --https=9443 off`.

`https://<name>.<tailnet>.ts.net` itself is a home page linking to each app,
with a dot showing which ones answer and a QR button on each (and on the page
itself) for opening it on your phone. The codes hold plain URLs, never a login
token. It is one static file that `tailscale serve` serves directly. Each app keeps its own port rather than a subpath,
because the apps load assets from absolute paths. Undo with `sudo tailscale
serve --https=443 off`.

World's cost boards use a price table kept in `80-herdr-world.sh`: Anthropic's
API list prices, so they show what your usage would cost on the API, not your
subscription bill. Update the rates there and re-run the script.

## pi setup

[`pi/`](pi) mirrors `~/.pi/agent` on the VM and is copied there on every
`./factory provision` (or just `./factory provision 60-pi-config.sh`).

- **Packages**: add pinned entries to `packages` in
  [`pi/settings.json`](pi/settings.json), not with `pi install` on the VM.
  The repo's list replaces the VM's, so ad-hoc installs there are dropped on
  the next provision. Read a package's source before adding it.
- **Other settings** in `pi/settings.json` override the VM's; anything pi
  saves itself (like the last model used) is kept.
- **Files** such as `AGENTS.md`, `extensions/`, `skills/`, `prompts/`, or
  `pi-redact.json` go in `pi/` at the same path they have under `~/.pi/agent`.
  Never put `auth.json` here.

Installed now: [pi-vigilant](https://github.com/brunoj/pi-vigilant)
(auto-continue, spec and feedback memory),
[pi-subagents](https://github.com/nicobailon/pi-subagents) (delegates to
child agents such as `scout`, `worker` and `reviewer`; try `/run` and
`/subagents-doctor`) and
[pi-redact](https://github.com/BubbatheVTOG/pi-redact) (masks API keys and
tokens in provider requests). pi-redact is listed last because it should
load after any other extension that rewrites requests.

[pi-claude-bridge](https://github.com/elidickinson/pi-claude-bridge) runs
Claude models through Claude Code, on your Claude subscription, and is the
default model (`claude-bridge/claude-opus-5-5`). It uses Claude Code's login,
not pi's: on the VM, run `claude auth login` once. In `/model`, pick
`claude-bridge/...`, not `anthropic/...` (pi's own provider, billed per token).
Because `defaultModel` is set here, each provision resets pi's startup model
to it. Claude Code sends bridge requests itself, so **pi-redact does not see
them**: only other providers' requests are redacted.

After provisioning, log the agents in on the VM (`ssh <name>`): run `pi` then
`/login`, and run `claude` and follow its login prompt.

## Issue workflow

A small take on [addyosmani/factory](https://github.com/addyosmani/factory),
at the size its own advice says to start: you pick an issue, one prompt turns
it into one draft PR, and a human reviews and merges. No triage, label state
machine or schedule yet.

1. In `factory.env`, set `SF_FACTORY_REPOS` (e.g. `dembrane/echo`) and
   `SF_GH_TOKEN`, a fine-grained PAT for just those repos (how to make it is
   in [`factory.env.example`](factory.env.example)). PRs are opened as you.
2. `./factory provision 55-github.sh` logs `gh` in and clones the repos to
   `~/work/<owner>/<repo>`.
3. Label an issue `SF_FACTORY_LABEL` (default `factory:<your username>`).
   `./factory issues` lists the open ones.
4. In a herdr pane: `cd ~/work/<owner>/<repo> && pi`, then
   `/factory-issue <number>`.

[`pi/prompts/factory-issue.md`](pi/prompts/factory-issue.md) checks the issue
has your label, makes a `factory/issue-<n>` branch (stopping if it already
exists, so two runs can't take one issue), then has pi-subagents' `scout` map
the code, `worker` write a failing test and the fix, and `reviewer` read the
diff cold. It gets one retry on a BLOCK verdict, then pushes and opens a
draft PR that says `Closes #<n>`. It never merges, force-pushes or touches
the issue itself. Branch protection on the default branch is what actually
stops a merge, since the token could.

`gh` being logged in also lets pi-subagents share a session as a public
gist, but only when you ask it to.

## Cost

About $0.15/hour running on the default `e2-standard-4`. Stopped, only the
disk is billed (about $5/month for 50 GB).
