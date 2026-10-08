#!/usr/bin/env bash
# Phase 3: install Nessus on KALI01, over SSH.
#   ./scripts/request-access.sh KALI01   # first, if SSH isn't open
#   ./scripts/install-nessus.sh
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"

IP="$(az vm list-ip-addresses --resource-group "$RESOURCE_GROUP" --name KALI01 \
  --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)"

ssh -i "$HOME/.ssh/haldane_kali" "haldaneadmin@${IP}" 'bash -s' < scripts/kali/install-nessus.sh
