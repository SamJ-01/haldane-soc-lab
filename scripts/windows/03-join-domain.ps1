# Run on WS01 (PowerShell as Administrator), after the network's DNS points
# at DC01 and WS01 has been restarted so it picks that DNS up.

# Check WS01 can find the domain first. If this fails, DNS isn't set yet.
Resolve-DnsName haldane.local

# Join the domain. When asked, sign in as HALDANE\haldaneadmin.
Add-Computer -DomainName "haldane.local" -Credential (Get-Credential) -Restart
