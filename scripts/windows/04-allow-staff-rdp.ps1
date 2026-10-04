# Run on WS01 after it has joined the domain
# (sign in as HALDANE\haldaneadmin, PowerShell as Administrator).
#
# Windows Server only lets administrators sign in over Remote Desktop by
# default. WS01 plays the shared staff workstation, so allow all domain users.
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "HALDANE\Domain Users"
Get-LocalGroupMember -Group "Remote Desktop Users"
