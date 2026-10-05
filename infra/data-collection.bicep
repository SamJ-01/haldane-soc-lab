// Phase 2: send Windows logs from DC01 and WS01 to Sentinel.
//
// The Azure Monitor Agent (AMA) on each VM reads event logs and sends them to
// the workspace. A data collection rule (DCR) says which logs to collect:
//   Security log                    -> SecurityEvent table
//   Sysmon Operational log          -> Event table
//
// The VMs need a system-assigned managed identity first; deploy-data-collection.sh
// adds it.

@description('Azure region. Defaults to the resource group\'s region.')
param location string = resourceGroup().location

@description('VMs to collect logs from.')
param vmNames array = [
  'DC01'
  'WS01'
]

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: 'law-haldane'
}

resource vms 'Microsoft.Compute/virtualMachines@2024-03-01' existing = [for name in vmNames: {
  name: name
}]

// The agent itself, installed as a VM extension.
resource agents 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = [for (name, i) in vmNames: {
  parent: vms[i]
  name: 'AzureMonitorWindowsAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}]

// Which logs to collect, and where to send them.
resource dcr 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcr-haldane-windows'
  location: location
  kind: 'Windows'
  properties: {
    dataSources: {
      windowsEventLogs: [
        {
          name: 'security-events'
          streams: [
            'Microsoft-SecurityEvent'
          ]
          xPathQueries: [
            'Security!*'
          ]
        }
        {
          name: 'sysmon'
          streams: [
            'Microsoft-Event'
          ]
          xPathQueries: [
            'Microsoft-Windows-Sysmon/Operational!*'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'law-haldane'
          workspaceResourceId: workspace.id
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-SecurityEvent'
        ]
        destinations: [
          'law-haldane'
        ]
      }
      {
        streams: [
          'Microsoft-Event'
        ]
        destinations: [
          'law-haldane'
        ]
      }
    ]
  }
}

// Link the rule to each VM.
resource associations 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = [for (name, i) in vmNames: {
  name: 'dcra-haldane-windows'
  scope: vms[i]
  properties: {
    dataCollectionRuleId: dcr.id
  }
  dependsOn: [
    agents[i]
  ]
}]
