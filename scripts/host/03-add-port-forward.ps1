#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Add NAT port-forwarding rules so other LAN machines can reach the VM.

.DESCRIPTION
    Default mappings: host:2222 -> VM:22 (SSH) and host:33890 -> VM:3389 (RDP).
    Override with -Map.

.EXAMPLE
    .\03-add-port-forward.ps1
    .\03-add-port-forward.ps1 -Map @( @{ External=30000; Internal=3000; Protocol="TCP" } )
#>
param(
    [string]$NatName = "NAT-Sandbox",
    [string]$GuestIP = "192.168.50.10",
    [array]$Map = @(
        @{ External = 2222;  Internal = 22;   Protocol = "TCP" },
        @{ External = 33890; Internal = 3389; Protocol = "TCP" }
    )
)

$ErrorActionPreference = "Stop"

if (-not (Get-NetNat -Name $NatName -ErrorAction SilentlyContinue)) {
    throw "NetNat '$NatName' not found. Run 02-create-nat-switch.ps1 first."
}

foreach ($m in $Map) {
    $existing = Get-NetNatStaticMapping -NatName $NatName -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ExternalPort      -eq $m.External -and
            $_.InternalIPAddress -eq $GuestIP    -and
            $_.InternalPort      -eq $m.Internal -and
            $_.Protocol          -eq $m.Protocol
        }
    if ($existing) {
        Write-Host "Mapping already exists: $($m.Protocol) host:$($m.External) -> ${GuestIP}:$($m.Internal)"
        continue
    }
    Write-Host "Adding mapping: $($m.Protocol) host:$($m.External) -> ${GuestIP}:$($m.Internal)"
    Add-NetNatStaticMapping -NatName $NatName `
        -Protocol $m.Protocol `
        -ExternalIPAddress "0.0.0.0" -ExternalPort $m.External `
        -InternalIPAddress $GuestIP  -InternalPort $m.Internal | Out-Null

    # Open the inbound port on the host firewall too.
    $ruleName = "ubuntu-sandbox-fwd-$($m.Protocol)-$($m.External)"
    if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow `
            -Protocol $m.Protocol -LocalPort $m.External -Profile Any | Out-Null
    }
}

Write-Host ""
Write-Host "Current mappings on '$NatName':"
Get-NetNatStaticMapping -NatName $NatName | Format-Table StaticMappingID,Protocol,ExternalPort,InternalIPAddress,InternalPort
