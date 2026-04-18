# 03 — Create the VM (Hyper-V Manager + a few PowerShell commands)

The VM is created in the Hyper-V Manager GUI. A small set of options can't be configured (or are easier) in PowerShell — those are at the end.

## A. Create the VM in Hyper-V Manager

Open **Hyper-V Manager** → in the right pane, **Action → New → Virtual Machine**.

| Wizard page | Setting |
|---|---|
| Name and location | Name: `ubuntu-sandbox`. Optionally tick "Store the virtual machine in a different location" and pick e.g. `D:\Hyper-V\`. |
| Specify Generation | **Generation 2**. |
| Assign Memory | **12288 MB** (12 GB). **Uncheck** "Use Dynamic Memory for this virtual machine". |
| Configure Networking | Pick any switch for now (e.g. **Default Switch**). You'll create the External switch and swap to it in step C, and set up networking properly in [05-networking.md](05-networking.md). |
| Connect Virtual Hard Disk | **Create a virtual hard disk**. Name: `ubuntu-sandbox.vhdx`. Location: same dir. **Size: 200 GB**. |
| Installation Options | **Install an operating system from a bootable image file**. Browse to the Ubuntu 24.04 ISO. |
| Summary | Finish. |

## B. Adjust VM settings before first boot

Right-click the new VM → **Settings…** and apply:

| Section | Change |
|---|---|
| **Security** | Secure Boot: **Enabled**. Template: **Microsoft UEFI Certificate Authority** (this is the one Linux needs — the default "Microsoft Windows" rejects the Ubuntu shim). |
| **Memory** | Confirm "Enable Dynamic Memory" is **unchecked** (we want fixed 12 GB). |
| **Processor** | Number of virtual processors: **4**. Leave nested virtualization-related boxes unchecked. |
| **SCSI Controller → Hard Drive** | Confirm `ubuntu-sandbox.vhdx` is attached. |
| **SCSI Controller → DVD Drive** | Confirm the Ubuntu ISO is mounted. |
| **Firmware** | Boot order: ensure **DVD Drive** is **first**, then **Hard Drive**. (You'll move DVD to last after install.) |
| **Checkpoints** | Checkpoint type: **Production checkpoints**. **Uncheck** "Use automatic checkpoints" (auto-checkpoints eat disk and can confuse Docker volume state). |

Click **OK**. **Don't start the VM yet.**

## C. The PowerShell bits the GUI can't do (or doesn't expose well)

Open an **elevated PowerShell** and run:

```powershell
$VM = "ubuntu-sandbox"

# Enable Enhanced Session Mode transport via Hyper-V hardware socket (hv_sock).
# Required for the "Enhanced Session" toolbar button in vmconnect to work later.
Set-VM -Name $VM -EnhancedSessionTransportType HvSocket

# Belt-and-braces: explicitly disable nested virtualization (default is off,
# but this guards against an old VM definition that had it enabled).
Set-VMProcessor -VMName $VM -ExposeVirtualizationExtensions $false

# Confirm critical settings
Get-VM -Name $VM | Format-List Name,Generation,ProcessorCount,MemoryStartup,DynamicMemoryEnabled,CheckpointType,AutomaticCheckpointsEnabled
Get-VMFirmware -VMName $VM | Format-List SecureBoot,SecureBootTemplate
```

You should see:

- `Generation : 2`
- `ProcessorCount : 4`
- `MemoryStartup : 12884901888` (12 GB)
- `DynamicMemoryEnabled : False`
- `CheckpointType : Production`
- `AutomaticCheckpointsEnabled : False`
- `SecureBoot : On`
- `SecureBootTemplate : MicrosoftUEFICertificateAuthority`

If any of those don't match, fix in Hyper-V Manager → Settings and re-run.

## D. Start the VM and install Ubuntu

Right-click the VM → **Connect** → click **Start** in the toolbar. Continue with [04-ubuntu-install.md](04-ubuntu-install.md).
