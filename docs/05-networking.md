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

## F. Reaching apps served from inside the VM

Any dev server or container port inside the VM is LAN-reachable at `http://<vm-ip>:<port>` (or whatever protocol it speaks) as long as two things are true:

1. **The service is bound to `0.0.0.0`, not `127.0.0.1`.** Many dev servers default to loopback-only — you have to opt in to LAN exposure:
   - Next.js / Vite: `next dev -H 0.0.0.0` / `vite --host 0.0.0.0`.
   - Node `http.createServer(...).listen(3000)` (no host arg) already binds `0.0.0.0`.
   - Python `http.server`: `python3 -m http.server 3000 --bind 0.0.0.0`.
   - Docker: `-p 3000:3000` already publishes on `0.0.0.0` unless you specify `-p 127.0.0.1:3000:3000`.
2. **Nothing else is blocking the port.** By design, the VM's `ufw` is inactive — there is no guest-side firewall to open holes in. If a port is listening on `0.0.0.0`, the LAN can reach it. This is deliberate (see [10-sandbox-hardening.md](10-sandbox-hardening.md)); if you want to firewall the VM, disconnect its vSwitch in Hyper-V Manager rather than fighting a port allowlist.

To find the VM's LAN IP from inside the VM: `hostname -I` (or `ip -4 addr show`).

## Notes

- **Sandbox isolation** — putting the VM on the LAN means it can reach every other LAN device (router admin page, NAS, IoT, etc.). The sandbox boundaries we rely on are (a) *no host credentials inside the VM*, (b) *no host-shared drives or clipboards in unattended runs*, and (c) host-side Windows Firewall with the network profile set to Private. See [10-sandbox-hardening.md](10-sandbox-hardening.md). If you want the VM unable to talk to other LAN devices, segment at your router (VLAN / guest network) — that's a one-time router change, outside this repo.
