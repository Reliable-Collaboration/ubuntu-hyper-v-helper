# Installation notes for disco-penguin

Test VM for the first real end-to-end run of the guest scripts. The VM itself was created by hand from a slightly-imperfect earlier pass at the docs; we're now running the guest scripts in order and recording what actually happens.

## Pre-bootstrap

Installed by hand before invoking any repo scripts:

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/Reliable-Collaboration/ubuntu-hyper-v-helper.git

sudo apt install curl -y
curl -fsSL https://claude.ai/install.sh | bash
```

## Starting state

- `uname -r`: `6.17.0-20-generic` (Ubuntu ships the rolling HWE kernel on 24.04.4; notably newer than the 6.8 series the script's comments implicitly assume, but the `linux-*-hwe-24.04` meta-packages resolve to the 6.17 point release cleanly — see below).
- `lsb_release -d`: `Ubuntu 24.04.4 LTS` (noble).
- `systemd-detect-virt`: `microsoft` (Hyper-V).
- `/usr/libexec/hypervkvpd/`: did not exist before the script ran.
- No `linux-tools-virtual-*` / `linux-cloud-tools-virtual-*` packages installed yet.

## `scripts/guest/01-bootstrap.sh` — first run

Ran as `waddle`. Exit 0. Relevant bits:

- `apt-get full-upgrade` → `0 upgraded, 0 newly installed` (VM was already current).
- `linux-tools-virtual-hwe-24.04` + `linux-cloud-tools-virtual-hwe-24.04` pulled in `linux-cloud-tools-6.17.0-20-generic`, `linux-cloud-tools-common`, `linux-hwe-6.17-cloud-tools-6.17.0-20`. The HWE meta-packages tracked the running kernel correctly.
- Three `hv-*-daemon` units got `multi-user.target.wants` symlinks (KVP, fcopy, VSS).
- dpkg emitted **`Could not execute systemctl:  at /usr/bin/deb-systemd-invoke line 148.`** once, while setting up `linux-cloud-tools-common`. This is the in-place `systemctl start` failing because the `sys-devices-virtual-misc-vmbus!hv_kvp.device` systemd device unit hadn't settled yet — see "hv daemons inactive post-install" below. Package installation itself succeeded.
- KVP helper symlink step ran; both symlinks now exist:
  - `/usr/libexec/hypervkvpd/hv_get_dhcp_info → /usr/sbin/hv_get_dhcp_info`
  - `/usr/libexec/hypervkvpd/hv_get_dns_info  → /usr/sbin/hv_get_dns_info`
- `/etc/udev/rules.d/60-ioschedulers.rules` written.
- `openssh-server` installed and `ssh.service` enabled + active. `ssh.socket` also enabled.
- Dev tools installed: `tmux`, `htop`, `build-essential` + transitive deps (42 new packages, ~196 MB).

Warnings that appeared in the log but are **expected / harmless** when running the script non-interactively (piped stdout, e.g. through `tee`):

- `dpkg-preconfigure: unable to re-open stdin: No such file or directory` — benign when no tty is wired to stdin.

## Post-install verification

- `/sys/block/sda/queue/scheduler` → `[none] mq-deadline` — the `none` scheduler is already active. (The udev rule handles new disks / hot-attach; the already-attached `sda` happened to be on `none` anyway on this kernel.)
- `systemctl is-enabled ssh` → `enabled`; `is-active` → `active`. Port 22 listening.
- `hv-kvp-daemon.service` / `hv-fcopy-daemon.service` / `hv-vss-daemon.service` → all `enabled`, all `inactive`.

### Gotcha: hv daemons inactive post-install

Manually starting `hv-kvp-daemon` immediately after bootstrap fails with:

```
A dependency job for hv-kvp-daemon.service failed. See 'journalctl -xe' for details.
…
Timed out waiting for device sys-devices-virtual-misc-vmbus!hv_kvp —
  /sys/devices/virtual/misc/vmbus!hv_kvp.
```

But the underlying pieces are all healthy:

- `hv_vmbus`, `hv_utils`, `hv_balloon`, `hv_netvsc`, `hv_storvsc`, `hid_hyperv`, `hyperv_keyboard`, `hyperv_drm` all loaded.
- `/dev/vmbus/hv_kvp` and `/dev/vmbus/hv_vss` exist as char devices.
- `/sys/bus/vmbus/devices/` is populated (14 devices).

So the KVP bits are live at the kernel level; only systemd's `.device` unit hasn't been wired up on this boot because the vmbus devices were enumerated before `hv-kvp-daemon.service` was installed, and no udev event has re-announced them. A reboot resolves it — which is exactly what the script's closing message recommends.

**Takeaway for the docs:** the reboot after `01-bootstrap.sh` is not optional on a first run. Skipping it leaves the integration daemons inactive until next boot. Current `docs/04-ubuntu-install.md` already says "Reboot once after the script finishes"; that wording is correct, not just a nicety.

## Next

Reboot, then verify the three hv daemons are active before moving on to `02-install-xrdp.sh`.
