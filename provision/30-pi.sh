#!/usr/bin/env bash
# pi coding agent (https://pi.dev). Needs Node >= 22.19; installed from
# NodeSource so it is a normal system package, then pi from npm.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

node_ok() {
    command -v node >/dev/null || return 1
    node -e 'const [a,b]=process.versions.node.split(".").map(Number); process.exit(a>22||(a===22&&b>=19)?0:1)'
}

if ! node_ok; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -yq nodejs
fi
node --version

sudo npm install -g --ignore-scripts @earendil-works/pi-coding-agent
pi --version
echo "pi installed. Log in on the VM with: pi, then /login"
