# CLAUDE.md

Conventions for working in this repo with Claude Code.

## What this repo is

Documentation and helper scripts for building an Ubuntu 24.04 desktop VM on Hyper-V (Windows 11 Pro) as a sandbox for Claude Code with `--dangerously-skip-permissions`. It is a setup helper — there is **no application code here**. Don't add one.

## File layout

- `README.md` — entry point, numbered quick-start, repo map. Update when adding/removing a doc or script.
- `docs/NN-topic.md` — one numbered Markdown doc per topic. Numbers establish reading order. Cross-link with relative paths.
- `scripts/host/*.ps1` — PowerShell, run on the Windows host **as Administrator**.
- `scripts/guest/*.sh` — bash, run inside the Ubuntu VM **as the user's normal account** (not root).
- The **single source of truth** for default VM/network values (VM name, memory, NAT subnet, port-forward map) is `docs/01-architecture-decisions.md`. If you change defaults, update both that doc and the `param(...)` blocks of any affected scripts in the same commit.

## Architectural rules (don't violate without discussing)

- **Generation 2 + Microsoft UEFI Certificate Authority** Secure Boot template.
- **Static memory, Dynamic Memory off, nested virtualization off.** Linux Docker Engine doesn't need nested virt; leaving it off keeps Dynamic Memory and runtime memory resize available.
- **Host is wired Ethernet** — External Switch is a viable Path A. WiFi-only hosts must use the NAT switch path.
- **Host ↔ VM isolation is the whole point.** Don't add docs/scripts that mount host folders, share host clipboards in long-running sessions, or copy host credentials into the VM. If a feature would weaken isolation, flag it explicitly.
- **xrdp uses the TigerVNC backend**, not Xorg (the Xorg backend regressed in Feb 2025).
- **Docker is Docker CE from the official apt repo**, not the snap, not Docker Desktop.

## Script conventions

PowerShell (`scripts/host/*.ps1`):
- Top-of-file `#Requires -RunAsAdministrator` and a comment-based `.SYNOPSIS` / `.EXAMPLE` block.
- `param(...)` block at the top with sane defaults; never hardcode user-overridable values inside the body.
- `$ErrorActionPreference = "Stop"`.
- **Idempotent.** Check `Get-VM` / `Get-VMSwitch` / `Get-NetNat` / `Get-NetFirewallRule` before creating.

Bash (`scripts/guest/*.sh`):
- Shebang `#!/usr/bin/env bash` and `set -euo pipefail`.
- Refuse to run as root (`if [[ $EUID -eq 0 ]]; then ... exit 1; fi`); use `sudo` internally.
- Idempotent: `apt-get install -y` is fine, `sed -i` patterns must not double-apply, `tee >` writes (not `tee -a`) for config files we own.
- `chmod +x` the script in the same commit you add it.

Both:
- End with a short "what to do next" message printed to stdout. The user runs these by hand; print pointers to the next step.

## Doc conventions

- Lowercase, hyphenated filenames (`07-remote-desktop-options.md`).
- Title is `# NN — Topic`.
- Lead with a short purpose sentence, then practical steps. Save deep "why" for a "## Why" or comparison table near the end.
- Link to other docs with relative paths (`[06-enhanced-session.md](06-enhanced-session.md)`).
- Use tables for comparisons (switch types, checkpoint types, remote-desktop options).
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
