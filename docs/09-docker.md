# 09 — Docker (no nested virtualization required)

Run [`scripts/guest/03-install-docker.sh`](../scripts/guest/03-install-docker.sh). It installs Docker CE from the **official Docker apt repo**, not the snap, and not Docker Desktop.

## Why not Docker Desktop?

Docker Desktop on Linux runs Docker inside its own VM via KVM/QEMU — that would require **nested virtualization** in our Hyper-V VM, which we deliberately disabled (see [01-architecture-decisions.md](01-architecture-decisions.md)). Docker CE (also called Docker Engine) runs natively using cgroups + namespaces, no hypervisor needed.

## What the script does

1. Adds Docker's apt signing key to `/etc/apt/keyrings/docker.asc`.
2. Adds the Docker `noble` repo (Ubuntu 24.04's codename) to `/etc/apt/sources.list.d/docker.list`.
3. Installs `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`.
4. Adds your user to the `docker` group.
5. Verifies with `docker run --rm hello-world`.

You'll need to **log out and back in** (or `newgrp docker`) for the group membership to take effect for your shell.

## Storage notes

- Docker stores images and volumes under `/var/lib/docker`, which lives on the VM's root VHDX. The dynamic 200 GB VHDX grows as needed.
- If you find Docker eating most of the disk: `docker system prune -a --volumes` to nuke unused images and volumes. (Be careful — this drops *everything* not currently in use.)

## Watch out for the snap version

If you ever ran `sudo snap install docker`, the snap version puts data in `/var/snap/docker/common/var-lib-docker/` and conflicts with the apt version. Remove with `sudo snap remove docker` *before* running the install script.

## Buildx & multi-arch

The script installs `docker-buildx-plugin`, so `docker buildx build --platform linux/amd64,linux/arm64` works out of the box. Useful if Claude Code is building images for deployment to ARM hosts.

## Reaching containerized apps from your LAN

A web app running on `0.0.0.0:3000` inside a container in the VM is reachable:

- **From the host:** `http://192.168.50.10:3000`.
- **From other LAN machines:** add a port forward (host `30000` → VM `3000`) with [`scripts/host/03-add-port-forward.ps1`](../scripts/host/03-add-port-forward.ps1), then `http://<host-LAN-ip>:30000`.
- **From VS Code Remote-SSH:** auto-forwarded to `localhost:3000` on your client (see [08-vscode-remote.md](08-vscode-remote.md)).
