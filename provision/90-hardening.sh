#!/usr/bin/env bash
# Locks the VM down further, on top of what the GCP firewall and the Ubuntu
# image already do. Agents run code we have not read on this VM, so the aim is
# to limit what that code can reach, not only who can log in. Safe to re-run.
#
# Already covered elsewhere, so not repeated here: password logins (off in the
# image), automatic security updates (on in the image), AppArmor, and the
# kernel sysctls that matter (the image's defaults are already strict).
#
# Left alone on purpose: passwordless sudo (provisioning needs it), and SSH TCP
# and socket forwarding (`ssh -L` to reach a dev server, `herdr --remote`).
set -euo pipefail

me="$(id -un)"

# --- sshd ---------------------------------------------------------------------
# sshd uses the first value it reads, so this file sorts before the image's
# 50-/60-cloudimg-settings.conf.
#   AllowUsers: only the login user. The image's `ubuntu` user can't get in.
#   AllowAgentForwarding no: a forwarded agent would let anything on the VM
#     use your laptop's keys while you're connected. Nothing here relies on it.
conf=/etc/ssh/sshd_config.d/10-factory-hardening.conf
want="$(cat <<EOF
# Written by software-factory provision/90-hardening.sh
PermitRootLogin no
AllowUsers $me
AllowAgentForwarding no
X11Forwarding no
MaxAuthTries 3
LoginGraceTime 30
EOF
)"
if [ "$(sudo cat "$conf" 2>/dev/null)" != "$want" ]; then
    printf '%s\n' "$want" | sudo tee "$conf" >/dev/null
    # A bad config would lock us out on the next connection, so check it
    # first and back out if sshd rejects it.
    if ! sudo sshd -t; then
        sudo rm -f "$conf"
        echo "sshd rejected $conf; removed it, nothing changed" >&2
        exit 1
    fi
    # Reload keeps the current connection open.
    sudo systemctl reload ssh
    echo "sshd: hardened ($conf)"
else
    echo "sshd: already hardened"
fi

# --- host firewall (ufw) ------------------------------------------------------
# The GCP firewall decides who can reach port 22. This adds a second layer for
# everything else: a dev server an agent starts on 0.0.0.0 is reachable over
# the tailnet only, not from other VMs in the project. Port 22 stays open here
# because the GCP rules already restrict it, and closing it here too would lock
# out ssh-access mode.
sudo apt-get install -y -qq ufw >/dev/null
sudo ufw default deny incoming >/dev/null
sudo ufw default allow outgoing >/dev/null
sudo ufw allow 22/tcp comment 'ssh (GCP firewall restricts sources)' >/dev/null
sudo ufw allow in on tailscale0 comment 'tailnet' >/dev/null
sudo ufw allow 41641/udp comment 'tailscale direct connections' >/dev/null
sudo ufw --force enable >/dev/null
echo "ufw: $(sudo ufw status | head -1)"
