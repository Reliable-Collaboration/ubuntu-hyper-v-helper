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

## GitHub CLI + push auth

The VM was cloned with HTTPS and had no credential helper, so pushing the first commit failed. We installed the GitHub CLI from the official apt repo and used its device-code login flow — this avoids pasting a PAT into shell history and gives us a per-VM credential that's trivially revocable from GitHub's UI.

```bash
# From https://cli.github.com/ install instructions
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update && sudo apt-get install -y gh

# Login (device-code flow — prints one-time code + URL, poll for approval)
gh auth login -h github.com -p https -w

# Wire gh as git's credential helper for github.com / gist.github.com
gh auth setup-git
```

Notes:

- Git commit identity is configured repo-locally to `waddle-p <waddle-bot@rcc.team>` (set with `git config user.{name,email}`, no `--global`). This keeps the disposable-VM commits visibly attributed and doesn't leak to anything cloned into this VM later.
- The gh OAuth token lives in `~/.config/gh/hosts.yml` in plaintext (gh warns about this on Linux — no keyring). Acceptable for a sandbox VM we'll nuke. **Do not commit that file.**
- Token scopes granted: `gist, read:org, repo` (gh's default for the device-code flow).
- Rotation: `gh auth logout` on the VM + "Revoke" the token under GitHub → Settings → Applications when the VM is retired.

This pattern is worth promoting to a real script in the `scripts/guest/` set later — it's going to be a per-sandbox step every time.

## Post-reboot verification

After `sudo reboot` and reconnecting:

```
uptime -p                     → up 1 minute
systemctl is-active ssh       → active
/sys/block/sda/queue/scheduler → [none] mq-deadline

hv-kvp-daemon    active
hv-fcopy-daemon  inactive   ← expected, see below
hv-vss-daemon    active
```

`hv-fcopy-daemon` is skipped each boot with:

```
hv-fcopy-daemon.service - Hyper-V File Copy Protocol Daemon was skipped
because of an unmet condition check (ConditionPathExists=/dev/vmbus/hv_fcopy).
```

`/dev/vmbus/` contains only `hv_kvp` and `hv_vss` — no `hv_fcopy`. That device only shows up when the host has **Integration Services → Guest services** enabled on the VM, which exposes `Copy-VMFile`. We deliberately leave it off: it's a host→guest file-push channel, same isolation-leak class as "Shared Drives" (which `docs/10-sandbox-hardening.md` already forbids). Updated both `docs/04-ubuntu-install.md` (corrected the post-reboot expected output) and `docs/10-sandbox-hardening.md` (added "Guest services" to the ❌ list) to reflect this.

## Next

Move on to `02-install-xrdp.sh`.
