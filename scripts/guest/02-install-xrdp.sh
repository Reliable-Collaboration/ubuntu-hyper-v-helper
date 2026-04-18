#!/usr/bin/env bash
# Install xrdp for Hyper-V Enhanced Session Mode, switching the backend from
# Xorg (which regressed in Feb 2025) to TigerVNC.
# Configures the hv_sock listener so vmconnect's "Enhanced Session" works.
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

echo "==> Removing the [Xorg] session entry from xrdp.ini (the Feb-2025-regressed backend)"
# Strip the [Xorg] block (and its trailing blank line) from xrdp.ini if present.
sudo python3 - <<'PY'
import re, pathlib
p = pathlib.Path('/etc/xrdp/xrdp.ini')
text = p.read_text()
# Remove a [Xorg] ... block that ends just before the next [section] or EOF.
new = re.sub(r'(?ms)^\[Xorg\].*?(?=^\[|\Z)', '', text)
if new != text:
    p.write_text(new)
    print("  removed [Xorg] block")
else:
    print("  [Xorg] block already absent")
PY

echo "==> Tuning [Xvnc] (TigerVNC) parameters in sesman.ini for usable framerate"
sudo python3 - <<'PY'
import re, pathlib
p = pathlib.Path('/etc/xrdp/sesman.ini')
text = p.read_text()
# Find the [Xvnc] section and ensure our tuning params are present.
m = re.search(r'(?ms)^\[Xvnc\].*?(?=^\[|\Z)', text)
if not m:
    raise SystemExit("[Xvnc] section not found in sesman.ini -- aborting")
section = m.group(0)
extra_params = [
    "param=-CompareFB",
    "param=1",
    "param=-ZlibLevel",
    "param=0",
    "param=-geometry",
    "param=1920x1080",
]
to_add = [p for p in extra_params if p not in section]
if to_add:
    section_new = section.rstrip() + "\n" + "\n".join(to_add) + "\n\n"
    text = text[:m.start()] + section_new + text[m.end():]
    p.write_text(text)
    print(f"  added {len(to_add)} param line(s) to [Xvnc]")
else:
    print("  [Xvnc] params already tuned")
PY

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

echo "==> Installing PAM stanza so the GNOME keyring unlocks at xrdp login (no per-session prompt)"
sudo tee /etc/pam.d/xrdp-sesman >/dev/null <<'EOT'
#%PAM-1.0
auth     required  pam_env.so readenv=1
auth     required  pam_env.so readenv=1 envfile=/etc/default/locale
@include common-auth
-auth    optional  pam_gnome_keyring.so
-auth    optional  pam_kwallet5.so
@include common-account
@include common-password
session    required     pam_limits.so
session    required     pam_loginuid.so
session    optional     pam_lastlog.so quiet
@include common-session
-session optional  pam_gnome_keyring.so auto_start
-session optional  pam_kwallet5.so auto_start
EOT

echo "==> Blacklisting vmw_vsock_vmci_transport (avoids known login delay)"
echo "blacklist vmw_vsock_vmci_transport" | \
    sudo tee /etc/modprobe.d/blacklist-vmw_vsock_vmci_transport.conf >/dev/null

echo "==> Pinning xrdp/xorgxrdp/tigervnc to avoid surprise regressions on apt upgrade"
sudo apt-mark hold xrdp xorgxrdp tigervnc-standalone-server tigervnc-xorg-extension || true

echo "==> Enabling and restarting xrdp"
sudo systemctl enable --now xrdp
sudo systemctl restart xrdp

cat <<'EOM'

xrdp configured with TigerVNC backend. Important next step:

    sudo poweroff

Then start the VM again from the host (don't just reboot). Hyper-V negotiates the
hv_sock channel at boot, so a full power cycle is the cleanest way to enable
Enhanced Session Mode.

Once back up:
  - From the host:  Hyper-V Manager -> Connect -> click "Enhanced Session" in toolbar.
  - From LAN:       mstsc / Microsoft Remote Desktop / Remmina to <vm-LAN-ip>:3389

For sandbox use:
  - In vmconnect "Show Options -> Local Resources", UNCHECK Drives.
  - To disable RDP-side drive/clipboard redirection completely:
        sudo sed -i 's/^allow_channels=true/allow_channels=false/' /etc/xrdp/xrdp.ini
        sudo systemctl restart xrdp
EOM
