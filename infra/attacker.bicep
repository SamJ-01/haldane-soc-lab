// Phase 3: the attacker / scanner VM.
//
//   KALI01  10.10.2.4  Kali Linux in the attacker subnet, running Nessus
//
// Sign-in is by SSH key only (no password), and SSH is closed by default:
// it is opened on request with Just-in-Time access, like RDP for the servers.
// The Nessus web interface is never exposed: reach it through an SSH tunnel.
//
// Deploy with scripts/deploy-attacker.sh, which finds the latest Kali image
// and accepts its Marketplace terms first.

@description('Azure region. Defaults to the resource group\'s region.')
param location string = resourceGroup().location

@description('Linux admin username.')
param adminUsername string = 'haldaneadmin'

@description('Your SSH public key (the contents of the .pub file).')
param sshPublicKey string

@description('Kali Marketplace image SKU, e.g. kali-2025-3.')
param kaliSku string

@description('VM size. B2s_v2 = 2 vCPUs, 8 GB RAM: enough for Nessus.')
param vmSize string = 'Standard_B2s_v2'

@description('Time (24h, UK time) when the VM shuts down automatically each day.')
param shutdownTime string = '2300'

var name = 'KALI01'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: 'vnet-haldane'
}

resource attackerSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: vnet
  name: 'snet-attacker'
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'pip-kali01'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-kali01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: attackerSubnet.id
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.10.2.4'
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: name
  location: location
  // Marketplace images carry a "plan" that must match the image.
  plan: {
    name: kaliSku
    product: 'kali'
    publisher: 'kali-linux'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: toLower(name)
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'kali-linux'
        offer: 'kali'
        sku: kaliSku
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk-kali01'
        createOption: 'FromImage'
        diskSizeGB: 64
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource shutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${name}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: shutdownTime
    }
    timeZoneId: 'GMT Standard Time'
    targetResourceId: vm.id
    notificationSettings: {
      status: 'Disabled'
    }
  }
}

output publicIpAddress string = publicIp.properties.ipAddress
