#!/usr/bin/env bash
# Phase 2: connect log sources to Sentinel.
#   - Windows Security events and Sysmon from DC01 and WS01 (via AMA)
#   - the subscription's Azure Activity log
#   ./scripts/deploy-data-collection.sh
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"

# The Azure Monitor Agent signs in to Azure with the VM's own identity.
for vm in DC01 WS01; do
  echo "Giving ${vm} a managed identity..."
  az vm identity assign --resource-group "$RESOURCE_GROUP" --name "$vm" --output none
done

echo "Installing the agent and the data collection rule (about 5 minutes)..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/data-collection.bicep \
  --output none

echo "Sending the Azure Activity log to the workspace..."
WORKSPACE_ID="$(az monitor log-analytics workspace show \
  --resource-group "$RESOURCE_GROUP" --workspace-name law-haldane --query id --output tsv)"
az deployment sub create \
  --location uksouth \
  --template-file infra/activity-log.bicep \
  --parameters workspaceId="$WORKSPACE_ID" \
  --output none

echo "Done. Logs take 10-20 minutes to start arriving. Check with queries/data-health.kql."
