#!/usr/bin/env bash
# Install Docker CE (Engine) from Docker's official apt repo.
# Idempotent.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as your normal user, not root. The script uses sudo where needed." >&2
    exit 1
fi

if command -v snap >/dev/null && snap list 2>/dev/null | grep -q '^docker '; then
    echo "Detected snap-installed docker. Remove it first to avoid conflicts:" >&2
    echo "    sudo snap remove docker" >&2
    exit 1
fi

echo "==> Installing Docker apt repository signing key"
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
fi

echo "==> Adding Docker apt repo (noble = Ubuntu 24.04)"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu noble stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

echo "==> Installing Docker Engine + CLI + buildx + compose"
sudo apt-get update
sudo apt-get install -y \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

echo "==> Adding $USER to the docker group"
sudo usermod -aG docker "$USER"

echo "==> Verifying with hello-world (using sudo since group membership not yet active in this shell)"
sudo docker run --rm hello-world

cat <<EOM

Docker installed. To use it without sudo, start a NEW shell (or run 'newgrp docker').

Quick sanity checks after re-login:
    docker version
    docker compose version
    docker buildx version
    docker run --rm hello-world

Storage lives at /var/lib/docker on the root VHDX.
Clean unused images/volumes when disk fills up:
    docker system prune -a --volumes
EOM
