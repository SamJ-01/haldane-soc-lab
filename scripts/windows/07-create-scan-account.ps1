# Phase 3: a dedicated account for Nessus credentialed scans.
# Run on DC01 (sign in as HALDANE\haldaneadmin, PowerShell as Administrator).
#
# A credentialed scan signs in to each machine and reads installed software,
# patch levels and settings directly, instead of guessing from the outside.
# That needs administrator rights on every target, and on a domain controller
# the only way to get them is membership of a domain-wide admin group.
#
# Trade-off, documented on purpose: this makes svc-nessus as powerful as a
# Domain Admin. In a real company it would be locked down further (allowed to
# sign in only from the scanner, monitored, and its password kept in a vault).
# Here it gets a long unique password and is disabled between scans:
#   Disable-ADAccount svc-nessus     /     Enable-ADAccount svc-nessus

Import-Module ActiveDirectory
$domain = "DC=haldane,DC=local"

$password = Read-Host -AsSecureString "Password for svc-nessus (20+ characters, unique)"

New-ADUser -Name "svc-nessus" -SamAccountName "svc-nessus" `
    -UserPrincipalName "svc-nessus@haldane.local" `
    -Description "Nessus credentialed vulnerability scans (Phase 3)" `
    -Path "OU=Service Accounts,OU=Haldane,$domain" `
    -AccountPassword $password -Enabled $true -PasswordNeverExpires $true

Add-ADGroupMember -Identity "Domain Admins" -Members "svc-nessus"

Get-ADUser svc-nessus -Properties MemberOf |
    Select-Object Name, Enabled, @{ n = "Groups"; e = { $_.MemberOf -join "; " } } |
    Format-List
