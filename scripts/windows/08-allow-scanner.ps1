# Phase 3: let the vulnerability scanner in, and nothing else.
# Runs on DC01 (sent there by scripts/allow-scanner.sh, or paste it into
# PowerShell as Administrator).
#
# Creates a Group Policy that adds Windows Firewall rules on every domain
# machine, allowing the management ports a credentialed scan needs, but ONLY
# from KALI01 (10.10.2.4). Every other address stays blocked.

$ErrorActionPreference = "Stop"
Import-Module GroupPolicy

$gpoName = "Haldane - Vulnerability scanner access"
$scanner = "10.10.2.4"
$store   = "haldane.local\$gpoName"

if (-not (Get-GPO -Name $gpoName -ErrorAction SilentlyContinue)) {
    New-GPO -Name $gpoName -Comment "Firewall rules for the Nessus scanner (KALI01, $scanner) only." | Out-Null
}

# Start from a clean set of rules, so re-running gives the same result.
Get-NetFirewallRule -PolicyStore $store -ErrorAction SilentlyContinue | Remove-NetFirewallRule

$rules = @(
    @{ Name = "Scanner - ping (ICMPv4 echo)";          Protocol = "ICMPv4"; IcmpType = "8" },
    @{ Name = "Scanner - RPC endpoint mapper (TCP 135)"; Protocol = "TCP"; LocalPort = "135" },
    @{ Name = "Scanner - NetBIOS session (TCP 139)";   Protocol = "TCP"; LocalPort = "139" },
    @{ Name = "Scanner - SMB (TCP 445)";                Protocol = "TCP"; LocalPort = "445" },
    @{ Name = "Scanner - RPC dynamic ports (WMI)";      Protocol = "TCP"; LocalPort = "RPC" }
)
foreach ($r in $rules) {
    $params = @{
        PolicyStore   = $store
        DisplayName   = $r.Name
        Direction     = "Inbound"
        Action        = "Allow"
        Profile       = "Any"
        RemoteAddress = $scanner
        Protocol      = $r.Protocol
    }
    if ($r.LocalPort) { $params.LocalPort = $r.LocalPort }
    if ($r.IcmpType)  { $params.IcmpType  = $r.IcmpType }
    New-NetFirewallRule @params | Out-Null
}

# Link it to the whole domain: that covers DC01 (Domain Controllers OU) and
# WS01 (Haldane\Servers OU).
$linked = (Get-GPInheritance -Target "DC=haldane,DC=local").GpoLinks.DisplayName -contains $gpoName
if (-not $linked) {
    New-GPLink -Name $gpoName -Target "DC=haldane,DC=local" -LinkEnabled Yes | Out-Null
}

gpupdate /force | Out-Null
Get-NetFirewallRule -PolicyStore $store |
    Select-Object DisplayName, Enabled, Action | Format-Table -AutoSize
