# 04 — Install Ubuntu 24.04 desktop & first-boot bootstrap

## During the installer

- **Language / keyboard** as desired.
- **Updates and other software** → "Normal installation"; tick "Download updates while installing" if you have bandwidth.
- **Installation type** → "Erase disk and install Ubuntu". This is the 200 GB VHDX, fully sandboxed.
- **Who are you?**
  - Pick a real password (not `password123`).
  - **Leave "Log in automatically" UNCHECKED.** xrdp won't work cleanly if the desktop user is auto-logged-in locally.
- Reboot when prompted. Eject the ISO afterward (Hyper-V Manager → settings → DVD drive → None) so future boots don't drop into the installer.

## First-boot bootstrap inside the VM

Open a terminal and run [`scripts/guest/01-bootstrap.sh`](../scripts/guest/01-bootstrap.sh). The fastest way to get the script in is:

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/<you>/ubuntu-hyper-v-helper.git
cd ubuntu-hyper-v-helper
./scripts/guest/01-bootstrap.sh
```

(If you haven't pushed this repo anywhere yet, you can also paste the script's contents into a file with `nano` — it's short.)

The script:

1. Updates the system.
2. Installs the **Hyper-V virtual / cloud tools** for the HWE kernel:
   - `linux-tools-virtual-hwe-24.04`
   - `linux-cloud-tools-virtual-hwe-24.04`
   - `hv-kvp-daemon-init`
3. Symlinks `hv_get_dhcp_info` / `hv_get_dns_info` into `/usr/libexec/hypervkvpd/` to silence the journald spam from the KVP daemon.
4. Installs an **udev rule** that sets the `none` I/O scheduler on virtual disks (per Microsoft's Linux-on-Hyper-V best-practice guide).
5. Installs `openssh-server` and enables it (so VS Code Remote-SSH and tmux-over-SSH work; see [08-vscode-remote.md](08-vscode-remote.md) and [12-tmux-workflow.md](12-tmux-workflow.md)).
6. Installs basic developer tooling: `git`, `curl`, `wget`, `tmux`, `htop`, `unzip`, `ca-certificates`.

Reboot once after the script finishes so the new kernel modules and udev rule are applied:

```bash
sudo reboot
```
