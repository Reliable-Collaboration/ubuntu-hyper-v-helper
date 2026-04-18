# 04 — Install Ubuntu 24.04 desktop & first-boot bootstrap

## During the installer

- **Language / keyboard** as desired.
- **Updates and other software** → "Normal installation"; tick "Download updates while installing" if you have bandwidth.
- **Installation type** → "Erase disk and install Ubuntu". This is the 200 GB VHDX, fully sandboxed.
- **Who are you?**
  - Pick a real password (not `password123`).
  - **Leave "Log in automatically" UNCHECKED.** xrdp won't work cleanly if the desktop user is auto-logged-in locally.
- Reboot when prompted. After it comes back up, eject the ISO (Hyper-V Manager → Settings → DVD Drive → None) and move **Hard Drive** above **DVD Drive** in the Firmware boot order so future boots don't drop into the installer.

## First-boot bootstrap inside the VM

Open a terminal in the VM and run:

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/Reliable-Collaboration/ubuntu-hyper-v-helper.git
cd ubuntu-hyper-v-helper
./scripts/guest/01-bootstrap.sh
```

The script:

1. Updates the system.
2. Installs the **Hyper-V virtual / cloud tools** for the HWE kernel:
   - `linux-tools-virtual-hwe-24.04`
   - `linux-cloud-tools-virtual-hwe-24.04` (this is where the kvp daemon and its systemd unit live on 24.04 — the standalone `hv-kvp-daemon-init` package from the 16.04 era is no longer needed)
3. Symlinks `hv_get_dhcp_info` / `hv_get_dns_info` from `/usr/sbin/` into `/usr/libexec/hypervkvpd/` to silence the journald spam from the KVP daemon (only if those binaries are present).
4. Installs an **udev rule** that sets the `none` I/O scheduler on virtual disks (per Microsoft's Linux-on-Hyper-V best-practice guide).
5. Installs `openssh-server` and enables it (so VS Code Remote-SSH and tmux-over-SSH work; see [08-vscode-remote.md](08-vscode-remote.md) and [12-tmux-workflow.md](12-tmux-workflow.md)).
6. Installs basic developer tooling: `git`, `curl`, `wget`, `tmux`, `htop`, `unzip`, `ca-certificates`, `jq`, `build-essential`.

Reboot once after the script finishes. The Hyper-V integration daemons (KVP, fcopy, VSS) fail to start in-place right after install — systemd hasn't wired up the `vmbus!hv_kvp` device unit yet — but they come up cleanly on the next boot.

```bash
sudo reboot
```

After the reboot, confirm the daemons are in the expected state:

```bash
systemctl is-active hv-kvp-daemon hv-fcopy-daemon hv-vss-daemon
# expect: active / inactive / active
```

`hv-fcopy-daemon` stays `inactive` because we keep the host-side "Guest services" integration disabled — see [10-sandbox-hardening.md](10-sandbox-hardening.md). The daemon unit is installed and enabled; it just skips starting until/unless `/dev/vmbus/hv_fcopy` shows up.
