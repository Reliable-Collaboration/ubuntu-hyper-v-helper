#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Take a timestamped production checkpoint of the VM.

.EXAMPLE
    .\snapshot.ps1 -Note "before-claude-refactor"
#>
param(
    [string]$VMName = "ubuntu-sandbox",
    [string]$Note   = "manual"
)

$ErrorActionPreference = "Stop"

# Sanitize $Note so the snapshot name is always valid (slashes/colons/spaces would otherwise
# trip up shell quoting later).
$safeNote = ($Note -replace '[^A-Za-z0-9._-]', '-').Trim('-')
if (-not $safeNote) { $safeNote = "manual" }

$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$name  = "$VMName-$stamp-$safeNote"

Write-Host "Creating production checkpoint: $name"
Checkpoint-VM -Name $VMName -SnapshotName $name

Write-Host ""
Write-Host "Existing snapshots:"
Get-VMSnapshot -VMName $VMName | Sort-Object CreationTime -Descending |
    Format-Table Name,CreationTime,SnapshotType
