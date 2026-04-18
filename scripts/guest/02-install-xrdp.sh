#!/usr/bin/env bash
# Install xrdp + TigerVNC backend for Hyper-V Enhanced Session Mode.
# Configures hv_sock listener so vmconnect's "Enhanced Session" works.
# Switches the backend from Xorg (regressed in Feb 2025) to TigerVNC.
# Idempotent.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as your normal user, not root. The script uses sudo where needed." >&2
    exit 1
fi

echo "==> Installing xrdp + TigerVNC backend"
sudo apt-get update
sudo apt-get install -y xrdp tigervnc-standalone-server tigervnc-xorg-extension

echo "==> Backing up existing xrdp configs (.bak)"
for f in /etc/xrdp/xrdp.ini /etc/xrdp/sesman.ini; do
    if [[ -f "$f" && ! -f "${f}.bak" ]]; then
        sudo cp -p "$f" "${f}.bak"
    fi
done

echo "==> Adding hv_sock listener to xrdp.ini (so Enhanced Session Mode works)"
if ! grep -q 'vsock://' /etc/xrdp/xrdp.ini; then
    sudo sed -i 's|^port=3389$|port=3389 vsock://-1:3389|' /etc/xrdp/xrdp.ini
fi

echo "==> Renaming Fuse mount (avoids 'thinclient_drives' weirdness)"
sudo sed -i 's|^FuseMountName=thinclient_drives|FuseMountName=shared-drives|' /etc/xrdp/sesman.ini || true

echo "==> Forcing GNOME (ubuntu) session via /etc/xrdp/startubuntu.sh"
sudo tee /etc/xrdp/startubuntu.sh >/dev/null <<'EOF'
#!/bin/sh
export GNOME_SHELL_SESSION_MODE=ubuntu
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
exec /etc/xrdp/startwm.sh
EOF
sudo chmod a+x /etc/xrdp/startubuntu.sh
sudo sed -i 's|startwm|startubuntu|g' /etc/xrdp/sesman.ini

echo "==> Blacklisting vmw_vsock_vmci_transport (avoids known login delay)"
echo "blacklist vmw_vsock_vmci_transport" | \
    sudo tee /etc/modprobe.d/blacklist-vmw_vsock_vmci_transport.conf >/dev/null

echo "==> Pinning xrdp/xorgxrdp/tigervnc to avoid surprise regressions on apt upgrade"
sudo apt-mark hold xrdp xorgxrdp tigervnc-standalone-server tigervnc-xorg-extension || true

echo "==> Enabling and restarting xrdp"
sudo systemctl enable --now xrdp
sudo systemctl restart xrdp

cat <<'EOM'

xrdp configured. Important next step:

    sudo poweroff

Then start the VM again from the host (don't just reboot). Hyper-V negotiates the
hv_sock channel at boot, so a full power cycle is the cleanest way to enable
Enhanced Session Mode.

Once back up:
  - From the host:  Hyper-V Manager -> Connect -> click "Enhanced Session" in toolbar.
  - From LAN:       mstsc / Microsoft Remote Desktop / Remmina to <host>:33890
                    (assuming you've run scripts/host/03-add-port-forward.ps1).

For sandbox use:
  - In vmconnect "Show Options -> Local Resources", UNCHECK Drives.
  - To disable RDP-side drive/clipboard redirection completely:
        sudo sed -i 's/^allow_channels=true/allow_channels=false/' /etc/xrdp/xrdp.ini
        sudo systemctl restart xrdp
EOM
