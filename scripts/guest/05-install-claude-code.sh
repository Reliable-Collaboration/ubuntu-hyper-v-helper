#!/usr/bin/env bash
# Install Node.js 22 LTS + Claude Code globally, with a sandbox-appropriate
# starter ~/.claude/settings.json (audit hook on, auto-updates on).
# Idempotent.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as your normal user, not root. The script uses sudo where needed." >&2
    exit 1
fi

NODE_MAJOR="${NODE_MAJOR:-22}"

# 1. Node.js
if ! command -v node >/dev/null || [[ "$(node -v | sed 's/^v\([0-9]*\).*/\1/')" -lt "$NODE_MAJOR" ]]; then
    echo "==> Installing Node.js $NODE_MAJOR LTS from NodeSource"
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    if [[ ! -f /etc/apt/keyrings/nodesource.gpg ]]; then
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
            sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    fi
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | \
        sudo tee /etc/apt/sources.list.d/nodesource.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y nodejs
else
    echo "==> Node $(node -v) already installed, skipping NodeSource setup"
fi

echo "==> Installing jq (used by the audit hook below)"
sudo apt-get install -y jq

# 2. Claude Code
# Allow npm global installs without sudo by giving the user a per-user prefix.
NPM_PREFIX="$HOME/.npm-global"
mkdir -p "$NPM_PREFIX"
npm config set prefix "$NPM_PREFIX"

if ! grep -q "$NPM_PREFIX/bin" "$HOME/.bashrc" 2>/dev/null; then
    echo "export PATH=\"$NPM_PREFIX/bin:\$PATH\"" >> "$HOME/.bashrc"
fi
export PATH="$NPM_PREFIX/bin:$PATH"

echo "==> Installing @anthropic-ai/claude-code (latest)"
npm install -g @anthropic-ai/claude-code

# 3. Starter ~/.claude/settings.json
mkdir -p "$HOME/.claude"
SETTINGS="$HOME/.claude/settings.json"

if [[ -f "$SETTINGS" ]]; then
    echo "==> $SETTINGS already exists - leaving it alone"
else
    echo "==> Writing starter $SETTINGS"
    cat > "$SETTINGS" <<'JSON'
{
  "autoUpdates": true,
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
JSON
fi

# 4. Convenience alias
if ! grep -q "alias cc=" "$HOME/.bashrc" 2>/dev/null; then
    echo "alias cc='claude --dangerously-skip-permissions'" >> "$HOME/.bashrc"
fi

# 5. ~/projects exists
mkdir -p "$HOME/projects"

cat <<EOM

Claude Code installed:  $(command -v claude || echo '(not on PATH yet - open a new shell)')
Version:                $(claude --version 2>/dev/null || echo '(open a new shell, then re-run: claude --version)')

NEXT STEPS:

1) Open a new shell (or 'source ~/.bashrc') so the npm bin directory is on PATH:
       source ~/.bashrc

2) Authenticate. Pick one:

   a) RECOMMENDED: create a SEPARATE API key in the Anthropic Console
      named 'sandbox-vm' (so you can revoke it independently of your
      personal key), then export it:
          echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc
          source ~/.bashrc

   b) Interactive login (if your CLI version supports it):
          claude auth login

3) Smoke test:
       cd ~/projects && mkdir hello && cd hello && git init
       claude "create a hello.py that prints Hello from the sandbox"

4) For long unattended runs, use tmux + the alias:
       tmux new -As claude
       cc "implement the next item in TODO.md"
       # Ctrl-b d to detach; reattach later from any client

Audit log of every Bash command Claude runs is at:  ~/.claude/audit-bash.log

See docs/13-claude-code-in-the-vm.md for the full daily workflow.
EOM
