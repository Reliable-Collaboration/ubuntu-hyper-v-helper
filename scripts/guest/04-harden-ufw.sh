#!/usr/bin/env bash
# Lock down outbound traffic from the VM with a basic ufw allowlist.
# Default deny in/out, then explicit allows.
# Inbound SSH/RDP are restricted to the VM's current LAN subnet
# (auto-detected from its primary IP).
# Idempotent.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as your normal user, not root. The script uses sudo where needed." >&2
    exit 1
fi

# Auto-detect the VM's primary IPv4 and infer its /24.
VM_IP="$(ip -4 -o route get 1 2>/dev/null | awk '{print $7; exit}')"
if [[ -z "${VM_IP}" ]]; then
    echo "Could not auto-detect the VM's primary IPv4. Pass LAN_SUBNET=192.168.1.0/24 (or your subnet) to override." >&2
    exit 1
fi
LAN_SUBNET="${LAN_SUBNET:-${VM_IP%.*}.0/24}"
echo "VM IP: $VM_IP   Inferred LAN subnet: $LAN_SUBNET"

ALLOWED_OUT_TCP=( 80 443 9418 22 )    # HTTP, HTTPS, git://, ssh out (e.g. git over ssh)
DNS_PORTS=( 53 )

echo "==> Installing ufw"
sudo apt-get update
sudo apt-get install -y ufw

echo "==> Resetting and configuring ufw policies"
sudo ufw --force reset

sudo ufw default deny incoming
sudo ufw default deny outgoing

# Outbound: DNS
for p in "${DNS_PORTS[@]}"; do
    sudo ufw allow out "$p"/udp comment "DNS"
    sudo ufw allow out "$p"/tcp comment "DNS over TCP"
done

# Outbound: web + git
for p in "${ALLOWED_OUT_TCP[@]}"; do
    sudo ufw allow out "$p"/tcp comment "outbound TCP $p"
done

# NTP
sudo ufw allow out 123/udp comment "NTP"

# Inbound: SSH and RDP only from the VM's own LAN subnet
sudo ufw allow from "$LAN_SUBNET" to any port 22   proto tcp comment "SSH from LAN"
sudo ufw allow from "$LAN_SUBNET" to any port 3389 proto tcp comment "RDP from LAN"

# Allow loopback (ufw does this by default but be explicit)
sudo ufw allow in on lo
sudo ufw allow out on lo

echo "==> Enabling ufw"
sudo ufw --force enable
sudo ufw status verbose

cat <<EOM

ufw enabled. To open more outbound ports later (e.g. PostgreSQL outbound to a managed DB):
    sudo ufw allow out 5432/tcp comment "Postgres outbound"

To temporarily disable while debugging:
    sudo ufw disable

To re-enable:
    sudo ufw enable

Current rules:
    sudo ufw status numbered
EOM
