param eventHubNamespaceName string
param virtualNetworkName string
param activityLogEventHubName string
param entraLogEventHubName string
param tags object = {}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' existing = {
  name: virtualNetworkName
}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: eventHubNamespaceName
  location: resourceGroup().location
  tags: tags
  sku: {
    capacity: 2
    name: 'Standard'
    tier: 'Standard'
  }
  identity: {
    type: 'None'
  }
  properties: {
    disableLocalAuth: true
    isAutoInflateEnabled: true
    maximumThroughputUnits: 10
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource eventHubNamespaceNetworkRuleSet 'Microsoft.EventHub/namespaces/networkRuleSets@2024-01-01' = {
  name: 'default'
  parent: eventHubNamespace
  properties: {
    defaultAction: 'Deny'
    ipRules: []
    publicNetworkAccess: 'Enabled'
    trustedServiceAccessEnabled: true
    virtualNetworkRules: [
      {
        ignoreMissingVnetServiceEndpoint: true
        subnet: {
          id: virtualNetwork.properties.subnets[0].id
        }
      }
      {
        ignoreMissingVnetServiceEndpoint: true
        subnet: {
          id: virtualNetwork.properties.subnets[1].id
        }
      }
    ]
  }
}

resource activityLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  name: activityLogEventHubName
  parent: eventHubNamespace
  properties: {
    partitionCount: 8
    retentionDescription: {
      cleanupPolicy: 'Delete'
      retentionTimeInHours: 24
    }
  }
}

resource entraLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  name: entraLogEventHubName
  parent: eventHubNamespace
  properties: {
    partitionCount: 8
    retentionDescription: {
      cleanupPolicy: 'Delete'
      retentionTimeInHours: 24
    }
  }
}

resource authorizationRule 'Microsoft.EventHub/namespaces/authorizationRules@2024-01-01' = {
  name: 'cs-eventhub-monitor-auth-rule'
  parent: eventHubNamespace
  properties: {
    rights: [
      'Send'
    ]
  }
}

output eventHubNamespaceName string = eventHubNamespace.name
output eventHubNamespaceServiceBusEndpoint string = eventHubNamespace.properties.serviceBusEndpoint
