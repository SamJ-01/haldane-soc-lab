# Phase 3: fix the top-priority Nessus findings with one Group Policy.
# Runs on DC01 (sent there by scripts/apply-fixes.sh).
#
#   1. CVE-2013-3900 (WinVerifyTrust): turn on Microsoft's opt-in fix,
#      EnableCertPaddingCheck, in both the 64-bit and 32-bit registry views.
#   2. LLMNR: switch off multicast name resolution, so no machine on the
#      network can answer "who is FILESERVR?" on a server's behalf.
#   3. SMB signing: require signed SMB on every server (DC01 already did;
#      WS01 did not), so captured logins can't be relayed to it.
#
# .NET / ASP.NET Core 6 (out of support) is NOT changed here: see the write-up.

$ErrorActionPreference = "Stop"
Import-Module GroupPolicy

$gpoName = "Haldane - Security fixes (Phase 3)"
if (-not (Get-GPO -Name $gpoName -ErrorAction SilentlyContinue)) {
    New-GPO -Name $gpoName -Comment "Fixes for the Phase 3 Nessus findings." | Out-Null
}

$settings = @(
    # 1. CVE-2013-3900. Microsoft documents the value as the string "1".
    @{ Key = "HKLM\Software\Microsoft\Cryptography\Wintrust\Config";             Name = "EnableCertPaddingCheck"; Type = "String"; Value = "1" },
    @{ Key = "HKLM\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config"; Name = "EnableCertPaddingCheck"; Type = "String"; Value = "1" },
    # 2. LLMNR off ("Turn off multicast name resolution").
    @{ Key = "HKLM\Software\Policies\Microsoft\Windows NT\DNSClient";            Name = "EnableMulticast";        Type = "DWord";  Value = 0 },
    # 3. SMB signing required ("Microsoft network server: Digitally sign communications (always)").
    @{ Key = "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters";   Name = "RequireSecuritySignature"; Type = "DWord"; Value = 1 },
    @{ Key = "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters";   Name = "EnableSecuritySignature";  Type = "DWord"; Value = 1 }
)
foreach ($s in $settings) {
    Set-GPRegistryValue -Name $gpoName -Key $s.Key -ValueName $s.Name -Type $s.Type -Value $s.Value | Out-Null
}

$linked = (Get-GPInheritance -Target "DC=haldane,DC=local").GpoLinks.DisplayName -contains $gpoName
if (-not $linked) {
    New-GPLink -Name $gpoName -Target "DC=haldane,DC=local" -LinkEnabled Yes | Out-Null
}

gpupdate /force | Out-Null
$settings | ForEach-Object {
    [pscustomobject]@{
        Setting = $_.Name
        Value   = (Get-ItemProperty -Path ($_.Key -replace '^HKLM', 'HKLM:') -Name $_.Name -ErrorAction SilentlyContinue).($_.Name)
        Key     = $_.Key -replace '^HKLM\\', ''
    }
} | Format-Table -AutoSize
