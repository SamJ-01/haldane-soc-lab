#!/usr/bin/env bash
# Phase 3: open the scan ports on DC01 and WS01 to KALI01 (10.10.2.4) only,
# with a Group Policy. Runs from the Mac through Azure Run Command, no RDP.
#   ./scripts/allow-scanner.sh
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"

echo "Creating the Group Policy on DC01 (about 1 minute)..."
az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP" --name DC01 \
  --command-id RunPowerShellScript \
  --scripts @scripts/windows/08-allow-scanner.ps1 \
  --query "value[].message" --output tsv

echo "Applying it on WS01 now rather than waiting for the next refresh..."
az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP" --name WS01 \
  --command-id RunPowerShellScript \
  --scripts "gpupdate /force" \
  --query "value[].message" --output tsv
