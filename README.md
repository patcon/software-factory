# software-factory

A remote GCP workstation for running coding agents, for when your own machine
is not powerful enough. One VM per person, managed by `./factory`.

## Set up your own

Needs `gcloud`, an SSH key in your agent, and a GCP project you can create
VMs in.

```
cp factory.env.example factory.env   # set SF_ACCOUNT and SF_PROJECT; read the rest
./factory create                     # VM + firewall + ~/.ssh/<name>.conf
./factory provision                  # run provision/*.sh in order
```

Then add `Include ~/.ssh/<name>.conf` near the top of `~/.ssh/config` (create
prints the exact line), and connect:

```
ssh <name>
herdr --remote <name>
```

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

After provisioning, log pi in on the VM: `ssh <name>`, then `pi` and `/login`.

## Cost

About $0.15/hour running on the default `e2-standard-4`. Stopped, only the
disk is billed (about $5/month for 50 GB).
