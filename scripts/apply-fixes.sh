#!/usr/bin/env bash
# Phase 3: apply the Group Policy that fixes the top Nessus findings, then
# refresh policy on both servers and show the resulting registry values.
#   ./scripts/apply-fixes.sh
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"

echo "Creating the fixes Group Policy on DC01..."
az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP" --name DC01 \
  --command-id RunPowerShellScript \
  --scripts @scripts/windows/09-security-fixes.ps1 \
  --query "value[].message" --output tsv

echo "Applying it on WS01..."
az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP" --name WS01 \
  --command-id RunPowerShellScript \
  --scripts "gpupdate /force | Out-Null; [pscustomobject]@{ EnableCertPaddingCheck = (Get-ItemProperty 'HKLM:\\Software\\Microsoft\\Cryptography\\Wintrust\\Config').EnableCertPaddingCheck; LLMNR_EnableMulticast = (Get-ItemProperty 'HKLM:\\Software\\Policies\\Microsoft\\Windows NT\\DNSClient').EnableMulticast; SmbSigningRequired = (Get-SmbServerConfiguration).RequireSecuritySignature } | Format-List" \
  --query "value[].message" --output tsv
