targetScope = 'managementGroup'

/*
  This Bicep template creates and assigns an Azure Policy used to ensure
  that Activity Log data is forwarded to CrowdStrike for Indicator of Attack (IOA)
  assessment.

  Copyright (c) 2024 CrowdStrike, Inc.
*/

/* Parameters */
@description('The location for the resources deployed in this solution.')
param location string = deployment().location

@description('Event Hub Authorization Rule Id.')
param eventHubAuthorizationRuleId string

@description('Event Hub Name.')
param eventHubName string = 'cs-eventhub-monitor-activity-logs'

param csIOAPolicySettings object = {
  name: 'Activity Logs must be send to CrowdStrike for IOA assessment'
  policyDefinition: json(loadTextContent('./policies/cs-ioa-policy/cs-ioa-policy.json'))
  parameters: {}
  identity: true
}

/* Variables */
var roleDefinitionIds = [
  '749f88d5-cbae-40b8-bcfc-e573ddc772fa' // Monitoring Contributor
  '2a5c394f-5eb7-4d4f-9c8e-e8eae39faebc' // Lab Services Reader
  'f526a384-b230-433a-b45c-95f59c4a2dec' // Azure Event Hubs Data Owner
]

var csIOAPolicyAssignmentName = 'cs-ioa-policy-assignment'

resource csIOAPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: guid(csIOAPolicySettings.name)
  properties: {
    displayName: csIOAPolicySettings.policyDefinition.properties.displayName
    description: csIOAPolicySettings.policyDefinition.properties.description
    policyType: csIOAPolicySettings.policyDefinition.properties.policyType
    metadata: csIOAPolicySettings.policyDefinition.properties.metadata
    mode: csIOAPolicySettings.policyDefinition.properties.mode
    parameters: csIOAPolicySettings.policyDefinition.properties.parameters
    policyRule: csIOAPolicySettings.policyDefinition.properties.policyRule
  }
}

resource csIOAPolicyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: csIOAPolicyAssignmentName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    assignmentType: 'Custom'
    description: 'Ensures that Activity Log data is send to CrowdStrike for Indicator of Attack (IOA) assessment.'
    displayName: 'CrowdStrike IOA'
    enforcementMode: 'Default'
    policyDefinitionId: csIOAPolicyDefinition.id
    parameters: {
      eventHubAuthorizationRuleId: {
        value: eventHubAuthorizationRuleId
      }
      eventHubName: {
        value: eventHubName
      }
    }
  }
}

resource csIOAPolicyRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleDefinitionId in roleDefinitionIds: {
    name: guid(csIOAPolicyAssignment.id, roleDefinitionId)
    properties: {
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
      principalId: csIOAPolicyAssignment.identity.principalId
      principalType: 'ServicePrincipal'
    }
  }
]
