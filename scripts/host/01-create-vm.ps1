#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Create the Ubuntu 24.04 sandbox VM in Hyper-V.

.DESCRIPTION
    Idempotent: skips creation steps when items already exist.
    Defaults match docs/01-architecture-decisions.md.

.EXAMPLE
    .\01-create-vm.ps1 -IsoPath C:\iso\ubuntu-24.04.4-desktop-amd64.iso

.EXAMPLE
    .\01-create-vm.ps1 -VMName ubuntu-sandbox -MemoryGB 16 -CpuCount 6 -DiskGB 256
#>
param(
    [string]$VMName    = "ubuntu-sandbox",
    [Parameter(Mandatory=$true)]
    [string]$IsoPath,
    [string]$VhdPath   = "D:\Hyper-V\sandbox\$VMName.vhdx",
    [int]$MemoryGB     = 12,
    [int]$CpuCount     = 4,
    [int]$DiskGB       = 200,
    [string]$SwitchName = "Default Switch"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $IsoPath)) { throw "ISO not found: $IsoPath" }

$vhdDir = Split-Path $VhdPath -Parent
if (-not (Test-Path $vhdDir)) {
    Write-Host "Creating VHDX directory: $vhdDir"
    New-Item -ItemType Directory -Path $vhdDir | Out-Null
}

if (-not (Test-Path $VhdPath)) {
    Write-Host "Creating dynamic VHDX (1 MB block, ${DiskGB} GB) at $VhdPath"
    New-VHD -Path $VhdPath -SizeBytes (${DiskGB} * 1GB) -Dynamic -BlockSizeBytes 1MB | Out-Null
} else {
    Write-Host "VHDX already exists at $VhdPath - reusing."
}

if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
    Write-Host "VM '$VMName' already exists - applying settings only."
} else {
    Write-Host "Creating Generation 2 VM '$VMName'"
    New-VM -Name $VMName -Generation 2 `
           -MemoryStartupBytes (${MemoryGB} * 1GB) `
           -VHDPath $VhdPath `
           -SwitchName $SwitchName | Out-Null
}

Write-Host "Configuring memory: static $MemoryGB GB, Dynamic Memory OFF"
Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false -StartupBytes (${MemoryGB} * 1GB)

Write-Host "Configuring CPU: $CpuCount vCPUs"
Set-VMProcessor -VMName $VMName -Count $CpuCount

Write-Host "Configuring Secure Boot template: MicrosoftUEFICertificateAuthority"
Set-VMFirmware -VMName $VMName `
    -EnableSecureBoot On `
    -SecureBootTemplate MicrosoftUEFICertificateAuthority

# Mount the install ISO and put DVD first in boot order (only if not already)
$dvd = Get-VMDvdDrive -VMName $VMName | Select-Object -First 1
if (-not $dvd -or $dvd.Path -ne $IsoPath) {
    if ($dvd) { Remove-VMDvdDrive -VMName $VMName -ControllerNumber $dvd.ControllerNumber -ControllerLocation $dvd.ControllerLocation }
    Add-VMDvdDrive -VMName $VMName -Path $IsoPath
    $dvd = Get-VMDvdDrive -VMName $VMName | Select-Object -First 1
}
Set-VMFirmware -VMName $VMName -FirstBootDevice $dvd

Write-Host "Enabling Enhanced Session transport (HvSocket)"
Set-VM -Name $VMName -EnhancedSessionTransportType HvSocket

Write-Host "Setting checkpoint type to Production; disabling automatic checkpoints"
Set-VM -Name $VMName -CheckpointType Production -AutomaticCheckpointsEnabled $false

# Make sure nested virt is OFF (it is, by default; this guards against an old VM definition)
Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $false

Write-Host ""
Write-Host "VM '$VMName' is configured. Summary:"
Get-VM -Name $VMName | Format-List Name,State,Generation,ProcessorCount,MemoryStartup,CheckpointType,AutomaticCheckpointsEnabled
Get-VMFirmware -VMName $VMName | Format-List SecureBoot,SecureBootTemplate

Write-Host ""
Write-Host "Starting VM and opening console..."
Start-VM -Name $VMName
Start-Sleep -Seconds 2
vmconnect.exe localhost $VMName
