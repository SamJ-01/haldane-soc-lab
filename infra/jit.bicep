// Phase 2: Just-in-Time (JIT) VM access for DC01 and WS01.
//
// RDP stays closed by default. When you need it, scripts/request-access.sh
// asks Defender for Cloud to open port 3389 for your current IP only, for up
// to 3 hours, after which it closes again by itself.
//
// Requires Defender for Servers Plan 2 to be enabled on the subscription.

@description('Azure region. Defaults to the resource group\'s region.')
param location string = resourceGroup().location

@description('VMs that get JIT access for RDP.')
param vmNames array = [
  'DC01'
  'WS01'
]

resource vms 'Microsoft.Compute/virtualMachines@2024-03-01' existing = [for name in vmNames: {
  name: name
}]

resource jitPolicy 'Microsoft.Security/locations/jitNetworkAccessPolicies@2020-01-01' = {
  name: '${location}/jit-haldane'
  kind: 'Basic'
  properties: {
    virtualMachines: [for (name, i) in vmNames: {
      id: vms[i].id
      ports: [
        {
          number: 3389
          protocol: 'TCP'
          // The exact IP is chosen at request time (your current IP).
          allowedSourceAddressPrefix: '*'
          maxRequestAccessDuration: 'PT3H'
        }
      ]
    }]
  }
}
