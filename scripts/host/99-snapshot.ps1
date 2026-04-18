#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Take a timestamped checkpoint of the VM. Optional note for the snapshot name.

.EXAMPLE
    .\99-snapshot.ps1 -Note "before-claude-refactor"
#>
param(
    [string]$VMName = "ubuntu-sandbox",
    [string]$Note   = "manual"
)

$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$name  = "$VMName-$stamp-$Note"
Write-Host "Creating production checkpoint: $name"
Checkpoint-VM -Name $VMName -SnapshotName $name
Write-Host ""
Write-Host "Existing snapshots:"
Get-VMSnapshot -VMName $VMName | Sort-Object CreationTime -Descending |
    Format-Table Name,CreationTime,SnapshotType
