#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Create a custom NAT switch and attach the VM to it.

.DESCRIPTION
    Required for "VM reachable from other LAN machines over WiFi". See docs/05-networking.md.
    Idempotent.

.EXAMPLE
    .\02-create-nat-switch.ps1
#>
param(
    [string]$SwitchName = "NAT-Sandbox",
    [string]$Subnet     = "192.168.50.0/24",
    [string]$GatewayIP  = "192.168.50.1",
    [int]$PrefixLength  = 24,
    [string]$VMName     = "ubuntu-sandbox"
)

$ErrorActionPreference = "Stop"

# 1. Switch
if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating internal switch: $SwitchName"
    New-VMSwitch -SwitchName $SwitchName -SwitchType Internal | Out-Null
} else {
    Write-Host "Switch '$SwitchName' already exists."
}

# 2. Host-side gateway IP on the new vEthernet
$alias  = "vEthernet ($SwitchName)"
$existingIp = Get-NetIPAddress -InterfaceAlias $alias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -eq $GatewayIP }
if (-not $existingIp) {
    $ifIndex = (Get-NetAdapter -Name $alias).ifIndex
    Write-Host "Assigning $GatewayIP/$PrefixLength to interface index $ifIndex ($alias)"
    New-NetIPAddress -IPAddress $GatewayIP -PrefixLength $PrefixLength -InterfaceIndex $ifIndex | Out-Null
} else {
    Write-Host "Gateway IP $GatewayIP already on $alias."
}

# 3. NAT (only one NetNat per host -- error if a different one exists)
$existingNat = Get-NetNat -ErrorAction SilentlyContinue
if ($existingNat) {
    if ($existingNat.Name -ne $SwitchName -or $existingNat.InternalIPInterfaceAddressPrefix -ne $Subnet) {
        Write-Warning "An existing NetNat is configured ($($existingNat.Name) -> $($existingNat.InternalIPInterfaceAddressPrefix))."
        Write-Warning "Windows only supports one NetNat per host. Either reuse it (and pick its subnet for your VM IP) or remove it:"
        Write-Warning "    Remove-NetNat -Name $($existingNat.Name) -Confirm:`$false"
        throw "Stopping to avoid disrupting existing NAT."
    } else {
        Write-Host "NetNat '$SwitchName' already exists for $Subnet."
    }
} else {
    Write-Host "Creating NAT '$SwitchName' for $Subnet"
    New-NetNat -Name $SwitchName -InternalIPInterfaceAddressPrefix $Subnet | Out-Null
}

# 4. Set the network category to Private so Windows Firewall doesn't slap Public-profile rules on it
Set-NetConnectionProfile -InterfaceAlias $alias -NetworkCategory Private -ErrorAction SilentlyContinue

# 5. Attach the VM
$adapter = Get-VMNetworkAdapter -VMName $VMName | Select-Object -First 1
if ($adapter.SwitchName -ne $SwitchName) {
    Write-Host "Connecting VM '$VMName' to switch '$SwitchName'"
    $adapter | Connect-VMNetworkAdapter -SwitchName $SwitchName
} else {
    Write-Host "VM '$VMName' already connected to '$SwitchName'."
}

Write-Host ""
Write-Host "Done. Inside the VM, configure NetworkManager with:"
Write-Host "    Address  : 192.168.50.10/24   (or another address in $Subnet)"
Write-Host "    Gateway  : $GatewayIP"
Write-Host "    DNS      : 1.1.1.1, 9.9.9.9"
Write-Host ""
Write-Host "Then run scripts/host/03-add-port-forward.ps1 to expose SSH/RDP to your LAN."
