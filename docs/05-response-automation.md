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
