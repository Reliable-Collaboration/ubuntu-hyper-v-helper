#!/usr/bin/env bash
# Install Tailscale on the Ubuntu VM and bring it up.
# Provides "from anywhere" access without touching NAT or firewall rules.
# Idempotent.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as your normal user, not root. The script uses sudo where needed." >&2
    exit 1
fi

if ! command -v tailscale >/dev/null; then
    echo "==> Installing Tailscale via official install script"
    curl -fsSL https://tailscale.com/install.sh | sh
fi

echo "==> Enabling tailscaled"
sudo systemctl enable --now tailscaled

# Recommended hardening: SSH access via Tailscale's built-in SSH (key+identity-based, easy ACLs)
EXTRA_FLAGS=()
if [[ "${TAILSCALE_SSH:-1}" -eq 1 ]]; then
    EXTRA_FLAGS+=( "--ssh" )
fi

# Use a tailnet-stable hostname
HOSTNAME_FLAG="--hostname=ubuntu-sandbox"

cat <<EOM

About to run:
    sudo tailscale up $HOSTNAME_FLAG ${EXTRA_FLAGS[*]:-}

This will print a one-time auth URL (or use an env var TAILSCALE_AUTHKEY=tskey-...).
Open the URL in a browser and log in to your tailnet.

After it completes:
  - Find this VM's tailnet name:   tailscale status
  - From any tailnet device:        ssh youruser@ubuntu-sandbox
  - In your tailnet ACLs (admin console), restrict access so only your own devices
    can reach this VM. Treat it as a sandbox, not a published service.
EOM

if [[ -n "${TAILSCALE_AUTHKEY:-}" ]]; then
    sudo tailscale up "$HOSTNAME_FLAG" "${EXTRA_FLAGS[@]}" --authkey "$TAILSCALE_AUTHKEY"
else
    sudo tailscale up "$HOSTNAME_FLAG" "${EXTRA_FLAGS[@]}"
fi

echo ""
echo "==> Tailscale status:"
tailscale status || true

cat <<'EOM'

Tip: also allow Tailscale-originated traffic in ufw if you've enabled it:
    sudo ufw allow in on tailscale0
EOM
