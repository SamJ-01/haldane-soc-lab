#!/usr/bin/env bash
# Phase 2: set up Just-in-Time RDP access for DC01 and WS01.
# Needs Defender for Servers Plan 2 switched on first.
#   ./scripts/deploy-jit.sh
set -euo pipefail

az deployment group create \
  --resource-group rg-haldane-lab \
  --template-file infra/jit.bicep \
  --output none
echo "JIT policy jit-haldane created. Open RDP with ./scripts/request-access.sh"
