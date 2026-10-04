# Phase 0: Foundations

**Result:** cost controls in place and the lab network deployed from code in
one command, at no cost (virtual networks and NSGs are free in Azure).

## What was built

| Resource | Purpose |
| --- | --- |
| `rg-haldane-lab` (UK South) | One resource group for the whole lab, so teardown is a single delete |
| `vnet-haldane` (10.10.0.0/16) | Lab network |
| `snet-corp` (10.10.1.0/24) | Domain controller and member server (Phase 1) |
| `snet-attacker` (10.10.2.0/24) | Kali VM for scans and simulations |
| `nsg-haldane-corp` | RDP (3389) allowed only from the administrator's IP |
| `nsg-haldane-attacker` | SSH (22) allowed only from the administrator's IP |

Template: [`infra/network.bicep`](../infra/network.bicep).
Deploy with [`scripts/deploy-network.sh`](../scripts/deploy-network.sh);
delete everything with [`scripts/teardown.sh`](../scripts/teardown.sh).

## Cost controls

- Monthly budget of £40 with email alerts at 50% and 90% of actual spend,
  and at 100% of forecast spend.
- Pay-as-you-go has no hard spending cap, so VMs will be deallocated after
  every session and set to shut down automatically each night.

## Problems and fixes

| Problem | Cause | Fix |
| --- | --- | --- |
| No VMs could be created | New pay-as-you-go subscriptions start with a vCPU quota of 0 for many VM families | Requested 10 Bsv2 vCPUs in UK South (approved automatically); regional limit was already 20 |
| `git push` rejected the password | GitHub no longer accepts account passwords for Git over HTTPS | Signed in with the GitHub CLI (`gh auth login`), which stores a token |
| The home IP address changed between sessions | Residential ISPs reassign public IPs | Re-run the deploy script; it detects the current IP and updates the NSG rules |

## Lessons

- **Re-running the deployment is safe.** Bicep deployments are idempotent:
  the second run compared the template with what existed and changed nothing.
- **Check quotas before planning VM sizes.** A quota of 0 would otherwise
  surface as a confusing error mid-build.
