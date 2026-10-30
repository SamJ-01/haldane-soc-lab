// Phase 5: approval-gated response playbook.
//
// When HAL-004 (many failed logons followed by a success) raises an incident,
// a Sentinel automation rule runs this Logic App. It:
//   1. reads the account from the incident,
//   2. emails the analyst an Approve / Reject request,
//   3. only on Approve, disables that account on DC01 (Azure Run Command,
//      using the Logic App's own managed identity, no stored passwords),
//   4. writes what happened back to the incident as a comment.
//
// Safety: nothing is disabled without a human clicking Approve; protected
// accounts are refused; the account name reaches PowerShell base64-encoded so
// it cannot break out of the script.

param location string = resourceGroup().location

@description('Email address that receives the approval request.')
param approverEmail string

@description('Object ID of the "Azure Security Insights" service principal, which needs permission to run playbooks from automation rules (looked up by scripts/deploy-playbook.sh).')
param securityInsightsPrincipalId string

@description('Domain controller that the disable command runs on.')
param domainControllerName string = 'DC01'

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: 'law-haldane'
}

resource dc 'Microsoft.Compute/virtualMachines@2024-03-01' existing = {
  name: domainControllerName
}

// Sentinel connector, authenticated with the Logic App's managed identity.
resource sentinelConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'azuresentinel-haldane'
  location: location
  properties: {
    displayName: 'Microsoft Sentinel (managed identity)'
    #disable-next-line BCP037
    parameterValueType: 'Alternative'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azuresentinel')
    }
  }
}

// Outlook.com connector for the approval email. It has to be signed in once
// in the portal after the first deployment (API connection > Authorize).
resource outlookConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'outlook-haldane'
  location: location
  properties: {
    displayName: 'Outlook.com (approval email)'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'outlook')
    }
  }
}

var runCommandUri = '${environment().resourceManager}${substring(dc.id, 1)}/runCommand?api-version=2024-03-01'

