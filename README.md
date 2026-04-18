# ubuntu-hyper-v-helper

Documentation and helper scripts for building an **Ubuntu 24.04 desktop VM on Hyper-V (Windows 11 Pro)** that:

- runs **Docker** for building/testing containerized apps,
- is **isolated from the Windows host** (no host file shares, no host credentials),
- is reachable from the host **and from any other machine on your home LAN** via SSH/tmux, RDP, and VS Code Remote-SSH,
- can be safely used as a sandbox for **Claude Code with `--dangerously-skip-permissions`**.

The host is assumed to be on **wired Ethernet** to the home router. The VM uses an **External Hyper-V switch** so it gets a DHCP-assigned IP from your router and is directly reachable on the LAN — no NAT, port forwarding, or virtual-router setup.

## Quick start

1. **Host prerequisites** — [docs/02-host-prereqs.md](docs/02-host-prereqs.md)
2. **Create the VM** (manual: Hyper-V Manager GUI + a few PowerShell commands) — [docs/03-create-vm.md](docs/03-create-vm.md)
3. **Install Ubuntu 24.04 Desktop** — [docs/04-ubuntu-install.md](docs/04-ubuntu-install.md)
4. **First-boot bootstrap inside the VM** — run [`scripts/guest/01-bootstrap.sh`](scripts/guest/01-bootstrap.sh)
5. **Networking** (manual: create the External vSwitch in Hyper-V Manager, optionally reserve a DHCP IP) — [docs/05-networking.md](docs/05-networking.md)
6. **Enhanced Session Mode (xrdp)** — run [`scripts/guest/02-install-xrdp.sh`](scripts/guest/02-install-xrdp.sh) (see [docs/06-enhanced-session.md](docs/06-enhanced-session.md))
7. **Remote desktop & monitoring options** — [docs/07-remote-desktop-options.md](docs/07-remote-desktop-options.md)
8. **VS Code Remote-SSH from any machine** — [docs/08-vscode-remote.md](docs/08-vscode-remote.md), and run [`scripts/guest/04-prepare-vscode-remote.sh`](scripts/guest/04-prepare-vscode-remote.sh)
9. **Docker** — run [`scripts/guest/03-install-docker.sh`](scripts/guest/03-install-docker.sh) (see [docs/09-docker.md](docs/09-docker.md))
10. **Sandbox hardening** (read-only — no script; there is no guest-side firewall by design) — [docs/10-sandbox-hardening.md](docs/10-sandbox-hardening.md)
11. **Checkpoints / backup discipline** — [docs/11-checkpoints-backup.md](docs/11-checkpoints-backup.md)
12. **tmux workflow** — [docs/12-tmux-workflow.md](docs/12-tmux-workflow.md)
13. **Run Claude Code in the sandbox** — run [`scripts/guest/05-install-claude-code.sh`](scripts/guest/05-install-claude-code.sh) (see [docs/13-claude-code-in-the-vm.md](docs/13-claude-code-in-the-vm.md))

## Why these specific choices

The full decision matrix (Gen 2, MS UEFI CA, fixed memory, no nested virt, External Switch, xrdp + TigerVNC backend, Docker CE) and the *why* behind each is in [docs/01-architecture-decisions.md](docs/01-architecture-decisions.md).

## Repo layout

```
.
├── README.md
├── CLAUDE.md
├── docs/                       Markdown reference for every step
│   ├── 01-architecture-decisions.md
│   ├── 02-host-prereqs.md
│   ├── 03-create-vm.md
│   ├── 04-ubuntu-install.md
│   ├── 05-networking.md
│   ├── 06-enhanced-session.md
│   ├── 07-remote-desktop-options.md
│   ├── 08-vscode-remote.md
│   ├── 09-docker.md
│   ├── 10-sandbox-hardening.md
│   ├── 11-checkpoints-backup.md
│   ├── 12-tmux-workflow.md
│   └── 13-claude-code-in-the-vm.md
└── scripts/
    ├── host/                   PowerShell — run on the Windows 11 host as Administrator
    │   └── snapshot.ps1            (only host script kept; everything else is manual GUI/PS)
    └── guest/                  bash — run inside the Ubuntu VM
        ├── 01-bootstrap.sh
        ├── 02-install-xrdp.sh
        ├── 03-install-docker.sh
        ├── 04-prepare-vscode-remote.sh
        └── 05-install-claude-code.sh
```

## Conventions

- **Host actions** are mostly manual: Hyper-V Manager (GUI) for VM/switch creation, with a small PowerShell block to set the few options the GUI doesn't expose. The one host script kept is `snapshot.ps1` (operational, not configurational).
- **Guest scripts** are POSIX bash; run inside the Ubuntu VM. They use `sudo` internally — don't run them *as* root, run them as your normal user.
- All scripts are designed to be **re-runnable** (idempotent where possible).
- Defaults match the values in `docs/01-architecture-decisions.md`. Override via parameters/env vars at the top of each script.
