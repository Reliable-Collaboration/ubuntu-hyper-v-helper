#!/usr/bin/env bash
# Prepare the VM to be a comfortable VS Code Remote-SSH target.
# Mostly: make sure sshd is up, generate an authorized_keys directory, ensure
# common globs (~/projects, ~/.config) exist, and print the snippet to add to
# the CLIENT machine's ~/.ssh/config.
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

echo "==> Hardening sshd: disable root login + password auth, keep ed25519 host keys"
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

# Detect the VM's NAT IP for printing the SSH config snippet
NAT_IP="$(ip -4 -o addr show | awk '/192\.168\.50\./ {split($4,a,"/"); print a[1]; exit}')"
NAT_IP="${NAT_IP:-192.168.50.10}"

cat <<EOF

---------------------------------------------------------------------
SSH on the VM is hardened: pubkey-only, no password, no root login.

NEXT STEP (do this on EACH client machine you want to connect from):

1) Generate an ed25519 key (skip if you already have one):
       ssh-keygen -t ed25519 -C "\$(hostname)-to-ubuntu-sandbox" -f ~/.ssh/ubuntu_sandbox_ed25519

2) Copy the public key into this VM:
       ssh-copy-id -i ~/.ssh/ubuntu_sandbox_ed25519.pub -p 2222 $USER@<windows-host-LAN-ip>

   (Or, if password auth is already disabled and you're locked out, paste the
    pubkey directly into ~/.ssh/authorized_keys via the local console.)

3) Add to ~/.ssh/config on the client:
       Host ubuntu-sandbox
           HostName <windows-host-LAN-ip>     # or ubuntu-sandbox.<tailnet>.ts.net
           Port 2222                          # drop this line for the Tailscale path
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

Reminder: this VM has IP $NAT_IP on the NAT switch.
---------------------------------------------------------------------
EOF
