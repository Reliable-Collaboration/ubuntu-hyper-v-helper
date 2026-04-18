# 06 — Enhanced Session Mode (xrdp via hv_sock)

Enhanced Session Mode lets `vmconnect` (and any RDP client) talk to the VM over Hyper-V's hardware socket transport (`hv_sock`) instead of needing a network round-trip. Benefits: better resolution scaling, audio, clipboard, and the ability to connect *before* the VM has a working network.

## Run the helper

```bash
./scripts/guest/02-install-xrdp.sh
```

What it does:

1. Installs `xrdp` and the **TigerVNC** backend (the Xorg backend regressed in Feb 2025; TigerVNC is the current consensus best-perf path).
2. Configures xrdp to listen on both **TCP 3389** and **`vsock://-1:3389`** (the hv_sock transport for Enhanced Session).
3. Forces a GNOME session via a small `startubuntu.sh` wrapper.
4. Blacklists `vmw_vsock_vmci_transport` (avoids a known login delay).
5. Pins `xrdp` and `xorgxrdp` package versions to prevent unattended-upgrades from re-introducing the Xorg regression. Unhold with `sudo apt-mark unhold xrdp xorgxrdp tigervnc-standalone-server`.

After it finishes, **fully shut the VM down** (don't just reboot):

```bash
sudo poweroff
```

Hyper-V negotiates the hv_sock channel at boot — a power cycle is the cleanest way to make sure the new transport is picked up.

## Connecting

- **From the Hyper-V host:** open Hyper-V Manager → right-click the VM → Connect. The toolbar will show "Enhanced Session" — click it. You'll get a resolution / display options dialog.
- **From other LAN machines (RDP):** `mstsc` on Windows, *Microsoft Remote Desktop* on macOS, or *Remmina* on Linux, pointed at `<windows-host-LAN-ip>:33890` (the port you forwarded in [05-networking.md](05-networking.md)). This goes over TCP, not hv_sock — works exactly the same to the user, slightly less polished integrations (clipboard depends on the client).

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

- **Black screen forever after login:** don't move the mouse during the few seconds after entering credentials — known race in xrdp's GNOME handoff.
- **"Cannot connect" right after install:** confirm `Set-VM -Name ubuntu-sandbox -EnhancedSessionTransportType HvSocket` ran on the host (the create-VM script does this).
- **Blank desktop / can't log in remotely while logged in locally:** xrdp doesn't share sessions with the local console. Log out locally before connecting remotely. (This is the long-standing xrdp limitation.)
- **After an apt upgrade, things broke:** restore configs from `/etc/xrdp/*.bak` (the install script saves them) and reapply the `vsock://` line. Or pin packages (`apt-mark hold ...`) which the script already does.

## Skip xrdp entirely?

For pure Claude Code work you may not need a desktop at all. Plain SSH + tmux ([12-tmux-workflow.md](12-tmux-workflow.md)) plus VS Code Remote-SSH ([08-vscode-remote.md](08-vscode-remote.md)) covers ~95% of dev work, faster and with smaller attack surface.
