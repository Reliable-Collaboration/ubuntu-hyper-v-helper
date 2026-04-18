# 10 — Sandbox hardening

The whole reason this VM exists. Goal: even if Claude Code with `--dangerously-skip-permissions` goes off the rails, the blast radius stays inside the VM.

## Threat model

- **In scope:** the agent destroys / leaks files inside the VM, exfiltrates secrets it finds inside the VM, opens reverse shells back to the internet.
- **Out of scope (we want to make it impossible):** the agent reads anything on the Windows host, uses your host's GitHub auth, your host's cloud creds, your host's browser cookies, your real SSH keys; pivots into other LAN devices.

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

## Network egress allowlist (inside the VM)

Run [`scripts/guest/04-harden-ufw.sh`](../scripts/guest/04-harden-ufw.sh). It sets:

- Default deny in/out.
- Allow out: DNS (53), HTTP/HTTPS (80/443), git (9418), apt key/sources changes via 443.
- Allow in: SSH (22) and RDP (3389) from the NAT subnet only.

If you want to be stricter, switch from "allow all 443" to a DNS-based allowlist using `dnsmasq` + `--ipset`, or front the VM with a Squid proxy on the host. That's a heavier setup and usually overkill for personal use.

## Block VM → host services (host firewall)

By default, the VM's gateway (`192.168.50.1`) is your Windows host. The VM can hit anything the host is listening on locally — RDP, SMB, dev servers. Block that with [`scripts/host/04-firewall-isolate.ps1`](../scripts/host/04-firewall-isolate.ps1):

```powershell
.\scripts\host\04-firewall-isolate.ps1 -SwitchAlias "vEthernet (NAT-Sandbox)"
```

It adds a Windows Firewall rule that blocks all inbound traffic from the NAT subnet (192.168.50.0/24) to the host **except** the gateway plumbing the NAT itself needs (DNS to the gateway, ICMP for ping).

## Snapshot before each long unattended run

```powershell
.\scripts\host\99-snapshot.ps1 -VMName ubuntu-sandbox -Note "before-claude-task-FOO"
```

Restore later with `Restore-VMSnapshot -VMName ubuntu-sandbox -Name <name> -Confirm:$false`. Pair with **git commits inside the VM** so rollbacks don't lose work you wanted to keep. See [11-checkpoints-backup.md](11-checkpoints-backup.md).

## Clipboard hygiene checklist

- After pasting any token: `echo -n '' | xclip -selection clipboard` (or close & reopen the terminal).
- Don't keep `.env` files visible in the editor for longer than needed.
- Don't `cat` secret files in a terminal — they'll sit in scrollback and tmux buffers.

## When you're really done with the VM

- Pause and export a clean snapshot (`Export-VM -Name ubuntu-sandbox -Path D:\backups\`) as your "golden image".
- For everyday work, you can throw away the running VM and restore the snapshot — gives you a known-clean base for the next agent task.
