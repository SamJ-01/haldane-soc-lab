# Haldane SOC Lab

> **Work in progress.** Phase 0 complete; Phase 1 (build Haldane Ltd) next.

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
| 1 | Build Haldane Ltd (AD domain) | Not started |
| 2 | Visibility (5 log sources into Sentinel) | Not started |
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
./scripts/teardown.sh         # deletes everything (asks to confirm)
```

## Licence

[MIT](LICENSE)
