// Phase 0: the Haldane Ltd lab network.
//
// One virtual network with two subnets:
//   corp     (10.10.1.0/24) - the domain controller and workstation (Phase 1)
//   attacker (10.10.2.0/24) - the Kali VM used for scans and simulations
//
// Nothing here is reachable from the internet except remote admin (RDP to
// corp, SSH to attacker), and only from the single IP address you pass in.

@description('Azure region for every resource. Defaults to the resource group\'s region.')
param location string = resourceGroup().location

@description('Your own public IP in CIDR form, e.g. 203.0.113.7/32. The only address allowed to connect.')
param adminSourceIp string

@description('DNS servers for the network. Leave empty until the domain controller exists (Phase 1).')
param dnsServers array = []

var corpPrefix = '10.10.1.0/24'
var attackerPrefix = '10.10.2.0/24'

// Network security group for the corp subnet: RDP from your IP only.
// Azure's default rules already allow traffic inside the virtual network
// and deny everything else from the internet.
resource corpNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-haldane-corp'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP-from-admin'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: adminSourceIp
          sourcePortRange: '*'
          destinationAddressPrefix: corpPrefix
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

// Network security group for the attacker subnet: SSH from your IP only.
resource attackerNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-haldane-attacker'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-from-admin'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: adminSourceIp
          sourcePortRange: '*'
          destinationAddressPrefix: attackerPrefix
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'vnet-haldane'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/16'
      ]
    }
    dhcpOptions: {
      dnsServers: dnsServers
    }
    subnets: [
      {
        name: 'snet-corp'
        properties: {
          addressPrefix: corpPrefix
          networkSecurityGroup: {
            id: corpNsg.id
          }
        }
      }
      {
        name: 'snet-attacker'
        properties: {
          addressPrefix: attackerPrefix
          networkSecurityGroup: {
            id: attackerNsg.id
          }
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output corpSubnetId string = vnet.properties.subnets[0].id
output attackerSubnetId string = vnet.properties.subnets[1].id
