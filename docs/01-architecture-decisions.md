# 01 — Architecture decisions

These are the design choices the rest of this repo assumes.

| Area | Choice | Why |
|---|---|---|
| VM Generation | **Generation 2** | UEFI, faster boot, modern devices, required for Enhanced Session Mode hardware sockets. |
| Secure Boot template | **Microsoft UEFI Certificate Authority** | Gen 2's default ("Microsoft Windows") rejects the Ubuntu shim. |
| Memory | **Static / fixed** (12 GB), Dynamic Memory **off** | Predictable for Docker. Dynamic Memory's balloon can OOM containers and confuses Linux memory accounting. |
| Nested virtualization | **Off** | Linux Docker Engine uses cgroups + namespaces, not a hypervisor. Only needed for Docker *Desktop*, WSL2-in-VM, or KVM. Leaving it off keeps Dynamic Memory and snapshotting flexible. |
| Disk | **Dynamic VHDX**, 1 MB block size, 200 GB | Best ext4 efficiency on dynamic VHDX (Microsoft's published guidance). |
| Filesystem | **ext4** with `-G 4096` group count | Microsoft's published efficiency tweak for dynamic VHDX. |
| I/O scheduler | **none** (blk-mq) | Hand scheduling to the host hypervisor. |
| Network switch | **External Switch on the host's wired NIC** | Host is on wired Ethernet to the home router, so the External Switch bridges cleanly (the WiFi-MAC restriction that breaks External Switch on WiFi hosts doesn't apply here). The VM gets DHCP from the router and is reachable on the LAN at its own IP. No NAT / port-forward / virtual-router setup needed. |
| Remote console | **Enhanced Session Mode via xrdp + hv_sock**, TigerVNC backend | Best perf as of 2025/2026 (the Xorg backend regressed in Feb 2025). |
| Remote dev IDE | **VS Code Remote-SSH** | Works over the same SSH path; auto-installs vscode-server in the VM; Ubuntu 24.04's glibc 2.39 is well above the 2.28 floor. |
| Checkpoints | **Production checkpoints**, automatic checkpoints **disabled** | App-consistent via Linux fs-freeze; auto-checkpoints eat disk and can confuse Docker volume state. |
| Docker | **Docker CE / Engine** from the official apt repo | No nested virt needed; runs at near-native speed. |
| Guest firewall | **`ufw` left inactive** (Ubuntu default) | The VM must be LAN-reachable on every port an application binds (SSH, RDP, dev servers on arbitrary ports). Outbound filtering by port/protocol doesn't match the agent-isolation threat model — if you want an internet kill-switch, disconnect the VM's vSwitch in Hyper-V Manager. See [10-sandbox-hardening.md](10-sandbox-hardening.md). |

## Why nested virtualization is left off

Nested virtualization is over-prescribed in random blog posts. You only need it if a guest-side hypervisor will run. Docker Engine on Linux is not a hypervisor — it's just isolated processes. Skipping nested virt keeps Dynamic Memory and runtime memory resize on the table, and avoids the "VM must be off to change memory" trap.

## Reference values

| Variable | Default | Used by |
|---|---|---|
| VM name | `ubuntu-sandbox` | docs and `snapshot.ps1` |
| Memory | `12 GB` static | manual VM creation in Hyper-V Manager |
| vCPUs | `4` | manual VM creation |
| Disk | `200 GB` dynamic VHDX, 1 MB block | manual VM creation |
| Switch | `External-Wired` (External, bound to host's wired NIC) | manual creation in Hyper-V Manager |
| VM LAN IP | DHCP from your home router (reserve in router for stability) | NetworkManager (auto) |

If you change any of these, also update [03-create-vm.md](03-create-vm.md) and [05-networking.md](05-networking.md) so the docs stay accurate.
