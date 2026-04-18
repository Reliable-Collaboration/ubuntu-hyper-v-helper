# 10 — Sandbox hardening

The whole reason this VM exists. Goal: even if Claude Code with `--dangerously-skip-permissions` goes off the rails, the blast radius stays inside the VM.

## Threat model

- **In scope:** the agent destroys / leaks files inside the VM, exfiltrates secrets it finds inside the VM, opens reverse shells back to the internet.
- **Out of scope (we want to make it impossible):** the agent reads anything on the Windows host, uses your host's GitHub auth, your host's cloud creds, your host's browser cookies, your real SSH keys.

A note on LAN reach: because the VM is on your home LAN with its own IP (External Switch), the agent can in principle make TCP connections to your router admin page, your NAS, your IoT devices, etc. The defenses below assume "an autonomous agent shouldn't be able to *exfiltrate* or *destroy*" — *not* "an autonomous agent shouldn't be able to ARP-scan your LAN." If you want the latter, segment your network at the router (VLAN / guest network) and put the host on the segregated side.

## Host ↔ VM separation rules

- ❌ **Don't enable Hyper-V Shared Drives** (the integration option that mounts host folders into the guest).
- ❌ **Don't tick "Drives"** in the Enhanced Session "Local Resources" dialog. (Default off in our setup; double-check.)
- ❌ **Don't share clipboard** in long unattended runs. For ad-hoc sessions, treat clipboard as one-way (host → VM only when needed) and never paste secrets through it.
- ❌ **Don't put your real `~/.ssh`, `~/.aws`, `~/.config/gcloud`, browser cookies, password-manager exports, or `.env` files into the VM.** Treat the VM as a fresh user identity.

## Identity isolation

- **Git / GitHub:** generate an ed25519 SSH key inside the VM. Use it only for the repos the agent needs. Better: create a dedicated GitHub user (e.g. `you-sandbox`) and add it as a collaborator only to the specific repos.
- **NPM / PyPI / cargo:** anonymous read-only is fine for installs. If you need publish rights, use a scoped, single-package token.
- **Cloud creds:** if a task genuinely needs them, generate a *fine-grained, scoped, short-lived* token for the specific job, paste it as an env var, and revoke it when done.
- **Docker Hub:** if you need to push, use a personal access token scoped to the specific repo.
- **Anthropic API key:** see the reconciliation note in [13-claude-code-in-the-vm.md](13-claude-code-in-the-vm.md) — use a *separate* sandbox key. The "no real credentials in the VM" rule above applies to host-equivalent identities; the sandbox API key is by design a sandbox-scoped credential and is fine.

## Network egress allowlist (inside the VM)

Run [`scripts/guest/04-harden-ufw.sh`](../scripts/guest/04-harden-ufw.sh). It sets:

- Default deny in/out.
- Allow out: DNS (53), HTTP/HTTPS (80/443), SSH out (22), git:// (9418), NTP (123).
- Allow in: SSH (22) and RDP (3389) from your LAN subnet (auto-detected from the VM's current IP).

If you want to be stricter, switch from "allow all 443" to a DNS-based allowlist using `dnsmasq` + `--ipset`, or put a Squid proxy on the host. That's a heavier setup and usually overkill for personal use.

## Host firewall (Windows side)

You don't *need* a separate firewall script for VM-to-host blocking on the External Switch path — the VM is a regular LAN device, and the host's existing Windows Firewall rules govern what the VM can hit on the host the same way they govern what any other LAN device can hit.

That said, do this once on the host as a sanity check:

1. **Network profile is Private**, not Public, for your LAN connection (`Get-NetConnectionProfile`). The Public profile is more locked-down by default but also blocks things you'll want from the VM (e.g. ICMP).
2. **Don't run dev servers on the host** that listen on `0.0.0.0`. Bind to `127.0.0.1` so only the host can reach them.
3. **No file/printer sharing** for the host unless you actually use it (`Get-NetFirewallRule | Where-Object {$_.DisplayGroup -like '*File and Printer*' -and $_.Enabled -eq 'True'}` to inspect).

## Snapshot before each long unattended run

```powershell
.\scripts\host\snapshot.ps1 -VMName ubuntu-sandbox -Note "before-claude-task-FOO"
```

Restore later with `Restore-VMSnapshot -VMName ubuntu-sandbox -Name <name> -Confirm:$false`. Pair with **git commits inside the VM** so rollbacks don't lose work you wanted to keep. See [11-checkpoints-backup.md](11-checkpoints-backup.md).

## Clipboard hygiene checklist

- After pasting any token: `echo -n '' | xclip -selection clipboard` (or close & reopen the terminal).
- Don't keep `.env` files visible in the editor for longer than needed.
- Don't `cat` secret files in a terminal — they'll sit in scrollback and tmux buffers.

## When you're really done with the VM

- Pause and export a clean snapshot (`Export-VM -Name ubuntu-sandbox -Path D:\backups\`) as your "golden image".
- For everyday work, you can throw away the running VM and restore the snapshot — gives you a known-clean base for the next agent task.
