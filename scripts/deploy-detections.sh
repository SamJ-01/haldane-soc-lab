#!/usr/bin/env bash
# Phase 4: deploy the Sentinel analytics rules from detections/*.kql.
#   ./scripts/deploy-detections.sh
set -euo pipefail

az deployment group create \
  --resource-group rg-haldane-lab \
  --template-file infra/detections.bicep \
  --output none
echo "Analytics rules deployed. Sentinel > Analytics shows them as enabled."
