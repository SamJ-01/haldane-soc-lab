// Phase 2: the SIEM.
//
// A Log Analytics workspace (where every log is stored and queried with KQL)
// with Microsoft Sentinel switched on for it. A daily cap stops runaway log
// ingestion from ever producing a surprise bill.

@description('Azure region. Defaults to the resource group\'s region.')
param location string = resourceGroup().location

@description('Most data (GB) the workspace will accept per day. Ingestion pauses until the next day if reached.')
param dailyCapGb int = 1

@description('How many days logs are kept. 30 days is included at no extra cost with Sentinel.')
param retentionDays int = 30

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-haldane'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionDays
    workspaceCapping: {
      dailyQuotaGb: dailyCapGb
    }
  }
}

// Turning Sentinel on is done by "onboarding" the workspace.
resource sentinel 'Microsoft.SecurityInsights/onboardingStates@2024-03-01' = {
  scope: workspace
  name: 'default'
  properties: {}
}

output workspaceName string = workspace.name
output workspaceId string = workspace.id
