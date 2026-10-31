# Haldane SOC Lab

A small fictional company, "Haldane Ltd", built from code in my own Azure
tenant, then secured, attacked, monitored, investigated and reported on end
to end: Active Directory, Microsoft Defender for Endpoint, Microsoft
Sentinel, Nessus, detections deployed from GitHub, and an approval-gated
response playbook.

During my internship I worked in the LOG(N) Pacific cyber range.
This is me building one myself, from an empty Azure subscription.

All systems are lab machines I own. No real company or user data is involved.

**Start with the [final report](docs/08-report.md).**

## Results at a glance

| | |
|---|---|
| Vulnerabilities | 67 → **58** findings; no High or Medium left after fixing the top three by real-world risk |
| Detection rules | **6** KQL rules (HAL-001 to HAL-006), deployed from this repo with Bicep, each baselined and tested |
| Purple team | My rules caught **3 of 4** valid-account attacks; Defender's built-in detections caught **0 of 4**. The fourth (discovery) was a gap, now closed |
| Malware | Attack toolkit **blocked by Defender** before anything ran |
| Response | Playbook disables an account **only after a human approves** by email; tested end to end |
| Policy | Account lockout policy added where there was none |

**Main finding:** Defender stops known malware; my rules catch an attacker
using valid accounts and built-in tools. Each caught what the other missed.

## What I can talk about

- **Ranking vulnerabilities by risk, not score:** why I fixed an "Info"
  finding (LLMNR) before two "Criticals" ([Phase 3](docs/03-vulnerability-management.md)).
- **Tuning without blinding:** excluding the scanner only inside approved
  time windows, and proving the exclusion works with a control test
  ([Phase 4](docs/04-detection-engineering.md), [Phase 7](docs/07-coverage-and-tuning.md)).
- **Safe automation:** least-privilege managed identity, human approval,
  input encoded so it can't inject commands, protected accounts refused
  ([Phase 5](docs/05-response-automation.md)).
- **Defender's attack disruption contained my own admin account**: what
  happened, why, and how I undid it ([Phase 6](docs/06-purple-team.md#defenders-automatic-attack-disruption-contained-accounts)).
- **Being wrong and checking:** the corrections are left in the write-ups
  ([report, lesson 4](docs/08-report.md#6-lessons-learned)).

## How AI was used

Code, queries and first drafts were written with AI assistance (Claude) and
are labelled in each phase. I built and ran the lab, did every portal step,
ran the scans and attacks, triaged every incident, and checked every result
against the evidence. Details in the [report](docs/08-report.md#7-how-ai-was-used).

## Progress

| Phase | Focus | Status |
| --- | --- | --- |
| 0 | Foundations: budget, network from code | [Done](docs/00-foundations.md) |
| 1 | Build Haldane Ltd (AD domain) | [Done](docs/01-build.md) |
| 2 | Visibility (5 log sources into Sentinel) | [Done](docs/02-visibility.md) |
| 3 | Vulnerability management | [Done](docs/03-vulnerability-management.md) |
| 4 | Detection engineering (rules as code) | [Done](docs/04-detection-engineering.md) |
| 5 | Response automation (approval-gated playbook) | [Done](docs/05-response-automation.md) |
| 6 | Purple-team exercise | [Done](docs/06-purple-team.md) |
| 7 | Coverage and tuning (+ HAL-006, lockout policy) | [Done](docs/07-coverage-and-tuning.md) |
| 8 | Final report | [Done](docs/08-report.md) |
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
