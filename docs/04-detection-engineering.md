# Phase 4: Detection engineering

> **In progress.** Rules are written in KQL, stored in [`detections/`](../detections),
> tested against real lab data, then deployed as scheduled analytics rules.

## HAL-001: Privileged account network logon from outside the corporate subnet

[`detections/HAL-001-privileged-logon-from-outside-corp.kql`](../detections/HAL-001-privileged-logon-from-outside-corp.kql)

**Why:** in Phase 3, the credentialed scanner signed in as a Domain Admin
thousands of times from the attacker subnet, and Microsoft Defender raised no
alert. An attacker using a stolen admin password would look the same.

**Logic:** successful (4624) network (type 3) logons by a privileged account
from an IP outside 10.10.1.0/24.

**MITRE ATT&CK:** T1078.002 Valid Accounts: Domain Accounts;
T1021.002 Remote Services: SMB/Windows Admin Shares.

**First run against 7 days of lab data:**

![HAL-001 query results in Sentinel (one IP address redacted)](../images/phase4-hal001-results.webp)

| Result | Verdict |
| --- | --- |
| `svc-nessus` from 10.10.2.4 (KALI01), ~1,600 logons on each server | **True positive, expected:** the approved Phase 3 re-scan. The rule would have caught the activity Defender missed. |
| `haldaneadmin` from a public IP, 2 logons on DC01 | **True positive, benign:** the lab admin's own Remote Desktop session through Just-in-Time access. A Domain Admin logging in from the internet is worth an alert in a real company; here it is expected and explained. |

**Deployed as code:** [`infra/detections.bicep`](../infra/detections.bicep) loads the
`.kql` file into a scheduled analytics rule ([`deploy-detections.sh`](../scripts/deploy-detections.sh)):
hourly, High severity, account/IP/host entity mapping, incidents grouped when
the same entities repeat within 5 hours.

![HAL-001 enabled in the Defender portal's detection rules](../images/phase4-hal001-rule.webp)

**Tested live:** within its first two runs the rule raised three High
incidents, each with the account, host and source IP mapped as entities:

| Incident | Entities | Cause |
| --- | --- | --- |
| 1 and 2 | `svc-nessus` on WS01 and DC01 | The Phase 3 re-scan, caught on the rule's first run |
| 3 | `haldaneadmin` on DC01, from a public IP | The lab admin's Remote Desktop session, the deliberate test |

![Three HAL-001 incidents in the Defender portal](../images/phase4-hal001-incidents.webp)
![HAL-001 incident graph: haldaneadmin, DC01 and the source IP (redacted)](../images/phase4-hal001-incident.webp)

The incidents did not show at first: the Defender portal's incident list
filters on "Priority score: 15-100" by default, and new single-alert
incidents from custom rules can score lower. Removing the filter showed them.

**Triage:** all three incidents were investigated and resolved as
*Informational, expected activity: Security testing* (shown in the portal as
"Benign Positive"), each with a comment recording why: the two scanner
incidents matched the approved re-scan window, and the admin logon was the
deliberate test through Just-in-Time access.

![Incident 2 resolved as Informational, expected activity: Security testing, with the reason recorded](../images/phase4-incident-closed.webp)

*Query written with AI assistance; tested and reviewed against lab data.*

## Problems and fixes

| Problem | Cause | Fix |
| --- | --- | --- |
| No incidents visible after the rule ran | The Defender portal's incident list filters on "Priority score: 15-100" by default | Removed the filter; the three incidents were there |
| Deploying the tuned rule failed: "Failed to resolve scalar expression named 'Account'" | Sentinel validates a rule's query when it is saved; the new watchlist had not been indexed yet, so its columns did not exist | Read the columns from `WatchlistItem` (always present) instead of as top-level columns |
