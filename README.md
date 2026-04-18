# ubuntu-hyper-v-helper

Documentation and helper scripts for building an **Ubuntu 24.04 desktop VM on Hyper-V (Windows 11 Pro)** that:

- runs **Docker** for building/testing containerized apps,
- is **isolated from the Windows host** (no host file shares, no host credentials),
- is reachable from the host **and from any other machine on your home WiFi LAN** via SSH/tmux, RDP, and VS Code Remote-SSH,
- can be safely used as a sandbox for **Claude Code with `--dangerously-skip-permissions`**.

## Quick start

If you just want to follow the recipe end to end:

1. **Host prerequisites** — [docs/02-host-prereqs.md](docs/02-host-prereqs.md)
2. **Create the VM** — run [`scripts/host/01-create-vm.ps1`](scripts/host/01-create-vm.ps1) (see [docs/03-create-vm.md](docs/03-create-vm.md))
3. **Install Ubuntu 24.04 Desktop** — [docs/04-ubuntu-install.md](docs/04-ubuntu-install.md)
4. **First-boot bootstrap inside the VM** — run [`scripts/guest/01-bootstrap.sh`](scripts/guest/01-bootstrap.sh)
5. **Networking** — pick one path:
   - **External Switch** (simplest, recommended when your host is wired): [`scripts/host/02b-create-external-switch.ps1`](scripts/host/02b-create-external-switch.ps1)
   - **NAT switch + LAN port-forward** (more isolated): [`scripts/host/02-create-nat-switch.ps1`](scripts/host/02-create-nat-switch.ps1) and [`scripts/host/03-add-port-forward.ps1`](scripts/host/03-add-port-forward.ps1)
   - See [docs/05-networking.md](docs/05-networking.md) for the comparison.
6. **Enhanced Session Mode (xrdp)** — run [`scripts/guest/02-install-xrdp.sh`](scripts/guest/02-install-xrdp.sh) (see [docs/06-enhanced-session.md](docs/06-enhanced-session.md))
7. **Remote desktop & SSH access** — [docs/07-remote-desktop-options.md](docs/07-remote-desktop-options.md)
8. **VS Code Remote-SSH from any machine** — [docs/08-vscode-remote.md](docs/08-vscode-remote.md)
9. **Docker** — run [`scripts/guest/03-install-docker.sh`](scripts/guest/03-install-docker.sh) (see [docs/09-docker.md](docs/09-docker.md))
10. **Sandbox hardening** — run [`scripts/guest/04-harden-ufw.sh`](scripts/guest/04-harden-ufw.sh) and [`scripts/host/04-firewall-isolate.ps1`](scripts/host/04-firewall-isolate.ps1) (see [docs/10-sandbox-hardening.md](docs/10-sandbox-hardening.md))
11. **Checkpoints / backup discipline** — [docs/11-checkpoints-backup.md](docs/11-checkpoints-backup.md)
12. **tmux workflow** — [docs/12-tmux-workflow.md](docs/12-tmux-workflow.md)
13. **Run Claude Code in the sandbox** — run [`scripts/guest/07-install-claude-code.sh`](scripts/guest/07-install-claude-code.sh) (see [docs/13-claude-code-in-the-vm.md](docs/13-claude-code-in-the-vm.md))

## Why these specific choices

The full decision matrix (Gen 2, MS UEFI CA, fixed memory, no nested virt, NAT switch on WiFi, xrdp + TigerVNC backend, Docker CE) and the *why* behind each is in [docs/01-architecture-decisions.md](docs/01-architecture-decisions.md).

## Repo layout

```
.
├── README.md
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
    │   ├── 01-create-vm.ps1
    │   ├── 02-create-nat-switch.ps1        (Path B: more isolated)
    │   ├── 02b-create-external-switch.ps1  (Path A: simplest when host is wired)
    │   ├── 03-add-port-forward.ps1         (only needed for Path B)
    │   ├── 04-firewall-isolate.ps1
    │   └── 99-snapshot.ps1
    └── guest/                  bash — run inside the Ubuntu VM
        ├── 01-bootstrap.sh
        ├── 02-install-xrdp.sh
        ├── 03-install-docker.sh
        ├── 04-harden-ufw.sh
        ├── 05-install-tailscale.sh
        ├── 06-prepare-vscode-remote.sh
        └── 07-install-claude-code.sh
```

## Conventions

- **Host scripts** are PowerShell `.ps1`; run from an elevated PowerShell prompt.
- **Guest scripts** are POSIX bash; run inside the Ubuntu VM. They use `sudo` internally — don't run them *as* root, run them as your normal user.
- All scripts are designed to be **re-runnable** (idempotent where possible).
- Defaults match the values in `docs/01-architecture-decisions.md`. Override via parameters/env vars at the top of each script.
