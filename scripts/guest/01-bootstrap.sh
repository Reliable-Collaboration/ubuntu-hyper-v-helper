#!/usr/bin/env bash
# First-boot bootstrap inside the Ubuntu 24.04 VM.
# Installs Hyper-V integration packages, fixes journal spam, sets I/O scheduler,
# installs OpenSSH server and basic dev tools.
# Idempotent. Run as your normal user (uses sudo internally).

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as your normal user, not root. The script uses sudo where needed." >&2
    exit 1
fi

echo "==> Updating apt cache and upgrading installed packages"
sudo apt-get update
sudo apt-get -y full-upgrade

echo "==> Installing Hyper-V integration tools (HWE kernel)"
# The kvp daemon and systemd units ship inside linux-cloud-tools-virtual-* on 24.04.
# (The standalone hv-kvp-daemon-init package from the 16.04 era is no longer needed.)
sudo apt-get install -y \
    linux-tools-virtual-hwe-24.04 \
    linux-cloud-tools-virtual-hwe-24.04

echo "==> Symlinking hv_kvp_daemon helpers (silences journald 'cannot find' errors)"
# The daemon looks for these helpers under /usr/libexec/hypervkvpd/, but they ship in /usr/sbin/.
if [[ -x /usr/sbin/hv_get_dhcp_info ]]; then
    sudo mkdir -p /usr/libexec/hypervkvpd
    sudo ln -sf /usr/sbin/hv_get_dhcp_info /usr/libexec/hypervkvpd/hv_get_dhcp_info
    sudo ln -sf /usr/sbin/hv_get_dns_info  /usr/libexec/hypervkvpd/hv_get_dns_info
else
    echo "  hv_get_dhcp_info not found at /usr/sbin/ -- skipping symlink. Check 'dpkg -L linux-cloud-tools-virtual-hwe-24.04' if journald complains later."
fi

echo "==> Installing 'none' I/O scheduler udev rule (per Microsoft Linux-on-Hyper-V best practice)"
sudo tee /etc/udev/rules.d/60-ioschedulers.rules >/dev/null <<'EOF'
# Hand I/O scheduling to the Hyper-V hypervisor.
ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
EOF

echo "==> Installing OpenSSH server (for tmux + VS Code Remote-SSH)"
sudo apt-get install -y openssh-server
sudo systemctl enable --now ssh

echo "==> Installing basic developer tools"
sudo apt-get install -y \
    git curl wget tmux htop unzip zip ca-certificates jq build-essential

echo ""
echo "Bootstrap complete. Recommended: reboot now so the new udev rule and kernel modules apply:"
echo "    sudo reboot"
