#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Block VM-originated traffic to the Windows host except what the NAT plumbing needs.

.DESCRIPTION
    The VM's gateway IS your Windows host, so by default the VM can hit any port the host listens on
    (RDP, SMB, dev servers, etc.). This script adds a Windows Firewall rule that blocks all inbound
    traffic from the NAT subnet, then carve-outs for DNS to the gateway and ICMP for ping.

    Idempotent.

.EXAMPLE
    .\04-firewall-isolate.ps1
#>
param(
    [string]$SwitchAlias = "vEthernet (NAT-Sandbox)",
    [string]$Subnet      = "192.168.50.0/24",
    [string]$GatewayIP   = "192.168.50.1"
)

$ErrorActionPreference = "Stop"

function EnsureRule {
    param([string]$Name, [scriptblock]$Create)
    if (Get-NetFirewallRule -DisplayName $Name -ErrorAction SilentlyContinue) {
        Write-Host "Rule already present: $Name"
    } else {
        Write-Host "Adding rule: $Name"
        & $Create
    }
}

EnsureRule "ubuntu-sandbox-block-vm-to-host" {
    New-NetFirewallRule `
        -DisplayName "ubuntu-sandbox-block-vm-to-host" `
        -Direction Inbound `
        -Action Block `
        -Profile Any `
        -InterfaceAlias $SwitchAlias `
        -RemoteAddress $Subnet | Out-Null
}

EnsureRule "ubuntu-sandbox-allow-dns-to-gateway" {
    New-NetFirewallRule `
        -DisplayName "ubuntu-sandbox-allow-dns-to-gateway" `
        -Direction Inbound `
        -Action Allow `
        -Profile Any `
        -InterfaceAlias $SwitchAlias `
        -Protocol UDP -LocalPort 53 `
        -LocalAddress $GatewayIP `
        -RemoteAddress $Subnet | Out-Null
}

EnsureRule "ubuntu-sandbox-allow-icmp" {
    New-NetFirewallRule `
        -DisplayName "ubuntu-sandbox-allow-icmp" `
        -Direction Inbound `
        -Action Allow `
        -Profile Any `
        -InterfaceAlias $SwitchAlias `
        -Protocol ICMPv4 `
        -RemoteAddress $Subnet | Out-Null
}

Write-Host ""
Write-Host "VM-to-host firewall isolation in place. Note:"
Write-Host " - VM can still reach the internet through NAT."
Write-Host " - Other LAN hosts can still reach the VM via the port forwards (those rules apply on the WiFi adapter, not on $SwitchAlias)."
Write-Host " - Test from inside the VM: 'ping 192.168.50.1' should succeed; 'curl http://192.168.50.1:<host-service-port>' should fail/timeout."
