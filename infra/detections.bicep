// Phase 4: detections as code.
//
// Each Sentinel analytics rule's KQL lives in detections/*.kql and is loaded
// here, so the repo is the single source of truth: change the .kql file,
// re-run scripts/deploy-detections.sh, and Sentinel is updated.

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: 'law-haldane'
}

resource hal001 'Microsoft.SecurityInsights/alertRules@2024-03-01' = {
  scope: workspace
  name: guid(workspace.id, 'HAL-001')
  kind: 'Scheduled'
  properties: {
    displayName: 'HAL-001 Privileged account network logon from outside the corporate subnet'
    description: 'A privileged account (Domain Admin or equivalent) signed in over the network from an address outside the corporate subnet 10.10.1.0/24. Expected only for the approved vulnerability scanner (svc-nessus from 10.10.2.4) during a scan window.'
    severity: 'High'
    enabled: true
    query: loadTextContent('../detections/HAL-001-privileged-logon-from-outside-corp.kql')
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionEnabled: false
    suppressionDuration: 'PT1H'
    tactics: [
      'InitialAccess'
      'LateralMovement'
    ]
    techniques: [
      'T1078'
      'T1021'
    ]
    eventGroupingSettings: {
      aggregationKind: 'AlertPerResult'
    }
    entityMappings: [
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'Name'
            columnName: 'TargetUserName'
          }
        ]
      }
      {
        entityType: 'IP'
        fieldMappings: [
          {
            identifier: 'Address'
            columnName: 'IpAddress'
          }
        ]
      }
      {
        entityType: 'Host'
        fieldMappings: [
          {
            identifier: 'FullName'
            columnName: 'Computer'
          }
        ]
      }
    ]
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
      }
    }
  }
}
