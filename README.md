# Haldane SOC Lab

> **Work in progress.** Phases 0–7 complete; Phase 8 (reporting) next.

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
| 3 | Vulnerability management | [Done](docs/03-vulnerability-management.md) |
| 4 | Detection engineering (5 rules as code) | [Done](docs/04-detection-engineering.md) |
| 5 | Response automation (approval-gated playbook) | [Done](docs/05-response-automation.md) |
| 6 | Purple-team exercise | [Done](docs/06-purple-team.md) |
| 7 | Coverage and tuning | [Done](docs/07-coverage-and-tuning.md) |
| 8 | Reporting | Not started |
| H | Honeypot (optional) | Not started |

## Build and tear down

### Everyday use

One script covers a normal session ([`scripts/lab.sh`](scripts/lab.sh)). It
works out your current IP (allowing the whole mobile block when you're on mobile
data), opens Just-in-Time access, and connects:

```bash
./scripts/lab.sh up dc01        # start the lab, open access, Remote Desktop to DC01
./scripts/lab.sh connect ws01   # another window, to WS01 (or kali01)
./scripts/lab.sh access         # your IP changed? re-open access
./scripts/lab.sh scan           # scan account on + Kali with Nessus at https://localhost:8834
./scripts/lab.sh fix            # apply and verify the Phase 3 fixes
./scripts/lab.sh status         # VM states and your IP
./scripts/lab.sh down           # scan account off, every VM deallocated
```

### Every script

```bash
az login
./scripts/deploy-network.sh   # resource group + network, RDP/SSH from your IP only
./scripts/deploy-servers.sh   # DC01 + WS01 (asks for the admin password)
./scripts/deploy-monitoring.sh  # Log Analytics workspace + Microsoft Sentinel
./scripts/deploy-attacker.sh  # Kali VM in the attacker subnet (SSH key only)
./scripts/deploy-jit.sh       # Just-in-Time RDP + SSH (needs Defender for Servers P2)
./scripts/install-sysmon.sh   # Sysmon on both VMs, via Azure Run Command
./scripts/deploy-data-collection.sh  # Windows + Sysmon + Activity logs into Sentinel
./scripts/deploy-detections.sh # Sentinel analytics rules from detections/*.kql
./scripts/install-nessus.sh   # Nessus on Kali, over SSH
./scripts/allow-scanner.sh    # Group Policy: scan ports open to Kali (10.10.2.4) only
./scripts/check-scan-ports.sh # from Kali, test which ports on DC01/WS01 it can reach
./scripts/scan-account.sh enable  # svc-nessus on for a credentialed scan (disable after)
./scripts/apply-fixes.sh      # Group Policy fixing the top Nessus findings
./scripts/verify-fixes.sh     # check those fixes are in place on DC01 and WS01
./scripts/start-lab.sh        # start all VMs and show their IPs
./scripts/request-access.sh   # open RDP for your current IP for 3 hours (add KALI01 for SSH)
./scripts/connect.sh ws01     # open Remote Desktop to WS01 (or dc01; add a username to sign in as staff)
./scripts/connect.sh kali01   # SSH to Kali, with Nessus at https://localhost:8834
./scripts/stop-lab.sh         # deallocate all VMs so billing stops
./scripts/teardown.sh         # deletes everything (asks to confirm)
```

## Licence

[MIT](LICENSE)
