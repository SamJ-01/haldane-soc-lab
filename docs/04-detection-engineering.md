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

### Tuning: approved scan windows

The scanner caused two of the three incidents. Simply excluding `svc-nessus`
would blind the rule to anyone who steals that Domain Admin account. Instead,
logons are ignored only when the **account, source IP and time** all match an
authorised scan in the `ApprovedScanWindows` watchlist
([`approved-scan-windows.csv`](../detections/watchlists/approved-scan-windows.csv)),
deployed with the rule. The same account used outside a window, or from
another address, still raises a High incident. If the watchlist is ever
missing, the rule fails safe: everything alerts.

After tuning, the same 7 days of data return only the admin's own logon; both
scanner rows are gone:

![HAL-001 after tuning: only the haldaneadmin row remains (IP redacted)](../images/phase4-hal001-tuned.webp)

**Triage:** all three incidents were investigated and resolved as
*Informational, expected activity: Security testing* (shown in the portal as
"Benign Positive"), each with a comment recording why: the two scanner
incidents matched the approved re-scan window, and the admin logon was the
deliberate test through Just-in-Time access.

![Incident 2 resolved as Informational, expected activity: Security testing, with the reason recorded](../images/phase4-incident-closed.webp)

*Query written with AI assistance; tested and reviewed against lab data.*

## HAL-002: Member added to a privileged Active Directory group

**Query:** [`detections/HAL-002-member-added-to-privileged-group.kql`](../detections/HAL-002-member-added-to-privileged-group.kql)
(the KQL was written with AI assistance; I ran the test and verified the results).

**Why:** an attacker who gets admin rights once will often add an account they
control to Domain Admins so they can come back. In a small organisation these
groups almost never change, so every addition deserves a look.

| | |
|---|---|
| **MITRE ATT&CK** | T1098 Account Manipulation; T1078.002 Valid Accounts: Domain Accounts |
| **Data** | `SecurityEvent` from DC01: 4728 (global group), 4732 (local group), 4756 (universal group) |
| **Groups watched** | Domain Admins, Administrators, Enterprise Admins, Schema Admins |
| **Severity** | High |
| **Runs** | Every hour, over the last hour; one incident per change |

A trap worth knowing: in these events `TargetUserName` is the **group**, not a
person. The account that was added is `MemberName` (`MemberSid`) and the
person who made the change is `SubjectUserName`.

**Test:** on DC01 I created a disabled test account, `hal002.test`, added it to
Domain Admins in Active Directory Users and Computers, then removed it.

![Test account added to Domain Admins](../images/phase4-hal002-group-add.webp)

The query found exactly that change: event 4728, Domain Admins,
`CN=HAL002 Test`, added by `haldaneadmin`.

![HAL-002 query result: the test addition to Domain Admins](../images/phase4-hal002-results.webp)

After deploying the rule, its first run picked up the same test and raised
incident 5 in Microsoft Defender:

![HAL-002 incident in the Defender incident queue](../images/phase4-hal002-incidents.webp)

## Problems and fixes

| Problem | Cause | Fix |
| --- | --- | --- |
| No incidents visible after the rule ran | The Defender portal's incident list filters on "Priority score: 15-100" by default | Removed the filter; the three incidents were there |
| Deploying the tuned rule failed: "Failed to resolve scalar expression named 'Account'" | Sentinel validates a rule's query when it is saved; the new watchlist had not been indexed yet, so its columns did not exist | Read the watchlist columns with `column_ifexists()`, so the rule stays valid and fails safe (every logon alerts) if the watchlist is missing |
