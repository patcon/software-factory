# Settings for ./factory. Override any of these in scripts/local.env
# (gitignored), e.g. SF_MACHINE_TYPE=e2-standard-8.

SF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SF_ACCOUNT="you@example.com"
SF_PROJECT="your-gcp-project"
SF_ZONE="northamerica-northeast2-a"
SF_NAME="software-factory"
SF_MACHINE_TYPE="e2-standard-4"
SF_DISK_GB="50"
SF_IMAGE_FAMILY="ubuntu-2404-lts-amd64"
SF_IMAGE_PROJECT="ubuntu-os-cloud"

# Login user on the VM, and the public key allowed in. Only this key works:
# project-wide SSH keys are blocked on this instance.
SF_USER="$USER"
SF_PUBKEY="$HOME/.ssh/id_ed25519.pub"

# Network tag + firewall rule that lets SSH in from your current IP only.
SF_TAG="software-factory"
SF_FIREWALL="software-factory-ssh"

# SSH host alias. `./factory ssh-config` writes this file; Include it from
# ~/.ssh/config so `ssh software-factory` and `herdr --remote` work.
SF_SSH_ALIAS="$SF_NAME"
SF_SSH_CONFIG="$HOME/.ssh/software-factory.conf"
SF_KNOWN_HOSTS="$HOME/.ssh/software-factory_known_hosts"

if [ -f "$SF_ROOT/scripts/local.env" ]; then
    # shellcheck disable=SC1091
    . "$SF_ROOT/scripts/local.env"
fi
