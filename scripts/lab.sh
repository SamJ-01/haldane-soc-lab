#!/usr/bin/env bash
# One command for everyday lab sessions. Wraps the individual scripts.
#
#   ./scripts/lab.sh up              start all VMs and open access for your current IP
#   ./scripts/lab.sh up dc01         ...then open Remote Desktop to DC01 (or ws01, kali01)
#   ./scripts/lab.sh access          re-open access (e.g. after your IP changes)
#   ./scripts/lab.sh connect ws01    connect to a VM (kali01 also tunnels Nessus)
#   ./scripts/lab.sh scan            enable the scan account and connect to Kali for Nessus
#   ./scripts/lab.sh fix             apply the Phase 3 fixes, then verify them
#   ./scripts/lab.sh status          VM states and your current IP
#   ./scripts/lab.sh down            disable the scan account and deallocate every VM
set -euo pipefail
cd "$(dirname "$0")/.."

RESOURCE_GROUP="rg-haldane-lab"

# Mobile connections change IP within the provider's block, so allow the
# whole block there; anywhere else, allow just the current IP.
set_admin_cidr() {
  local ip
  ip="$(curl -s https://api.ipify.org)"
  if [[ "$ip" =~ ^92\.40\.(20[89]|21[0-9]|22[0-3])\. ]]; then
    export ADMIN_CIDR="92.40.208.0/20"
    echo "Your IP: ${ip} (mobile), allowing ${ADMIN_CIDR}"
  else
    unset ADMIN_CIDR
    echo "Your IP: ${ip}"
  fi
}

open_access() {
  set_admin_cidr
  ./scripts/request-access.sh DC01 WS01 KALI01
}

case "${1:-}" in
  up)
    ./scripts/start-lab.sh
    open_access
    if [[ -n "${2:-}" ]]; then
      # macOS ships bash 3.2, so lower-case with tr rather than ${2,,}.
      vm="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
      if [[ "$vm" != kali* ]]; then
        echo "Waiting 60 seconds for Windows to finish starting..."
        sleep 60
      fi
      ./scripts/connect.sh "$vm"
    fi
    ;;
  access)
    open_access
    ;;
  connect)
    ./scripts/connect.sh "${2:?Usage: $0 connect dc01|ws01|kali01 [username]}" "${3:-}"
    ;;
  scan)
    ./scripts/scan-account.sh enable
    open_access
    echo "Leave this window open; Nessus is at https://localhost:8834"
    echo "When the scan is finished: ./scripts/scan-account.sh disable (or lab.sh down)"
    ./scripts/connect.sh kali01
    ;;
  fix)
    ./scripts/apply-fixes.sh
    ./scripts/verify-fixes.sh
    ;;
  status)
    az vm list -d -g "$RESOURCE_GROUP" --query "[].{VM:name, State:powerState, PublicIP:publicIps}" -o table
    echo "Your IP: $(curl -s https://api.ipify.org)"
    ;;
  down)
    # Only touch the scan account if DC01 is running; Run Command needs it up.
    if [[ "$(az vm get-instance-view -g "$RESOURCE_GROUP" -n DC01 \
          --query "instanceView.statuses[1].code" -o tsv)" == "PowerState/running" ]]; then
      ./scripts/scan-account.sh disable
    fi
    ./scripts/stop-lab.sh
    ;;
  *)
    sed -n '2,12p' "$0"
    exit 1
    ;;
esac
