#!/usr/bin/env bash
# Phase 2: create the Log Analytics workspace and switch on Microsoft Sentinel.
#   ./scripts/deploy-monitoring.sh
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/monitoring.bicep \
  --query "properties.outputs.workspaceName.value" \
  --output tsv
