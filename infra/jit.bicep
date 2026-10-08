// Phase 2: Just-in-Time (JIT) VM access for the lab VMs.
//
// Remote access stays closed by default. When you need it,
// scripts/request-access.sh asks Defender for Cloud to open the port (RDP 3389
// for the Windows servers, SSH 22 for Kali) for your current IP only, for up
// to 3 hours, after which it closes again by itself.
//
// Requires Defender for Servers Plan 2 to be enabled on the subscription.

@description('Azure region. Defaults to the resource group\'s region.')
param location string = resourceGroup().location

@description('VMs that get JIT access, and the port each one needs.')
param jitVms array = [
  {
    name: 'DC01'
    port: 3389
  }
  {
    name: 'WS01'
    port: 3389
  }
  {
    name: 'KALI01'
    port: 22
  }
]

resource vms 'Microsoft.Compute/virtualMachines@2024-03-01' existing = [for v in jitVms: {
  name: v.name
}]

resource jitPolicy 'Microsoft.Security/locations/jitNetworkAccessPolicies@2020-01-01' = {
  name: '${location}/jit-haldane'
  kind: 'Basic'
  properties: {
    virtualMachines: [for (v, i) in jitVms: {
      id: vms[i].id
      ports: [
        {
          number: v.port
          protocol: 'TCP'
          // The exact IP is chosen at request time (your current IP).
          allowedSourceAddressPrefix: '*'
          maxRequestAccessDuration: 'PT3H'
        }
      ]
    }]
  }
}
