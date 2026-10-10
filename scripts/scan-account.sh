#!/usr/bin/env bash
# Enable or disable the Nessus scan account (svc-nessus, a Domain Admin).
# It should only be enabled while a credentialed scan is running.
#   ./scripts/scan-account.sh enable
#   ./scripts/scan-account.sh disable
set -euo pipefail

case "${1:-}" in
  enable)  CMD="Enable-ADAccount svc-nessus" ;;
  disable) CMD="Disable-ADAccount svc-nessus" ;;
  *) echo "Usage: $0 enable|disable" >&2; exit 1 ;;
esac

az vm run-command invoke \
  --resource-group rg-haldane-lab --name DC01 \
  --command-id RunPowerShellScript \
  --scripts "$CMD; Get-ADUser svc-nessus | Select-Object Name, Enabled" \
  --query "value[].message" --output tsv
