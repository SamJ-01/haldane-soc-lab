// Phase 4: detections as code.
//
// Each Sentinel analytics rule's KQL lives in detections/*.kql and is loaded
// here, so the repo is the single source of truth: change the .kql file,
// re-run scripts/deploy-detections.sh, and Sentinel is updated.

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: 'law-haldane'
}

// Approved vulnerability-scan windows, used by HAL-001 to ignore the scanner
// only while a scan is authorised.
resource scanWindows 'Microsoft.SecurityInsights/watchlists@2024-03-01' = {
  scope: workspace
  name: 'ApprovedScanWindows'
  properties: {
    displayName: 'Approved scan windows'
    description: 'Authorised credentialed vulnerability scans: account, source IP and time window.'
    provider: 'Haldane SOC'
    source: 'approved-scan-windows.csv'
    itemsSearchKey: 'ScanId'
    contentType: 'text/csv'
    numberOfLinesToSkip: 0
    rawContent: loadTextContent('../detections/watchlists/approved-scan-windows.csv')
  }
}

resource hal001 'Microsoft.SecurityInsights/alertRules@2024-03-01' = {
  scope: workspace
  dependsOn: [
    scanWindows
  ]
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

resource hal002 'Microsoft.SecurityInsights/alertRules@2024-03-01' = {
  scope: workspace
  name: guid(workspace.id, 'HAL-002')
  kind: 'Scheduled'
  properties: {
    displayName: 'HAL-002 Member added to a privileged Active Directory group'
    description: 'An account was added to Domain Admins, Administrators, Enterprise Admins or Schema Admins. These groups give full control of the domain and should change only through an approved change.'
    severity: 'High'
    enabled: true
    query: loadTextContent('../detections/HAL-002-member-added-to-privileged-group.kql')
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionEnabled: false
    suppressionDuration: 'PT1H'
    tactics: [
      'Persistence'
      'PrivilegeEscalation'
    ]
    techniques: [
      'T1098'
      'T1078'
    ]
    eventGroupingSettings: {
      aggregationKind: 'AlertPerResult'
    }
    entityMappings: [
      {
        // The account that was added to the group
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'Sid'
            columnName: 'MemberSid'
          }
        ]
      }
      {
        // The account that made the change
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'Name'
            columnName: 'AddedBy'
          }
          {
            identifier: 'NTDomain'
            columnName: 'AddedByDomain'
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
