# Run on DC01 after it has restarted as a domain controller
# (sign in as HALDANE\haldaneadmin, PowerShell as Administrator).
# Creates Haldane Ltd's OUs, groups and fictional staff accounts.

Import-Module ActiveDirectory
$domain = "DC=haldane,DC=local"

# --- Organisational units -------------------------------------------------
New-ADOrganizationalUnit -Name "Haldane" -Path $domain
foreach ($ou in "Staff", "Groups", "Servers", "Service Accounts") {
    New-ADOrganizationalUnit -Name $ou -Path "OU=Haldane,$domain"
}

# --- Groups ---------------------------------------------------------------
foreach ($group in "IT Admins", "Finance", "HR", "Engineering") {
    New-ADGroup -Name $group -GroupScope Global -GroupCategory Security `
        -Path "OU=Groups,OU=Haldane,$domain"
}

# --- Staff (fictional people) ---------------------------------------------
# One starting password for every lab account. Use a strong one and save it.
$password = Read-Host -AsSecureString "Starting password for the staff accounts"

$staff = @(
    @{ Sam = "a.patel";    First = "Asha";   Last = "Patel";    Dept = "Finance" },
    @{ Sam = "j.okafor";   First = "James";  Last = "Okafor";   Dept = "Finance" },
    @{ Sam = "l.hughes";   First = "Laura";  Last = "Hughes";   Dept = "HR" },
    @{ Sam = "m.kowalski"; First = "Marek";  Last = "Kowalski"; Dept = "Engineering" },
    @{ Sam = "s.reid";     First = "Sophie"; Last = "Reid";     Dept = "Engineering" },
    @{ Sam = "d.evans";    First = "Daniel"; Last = "Evans";    Dept = "IT Admins" }
)

foreach ($person in $staff) {
    New-ADUser -Name "$($person.First) $($person.Last)" `
        -GivenName $person.First -Surname $person.Last `
        -SamAccountName $person.Sam `
        -UserPrincipalName "$($person.Sam)@haldane.local" `
        -Department $person.Dept `
        -Path "OU=Staff,OU=Haldane,$domain" `
        -AccountPassword $password -Enabled $true
    Add-ADGroupMember -Identity $person.Dept -Members $person.Sam
}

# --- A service account, as most companies have ----------------------------
New-ADUser -Name "svc-backup" -SamAccountName "svc-backup" `
    -Description "Backup service account" `
    -Path "OU=Service Accounts,OU=Haldane,$domain" `
    -AccountPassword $password -Enabled $true

# Daniel is the IT admin, so he can sign in to servers remotely.
Add-ADGroupMember -Identity "Domain Admins" -Members "d.evans"

Get-ADUser -Filter * -SearchBase "OU=Haldane,$domain" |
    Select-Object Name, SamAccountName, Enabled | Format-Table
