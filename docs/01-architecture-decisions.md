# 01 — Architecture decisions

These are the design choices the rest of this repo assumes. Each row links to the doc that goes deeper.

| Area | Choice | Why |
|---|---|---|
| VM Generation | **Generation 2** | UEFI, faster boot, modern devices, required for Enhanced Session Mode hardware sockets. |
| Secure Boot template | **Microsoft UEFI Certificate Authority** | Gen 2's default ("Microsoft Windows") rejects the Ubuntu shim. |
| Memory | **Static / fixed** (default 12 GB), Dynamic Memory **off** | Predictable for Docker. Dynamic Memory's balloon can OOM containers and confuses Linux memory accounting. |
| Nested virtualization | **Off** | Linux Docker Engine uses cgroups + namespaces, not a hypervisor. Only needed for Docker *Desktop*, WSL2-in-VM, or KVM. Leaving it off keeps Dynamic Memory and snapshotting flexible. |
| Disk | **Dynamic VHDX**, 1 MB block size, 200 GB | Best ext4 efficiency on dynamic VHDX (Microsoft's published guidance). |
| Filesystem | **ext4** with `-G 4096` group count | Microsoft's published efficiency tweak for dynamic VHDX. |
| I/O scheduler | **none** (blk-mq) | Hand scheduling to the host hypervisor. |
| Network switch | **External Switch on a wired host NIC** (simpler) **or Custom NAT switch + port-forward** (more isolated) | If the host PC is wired (this setup), External Switch works without the WiFi-MAC issue and lets the VM live directly on the LAN. Use NAT switch when you want the VM in its own subnet for tighter firewalling. See [05-networking.md](05-networking.md). |
| Remote console | **Enhanced Session Mode via xrdp + hv_sock**, TigerVNC backend | Best perf as of 2025/2026 (the Xorg backend regressed in Feb 2025). |
| Remote dev IDE | **VS Code Remote-SSH** | Works over the same SSH path; auto-installs vscode-server in the VM; Ubuntu 24.04's glibc 2.39 is well above the 2.28 floor. |
| Checkpoints | **Production checkpoints**, automatic checkpoints **disabled** | App-consistent via Linux fs-freeze; auto-checkpoints eat disk and can confuse Docker volume state. |
| Docker | **Docker CE / Engine** from the official apt repo | No nested virt needed; runs at near-native speed. |

## The two non-obvious traps

1. **Default Switch vs. External Switch.** Default Switch is host-NAT — your *host* can SSH in, but other LAN boxes cannot, and you can't add port-forwarding rules. External Switch bridges to your physical NIC and works perfectly on Ethernet but is famously broken on WiFi (the AP rejects extra MAC addresses). The escape hatch: build your own *Internal* switch and bind a NAT gateway with `New-NetNat`. That gives you LAN reachability via host-side port forwarding even on WiFi. See [05-networking.md](05-networking.md).

2. **Nested virtualization is over-prescribed.** You only need it if a guest-side hypervisor will run. Docker Engine on Linux is not a hypervisor — it's just isolated processes. Skipping nested virt keeps Dynamic Memory and runtime memory resize on the table, and avoids the "VM must be off to change memory" trap.

## Reference values used by the helper scripts

| Variable | Default | Used by |
|---|---|---|
| `$VMName` | `ubuntu-sandbox` | every host script |
| Memory | `12 GB` static | `01-create-vm.ps1` |
| vCPUs | `4` | `01-create-vm.ps1` |
| Disk | `200 GB` dynamic VHDX, 1 MB block | `01-create-vm.ps1` |
| NAT subnet | `192.168.50.0/24`, gateway `.1`, VM `.10` | `02-create-nat-switch.ps1` |
| Forwarded ports | host `2222` → VM `22` (SSH); host `33890` → VM `3389` (RDP) | `03-add-port-forward.ps1` |

Override any of these by editing the top-of-file `param(...)` blocks.
