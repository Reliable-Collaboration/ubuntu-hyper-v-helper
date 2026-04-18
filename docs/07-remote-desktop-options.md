# 07 — Remote desktop & monitoring options

Beyond `vmconnect` (Hyper-V Manager's built-in console), here are the realistic options for watching/using the VM from another machine.

## TL;DR pick

For your scenario (sandbox VM, accessed from host + other LAN/WiFi machines, occasionally from off-LAN):

- **xrdp** for the remote desktop itself (already installed in [06-enhanced-session.md](06-enhanced-session.md)).
- **Any RDP client** to reach it: `mstsc` on Windows, *Microsoft Remote Desktop* on macOS, *Remmina* on Linux, *RD Client* on iOS/Android.
- **NAT port forward (host:33890 → VM:3389)** for LAN access from other machines.
- **Tailscale** as the easy "from anywhere" overlay; you can RDP straight to `ubuntu-sandbox:3389` over the tailnet without thinking about NAT.
- **VS Code Remote-SSH** for editing files and running commands ([08-vscode-remote.md](08-vscode-remote.md)) — usually faster than driving a GUI.

You do not need to pick one. Layer them: xrdp + Remmina/mstsc for "see the desktop", Tailscale for "from anywhere", VS Code Remote-SSH for "edit and run", tmux for "long-running shells".

## The full menu, compared

| Tool | Protocol | LAN perf | Anywhere? | Self-hostable? | Open source? | Best for |
|---|---|---|---|---|---|---|
| **xrdp + RDP client** | RDP | Excellent | via Tailscale | yes | yes | The default. Wide client support. |
| **NoMachine** (free for personal) | NX | Excellent–best | yes | yes (server free) | partial | Lowest-latency desktop on LAN. |
| **RustDesk** | proprietary | Good | yes | yes (relay server self-hostable) | yes | TeamViewer replacement; behind-NAT relay. |
| **Sunshine + Moonlight** | game-streaming codecs | Best | via Tailscale/Internet | yes | yes | Smooth video/animation; overkill for shells. |
| **Apache Guacamole** | RDP/VNC/SSH in browser | OK | yes | yes | yes | "Click a URL, get a desktop" with no client install. Heavier setup. |
| **TigerVNC standalone** | VNC | Decent | via SSH tunnel | yes | yes | Headless servers; we use it as the *backend* of xrdp. |
| **GNOME Remote Desktop** (built-in) | RDP | Good | via Tailscale/forward | yes | yes | Zero-install, but only attaches to the local console session — bad fit for a sandbox you'll often use without a local user. |

### Why xrdp instead of GNOME Remote Desktop on Ubuntu 24.04?

GNOME's built-in RDP server attaches to the *currently logged-in console* session. That means the VM has to have someone logged in at the local console, and you can only have one session. For a headless-ish sandbox VM, xrdp is the right call — it spawns its own session for each RDP login.

### Why not Docker Desktop's GUI / a Windows-side tool?

The whole point of this VM is to *not* trust the Windows host. Anything that proxies through host services widens the trust boundary again.

## Layered access pattern (recommended)

Put together, here's the flow this repo sets you up for:

```
                          Internet
                              │
                       (Tailscale tailnet)
                              │
   ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
   │ Your laptop on  │   │ Your phone      │   │ Other LAN box   │
   │ the road        │   │ (RD Client)     │   │ on home WiFi    │
   └────────┬────────┘   └────────┬────────┘   └────────┬────────┘
            │                     │                     │
            │ Tailscale           │ Tailscale           │ direct LAN +
            │                     │                     │ host port forward
            ▼                     ▼                     ▼
   ┌──────────────────────────────────────────────────────────────┐
   │                Windows 11 Pro host (Hyper-V)                 │
   │                                                              │
   │       NAT switch 192.168.50.0/24 ── port-forward 2222→22     │
   │                              │             port-forward 33890→3389
   │                              ▼                               │
   │                   ┌──────────────────────┐                   │
   │                   │ Ubuntu 24.04 VM      │ ◀─ xrdp           │
   │                   │ 192.168.50.10        │ ◀─ openssh        │
   │                   │ tailscale            │ ◀─ Tailscale node │
   │                   └──────────────────────┘                   │
   └──────────────────────────────────────────────────────────────┘
```

- LAN-only access uses **NAT port forwarding** through the host.
- Remote / WiFi-blocked access uses **Tailscale**.
- Both expose the same SSH (22) and RDP (3389) on the VM, with no need to choose ahead of time.

## If you want the lowest-latency desktop possible

Install **NoMachine** server in the VM and the NoMachine client on your other machines. Their NX protocol typically beats RDP and VNC for animation-heavy desktops. The free tier is fine for personal use. Good fit if you find yourself watching live logs in a GUI tool and feel xrdp is sluggish.

## If you want a "no-install" web-browser path

Stand up **Apache Guacamole** somewhere (a small VM or container) and point it at `192.168.50.10:3389`. You'll get a browser-based RDP gateway — handy for the rare case where you need to hop in from a borrowed laptop. Adds a service to manage; only worth it if "open a URL" is the goal.

## Monitoring vs. controlling

If you only want to *watch* the VM (not control), the lightest paths are:

- `ssh youruser@<vm> 'top -b -n1'` over SSH from anywhere.
- A web dashboard like **Netdata** (`bash <(curl -s https://my-netdata.io/kickstart.sh)`) running on `192.168.50.10`, accessible at `http://<host>:<forwarded-port>/` after adding a port forward for it.
- For "is the VM up at all", `Get-VM ubuntu-sandbox | Select State,Uptime` on the host.
