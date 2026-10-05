# Run on DC01 (PowerShell as Administrator).
# New domain members land in the default "Computers" container. Move WS01
# into Haldane\Servers so settings applied to that OU reach it.
Get-ADComputer WS01 | Move-ADObject -TargetPath "OU=Servers,OU=Haldane,DC=haldane,DC=local"
Get-ADComputer WS01 | Select-Object Name, DistinguishedName
