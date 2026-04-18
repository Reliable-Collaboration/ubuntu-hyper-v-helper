# 02 — Windows 11 host prerequisites

Before you do anything else.

## 1. Confirm hardware support

- **CPU virtualization** (Intel VT-x or AMD-V) and **SLAT** must be enabled in BIOS/UEFI. Check Task Manager → Performance → CPU; "Virtualization: Enabled" should be present.
- Open an elevated PowerShell and run `systeminfo | findstr /C:"Hyper-V"`. All four lines should say "Yes" (or "A hypervisor has been detected" if Hyper-V is already on).

## 2. Enable Hyper-V

- `Settings → System → Optional features → More Windows features` → tick **Hyper-V** (and its sub-features). Reboot when prompted.
- Or PowerShell: `Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All`. Reboot.

## 3. Pick install media

- Download the **official Ubuntu 24.04.x desktop ISO** from `https://releases.ubuntu.com/24.04/`. Verify the SHA256 against the `SHA256SUMS` file alongside it.
- Don't use the **Hyper-V Quick Create gallery** image for this build — it ships with shared folders and clipboard sharing pre-enabled, the opposite of what you want for a sandbox.

## 4. Pick a VHDX directory with space

The helper scripts default to `D:\Hyper-V\sandbox\`. Make sure that path exists and has at least 50 GB free (the dynamic VHDX starts small but grows toward its 200 GB max as you install software and pull Docker images). On a single-disk laptop, `C:\Hyper-V\sandbox\` is fine.

## 5. Optional but recommended

- Install **Windows Terminal** — a far nicer PowerShell experience for the host scripts in this repo.
- Install **VS Code** on the host now if you want; you'll wire up Remote-SSH later (see [08-vscode-remote.md](08-vscode-remote.md)).
- If you intend to use **Tailscale** for cross-LAN/remote access, install the Windows client on the host as well so the host can also see the tailnet (see [07-remote-desktop-options.md](07-remote-desktop-options.md)).
