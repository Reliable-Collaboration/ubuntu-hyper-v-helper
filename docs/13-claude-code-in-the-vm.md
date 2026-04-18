# 13 — Running Claude Code inside the sandbox VM

This is the payoff of the rest of this repo. The VM is built so you can let Claude Code run with `--dangerously-skip-permissions` and not lie awake worrying about your host.

## TL;DR daily flow

```bash
# from any client (host laptop / WiFi laptop / phone via Tailscale)
ssh ubuntu-sandbox

# inside the VM
tmux new -As claude            # named session you can reattach from anywhere
cd ~/projects/some-repo
claude --dangerously-skip-permissions
```

Before each substantial task: take a host-side snapshot (`scripts/host/99-snapshot.ps1`). After: review the diff in VS Code Remote-SSH, run tests, decide to keep, commit, or roll the snapshot back.

## 1. Install

Run [`scripts/guest/07-install-claude-code.sh`](../scripts/guest/07-install-claude-code.sh). It:

1. Installs **Node.js 22 LTS** from NodeSource (Ubuntu 24.04's distro `nodejs` package is older than what Claude Code expects).
2. Installs `@anthropic-ai/claude-code` globally with `npm`.
3. Creates a starter `~/.claude/settings.json` with sandbox-appropriate defaults (auto-updates on, audit hook on).
4. Creates `~/projects/` if missing.
5. Prints the auth instructions.

Verify:

```bash
claude --version
which claude
```

## 2. Authenticate

You have a few options — pick what fits how you bill:

- **Anthropic API key (recommended for sandbox):** create a *separate* API key in the Anthropic Console called something like `sandbox-vm` so you can revoke it independently of your personal key. Set it as an env var (in `~/.bashrc` or a per-project `.envrc`):

  ```bash
  export ANTHROPIC_API_KEY="sk-ant-..."
  ```

- **`claude` interactive login flow:** `claude auth login` opens a browser. On a headless setup, copy the URL and complete the flow on a machine that has a browser; paste the resulting token back. (See `claude auth --help` for the latest device-flow mechanics — the CLI evolves quickly.)

**Why a separate key:** if Claude Code on the sandbox does something silly (or a token leaks through prompt injection), you revoke the sandbox key in one click and your host workflow is unaffected.

## 3. Settings: `~/.claude/settings.json`

The install script writes a starter file. Annotated:

```jsonc
{
  // Keep claude up to date - one less manual chore on a sandbox you reset often.
  "autoUpdates": true,

  // Hooks let you observe/intervene around tool calls. We use one to audit
  // every Bash command Claude runs to a log file you can grep later.
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r --arg ts \"$(date -Iseconds)\" '\"\\($ts) \\(.tool_input.command)\"' >> ~/.claude/audit-bash.log"
          }
        ]
      }
    ]
  }
}
```

Tweak as you go. Useful additions:

- **Model choice:** add a `"model"` field if you want to pin to a specific Claude model rather than letting the CLI default change under you.
- **Permissions allowlist:** even though you'll mostly run with `--dangerously-skip-permissions` here, the `permissions` block can encode what you *would* allow without prompting for the rare time you run without that flag. See [the Claude Code permissions docs](https://docs.claude.com/en/docs/claude-code/iam) for the schema.
- **Stop / SubagentStop hooks:** trigger desktop notifications, post to Slack, etc. when a long-running agent finishes.

For anything beyond simple tweaks, ask Claude Code itself (`/config` or `/help`) — the schema evolves.

## 4. Project-level memory: `CLAUDE.md`

Claude Code auto-loads a `CLAUDE.md` at the project root (and walks up parents). Use it to capture the project conventions Claude can't infer from code alone:

```markdown
# CLAUDE.md

## Run / build / test
- Install:  `pnpm install`
- Dev:      `pnpm dev` (runs at localhost:3000)
- Build:    `pnpm build`
- Test:     `pnpm test` (vitest, watch off in CI)
- Lint:     `pnpm lint --fix`

## Conventions
- TypeScript strict everywhere.
- All API routes under `src/app/api/`.
- DB migrations live in `db/migrations/` - never edit existing migrations, add a new one.
- Don't add comments to obvious code; only document non-obvious *why*.

## Out of scope
- Don't touch `vendor/` or `generated/` directories.
- Don't add new npm dependencies without flagging it in your response.
```

Keep it short. Long prompts dilute attention.

## 5. The autonomous run pattern

For long unattended tasks (the whole reason you set up the sandbox):

```bash
ssh ubuntu-sandbox
tmux new -As claude
cd ~/projects/the-repo
git status                                    # confirm clean tree
git checkout -b experiment/$(date +%s)        # so you can throw it away easily
claude --dangerously-skip-permissions \
  "Read TODO.md and implement the first task end-to-end, including tests."
# Ctrl-b d        # detach -- the session keeps running
```

Reattach from any other machine: `ssh ubuntu-sandbox` → `tmux attach -t claude`.

For *recurring* autonomous runs, Claude Code's `/loop` command lets the agent re-fire a prompt on a schedule and `/schedule` lets you create cron-like triggers. Useful for things like "every 4 hours, check open PRs and respond to review comments." Both should only be used inside this sandbox VM.

## 6. Working from VS Code Remote-SSH

You have two patterns that both work well:

### A. Claude Code as a VS Code extension (workspace install)

- In a VS Code Remote-SSH window into the VM, install the Claude Code extension.
- When prompted, install it as **Workspace** (not UI) — this is non-negotiable for the sandbox model. UI install would put the agent on your host.
- Drive it from the chat panel; it reads `CLAUDE.md` and `.claude/settings.json` from the workspace.

### B. Claude Code in the integrated terminal

- Open a Remote-SSH terminal (which runs inside the VM).
- Run `claude --dangerously-skip-permissions` directly.
- Watch its output in the terminal while you read/edit files in adjacent tabs.

Both leave files on the VM, agent execution on the VM, and only the editor UI on your client. Diffs, terminals, debug sessions, and forwarded ports all happen in the VM.

## 7. Working from tmux + SSH (no GUI)

For pure terminal use, the workflow above is all you need. Add a couple of conveniences:

- A shell alias for the common invocation: `alias cc='claude --dangerously-skip-permissions'`.
- A tmux config that survives reboots ([12-tmux-workflow.md](12-tmux-workflow.md) covers `tmux-resurrect`).
- `mosh` if you roam between WiFi networks while attached.

## 8. Recovery: when things go sideways

The blast radius is **the VM**, by design. Recovery options, in order of cheapness:

1. **Reset the experiment branch:** `git reset --hard origin/main && git clean -fd` — fast, keeps installed deps.
2. **Roll the working tree back to the snapshot you took before the run:** see [11-checkpoints-backup.md](11-checkpoints-backup.md). Loses any uncommitted work since the snapshot.
3. **Nuke the project clone and re-clone:** `rm -rf ~/projects/the-repo && git clone …`.
4. **Roll the entire VM back to a clean baseline snapshot** (the "golden export" pattern).

The agent **cannot reach** your host's files, your real SSH keys, your browser cookies, your cloud credentials, or your other LAN devices' admin pages (assuming you ran the hardening scripts and are using a separate sandbox API key). That's the contract this whole repo is designed around.

## 9. Things to avoid in the sandbox VM

- ❌ Don't `gh auth login` with your real GitHub user. Use a dedicated `you-sandbox` account or fine-grained PATs.
- ❌ Don't paste your `~/.ssh/id_*` keys into the VM "just for convenience".
- ❌ Don't `gcloud auth application-default login` with your real account.
- ❌ Don't enable Hyper-V Shared Drives or Enhanced Session drive redirection.
- ❌ Don't disable `ufw` and forget to turn it back on.
- ❌ Don't run `claude` *on the host* after testing in the VM — easy muscle-memory mistake; alias `claude` on the host to print a "use the VM" warning if you want a guard.

## 10. Pointers

- Claude Code docs: https://docs.claude.com/en/docs/claude-code
- Settings/permissions reference: https://docs.claude.com/en/docs/claude-code/iam
- This repo's hardening checklist: [10-sandbox-hardening.md](10-sandbox-hardening.md)
- Snapshot/restore mechanics: [11-checkpoints-backup.md](11-checkpoints-backup.md)
