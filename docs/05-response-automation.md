# Phase 5: Response automation

> **In progress.** An approval-gated playbook: when HAL-004 (many failed
> logons followed by a success) fires, Sentinel asks a human by email whether
> to disable the account, and only acts on **Approve**.

## Design

| Step | What happens | How |
|---|---|---|
| 1 | HAL-004 raises an incident | Analytics rule from Phase 4 |
| 2 | An automation rule starts the playbook | `Microsoft.SecurityInsights/automationRules` |
| 3 | The playbook reads the account from the incident | Sentinel connector, managed identity |
| 4 | The analyst gets an **Approve / Reject** email | Outlook.com connector |
| 5 | On Approve only: the account is disabled on DC01 | Azure Run Command, called with the playbook's managed identity |
| 6 | The outcome is written to the incident as a comment | Sentinel connector |

Everything is code: [`infra/playbook.bicep`](../infra/playbook.bicep),
deployed with [`scripts/deploy-playbook.sh`](../scripts/deploy-playbook.sh).
The playbook was written with AI assistance; I deployed, configured and
tested it.

## Safety decisions

- **A human decides.** Disabling an account can lock out a real user, so
  the playbook never acts without an explicit Approve.
- **No stored passwords.** The playbook signs in to Azure with its own
  managed identity, which can only comment on incidents (Microsoft Sentinel
  Responder) and run commands on DC01 (Virtual Machine Contributor on that
  one VM).
- **Protected accounts are refused** (`haldaneadmin`, `administrator`,
  `krbtgt`), so an attacker cannot use the playbook to lock out the admins.
- **Untrusted input is never pasted into a script.** The account name comes
  from log data, which an attacker can influence (Phase 4 showed attacker
  text in the username field). It reaches PowerShell base64-encoded and is
  checked against a strict pattern before use.

## Deployment

`deploy-playbook.sh` created the Logic App, its two connections, the role
assignments and the automation rule. The Outlook.com connection then had to
be signed in once by hand (API connection > Edit API connection >
Authorize), because a mailbox can't be signed in from code.

The automation rule runs the playbook whenever HAL-004 creates an incident:

![Automation rule: HAL-004 incident created, run playbook pb-hal-disable-account](../images/phase5-automation-rule.webp)

## Test

On 30 Oct I created a fresh test account, `hal-pb.test`, on DC01, then on
WS01 entered a wrong password for it 12 times followed by the right one
(finishing at about 16:49 UTC), the same pattern as Phase 6's T3. This
should make HAL-004 fire, which should start the playbook.

![Test account created](../images/phase5-test-account.webp)

![Repeated wrong passwords, then success](../images/phase5-password-test.webp)

HAL-004 raised **incident 25** and the playbook sent the approval request at
17:08, about 19 minutes after the test, naming the incident and the account:

![Approval email for incident 25 (subscription details in the link redacted)](../images/phase5-approval-email.webp)

I clicked **Approve**. About a minute later the account was disabled on DC01
(`Enabled: False`), done by the playbook through Azure Run Command, not by
hand:

![hal-pb.test disabled by the playbook](../images/phase5-account-disabled.webp)
