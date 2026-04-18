# 05 — Networking: reaching the VM from your LAN

Your situation: **host PC is wired (Ethernet)**, other client machines (laptop, etc.) are on WiFi. That changes which Hyper-V switch type is easiest.

## The three Hyper-V switch options, compared for your setup

| Switch type | LAN reachable from other machines? | Works because host is wired? | DHCP? | Isolation level |
|---|---|---|---|---|
| **Default Switch** (built-in NAT) | ❌ no — host only | n/a | ✅ | Highest (host-only) but useless for your laptop |
| **External Switch** (bridge to host's Ethernet NIC) | ✅ direct, VM gets its own LAN IP | ✅ Ethernet bridges fine | ✅ from your router | Lowest — VM is just another LAN device |
| **Custom NAT switch** (Internal + `New-NetNat`) | ✅ via host port-forward | ✅ | ❌ static IP | Medium — VM lives in its own subnet |

The WiFi-bridge trap that breaks External Switch on most laptops doesn't apply to you, because the bridged adapter is your **wired Ethernet** on the host. Other machines connecting *over* WiFi are clients, not bridged hosts — they don't have to share a MAC with the VM.

## Pick one based on what you value more

**Pick External Switch** if you want:
- Simplest "it just works" connectivity from any device on your LAN.
- No port forwarding to manage.
- DHCP-assigned IP (or a router-side reservation for stability).
- Tradeoff: the VM is a first-class citizen on your home LAN — it can reach every other device (router admin pages, NAS, IoT gear, etc.) the same way you can. Your sandbox isolation has to come from VM-internal `ufw` rules and your router/firewall, not from the network topology.

**Pick custom NAT switch** if you want:
- The VM in its own `192.168.50.0/24` subnet, separated from your LAN by a NAT boundary on the host.
- Easier-to-write Windows Firewall rules to block VM↔host traffic (one vEthernet adapter, one well-defined remote subnet).
- Tradeoff: have to maintain port-forward rules for each new exposed service (SSH, RDP, dev servers).

For a serious Claude Code sandbox I lean toward **NAT switch** — the extra isolation is cheap, and the port-forward rules end up being a feature (you have to think before exposing a service). For a generic dev VM, **External Switch** is hard to beat.

You can also hedge: build it with the External Switch first, and switch to NAT later if you find yourself wanting more separation. The VM doesn't care.

---

## Path A — External Switch (recommended for your wired host)

Run [`scripts/host/02b-create-external-switch.ps1`](../scripts/host/02b-create-external-switch.ps1) from elevated PowerShell:

```powershell
.\scripts\host\02b-create-external-switch.ps1 `
    -SwitchName "External-Wired" `
    -NetAdapterName "Ethernet" `
    -VMName ubuntu-sandbox
```

If you don't pass `-NetAdapterName`, the script auto-picks the first **wired, up, non-virtual** NIC. The script:

1. Creates the External vSwitch bound to your wired NIC (with `AllowManagementOS=true` so the host keeps its network).
2. Detaches the VM from any previous switch and attaches it here.
3. Prints the VM's DHCP-assigned IP after a few seconds so you can record it.

**Heads up:** Windows briefly drops the host's network while binding the NIC to the vSwitch (~1-2 s). Don't run this over an active SSH/RDP session into the host.

Inside the VM, NetworkManager will pick up DHCP automatically. To make the IP stable, do **either**:

- A DHCP reservation on your router for the VM's MAC (find it with `ip a` inside the VM, look for the `link/ether` line on the eth interface), **or**
- Set a manual static IP inside NetworkManager that's outside your router's DHCP pool.

Then from any LAN device:

```bash
ssh youruser@<vm-LAN-ip>
```

No port forwarding needed.

---

## Path B — Custom NAT switch (more isolated)

Same as before — see [`scripts/host/02-create-nat-switch.ps1`](../scripts/host/02-create-nat-switch.ps1) and [`scripts/host/03-add-port-forward.ps1`](../scripts/host/03-add-port-forward.ps1).

```powershell
.\scripts\host\02-create-nat-switch.ps1 -SwitchName "NAT-Sandbox" -VMName ubuntu-sandbox
.\scripts\host\03-add-port-forward.ps1   -NatName   "NAT-Sandbox" -GuestIP 192.168.50.10
```

Inside the VM (NetworkManager → Wired → manual):

| Field | Value |
|---|---|
| Address | `192.168.50.10/24` |
| Gateway | `192.168.50.1` |
| DNS | `1.1.1.1, 9.9.9.9` |

Then from another LAN box: `ssh -p 2222 youruser@<windows-host-LAN-ip>`.

### Gotchas with NAT switch

- **One `New-NetNat` per host.** If WSL2 / Docker Desktop / an older Hyper-V VM already created one, `New-NetNat` will fail. `Get-NetNat` to inspect.
- The new vEthernet defaults to *Public* profile in Windows Firewall; the script sets it to *Private*. Re-run the script after host reboots if connectivity goes weird.

---

## Either path: add Tailscale on top

Tailscale doesn't replace either switch — but it gives you a stable hostname that works **from anywhere** (your laptop on WiFi at home, your laptop at a coffee shop, your phone, etc.) without any of the above NAT/port-forward configuration applying to *that* path.

- Run [`scripts/guest/05-install-tailscale.sh`](../scripts/guest/05-install-tailscale.sh) inside the VM.
- Then: `ssh youruser@ubuntu-sandbox` (MagicDNS) from any tailnet device.
- In your tailnet ACLs, restrict access so only your own user/devices can reach the VM.

Recommended layered design:

- **External Switch** (or NAT switch) → handles same-LAN access.
- **Tailscale** → handles off-LAN access and provides a single, stable hostname your SSH config and VS Code Remote-SSH can target everywhere.

## Sandbox networking checklist

Whichever switch you pick, the sandbox isolation comes from:

1. **`ufw` inside the VM** with default-deny in/out — see [`scripts/guest/04-harden-ufw.sh`](../scripts/guest/04-harden-ufw.sh).
2. **Windows Firewall** rules blocking VM→host traffic — see [`scripts/host/04-firewall-isolate.ps1`](../scripts/host/04-firewall-isolate.ps1). (Easier to scope cleanly when using the NAT switch, since the vEthernet adapter is dedicated.)
3. **Don't put real credentials inside the VM** — see [10-sandbox-hardening.md](10-sandbox-hardening.md).
