# 03 — Create the VM

Use [`scripts/host/01-create-vm.ps1`](../scripts/host/01-create-vm.ps1) from an **elevated PowerShell**:

```powershell
cd path\to\ubuntu-hyper-v-helper
.\scripts\host\01-create-vm.ps1 `
    -VMName ubuntu-sandbox `
    -IsoPath C:\iso\ubuntu-24.04.4-desktop-amd64.iso `
    -VhdPath D:\Hyper-V\sandbox\ubuntu-sandbox.vhdx `
    -MemoryGB 12 -CpuCount 4 -DiskGB 200
```

The script:

1. Creates a **dynamic VHDX** with 1 MB block size (best ext4 efficiency).
2. Creates a **Generation 2** VM with the **Microsoft UEFI Certificate Authority** Secure Boot template (required for the Ubuntu shim).
3. Sets **static memory** and disables Dynamic Memory.
4. Mounts the install ISO and puts the DVD first in boot order.
5. Sets `EnhancedSessionTransportType = HvSocket` (required for Enhanced Session Mode later).
6. Sets `CheckpointType = Production` and disables automatic checkpoints.
7. Starts the VM and opens `vmconnect`.

It does **not** enable nested virtualization on purpose — see [01-architecture-decisions.md](01-architecture-decisions.md).

## Manual GUI equivalent (if you prefer Hyper-V Manager)

If you'd rather click through Hyper-V Manager:

1. Action → New → Virtual Machine. Name `ubuntu-sandbox`.
2. **Specify Generation** → **Generation 2**.
3. **Assign Memory** → 12288 MB. **Uncheck** "Use Dynamic Memory".
4. **Configure Networking** → leave on Default Switch for now (we'll switch this in [05-networking.md](05-networking.md)).
5. **Connect Virtual Hard Disk** → Create new. Use **200 GB**.
6. **Installation Options** → Install from ISO → pick the Ubuntu ISO.
7. Finish. Then **before starting**, edit the VM settings:
   - **Security** → Secure Boot template: **Microsoft UEFI Certificate Authority**.
   - **Processor** → 4 vCPUs.
   - **Checkpoints** → Production checkpoints; uncheck "Use automatic checkpoints".
8. Save. Run `Set-VM -Name ubuntu-sandbox -EnhancedSessionTransportType HvSocket` from elevated PowerShell.
9. Right-click the VM → Connect → Start.
