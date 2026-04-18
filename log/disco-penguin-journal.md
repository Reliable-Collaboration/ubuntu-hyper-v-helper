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

## Preferences
These commands will prevent the desktop from automatically locking when it's idle.
``` bash
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0

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

## Spec correction + doc cleanup pass

Before proceeding to `02-install-xrdp.sh` we paused to reconcile a spec drift that had accreted in the docs. The original hardening doc framed outbound network filtering as a core defense ("reverse shells back to the internet" listed as in-scope) and shipped a `04-harden-ufw.sh` script with an egress allowlist plus an inbound SSH/RDP allowlist scoped to the LAN subnet. Those fits were wrong for the actual use case:

- The VM's purpose is to be fully LAN-reachable on whatever ports an application binds (SSH, RDP, HTTP dev servers, anything else). An inbound allowlist restricted to 22/3389 is user-hostile and counter to the goal.
- Outbound filtering by port/protocol is a poor fit for the agent-isolation threat model — easy to evade, frustrating for developers who don't know what's blocked. If the kill-switch matters for a given run, disconnecting the VM's vSwitch in Hyper-V Manager is the honest version.
- "Off-LAN access (coffee shop)" was a hypothetical we don't have: the host is a stationary Windows 11 desktop on wired Ethernet, not a mobile laptop.

Changes (all in this commit):

- Deleted `scripts/guest/04-harden-ufw.sh`.
- Renumbered `05-prepare-vscode-remote.sh` → `04-prepare-vscode-remote.sh` and `06-install-claude-code.sh` → `05-install-claude-code.sh` so the guest-scripts numbering stays contiguous.
- Rewrote `docs/10-sandbox-hardening.md` around an explicit threat model (agent-in-VM is untrusted; host / LAN / internet are more trustworthy than the agent) and explicit anti-defenses ("what's not a defense: a guest-side firewall; what's out of scope: LAN segmentation"). Kept the real defenses: host↔VM isolation, no-host-creds-in-VM, snapshots.
- `docs/05-networking.md`: removed the coffee-shop bullet; rewrote the sandbox-isolation note to not mention ufw; added a new section "F. Reaching apps served from inside the VM" with the bind-to-`0.0.0.0` pattern for Next.js/Vite/Python/Docker.
- `docs/01-architecture-decisions.md`: added a "Guest firewall — ufw left inactive" row with the rationale.
- `docs/07-remote-desktop-options.md`: cut the NoMachine/RustDesk/Guacamole/Sunshine alternatives menu. We use xrdp; the alternatives are scope drift for this use case.
- `docs/13-claude-code-in-the-vm.md`: dropped the `"assuming you ran the hardening script"` caveat and the "don't disable `ufw`" bullet. Script reference updated to `05-install-claude-code.sh`.
- `docs/08-vscode-remote.md`: script reference updated to `04-prepare-vscode-remote.sh`.
- `README.md`: quick-start step 8/10/13 updated; repo-layout tree reflects the new guest-script set.
- `CLAUDE.md`: added two out-of-scope rules so this design decision doesn't drift back in — "don't re-add a guest-side firewall script" and "don't invent mobility/off-LAN scenarios."

## Next

Move on to `02-install-xrdp.sh`.
