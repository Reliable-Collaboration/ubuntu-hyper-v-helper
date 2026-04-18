# 06 — Enhanced Session Mode (xrdp via hv_sock)

Enhanced Session Mode lets `vmconnect` (and any RDP client) talk to the VM over Hyper-V's hardware socket transport (`hv_sock`) instead of needing a network round-trip. Benefits: better resolution scaling, audio, clipboard, and the ability to connect *before* the VM has a working network.

## Run the helper

```bash
./scripts/guest/02-install-xrdp.sh
```

What it does:

1. Installs `xrdp`, `tigervnc-standalone-server`, and `tigervnc-xorg-extension`.
2. Configures xrdp to listen on both **TCP 3389** and **`vsock://-1:3389`** (the hv_sock transport for Enhanced Session).
3. **Removes the `[Xorg]` session block from `/etc/xrdp/xrdp.ini`** so the regressed Xorg backend is no longer the default.
4. **Adds tuning params to the `[Xvnc]` section of `/etc/xrdp/sesman.ini`** (`-CompareFB 1`, `-ZlibLevel 0`, `-geometry 1920x1080`) so the TigerVNC backend gives a usable framerate.
5. Forces a GNOME session via a small `startubuntu.sh` wrapper.
6. Installs a PAM stanza that unlocks the GNOME keyring at xrdp login (no per-session password prompt).
7. Blacklists `vmw_vsock_vmci_transport` (avoids a known login delay).
8. Pins `xrdp`, `xorgxrdp`, and the TigerVNC packages with `apt-mark hold` so `unattended-upgrades` can't re-introduce the regression. Unhold with `sudo apt-mark unhold xrdp xorgxrdp tigervnc-standalone-server tigervnc-xorg-extension` when you want updates.

After it finishes, **fully shut the VM down** (don't just reboot):

```bash
sudo poweroff
```

Hyper-V negotiates the hv_sock channel at boot — a power cycle is the cleanest way to make sure the new transport is picked up.

## Connecting

- **From the Hyper-V host:** open Hyper-V Manager → right-click the VM → Connect. The toolbar will show "Enhanced Session" — click it. You'll get a resolution / display options dialog.
- **From other LAN machines (RDP):** `mstsc` on Windows, *Microsoft Remote Desktop* on macOS, or *Remmina* on Linux, pointed at `<vm-LAN-ip>:3389`. This goes over TCP, not hv_sock — same UX, slightly less polished integrations (clipboard depends on the client).

## Sandbox hygiene

In the `vmconnect` "Show Options → Local Resources" dialog **before connecting**:

- ❌ Uncheck **Drives** (drive redirection — biggest data leak vector).
- ❌ Uncheck **Printers**, **Smart cards**, **Ports** unless you actively need them.
- ✅ Leave **Clipboard** if you want copy/paste, but treat it as a leak channel — never paste credentials.

Server-side equivalent (block all redirected channels at the xrdp level):

```bash
sudo sed -i 's/^allow_channels=true/allow_channels=false/' /etc/xrdp/xrdp.ini
sudo systemctl restart xrdp
```

## Troubleshooting

- **"Enhanced Session" button greyed out:** check Hyper-V Manager → Hyper-V Settings → Server / User both have Enhanced Session Mode enabled (see [02-host-prereqs.md](02-host-prereqs.md)).
- **Black screen forever after login:** don't move the mouse during the few seconds after entering credentials — known race in xrdp's GNOME handoff.
- **"Cannot connect" right after install:** confirm `Set-VM -Name ubuntu-sandbox -EnhancedSessionTransportType HvSocket` ran on the host (the PowerShell block in [03-create-vm.md](03-create-vm.md)).
- **Blank desktop / can't log in remotely while logged in locally:** xrdp doesn't share sessions with the local console. Log out locally before connecting remotely. (Long-standing xrdp limitation.)
- **After an apt upgrade, things broke:** restore configs from `/etc/xrdp/*.bak` (the install script saves them) and reapply the `vsock://` line. Or re-run the install script — it's idempotent.

## Skip xrdp entirely?

For pure Claude Code work you may not need a desktop at all. Plain SSH + tmux ([12-tmux-workflow.md](12-tmux-workflow.md)) plus VS Code Remote-SSH ([08-vscode-remote.md](08-vscode-remote.md)) covers ~95% of dev work, faster and with smaller attack surface.
