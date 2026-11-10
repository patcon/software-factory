# patcon-software-factory

A remote GCP workstation for running coding agents, because the local machine
is not powerful enough. One VM, managed by `./factory`.

```
./factory create        # VM + SSH firewall rule + ~/.ssh/software-factory.conf
./factory provision     # run provision/*.sh in order (or name one: 30-pi.sh)
herdr --remote software-factory
./factory stop          # when done for the day; ./factory start to resume
./factory destroy       # delete the VM and its disk
```

One-time setup: add `Include ~/.ssh/software-factory.conf` near the top of
`~/.ssh/config`. The VM's IP changes on every start; `./factory start` rewrites
that file.

## Defaults

Set in `scripts/config.sh`; override in `scripts/local.env` (gitignored).

- `e2-standard-4` (4 vCPU, 16 GB), Ubuntu 24.04, 50 GB disk, in
  `northamerica-northeast2-a`, project `your-gcp-project`.
- Login as `$USER` with `~/.ssh/id_ed25519` only. Project-wide SSH keys are
  blocked on this instance.
- SSH is allowed from your current IP (`./factory allow-ip` after it changes).
- No service account: nothing on the VM can act as you in GCP.

## Provisioning

Each `provision/*.sh` runs on the VM as the login user over SSH, in name order.
Keep them safe to re-run. Add a step by dropping in a new numbered script.

| Script | Installs |
|---|---|
| `10-base.sh` | git, build tools, ripgrep, jq, tmux; `~/.local/bin` on PATH |
| `20-herdr.sh` | [herdr](https://herdr.dev) (TUI), or updates it |
| `30-pi.sh` | Node 22 (NodeSource) and [pi](https://pi.dev) |
| `40-tailscale.sh` | [Tailscale](https://tailscale.com), joined to your tailnet. Set `TS_AUTHKEY` in `scripts/local.env` to skip the browser login |

After provisioning, log pi in on the VM: `ssh software-factory`, then `pi` and
`/login`.

## Cost

Roughly $0.15/hour running. Stopped, only the 50 GB disk is billed (~$5/month).