resource playbook 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'pb-hal-disable-account'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    parameters: {
      '$connections': {
        value: {
          azuresentinel: {
            connectionId: sentinelConnection.id
            connectionName: sentinelConnection.name
            id: sentinelConnection.properties.api.id
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
          }
          outlook: {
            connectionId: outlookConnection.id
            connectionName: outlookConnection.name
            id: outlookConnection.properties.api.id
          }
        }
      }
    }
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          type: 'Object'
          defaultValue: {}
        }
      }
      triggers: {
        Microsoft_Sentinel_incident: {
          type: 'ApiConnectionWebhook'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azuresentinel\'][\'connectionId\']'
              }
            }
            body: {
              callback_url: '@{listCallbackUrl()}'
            }
            path: '/incident-creation'
          }
        }
      }
      actions: {
        Get_accounts: {
          type: 'ApiConnection'
          runAfter: {}
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azuresentinel\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/entities/account'
            body: '@triggerBody()?[\'object\']?[\'properties\']?[\'relatedEntities\']'
          }
        }
        Account_name: {
          type: 'InitializeVariable'
          runAfter: {
            Get_accounts: [
              'Succeeded'
            ]
          }
          inputs: {
            variables: [
              {
                name: 'AccountName'
                type: 'string'
                value: '@{toLower(coalesce(first(body(\'Get_accounts\')?[\'Accounts\'])?[\'Name\'], \'\'))}'
              }
            ]
          }
        }
        Ask_for_approval: {
          type: 'ApiConnectionWebhook'
          runAfter: {
            Account_name: [
              'Succeeded'
            ]
          }
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'outlook\'][\'connectionId\']'
              }
            }
            path: '/approvalmail/$subscriptions'
            body: {
              NotificationUrl: '@{listCallbackUrl()}'
              Message: {
                To: approverEmail
                Subject: 'Haldane SOC: disable account @{variables(\'AccountName\')}?'
                Options: 'Approve, Reject'
                Importance: 'High'
                Body: 'Defender incident @{coalesce(triggerBody()?[\'object\']?[\'properties\']?[\'providerIncidentId\'], \'(not synced yet)\')} (Sentinel incident @{triggerBody()?[\'object\']?[\'properties\']?[\'incidentNumber\']}): @{triggerBody()?[\'object\']?[\'properties\']?[\'title\']}\n\nAccount: @{variables(\'AccountName\')}\n\nApprove to disable this account in Active Directory on ${domainControllerName}. Reject to take no action.\n\nIncident: @{triggerBody()?[\'object\']?[\'properties\']?[\'incidentUrl\']}'
              }
            }
          }
        }
        If_approved: {
          type: 'If'
          runAfter: {
            Ask_for_approval: [
              'Succeeded'
            ]
          }
          expression: {
            and: [
              {
                equals: [
                  '@body(\'Ask_for_approval\')?[\'SelectedOption\']'
                  'Approve'
                ]
              }
            ]
          }
          actions: {
            Disable_account_on_DC: {
              type: 'Http'
              inputs: {
                method: 'POST'
                uri: runCommandUri
                authentication: {
                  type: 'ManagedServiceIdentity'
                  audience: environment().resourceManager
                }
                body: {
                  commandId: 'RunPowerShellScript'
                  script: [
                    '$n = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(\'@{base64(variables(\'AccountName\'))}\'))'
                    'if ($n -notmatch \'^[a-z0-9._-]{1,20}$\') { throw "Refused: unexpected account name" }'
                    'if (\'haldaneadmin\', \'administrator\', \'krbtgt\' -contains $n) { throw "Refused: $n is a protected account" }'
                    'Disable-ADAccount -Identity $n'
                    'Get-ADUser -Identity $n | Select-Object SamAccountName, Enabled | Format-List | Out-String'
                  ]
                }
              }
            }
            Comment_disabled: {
              type: 'ApiConnection'
              runAfter: {
                Disable_account_on_DC: [
                  'Succeeded'
                  'Failed'
                ]
              }
              inputs: {
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'azuresentinel\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '/Incidents/Comment'
                body: {
                  incidentArmId: '@triggerBody()?[\'object\']?[\'id\']'
                  message: '<p>Playbook pb-hal-disable-account: analyst <b>approved</b> disabling <b>@{variables(\'AccountName\')}</b> on ${domainControllerName}.</p><p>Run Command result (@{actions(\'Disable_account_on_DC\')?[\'status\']}):</p><pre>@{coalesce(body(\'Disable_account_on_DC\')?[\'value\']?[0]?[\'message\'], string(body(\'Disable_account_on_DC\')))}</pre>'
                }
              }
            }
          }
          else: {
            actions: {
              Comment_rejected: {
                type: 'ApiConnection'
                inputs: {
                  host: {
                    connection: {
                      name: '@parameters(\'$connections\')[\'azuresentinel\'][\'connectionId\']'
                    }
                  }
                  method: 'post'
                  path: '/Incidents/Comment'
                  body: {
                    incidentArmId: '@triggerBody()?[\'object\']?[\'id\']'
                    message: '<p>Playbook pb-hal-disable-account: analyst <b>rejected</b> disabling <b>@{variables(\'AccountName\')}</b>. No action taken.</p>'
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

// The playbook's identity may comment on incidents ...
var sentinelResponderRoleId = '3e150937-b8fe-4cfb-8069-0eaf05ecd056'
resource responderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: workspace
  name: guid(workspace.id, playbook.id, sentinelResponderRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', sentinelResponderRoleId)
    principalId: playbook.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ... and run commands on the domain controller, and nothing else.
var vmContributorRoleId = '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
resource dcRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: dc
  name: guid(dc.id, playbook.id, vmContributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmContributorRoleId)
    principalId: playbook.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Sentinel itself must be allowed to start playbooks in this resource group.
var automationContributorRoleId = 'f4c81013-99ee-4d62-a7ee-b3f1f648599a'
resource sentinelRunsPlaybooks 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, securityInsightsPrincipalId, automationContributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', automationContributorRoleId)
    principalId: securityInsightsPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Run the playbook automatically when HAL-004 raises an incident.
resource automationRule 'Microsoft.SecurityInsights/automationRules@2024-03-01' = {
  scope: workspace
  dependsOn: [
    sentinelRunsPlaybooks
  ]
  name: guid(workspace.id, 'AUTO-HAL-004-disable-account')
  properties: {
    displayName: 'HAL-004: ask to disable the account'
    order: 1
    triggeringLogic: {
      isEnabled: true
      triggersOn: 'Incidents'
      triggersWhen: 'Created'
      conditions: [
        {
          conditionType: 'Property'
          conditionProperties: {
            propertyName: 'IncidentRelatedAnalyticRuleIds'
            operator: 'Contains'
            propertyValues: [
              extensionResourceId(workspace.id, 'Microsoft.SecurityInsights/alertRules', guid(workspace.id, 'HAL-004'))
            ]
          }
        }
      ]
    }
    actions: [
      {
        order: 1
        actionType: 'RunPlaybook'
        actionConfiguration: {
          logicAppResourceId: playbook.id
          tenantId: subscription().tenantId
        }
      }
    ]
  }
}

output playbookName string = playbook.name
output outlookConnectionName string = outlookConnection.name
