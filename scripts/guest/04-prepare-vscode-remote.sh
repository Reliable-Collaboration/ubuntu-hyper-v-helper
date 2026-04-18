#!/usr/bin/env bash
# Prepare the VM to be a comfortable VS Code Remote-SSH target.
# Hardens sshd (pubkey-only, no root, no password), creates ~/projects, and
# prints the SSH-config snippet to add on each client machine.
# Idempotent.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as your normal user, not root. The script uses sudo where needed." >&2
    exit 1
fi

echo "==> Ensuring openssh-server is installed and running"
sudo apt-get update
sudo apt-get install -y openssh-server
sudo systemctl enable --now ssh

echo "==> Hardening sshd: disable root login + password auth"
sudo sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/'           /etc/ssh/sshd_config
sudo sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config

# Make sure pubkey auth is on (default is yes, but be explicit)
sudo sed -i 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/'  /etc/ssh/sshd_config

# Keepalive so VS Code Remote-SSH survives WiFi blips
if ! grep -q '^ClientAliveInterval' /etc/ssh/sshd_config; then
    echo "ClientAliveInterval 30" | sudo tee -a /etc/ssh/sshd_config >/dev/null
    echo "ClientAliveCountMax 6"  | sudo tee -a /etc/ssh/sshd_config >/dev/null
fi

sudo systemctl restart ssh

echo "==> Ensuring ~/.ssh exists and authorized_keys is set up"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"

echo "==> Creating ~/projects (a conventional dir for VS Code workspaces)"
mkdir -p "$HOME/projects"

# Detect the VM's primary LAN IP for printing the SSH config snippet
LAN_IP="$(ip -4 -o route get 1 2>/dev/null | awk '{print $7; exit}')"
LAN_IP="${LAN_IP:-<vm-LAN-ip>}"

cat <<EOF

---------------------------------------------------------------------
SSH on the VM is hardened: pubkey-only, no password, no root login.

NEXT STEP (do this on EACH client machine you want to connect from):

1) Generate an ed25519 key (skip if you already have one):
       ssh-keygen -t ed25519 -C "\$(hostname)-to-ubuntu-sandbox" -f ~/.ssh/ubuntu_sandbox_ed25519

2) Copy the public key into this VM:
       ssh-copy-id -i ~/.ssh/ubuntu_sandbox_ed25519.pub $USER@$LAN_IP

   (Or, if password auth is already disabled and you're locked out, paste the
    pubkey directly into ~/.ssh/authorized_keys via the local console.)

3) Add to ~/.ssh/config on the client:
       Host ubuntu-sandbox
           HostName $LAN_IP
           User $USER
           IdentityFile ~/.ssh/ubuntu_sandbox_ed25519
           IdentitiesOnly yes
           ServerAliveInterval 30
           ServerAliveCountMax 6

4) Connect:
       ssh ubuntu-sandbox

5) In VS Code on the client:
       - Install the "Remote - SSH" extension.
       - F1 -> Remote-SSH: Connect to Host... -> ubuntu-sandbox
       - File -> Open Folder -> /home/$USER/projects (or wherever your code lives)

This VM's current LAN IP is $LAN_IP. Reserve this IP for the VM's MAC
in your home router's DHCP settings if you want it to stay stable.
---------------------------------------------------------------------
EOF
