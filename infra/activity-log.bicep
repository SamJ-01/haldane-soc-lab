// Phase 2: send the subscription's Azure Activity log to Sentinel.
// The Activity log records every management action in Azure: who created,
// changed, started, stopped or deleted what, and when (AzureActivity table).
targetScope = 'subscription'

@description('Resource ID of the law-haldane workspace.')
param workspaceId string

resource activityToWorkspace 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'activity-to-law-haldane'
  properties: {
    workspaceId: workspaceId
    logs: [for category in [
      'Administrative'
      'Security'
      'Policy'
      'Alert'
    ]: {
      category: category
      enabled: true
    }]
  }
}
