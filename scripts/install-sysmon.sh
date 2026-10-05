#!/usr/bin/env bash
# Phase 2: install Sysmon on DC01 and WS01 from the Mac, without RDP.
# Azure's "Run Command" runs the PowerShell script inside each VM.
#   ./scripts/install-sysmon.sh
set -euo pipefail

for vm in DC01 WS01; do
  echo "Installing Sysmon on ${vm} (about 1-2 minutes)..."
  az vm run-command invoke \
    --resource-group rg-haldane-lab --name "$vm" \
    --command-id RunPowerShellScript \
    --scripts @scripts/windows/06-install-sysmon.ps1 \
    --query "value[].message" --output tsv   # output, then any errors
done
