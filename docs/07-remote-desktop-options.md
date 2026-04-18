# 07 — Remote desktop & monitoring options

Beyond `vmconnect` (Hyper-V Manager's built-in console), here are realistic options for watching/using the VM from another machine on your LAN.

## TL;DR pick

For your scenario (sandbox VM on the LAN at its own IP, accessed from the host + WiFi laptop):

- **xrdp** for the remote desktop itself (already installed in [06-enhanced-session.md](06-enhanced-session.md)).
- **Any RDP client** to reach it: `mstsc` on Windows, *Microsoft Remote Desktop* on macOS, *Remmina* on Linux, *RD Client* on iOS/Android. Point it at `<vm-LAN-ip>:3389`.
- **VS Code Remote-SSH** for editing files and running commands ([08-vscode-remote.md](08-vscode-remote.md)) — usually faster than driving a GUI.

You do not need to pick one. Layer them: xrdp + Remmina/mstsc for "see the desktop", VS Code Remote-SSH for "edit and run", tmux + SSH for "long-running shells".

## The full menu, compared

| Tool | Protocol | LAN perf | Self-hostable? | Open source? | Best for |
|---|---|---|---|---|---|
| **xrdp + RDP client** | RDP | Excellent | yes | yes | The default. Wide client support. |
| **NoMachine** (free for personal) | NX | Excellent–best | yes | partial | Lowest-latency desktop on LAN. |
| **RustDesk** | proprietary | Good | yes (relay server self-hostable) | yes | TeamViewer replacement; behind-NAT relay. |
| **Sunshine + Moonlight** | game-streaming codecs | Best | yes | yes | Smooth video/animation; overkill for shells. |
| **Apache Guacamole** | RDP/VNC/SSH in browser | OK | yes | yes | "Click a URL, get a desktop" with no client install. Heavier setup. |
| **TigerVNC standalone** | VNC | Decent | yes | yes | Headless servers; we use it as the *backend* of xrdp. |
| **GNOME Remote Desktop** (built-in) | RDP | Good | yes | yes | Zero-install, but only attaches to the local console session — bad fit for a sandbox you'll often use without a local user. |

### Why xrdp instead of GNOME Remote Desktop on Ubuntu 24.04?

GNOME's built-in RDP server attaches to the *currently logged-in console* session. That means the VM has to have someone logged in at the local console, and you can only have one session. For a headless-ish sandbox VM, xrdp is the right call — it spawns its own session for each RDP login.

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
                   └──────────────────────────┘
```

- The VM is just another device on the LAN. There is no NAT, no port-forward, no virtual router in this picture.
- All clients address the VM by its LAN IP (or the hostname your router gives it via DNS, if you're using something like Pi-hole or your router's local DNS).

## If you want the lowest-latency desktop possible

Install **NoMachine** server in the VM and the NoMachine client on your other machines. Their NX protocol typically beats RDP and VNC for animation-heavy desktops. The free tier is fine for personal use.

## If you want a "no-install" web-browser path

Stand up **Apache Guacamole** somewhere (a small VM or container) and point it at `<vm-LAN-ip>:3389`. You'll get a browser-based RDP gateway — handy for the rare case where you need to hop in from a borrowed laptop. Adds a service to manage; only worth it if "open a URL" is the goal.

## Monitoring vs. controlling

If you only want to *watch* the VM (not control), the lightest paths are:

- `ssh youruser@<vm-ip> 'top -b -n1'` over SSH from anywhere on the LAN.
- A web dashboard like **Netdata** running on the VM, accessible at `http://<vm-ip>:19999/`.
- For "is the VM up at all", `Get-VM ubuntu-sandbox | Select State,Uptime` on the host.
