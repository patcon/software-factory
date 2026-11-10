# Local checks for ./factory. Each check_* prints nothing and returns 0 when
# fine, or prints a one-line problem with its fix and returns 1.
# Sourced by ./factory after scripts/config.sh.

check_env() {
    if [ ! -f "$SF_ROOT/factory.env" ]; then
        echo "no factory.env: cp factory.env.example factory.env, then fill it in"; return 1
    fi
    if [ -z "$SF_ACCOUNT" ] || [ -z "$SF_PROJECT" ]; then
        echo "set SF_ACCOUNT and SF_PROJECT in factory.env"; return 1
    fi
    case "$SF_ACCESS" in ssh|tailscale) ;;
        *) echo "SF_ACCESS in factory.env must be ssh or tailscale, not '$SF_ACCESS'"; return 1 ;;
    esac
}

check_gcloud() {
    command -v gcloud >/dev/null \
        || { echo "gcloud not installed: https://cloud.google.com/sdk/docs/install"; return 1; }
    gcloud auth list --format='value(account)' 2>/dev/null | grep -qxF "$SF_ACCOUNT" \
        || { echo "gcloud is not logged in as $SF_ACCOUNT: gcloud auth login $SF_ACCOUNT"; return 1; }
}

check_key() {
    [ -f "$SF_PUBKEY" ] \
        || { echo "no SSH key at $SF_PUBKEY: ssh-keygen -t ed25519 (or set SF_PUBKEY)"; return 1; }
    local fp; fp="$(ssh-keygen -lf "$SF_PUBKEY" | awk '{print $2}')"
    ssh-add -l 2>/dev/null | grep -qF "$fp" \
        || { echo "SSH key not loaded in your agent: ssh-add ${SF_PUBKEY%.pub}"; return 1; }
}

check_include() {
    grep -qE "^[[:space:]]*Include[[:space:]]+(${SF_SSH_CONFIG}|~/.ssh/${SF_SSH_CONFIG##*/})([[:space:]]|\$)" \
        "$HOME/.ssh/config" 2>/dev/null \
        || { echo "~/.ssh/config doesn't include $SF_SSH_CONFIG, so 'ssh $SF_NAME' and herdr can't find the VM: ./factory setup adds it"; return 1; }
}

check_tailscale() {
    [ "$SF_ACCESS" = tailscale ] || return 0
    command -v tailscale >/dev/null \
        || { echo "SF_ACCESS=tailscale but Tailscale isn't installed here: https://tailscale.com/download"; return 1; }
    tailscale status >/dev/null 2>&1 \
        || { echo "Tailscale isn't connected on this machine: open Tailscale, or tailscale up"; return 1; }
}

check_herdr() {
    command -v herdr >/dev/null \
        || { echo "herdr not installed here: brew install herdr (or curl -fsSL https://herdr.dev/install.sh | sh)"; return 1; }
}

# Before every command: stop on what would make it fail outright, and remind
# about the rest in one line each.
preflight() {
    local msg
    for c in check_env check_gcloud; do
        msg="$($c)" || die "$msg (or run ./factory setup)"
    done
    for c in check_key check_include check_tailscale; do
        msg="$($c)" || echo "! $msg" >&2
    done
    return 0
}

# ./factory setup: every check, verbosely, fixing what is safe to fix.
cmd_setup() {
    local msg failed=0
    run() {  # run <label> <check>
        if msg="$($2)"; then echo "  ok    $1"; else echo "  FIX   $1: $msg"; failed=1; fi
    }

    if [ ! -f "$SF_ROOT/factory.env" ]; then
        cp "$SF_ROOT/factory.env.example" "$SF_ROOT/factory.env"
        echo "created factory.env from the example. Fill in SF_ACCOUNT and SF_PROJECT"
        echo "(and read the rest), then run ./factory setup again."
        return 1
    fi

    echo "Checking local setup for $SF_NAME ($SF_ACCESS access):"
    run "factory.env"            check_env
    run "gcloud login"           check_gcloud
    run "SSH key in agent"       check_key
    run "Tailscale"              check_tailscale
    run "herdr"                  check_herdr

    if msg="$(check_include)"; then
        echo "  ok    ~/.ssh/config includes $SF_SSH_CONFIG"
    else
        local ans
        read -r -p "  ADD   'Include $SF_SSH_CONFIG' to the top of ~/.ssh/config? [Y/n] " ans
        case "$ans" in
            ""|y|Y|yes)
                mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
                local tmp; tmp="$(mktemp)"
                { echo "Include $SF_SSH_CONFIG"; echo; cat "$HOME/.ssh/config" 2>/dev/null || true; } > "$tmp"
                # Write through, not mv: keeps a symlinked ~/.ssh/config intact.
                cat "$tmp" > "$HOME/.ssh/config" && rm -f "$tmp" && chmod 600 "$HOME/.ssh/config"
                echo "  ok    added" ;;
            *) echo "  FIX   $msg"; failed=1 ;;
        esac
    fi

    echo
    if [ $failed = 0 ]; then echo "All set."; else echo "Fix the items marked FIX, then run ./factory setup again."; fi
    return $failed
}
