#!/usr/bin/env bash
# Phase 3: check the fixes for the top Nessus findings are in place on both
# servers (refreshes Group Policy first). Read-only apart from the refresh.
#   ./scripts/verify-fixes.sh
set -euo pipefail

for vm in DC01 WS01; do
  echo "== ${vm} =="
  az vm run-command invoke \
    --resource-group rg-haldane-lab --name "$vm" \
    --command-id RunPowerShellScript \
    --scripts "gpupdate /force | Out-Null; [pscustomobject]@{ CertPadding64 = (Get-ItemProperty 'HKLM:\\Software\\Microsoft\\Cryptography\\Wintrust\\Config' -ErrorAction SilentlyContinue).EnableCertPaddingCheck; CertPadding32 = (Get-ItemProperty 'HKLM:\\Software\\Wow6432Node\\Microsoft\\Cryptography\\Wintrust\\Config' -ErrorAction SilentlyContinue).EnableCertPaddingCheck; LLMNR_EnableMulticast = (Get-ItemProperty 'HKLM:\\Software\\Policies\\Microsoft\\Windows NT\\DNSClient' -ErrorAction SilentlyContinue).EnableMulticast; SmbSigningRequired = (Get-SmbServerConfiguration).RequireSecuritySignature } | Format-List" \
    --query "value[].message" --output tsv
done
