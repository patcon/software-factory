# Defaults for ./factory. Don't edit: set your own values in factory.env
# (copy factory.env.example), which is loaded on top of these.

SF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SF_ACCOUNT=""
SF_PROJECT=""
SF_NAME="software-factory-$USER"
SF_ZONE="northamerica-northeast2-a"
SF_MACHINE_TYPE="e2-standard-4"
SF_DISK_GB="50"
SF_IMAGE_FAMILY="ubuntu-2404-lts-amd64"
SF_IMAGE_PROJECT="ubuntu-os-cloud"
SF_USER="$USER"
SF_PUBKEY="$HOME/.ssh/id_ed25519.pub"
SF_ACCESS="ssh"
SF_OVIS_TELEMETRY="1"

if [ -f "$SF_ROOT/factory.env" ]; then
    # shellcheck disable=SC1091
    . "$SF_ROOT/factory.env"
fi

# Derived from SF_NAME, so two factories in one project never collide.
SF_TAG="$SF_NAME"
SF_FW_ALLOW="$SF_NAME-ssh"        # port 22 from your IP (ssh access, bootstrap)
SF_FW_DENY="$SF_NAME-deny-ssh"    # port 22 from everywhere else
SF_SSH_CONFIG="$HOME/.ssh/$SF_NAME.conf"
SF_KNOWN_HOSTS="$HOME/.ssh/${SF_NAME}_known_hosts"
