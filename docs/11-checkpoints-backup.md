# 11 — Checkpoints & backup

## Production vs Standard checkpoints

| Type | What it captures | Crash-consistent? | App-consistent? | Reverts memory? | Right for |
|---|---|---|---|---|---|
| **Standard** | Disk + RAM | Yes | No | Yes | Quick "scratch" experiments where you want to roll back the running state. Risky with Docker (containers may end up in a half-state). |
| **Production** | Disk only, via fs-freeze on Linux | Yes | Yes | No (boots cold) | What we use. Safe for Docker — containers boot fresh after restore. |

The VM-creation steps in [03-create-vm.md](03-create-vm.md) set the default to **Production**. They also disable **automatic checkpoints** so you don't accumulate one-per-VM-start.

## Snapshot before risky work

```powershell
.\scripts\host\snapshot.ps1 -VMName ubuntu-sandbox -Note "before-claude-refactor"
```

The script timestamps the name and sanitises the note, e.g. `ubuntu-sandbox-20260417-1532-before-claude-refactor`. (Notes containing `/`, spaces, or other special characters are converted to `-`.)

You can also run the equivalent by hand if you don't want to use the script:

```powershell
$VMName = "ubuntu-sandbox"
$Note   = "before-claude-refactor"
$stamp  = Get-Date -Format "yyyyMMdd-HHmm"
Checkpoint-VM -Name $VMName -SnapshotName "$VMName-$stamp-$Note"
```

## Restore

```powershell
Get-VMSnapshot -VMName ubuntu-sandbox | Sort-Object CreationTime -Descending | Format-Table Name,CreationTime
Restore-VMSnapshot -VMName ubuntu-sandbox -Name "<name>" -Confirm:$false
Start-VM -Name ubuntu-sandbox
```

## Cleanup discipline

Each snapshot creates an `.avhdx` differencing disk that grows as you change files. A long chain wastes disk and slows I/O.

- Periodically delete old snapshots: `Remove-VMSnapshot -VMName ubuntu-sandbox -Name "<old-name>"`.
- Or nuke the whole tree: `Remove-VMSnapshot -VMName ubuntu-sandbox -IncludeAllChildSnapshots -Confirm:$false`.
- Hyper-V auto-merges the AVHDX back into the parent VHDX; can take a while on large changes.

## Periodic "golden export"

Every few weeks, export a clean snapshot as a self-contained backup:

```powershell
Stop-VM -Name ubuntu-sandbox
Export-VM   -Name ubuntu-sandbox -Path D:\backups\
Start-VM    -Name ubuntu-sandbox
```

The export folder contains everything needed to `Import-VM` later, on this host or another. Move it to external storage if disaster-recovery matters to you.

## Don't rely on snapshots as your only backup

Snapshots live in the same VHDX directory as the VM. A disk failure wipes all of them. Treat snapshots as "undo button for an afternoon" and exports / git pushes / cloud sync as your real backups.
