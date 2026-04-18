# 07 — Remote desktop & monitoring options

Beyond `vmconnect` (Hyper-V Manager's built-in console), the options you'll actually use for this sandbox VM from other LAN devices.

## TL;DR pick

- **xrdp** for the remote desktop itself (installed in [06-enhanced-session.md](06-enhanced-session.md)).
- **Any RDP client** to reach it: `mstsc` on Windows, *Microsoft Remote Desktop* on macOS, *Remmina* on Linux, *RD Client* on iOS/Android. Point it at `<vm-LAN-ip>:3389`.
- **VS Code Remote-SSH** for editing files and running commands ([08-vscode-remote.md](08-vscode-remote.md)) — usually faster than driving a GUI.

You don't pick one — you layer them: xrdp + any RDP client for "see the desktop", VS Code Remote-SSH for "edit and run", tmux + SSH for "long-running shells".

## Why xrdp instead of GNOME Remote Desktop on Ubuntu 24.04

GNOME's built-in RDP server attaches to the *currently logged-in console* session — the VM would have to have someone logged in locally, and only one session is possible. For a headless-ish sandbox VM, xrdp is the right call; it spawns its own session for each RDP login.

## Layered access pattern

```
   ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
   │ Host (wired)    │   │ Laptop (WiFi)   │   │ Phone / tablet  │
   │ Hyper-V Manager │   │ mstsc / Remmina │   │ RD Client       │
   │ + VS Code RSH   │   │ + VS Code RSH   │   │                 │
   └────────┬────────┘   └────────┬────────┘   └────────┬────────┘
            │                     │                     │
            └─────────────────────┼─────────────────────┘
                       Home LAN (one subnet)
                                  │
                                  ▼
                   ┌──────────────────────────┐
                   │ Ubuntu 24.04 VM          │
                   │ <router-issued IP>       │
                   │ External-Wired vSwitch   │ ◀─ xrdp (3389)
                   │                          │ ◀─ openssh (22)
                   │                          │ ◀─ any app port
                   └──────────────────────────┘
```

The VM is just another device on the LAN. Clients address it by its LAN IP (or by its hostname if your router publishes local DNS).

## Monitoring from the host without opening a desktop

- `ssh youruser@<vm-ip> 'top -b -n1'` from anywhere on the LAN.
- `Get-VM ubuntu-sandbox | Select State,Uptime` on the host, for "is it up?".
