# Haldane SOC Lab

> **Work in progress.** Phases 0–2 complete; Phase 3 (vulnerability management) next.

A small fictional company, "Haldane Ltd", built from code in my own Azure
tenant, then secured, attacked, monitored, investigated and reported on end
to end: Active Directory, Microsoft Defender for Endpoint, Microsoft
Sentinel, Nessus, detections deployed from GitHub, and an approval-gated
response playbook.

All systems are lab machines I own. No real company or user data is involved.

## Progress

| Phase | Focus | Status |
| --- | --- | --- |
| 0 | Foundations: budget, network from code | [Done](docs/00-foundations.md) |
| 1 | Build Haldane Ltd (AD domain) | [Done](docs/01-build.md) |
| 2 | Visibility (5 log sources into Sentinel) | [Done](docs/02-visibility.md) |
| 3 | Vulnerability management | Not started |
| 4 | Detection engineering (rules as code) | Not started |
| 5 | Response automation | Not started |
| 6 | Purple-team exercise | Not started |
| 7 | Coverage and tuning | Not started |
| 8 | Reporting | Not started |
| H | Honeypot (optional) | Not started |

## Build and tear down

```bash
az login
./scripts/deploy-network.sh   # resource group + network, RDP/SSH from your IP only
./scripts/deploy-servers.sh   # DC01 + WS01 (asks for the admin password)
./scripts/deploy-monitoring.sh  # Log Analytics workspace + Microsoft Sentinel
./scripts/deploy-attacker.sh  # Kali VM in the attacker subnet (SSH key only)
./scripts/deploy-jit.sh       # Just-in-Time RDP + SSH (needs Defender for Servers P2)
./scripts/install-sysmon.sh   # Sysmon on both VMs, via Azure Run Command
./scripts/deploy-data-collection.sh  # Windows + Sysmon + Activity logs into Sentinel
./scripts/start-lab.sh        # start all VMs and show their IPs
./scripts/request-access.sh   # open RDP for your current IP for 3 hours (add KALI01 for SSH)
./scripts/connect.sh ws01     # open Remote Desktop to WS01 (or dc01; add a username to sign in as staff)
./scripts/connect.sh kali01   # SSH to Kali, with Nessus at https://localhost:8834
./scripts/stop-lab.sh         # deallocate all VMs so billing stops
./scripts/teardown.sh         # deletes everything (asks to confirm)
```

## Licence

[MIT](LICENSE)
