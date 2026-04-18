# 08 — VS Code Remote-SSH from any machine

Run VS Code on the host (or any other machine on your LAN / tailnet) and have it edit, run, debug, and terminal **inside the VM**. The whole project — including Claude Code, if you use the extension — runs in the VM, not on your host.

## Why this is the right pattern

- **Zero copy of the workspace.** Files live in the VM. Closing the laptop doesn't move them. Multiple clients can connect to the same VM.
- **Same isolation guarantees.** The IDE is a thin client; the agent and tools all run remote. No host credential leakage just because you opened the editor.
- **One bootstrap, every machine works.** Same SSH config works from your host laptop, work laptop, even iPad with Code Editor.

## Prerequisites

The bootstrap script ([`scripts/guest/01-bootstrap.sh`](../scripts/guest/01-bootstrap.sh)) already installs `openssh-server`. Verify:

```bash
sudo systemctl status ssh         # active (running)
ss -tlnp | grep ':22 '            # sshd is listening
```

Ubuntu 24.04 ships glibc 2.39 — well above VS Code's 2.28 floor.

## One-time setup (each client machine)

1. Install **VS Code** (or VS Code Insiders / VSCodium / Cursor — they all support Remote-SSH).
2. Install the **Remote-SSH** extension (`ms-vscode-remote.remote-ssh`). The "Remote Development" extension pack also adds Containers and WSL support if you want them.
3. Generate an **ed25519 SSH key** if you don't have one:

   ```bash
   ssh-keygen -t ed25519 -C "$(hostname)-to-ubuntu-sandbox" -f ~/.ssh/ubuntu_sandbox_ed25519
   ```

4. Copy the public key into the VM:

   ```bash
   ssh-copy-id -i ~/.ssh/ubuntu_sandbox_ed25519.pub -p 2222 youruser@<windows-host-LAN-ip>
   ```

5. Add an entry to `~/.ssh/config` so VS Code (and tmux) know how to reach it:

   ```sshconfig
   Host ubuntu-sandbox
       HostName <windows-host-LAN-ip>      # or "ubuntu-sandbox.tailXXXX.ts.net" if Tailscale
       Port 2222
       User youruser
       IdentityFile ~/.ssh/ubuntu_sandbox_ed25519
       IdentitiesOnly yes
       ServerAliveInterval 30
       ServerAliveCountMax 6
   ```

6. From any shell: `ssh ubuntu-sandbox` should drop you into the VM with no password.

## Connect VS Code

- `F1` (or Cmd/Ctrl-Shift-P) → **Remote-SSH: Connect to Host…** → pick `ubuntu-sandbox`.
- VS Code installs `vscode-server` into `~/.vscode-server/` in the VM the first time. Takes a minute or two, then you're in.
- File → Open Folder → pick a path **inside the VM** (e.g. `/home/youruser/projects/`). All terminals, tasks, debug sessions, and forwarded ports now run in the VM.

## Use from multiple machines

The same `~/.ssh/config` entry works on every client. VS Code on each machine installs its own `vscode-server` lock once and reuses it after that. Two clients editing the same workspace at the same time is fine — it's a regular shared filesystem.

## Forwarded ports for web preview

When you start a web app inside the VM (e.g. `npm run dev` on `localhost:3000`), VS Code Remote-SSH **auto-forwards** that port back to your client. Just `Cmd/Ctrl-click` the URL in the VS Code terminal — opens in your local browser, served from the VM. No additional Hyper-V port forwards needed for dev preview.

## Extension placement: workspace vs UI

When you install an extension in a Remote-SSH window, VS Code asks where it should live:

- **Workspace (remote)** — language servers, linters, debuggers, **Claude Code**, anything that touches files or runs commands.
- **UI (local)** — themes, key bindings, vim emulation, anything purely cosmetic.

For Claude Code with `--dangerously-skip-permissions`, **install it as a workspace extension** so the agent runs inside the VM sandbox. If you install it locally, it'll touch your host filesystem — defeats the entire point.

## Tailscale path (off-LAN)

Once Tailscale is installed in the VM ([`scripts/guest/05-install-tailscale.sh`](../scripts/guest/05-install-tailscale.sh)), you can replace the `HostName` in your SSH config with the tailnet name and drop the `Port` line. Then `ssh ubuntu-sandbox` (and VS Code Remote-SSH → ubuntu-sandbox) works from any of your machines, anywhere, without touching NAT or firewall rules.

## Alternative IDEs

- **JetBrains Gateway** (free) → same idea for IntelliJ / PyCharm / WebStorm. Pointed at the same SSH config, works the same way.
- **Cursor** uses the same Remote-SSH protocol; the config above works as-is.
- **Zed** has a remote dev mode in beta as of late 2025 — same SSH path.

## Troubleshooting

- **"Could not establish connection"** → from a shell, run `ssh -v ubuntu-sandbox` and read the verbose output. Almost always: wrong port, wrong key, or sshd not running in the VM.
- **`vscode-server` install hangs** → check disk space in the VM (`df -h ~`). The server is ~200 MB but the install pulls more during first-run extension installs.
- **Connection drops every few minutes** → bump `ServerAliveInterval` lower in the SSH config (e.g. 15) or set `ClientAliveInterval 30` in the VM's `/etc/ssh/sshd_config`.
- **Lots of CPU in `node` from VS Code** → typically a workspace extension scanning a huge `node_modules`. Add `**/node_modules` to `files.watcherExclude` in the workspace settings.
