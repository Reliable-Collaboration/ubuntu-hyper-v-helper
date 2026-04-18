# 12 — tmux workflow

The pattern: **one long-running tmux server in the VM**, attached to from any machine via SSH.

## One-time setup

- The bootstrap script already installs `tmux`.
- SSH config from [08-vscode-remote.md](08-vscode-remote.md) gives you `ssh ubuntu-sandbox` from any client.

## Daily flow

```bash
# From any machine on your LAN/tailnet:
ssh ubuntu-sandbox

# Inside the VM:
tmux new -s work          # first time
# ... do stuff ...
# Ctrl-b d                # detach (the session keeps running)
exit                      # close the SSH connection

# Later, from a different machine:
ssh ubuntu-sandbox
tmux ls                   # list sessions
tmux attach -t work       # reattach
```

The VM keeps the session alive across SSH disconnects, host reboots of *your client*, even VM reboots if you use `tmux-resurrect` (below).

## Useful aliases (`~/.bashrc` in the VM)

```bash
alias tn='tmux new -s'
alias ta='tmux attach -t'
alias tl='tmux ls'
alias td='tmux detach'
```

## A nicer config (`~/.tmux.conf` in the VM)

```tmux
# Use Ctrl-a like screen (optional)
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Mouse, longer history, true color
set -g mouse on
set -g history-limit 100000
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",xterm-256color:Tc"

# Sane window/pane splits
bind | split-window -h
bind - split-window -v

# Status bar shows hostname so you remember where you are
set -g status-right "#h | %Y-%m-%d %H:%M"
```

## Surviving VM reboots

Add `tmux-resurrect` + `tmux-continuum` so sessions are auto-saved every 15 minutes and auto-restored on next login:

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
cat >> ~/.tmux.conf <<'EOF'
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'
run '~/.tmux/plugins/tpm/tpm'
EOF
# In tmux: prefix + I to install plugins
```

## Long-lived agent runs

Pattern for letting Claude Code run autonomously for an hour:

```bash
ssh ubuntu-sandbox
tmux new -s claude
cd ~/projects/whatever
claude --dangerously-skip-permissions "implement the feature in TODO.md"
# Ctrl-b d to detach -- it keeps running
```

Reattach later from any machine: `ssh ubuntu-sandbox` → `tmux attach -t claude`.

## Reliability tip: keep the SSH connection chatty

Already in the recommended `~/.ssh/config` block (`ServerAliveInterval 30`). Without it, a sleeping laptop or a flaky AP will silently drop the SSH connection, and tmux is happy but you can't see it until the next attach.

## When tmux isn't enough

If you frequently roam between networks (e.g. between WiFi access points or on/off VPN), look at **mosh** instead — it survives IP changes seamlessly and reconnects instantly. Install in the VM with `sudo apt install -y mosh` and add the UDP port range (60000-61000) to ufw and to the host port forward.
