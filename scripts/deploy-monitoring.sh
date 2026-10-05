#!/usr/bin/env bash
# Phase 2: create the Log Analytics workspace and switch on Microsoft Sentinel.
#   ./scripts/deploy-monitoring.sh
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"

# New subscriptions have most Azure services ("resource providers") switched
# off until they're registered. Sentinel needs these. Registering is free and
# only takes effect once; re-running it is harmless.
for provider in Microsoft.OperationalInsights Microsoft.OperationsManagement \
                Microsoft.SecurityInsights Microsoft.Security Microsoft.Insights; do
  echo "Registering ${provider}..."
  az provider register --namespace "$provider" --wait
done

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/monitoring.bicep \
  --query "properties.outputs.workspaceName.value" \
  --output tsv
