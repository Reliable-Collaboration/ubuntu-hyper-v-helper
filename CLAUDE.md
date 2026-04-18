# CLAUDE.md

Conventions for working in this repo with Claude Code.

## What this repo is

Documentation and helper scripts for building an Ubuntu 24.04 desktop VM on Hyper-V (Windows 11 Pro) as a sandbox for Claude Code with `--dangerously-skip-permissions`. It is a setup helper — there is **no application code here**. Don't add one.

## File layout

- `README.md` — entry point, numbered quick-start, repo map. Update when adding/removing a doc or script.
- `docs/NN-topic.md` — one numbered Markdown doc per topic. Numbers establish reading order. Cross-link with relative paths.
- `scripts/host/*.ps1` — PowerShell, run on the Windows host **as Administrator**. Operational only — no host *configuration* scripts (those steps are documented as Hyper-V Manager + small PowerShell blocks the user runs by hand).
- `scripts/guest/*.sh` — bash, run inside the Ubuntu VM **as the user's normal account** (not root).
- The **single source of truth** for default values (VM name, memory, disk, etc.) is `docs/01-architecture-decisions.md`. If you change defaults, update that doc and any references in the docs and scripts in the same commit.

## Architectural rules (don't violate without discussing)

- **Generation 2 + Microsoft UEFI Certificate Authority** Secure Boot template.
- **Static memory, Dynamic Memory off, nested virtualization off.** Linux Docker Engine doesn't need nested virt; leaving it off keeps Dynamic Memory and runtime memory resize available.
- **Network: External Switch on the host's wired NIC.** Host is wired; the VM gets DHCP from the home router and lives directly on the LAN. **No NAT switch, no port forwarding, no Tailscale, no virtual-router setup** — these were considered and trimmed for simplicity.
- **Host actions stay manual.** VM creation, switch creation, and host-side firewall changes are documented as Hyper-V Manager + a small PowerShell block — not as host scripts. The only host script is `snapshot.ps1`, which is operational, not configurational.
- **Host ↔ VM isolation is the whole point.** Don't add docs/scripts that mount host folders, share host clipboards in long-running sessions, or copy host credentials into the VM. If a feature would weaken isolation, flag it explicitly.
- **xrdp uses the TigerVNC backend**, not Xorg (the Xorg backend regressed in Feb 2025). The install script must actually edit `/etc/xrdp/xrdp.ini` and `/etc/xrdp/sesman.ini` to switch backends — not just install the TigerVNC packages.
- **Docker is Docker CE from the official apt repo**, not the snap, not Docker Desktop.

## Script conventions

PowerShell (`scripts/host/*.ps1`):
- Top-of-file `#Requires -RunAsAdministrator` and a comment-based `.SYNOPSIS` / `.EXAMPLE` block.
- `param(...)` block at the top with sane defaults.
- `$ErrorActionPreference = "Stop"`.
- **Idempotent.**

Bash (`scripts/guest/*.sh`):
- Shebang `#!/usr/bin/env bash` and `set -euo pipefail`.
- Refuse to run as root (`if [[ $EUID -eq 0 ]]; then ... exit 1; fi`); use `sudo` internally.
- Idempotent: `apt-get install -y` is fine, `sed -i` patterns must not double-apply, `tee >` writes (not `tee -a`) for config files we own. Use Python heredocs (`sudo python3 - <<'PY'`) for non-trivial config-file surgery instead of fragile multi-line `sed`.
- `chmod +x` the script in the same commit you add it.

Both:
- End with a short "what to do next" message printed to stdout.

## Doc conventions

- Lowercase, hyphenated filenames (`07-remote-desktop-options.md`).
- Title is `# NN — Topic`.
- Lead with a short purpose sentence, then practical steps. Save deep "why" for a "## Why" or comparison table near the end.
- Link to other docs with relative paths from the file's own location (e.g. inside `docs/`: `[06-enhanced-session.md](06-enhanced-session.md)`; from the repo root: `[06-enhanced-session.md](docs/06-enhanced-session.md)`).
- Use tables for comparisons.
- No emoji except sparingly in tables (✅/❌/⚠️) where they aid scanning.

## Commit style

- Subject ≤ 70 characters, imperative mood, no trailing period.
- Body explains the *why* and significant choices, not a file list (the diff shows that).
- Group logically related additions into one commit. Two clear commits beat one mixed one.
- Always include the `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` trailer on commits you make.

## What "done" looks like for a change

- README's quick-start and repo-layout sections reflect the new/changed files.
- Numbered ordering is preserved (renumber only if the new doc genuinely changes the reading order).
- Scripts run cleanly twice in a row (idempotency).
- Cross-links between docs are correct and relative.

## Out of scope

- Don't add CI/CD, tests, or build tooling — there's no code to build.
- Don't add a package manifest (`package.json`, etc.).
- Don't add binary assets (screenshots, ISOs, VHDX templates).
- Don't restructure into subdirectories beyond `docs/` and `scripts/{host,guest}/` without discussing.
- Don't re-add NAT switching, port forwarding, or Tailscale — they were removed deliberately as part of the trim. Discuss before reintroducing.
- Don't re-add a guest-side firewall script or a `ufw` allowlist. The VM is meant to be fully LAN-reachable on every port an application binds; outbound filtering by protocol/port isn't the right layer for the agent-isolation threat model (disconnect the vSwitch if you want a kill-switch). This was considered and removed deliberately.
- Don't invent mobility / off-LAN scenarios ("laptop at a coffee shop", roaming, etc.). The host is a stationary Windows 11 Pro desktop on wired Ethernet; anything about "what if the VM moved to another network" is out of scope.
