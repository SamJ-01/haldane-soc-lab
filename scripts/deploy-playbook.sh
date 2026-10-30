#!/usr/bin/env bash
# Phase 5: deploy the approval-gated response playbook (infra/playbook.bicep).
#   APPROVER_EMAIL=you@example.com ./scripts/deploy-playbook.sh
# The approver's email is passed in at deploy time, never stored in the repo.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${APPROVER_EMAIL:?Set APPROVER_EMAIL to the address that should receive approval requests}"

# Sentinel runs playbooks as the "Azure Security Insights" app; find its
# object ID in this tenant so it can be given permission to start the playbook.
SENTINEL_SP="$(az ad sp show --id 98785600-1bb7-4fb9-b9fa-19afe2c8a360 --query id -o tsv)"

az deployment group create \
  --resource-group rg-haldane-lab \
  --template-file infra/playbook.bicep \
  --parameters approverEmail="$APPROVER_EMAIL" securityInsightsPrincipalId="$SENTINEL_SP" \
  --output none

echo "Playbook deployed."
echo "One manual step: Azure portal > API connections > outlook-haldane > Edit API connection > Authorize,"
echo "sign in with the approver mailbox, then Save."
