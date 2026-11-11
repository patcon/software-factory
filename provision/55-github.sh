#!/usr/bin/env bash
# GitHub CLI (https://cli.github.com), logged in with SF_GH_TOKEN, and clones
# of SF_FACTORY_REPOS in ~/work, for pi's /factory-issue workflow. SSH agent
# forwarding is off (90-hardening.sh), so this token is the VM's only GitHub
# credential: gh uses it, and git uses it through `gh auth setup-git`.
# Safe to re-run: installs gh once, re-logs in, fetches existing clones.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if ! command -v gh >/dev/null; then
    # GitHub's own apt repo: Ubuntu's gh package lags far behind.
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
        sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
        sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update -q
    sudo apt-get install -yq gh
fi
gh --version | head -1

if [ -z "${SF_GH_TOKEN:-}" ]; then
    echo "SF_GH_TOKEN not set: gh is not logged in. Set it in factory.env and re-run:"
    echo "  ./factory provision 55-github.sh"
    exit 0
fi
# The token goes in on stdin, never as an argument.
printf '%s\n' "$SF_GH_TOKEN" | gh auth login --hostname github.com --git-protocol https --with-token
gh auth setup-git
gh auth status

name="${SF_GH_NAME:-}"
email="${SF_GH_EMAIL:-}"
if [ -z "$name" ] || [ -z "$email" ]; then
    user="$(gh api user)"
    [ -n "$name" ] || name="$(jq -r '.name // .login' <<<"$user")"
    [ -n "$email" ] || email="$(jq -r '"\(.id)+\(.login)@users.noreply.github.com"' <<<"$user")"
fi
git config --global user.name "$name"
git config --global user.email "$email"
echo "git identity: $name <$email>"

# /factory-issue reads the label from here: pi prompts can't see factory.env.
mkdir -p "$HOME/.config/software-factory"
printf '%s\n' "${SF_FACTORY_LABEL:-factory:$USER}" > "$HOME/.config/software-factory/label"

for repo in ${SF_FACTORY_REPOS:-}; do
    dir="$HOME/work/$repo"
    if [ -d "$dir/.git" ]; then
        echo "fetching $repo"
        git -C "$dir" fetch --prune origin
    else
        echo "cloning $repo"
        mkdir -p "$(dirname "$dir")"
        gh repo clone "$repo" "$dir"
    fi
done
