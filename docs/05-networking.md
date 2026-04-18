# 05 — Networking: External Switch on the host's wired NIC

Goal: the VM appears as a regular device on your home LAN with its own router-issued IP. Reachable from any other machine in the house with `ssh user@<vm-ip>`. No NAT, no port forwarding, no virtual-router setup.

## How the External Switch works

Hyper-V's External vSwitch bridges the VM's virtual NIC onto your physical Ethernet. Your home router sees the VM as another device on the LAN and hands it a DHCP address. From every other machine on the LAN, the VM is just an IP.

This works cleanly because the bridged adapter on the host is **wired Ethernet**. The infamous "WiFi blocks bridged MACs" trap that breaks External Switch on WiFi hosts doesn't apply.

## A. Create the External Switch (Hyper-V Manager)

1. Hyper-V Manager → right pane: **Virtual Switch Manager…**
2. **New virtual network switch** → select **External** → **Create Virtual Switch**.
3. Name: `External-Wired`.
4. Connection type: **External network** → pick your wired Ethernet adapter from the dropdown.
5. Tick **Allow management operating system to share this network adapter** (so your host keeps its network).
6. **OK**.

Windows briefly drops the host's network (~1–2 s) while it rebinds the NIC. Don't do this from a machine you're remoted into.

## B. Attach the VM to the new switch

In Hyper-V Manager → right-click the VM → **Settings…** → **Network Adapter** → switch dropdown → **External-Wired** → **OK**.

(Alternatively, one-line PowerShell: `Get-VMNetworkAdapter -VMName ubuntu-sandbox | Connect-VMNetworkAdapter -SwitchName "External-Wired"`.)

## C. Inside the VM: pick up DHCP

NetworkManager handles this automatically once the adapter is up. After the VM finishes booting, check the IP with:

```bash
ip -4 addr show | awk '/inet /{print $2}'
```

You should see something like `192.168.1.42/24` (whatever your home subnet is).

## D. Make the IP stable

DHCP can re-assign on long uptimes. Pin the address so SSH configs and bookmarks don't break. **One** of:

- **DHCP reservation on your router** (recommended): find your router's admin page → DHCP / LAN settings → add a reservation for the VM's MAC. Get the MAC inside the VM with `ip link show | awk '/link\/ether/{print $2}'` (the one on the eth-style interface).
- **Static IP in NetworkManager**: Settings → Network → wired adapter → ⚙ → IPv4 → Manual. Pick an IP **outside** your router's DHCP pool to avoid clashes. Set the gateway and DNS to your router's IP.

## E. Connect from any LAN device

```bash
ssh youruser@<vm-ip>
```

That's it. The same path works from your host, your WiFi laptop, your phone (Termius / iSH), etc. — anything on your home LAN.

## Notes

- **Off-LAN access** (laptop at a coffee shop, etc.) is intentionally not solved here. If you need it later, Tailscale is the usual answer; this repo's earlier draft included it but we've trimmed it for simplicity.
- **Sandbox isolation** — putting the VM on the LAN means it can reach every other LAN device (router admin page, NAS, IoT, etc.). The sandbox boundaries enforced here are: (a) `ufw` inside the VM ([10-sandbox-hardening.md](10-sandbox-hardening.md)), (b) not putting host credentials inside the VM, and (c) Windows Firewall on the host with sensible Public/Private profile defaults.
