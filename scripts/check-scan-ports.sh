#!/usr/bin/env bash
# Phase 3: from KALI01, test which Windows ports on DC01 and WS01 the scanner
# can reach. Run on the Mac; the test itself runs on Kali over SSH.
#   ./scripts/check-scan-ports.sh
set -euo pipefail

IP="$(az vm list-ip-addresses --resource-group rg-haldane-lab --name KALI01 \
  --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)"

ssh -i "$HOME/.ssh/haldane_kali" "haldaneadmin@${IP}" 'bash -s' <<'TEST'
for host in 10.10.1.4 10.10.1.10; do
  for port in 53 88 135 139 389 445 3389; do
    if timeout 2 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
      echo "$host port $port OPEN"
    else
      echo "$host port $port closed/filtered"
    fi
  done
done
TEST
