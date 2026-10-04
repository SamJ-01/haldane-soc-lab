# Run on DC01 (PowerShell as Administrator).
# Turns DC01 into the first domain controller of a new forest, haldane.local.
# DC01 restarts automatically when it finishes (about 5-10 minutes).

# 1. Install the Active Directory Domain Services role and its admin tools.
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# 2. The Directory Services Restore Mode (DSRM) password is used only to
#    repair AD in an emergency. Save it in your password manager.
$dsrmPassword = Read-Host -AsSecureString "Choose a DSRM (recovery) password"

# 3. Create the forest and domain. -InstallDns makes DC01 the DNS server
#    that every other machine will use to find the domain.
Install-ADDSForest `
    -DomainName "haldane.local" `
    -DomainNetbiosName "HALDANE" `
    -InstallDns `
    -SafeModeAdministratorPassword $dsrmPassword `
    -Force
