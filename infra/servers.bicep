// Phase 1: the two Haldane Ltd servers.
//
//   DC01  10.10.1.4   domain controller for haldane.local
//   WS01  10.10.1.10  member server, used as the "staff workstation"
//
// Both run Windows Server 2022 so that Defender for Servers covers them
// (Windows 11 would need a separate Defender for Endpoint client licence).
// Each VM shuts down automatically every night to keep costs down.
//
// Deploy after network.bicep, with scripts/deploy-servers.sh.

@description('Azure region. Defaults to the resource group\'s region.')
param location string = resourceGroup().location

@description('Local administrator username for both VMs.')
param adminUsername string = 'haldaneadmin'

@description('Local administrator password: 12+ characters with upper, lower, number and symbol.')
@secure()
param adminPassword string

@description('VM size. B2s_v2 = 2 vCPUs, 8 GB RAM, burstable and cheap.')
param vmSize string = 'Standard_B2s_v2'

@description('Time (24h, UK time) when the VMs shut down automatically each day.')
param shutdownTime string = '2300'

var servers = [
  {
    name: 'DC01'
    privateIp: '10.10.1.4'
  }
  {
    name: 'WS01'
    privateIp: '10.10.1.10'
  }
]

// The network created in Phase 0.
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: 'vnet-haldane'
}

resource corpSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: vnet
  name: 'snet-corp'
}

// A public IP for each VM, so you can RDP in. The NSG from Phase 0 only
// allows RDP from your own IP address.
resource publicIps 'Microsoft.Network/publicIPAddresses@2023-11-01' = [for server in servers: {
  name: 'pip-${toLower(server.name)}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}]

// Fixed private IPs: the domain controller's address must never change,
// because every other machine uses it for DNS.
resource nics 'Microsoft.Network/networkInterfaces@2023-11-01' = [for (server, i) in servers: {
  name: 'nic-${toLower(server.name)}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: corpSubnet.id
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: server.privateIp
          publicIPAddress: {
            id: publicIps[i].id
          }
        }
      }
    ]
  }
}]

resource vms 'Microsoft.Compute/virtualMachines@2024-03-01' = [for (server, i) in servers: {
  name: server.name
  location: location
  // A managed identity lets the Azure Monitor Agent (Phase 2) sign in to Azure.
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: server.name
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        timeZone: 'GMT Standard Time'
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk-${toLower(server.name)}'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics[i].id
        }
      ]
    }
  }
}]

// Nightly auto-shutdown: a safety net in case you forget to stop the lab.
// (This deallocates the VM, so compute billing stops.)
resource shutdownSchedules 'Microsoft.DevTestLab/schedules@2018-09-15' = [for (server, i) in servers: {
  name: 'shutdown-computevm-${server.name}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: shutdownTime
    }
    timeZoneId: 'GMT Standard Time'
    targetResourceId: vms[i].id
    notificationSettings: {
      status: 'Disabled'
    }
  }
}]

output publicIpAddresses array = [for (server, i) in servers: {
  name: server.name
  publicIp: publicIps[i].properties.ipAddress
}]
