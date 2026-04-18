#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Create an External Hyper-V switch on a wired Ethernet adapter and attach the VM to it.

.DESCRIPTION
    Best fit when the host PC is wired (External Switch on a wired NIC works fine; on a
    WiFi NIC it usually doesn't). The VM gets DHCP from your home router and is reachable
    from any other LAN device on its own IP, with no port forwarding.

    Idempotent.

.EXAMPLE
    .\02b-create-external-switch.ps1
    .\02b-create-external-switch.ps1 -NetAdapterName "Ethernet" -VMName ubuntu-sandbox
#>
param(
    [string]$SwitchName     = "External-Wired",
    [string]$NetAdapterName = "",
    [string]$VMName         = "ubuntu-sandbox",
    [switch]$AllowManagementOS = $true
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($NetAdapterName)) {
    $candidate = Get-NetAdapter |
        Where-Object { $_.Status -eq 'Up' -and -not $_.Virtual -and $_.MediaType -ne 'Native 802.11' } |
        Sort-Object LinkSpeed -Descending |
        Select-Object -First 1
    if (-not $candidate) {
        throw "No wired adapter found. Pass -NetAdapterName explicitly. Available adapters:`n" +
              ((Get-NetAdapter | Format-Table Name,Status,MediaType,LinkSpeed | Out-String))
    }
    $NetAdapterName = $candidate.Name
    Write-Host "Auto-selected wired adapter: $NetAdapterName ($($candidate.LinkSpeed))"
}

# Verify the adapter exists and isn't already bound to another switch
$adapter = Get-NetAdapter -Name $NetAdapterName
$existingExt = Get-VMSwitch -SwitchType External -ErrorAction SilentlyContinue |
    Where-Object { $_.NetAdapterInterfaceDescription -eq $adapter.InterfaceDescription }

if ($existingExt -and $existingExt.Name -ne $SwitchName) {
    throw "Adapter '$NetAdapterName' is already bound to External switch '$($existingExt.Name)'. " +
          "Either reuse it (pass -SwitchName '$($existingExt.Name)') or remove it first."
}

if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
    Write-Warning "Creating External vSwitch on '$NetAdapterName'. Your host network may drop briefly (~1-2s) while the NIC is rebound."
    Write-Warning "Don't run this from an active SSH/RDP session into the host."
    Start-Sleep -Seconds 2
    New-VMSwitch -Name $SwitchName -NetAdapterName $NetAdapterName -AllowManagementOS $AllowManagementOS | Out-Null
} else {
    Write-Host "External switch '$SwitchName' already exists - reusing."
}

# Attach the VM
$vmAdapter = Get-VMNetworkAdapter -VMName $VMName | Select-Object -First 1
if ($vmAdapter.SwitchName -ne $SwitchName) {
    Write-Host "Connecting VM '$VMName' to switch '$SwitchName'"
    $vmAdapter | Connect-VMNetworkAdapter -SwitchName $SwitchName
} else {
    Write-Host "VM '$VMName' already connected to '$SwitchName'."
}

# Best-effort: print the VM's DHCP-assigned IP. Requires the VM to be running and integration services up.
Write-Host ""
Write-Host "VM network details (may take a few seconds after VM boot to populate):"
$tries = 0
do {
    $ip = (Get-VMNetworkAdapter -VMName $VMName).IPAddresses |
          Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } |
          Select-Object -First 1
    if ($ip) { break }
    Start-Sleep -Seconds 2
    $tries++
} while ($tries -lt 10)

if ($ip) {
    Write-Host "    VM IP : $ip"
    Write-Host ""
    Write-Host "From any LAN device:  ssh youruser@$ip"
} else {
    Write-Host "    (VM not yet reporting an IP; check inside the VM with 'ip a')"
}

Write-Host ""
Write-Host "For a STABLE address, do one of:"
Write-Host "  - Add a DHCP reservation on your home router for the VM's MAC."
Write-Host "  - Or set a static IP in NetworkManager (outside the router's DHCP pool)."
$macStr = (Get-VMNetworkAdapter -VMName $VMName | Select-Object -First 1).MacAddress
if ($macStr) {
    $macFormatted = ($macStr -split '(..)' | Where-Object { $_ }) -join ':'
    Write-Host "  - VM MAC address: $macFormatted"
}
