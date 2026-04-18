# 10 — Sandbox hardening

The whole reason this VM exists. Goal: even if Claude Code with `--dangerously-skip-permissions` goes off the rails, the blast radius stays inside the VM.

## Threat model

- **Untrusted:** the agent running inside the VM.
- **Trusted (more than the agent):** the Windows host, other devices on your home LAN, the internet.
- **In scope:** the agent destroys or leaks files inside the VM.
- **Out of scope (we want to make it impossible):** the agent reads anything on the Windows host, uses your host's GitHub auth, your host's cloud creds, your host's browser cookies, or your real SSH keys.

The defenses are:

1. **Host ↔ VM isolation** — the agent cannot see or modify anything on the Windows side (rules below).
2. **No host-equivalent credentials inside the VM** — even if the agent wants to exfiltrate, there's nothing worth taking.
3. **Snapshots** — a bad run is reversible on the host side in seconds.

## What's explicitly *not* a defense

- **No guest-side firewall allowlisting.** The VM is meant to be fully reachable on your LAN (SSH, RDP, and every dev-server port an application happens to bind). Ubuntu ships `ufw` inactive by default and we leave it that way. If you decide a particular run is risky enough that the agent shouldn't reach the internet, disconnect the VM's vSwitch in Hyper-V Manager — that's a cleaner, more honest kill-switch than a port/protocol allowlist that's both easy to work around and annoying for day-to-day development.
- **No LAN segmentation in this repo.** Because the VM lives on your home LAN, it can in principle reach your router admin page, NAS, IoT devices, etc. If that matters to you, segment at the router (VLAN / guest network) and put the Windows host on the segregated side. That's a one-time network change, not something this repo scripts.

## Host ↔ VM separation rules

- ❌ **Don't enable Hyper-V Shared Drives** (the integration option that mounts host folders into the guest).
- ❌ **Don't enable the "Guest services" integration service** (Hyper-V Manager → VM → Settings → Management → Integration Services). It's the host→guest file-copy channel behind `Copy-VMFile` / `hv_fcopy_daemon`; same isolation-leak class as Shared Drives. With it off, `hv-fcopy-daemon.service` stays `inactive` by design.
- ❌ **Don't tick "Drives"** in the Enhanced Session "Local Resources" dialog. (Default off in our setup; double-check.)
- ❌ **Don't share clipboard** in long unattended runs. For ad-hoc sessions, treat clipboard as one-way (host → VM only when needed) and never paste secrets through it.
- ❌ **Don't put your real `~/.ssh`, `~/.aws`, `~/.config/gcloud`, browser cookies, password-manager exports, or `.env` files into the VM.** Treat the VM as a fresh user identity.

## Identity isolation

The one rule: nothing whose blast radius extends beyond the VM belongs in the VM.

- **Git / GitHub:** use a per-VM credential — either an ed25519 SSH key generated inside the VM, or the GitHub CLI's device-code login flow (`gh auth login -w`), which stores a per-VM OAuth token you can revoke independently. Don't paste your personal SSH key or your host's `gh` token into the VM.
- **NPM / PyPI / cargo:** anonymous read-only is fine for installs. If you need publish rights, use a scoped, single-package token.
- **Cloud creds:** if a task genuinely needs them, generate a *fine-grained, scoped, short-lived* token for the specific job, paste it as an env var, and revoke it when done.
- **Docker Hub:** if you need to push, use a personal access token scoped to the specific repo.
- **Anthropic API key:** use a *separate* sandbox API key (see [13-claude-code-in-the-vm.md](13-claude-code-in-the-vm.md)). The "no real credentials in the VM" rule is really "no credentials whose blast radius extends beyond the sandbox" — a sandbox-scoped API key is the exception that proves the rule.

## Host firewall (Windows side)

You don't need any host firewall tweaks for VM-to-host blocking — the VM is a regular LAN device, and Windows Firewall governs it the same way it governs every other LAN device. Two sanity checks worth doing once:

1. **Set the network profile to Private** for your LAN connection (`Get-NetConnectionProfile`). Public is locked down enough that it will block things you actually want (e.g. ICMP, mDNS).
2. **Don't run dev servers on the Windows host bound to `0.0.0.0`** — bind to `127.0.0.1` so only the host can reach them. This keeps the VM from reaching host-local services by accident (or on purpose).

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
