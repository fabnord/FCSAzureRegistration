targetScope = 'subscription'

/* Parameter */
@description('The location for the resources deployed in this solution.')
param location string = deployment().location

@description('The suffix to be added to the deployment name.')
param deploymentNamePrefix string = 'cs-ioa'

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = utcNow()

@description('The name of the resource group.')
param resourceGroupName string = 'cs-ioa-group'

@description('Tags to be applied to all resources.')
param tags object = {
  'cstag-vendor': 'crowdstrike'
  'cstag-product': 'fcs'
  'cstag-purpose': 'ioa'
}

@description('The CID for the Falcon API.')
param falconCID string

@description('The client ID for the Falcon API.')
param falconClientId string

@description('The client secret for the Falcon API.')
@secure()
param falconClientSecret string

param randomSuffix string = uniqueString(resourceGroupName, subscription().subscriptionId)

/* Parameterbag for CS Logs */
param csLogSettings object = {
  storageAccountName: substring('cshorizonlogs${randomSuffix}', 0, 24)
  storageAccountIdentityName: substring('cshorizonlogs${randomSuffix}', 0, 24)
  storagePrivateEndpointName: 'log-storage-private-endpoint'
  storagePrivateEndpointConnectionName: 'cs-log-storage-private-endpoint'
}

/* Parameterbag for Activity Logs */
param activityLogSettings object = {
  hostingPlanName: 'cs-activity-service-plan'
  functionAppName: 'cs-activity-func-${subscription().subscriptionId}'
  functionAppIdentityName: 'cs-activity-func-${subscription().subscriptionId}'
  ioaPackageURL: 'https://cs-prod-cloudconnect-templates.s3-us-west-1.amazonaws.com/azure/4.x/ioa.zip'
  storageAccountName: substring('cshorizonact${randomSuffix}', 0, 24)
  storageAccountIdentityName: substring('cshorizonact${randomSuffix}', 0, 24)
  storagePrivateEndpointName: 'activity-storage-private-endpoint'
  storagePrivateEndpointConnectionName: 'cs-activity-storage-private-endpoint'
  eventHubName: 'cs-eventhub-monitor-activity-logs'
}

/* Parameterbag for EntraId Logs */
param entraLogSettings object = {
  hostingPlanName: 'cs-aad-service-plan'
  functionAppName: 'cs-aad-func-${subscription().subscriptionId}'
  functionAppIdentityName: 'cs-aad-func-${subscription().subscriptionId}'
  ioaPackageURL: 'https://cs-prod-cloudconnect-templates.s3-us-west-1.amazonaws.com/azure/4.x/ioa.zip'
  storageAccountName: substring('cshorizonaad${randomSuffix}', 0, 24)
  storageAccountIdentityName: substring('cshorizonaad${randomSuffix}', 0, 24)
  storagePrivateEndpointName: 'aad-storage-private-endpoint'
  storagePrivateEndpointConnectionName: 'cs-aad-storage-private-endpoint'
  eventHubName: 'cs-eventhub-monitor-aad-logs'
}

/* Variables */
var eventHubNamespaceName = 'cs-horizon-ns-${subscription().subscriptionId}'
var keyVaultName = 'cs-kv-${randomSuffix}'
var virtualNetworkName = 'cs-vnet'
var scope = az.resourceGroup(resourceGroup.name)

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// Create Virtual Network for secure communication of services
module virtualNetwork 'modules/virtualNetwork.bicep' = {
  name: '${deploymentNamePrefix}-virtualNetwork-${deploymentNameSuffix}'
  scope: scope
  params: {
    virtualNetworkName: virtualNetworkName
    tags: tags
  }
}

// Create EventHub Namespace and Eventhubs used by CrowdStrike
module eventHub 'modules/eventHub.bicep' = {
  name: '${deploymentNamePrefix}-eventHubs-${deploymentNameSuffix}'
  scope: scope
  params: {
    eventHubNamespaceName: eventHubNamespaceName
    activityLogEventHubName: activityLogSettings.eventHubName
    entraLogEventHubName: entraLogSettings.eventHubName
    virtualNetworkName: virtualNetwork.outputs.virtualNetworkName
    tags: tags
  }
}

// Create KeyVault and secrets
module keyVault 'modules/keyVault.bicep' = {
  name: '${deploymentNamePrefix}-keyVault-${deploymentNameSuffix}'
  scope: scope
  params: {
    keyVaultName: keyVaultName
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    virtualNetworkName: virtualNetwork.outputs.virtualNetworkName
    tags: tags
  }
}

/* General CS Log Storage */
module csLogStorage 'modules/storageAccount.bicep' = {
  scope: scope
  name: '${deploymentNamePrefix}-csLogStorage-${deploymentNameSuffix}'
  params: {
    userAssignedIdentityName: csLogSettings.storageAccountIdentityName
    storageAccountName: csLogSettings.storageAccountName
    keyVaultName: keyVault.outputs.keyVaultName
    storageAccountSubnetId: virtualNetwork.outputs.csSubnet1Id
    storagePrivateEndpointName: csLogSettings.storagePrivateEndpointName
    storagePrivateEndpointConnectionName: csLogSettings.storagePrivateEndpointConnectionName
    storagePrivateEndpointSubnetId: virtualNetwork.outputs.csSubnet3Id
    tags: tags
  }
}

module csLogStorageEncryption 'modules/enableEncryption.bicep' = {
  name: '${deploymentNamePrefix}-csLogStorageEncryption-${deploymentNameSuffix}'
  scope: scope
  params: {
    userAssignedIdentity: csLogStorage.outputs.userAssignedIdentityId
    storageAccountName: csLogStorage.outputs.storageAccountName
    keyName: keyVault.outputs.csLogStorageKeyName
    keyVaultUri: keyVault.outputs.keyVaultUri
  }
}

/* Activity Log Storage */
module activityLogStorage 'modules/storageAccount.bicep' = {
  scope: scope
  name: '${deploymentNamePrefix}-activityLogStorage-${deploymentNameSuffix}'
  params: {
    userAssignedIdentityName: activityLogSettings.storageAccountIdentityName
    storageAccountName: activityLogSettings.storageAccountName
    keyVaultName: keyVault.outputs.keyVaultName
    storageAccountSubnetId: virtualNetwork.outputs.csSubnet1Id
    storagePrivateEndpointName: activityLogSettings.storagePrivateEndpointName
    storagePrivateEndpointConnectionName: activityLogSettings.storagePrivateEndpointConnectionName
    storagePrivateEndpointSubnetId: virtualNetwork.outputs.csSubnet3Id
    tags: tags
  }
}

module activityLogStorageEncryption 'modules/enableEncryption.bicep' = {
  name: '${deploymentNamePrefix}-activityLogStorageEncryption-${deploymentNameSuffix}'
  scope: scope
  params: {
    userAssignedIdentity: activityLogStorage.outputs.userAssignedIdentityId
    storageAccountName: activityLogStorage.outputs.storageAccountName
    keyName: keyVault.outputs.activityLogStorageKeyName
    keyVaultUri: keyVault.outputs.keyVaultUri
    tags: tags
  }
}

/* EntraId Log Storage */
module entraLogStorage 'modules/storageAccount.bicep' = {
  scope: scope
  name: '${deploymentNamePrefix}-entraLogStorage-${deploymentNameSuffix}'
  params: {
    userAssignedIdentityName: entraLogSettings.storageAccountIdentityName
    storageAccountName: entraLogSettings.storageAccountName
    keyVaultName: keyVault.outputs.keyVaultName
    storageAccountSubnetId: virtualNetwork.outputs.csSubnet2Id
    storagePrivateEndpointName: entraLogSettings.storagePrivateEndpointName
    storagePrivateEndpointConnectionName: entraLogSettings.storagePrivateEndpointConnectionName
    storagePrivateEndpointSubnetId: virtualNetwork.outputs.csSubnet3Id
    tags: tags
  }
}

module entraLogStorageEncryption 'modules/enableEncryption.bicep' = {
  name: '${deploymentNamePrefix}-entraLogStorageEncryption-${deploymentNameSuffix}'
  scope: scope
  params: {
    userAssignedIdentity: entraLogStorage.outputs.userAssignedIdentityId
    storageAccountName: entraLogStorage.outputs.storageAccountName
    keyName: keyVault.outputs.activityLogStorageKeyName
    keyVaultUri: keyVault.outputs.keyVaultUri
    tags: tags
  }
}

/* Activity Log Function Deployment */
module activityLogFunctionIdentity 'modules/functionIdentity.bicep' = {
  name: '${deploymentNamePrefix}-activityLogFunctionIdentity-${deploymentNameSuffix}'
  scope: scope
  params: {
    functionAppIdentityName: activityLogSettings.functionAppIdentityName
    keyVaultName: keyVault.outputs.keyVaultName
    storageAccountName: activityLogSettings.storageAccountName
    eventHubNamespaceName: eventHub.outputs.eventHubNamespaceName
    tags: tags
  }
  dependsOn: [
    activityLogStorage
    activityLogStorageEncryption
  ]
}

module activityLogFunction 'modules/functionApp.bicep' = {
  name: '${deploymentNamePrefix}-activityLogFunction-${deploymentNameSuffix}'
  scope: scope
  params: {
    hostingPlanName: activityLogSettings.hostingPlanName
    functionAppName: activityLogSettings.functionAppName
    userAssignedIdentityId: activityLogFunctionIdentity.outputs.functionIdentityId
    packageURL: activityLogSettings.ioaPackageURL
    storageAccountName: activityLogSettings.storageAccountName
    eventHubNamespaceName: eventHub.outputs.eventHubNamespaceName
    eventHubName: activityLogSettings.eventHubName
    virtualNetworkName: virtualNetwork.outputs.virtualNetworkName
    virtualNetworkSubnetId: virtualNetwork.outputs.csSubnet1Id
    csCID: falconCID
    csClientIdUri: keyVault.outputs.csClientIdUri
    csClientSecretUri: keyVault.outputs.csClientSecretUri
    tags: tags
  }
  dependsOn: [
    activityLogStorage
    activityLogStorageEncryption
    activityLogFunctionIdentity
  ]
}

/* EntraId Log Function Deployment */
module entraLogFunctionIdentity 'modules/functionIdentity.bicep' = {
  name: '${deploymentNamePrefix}-entraLogFunctionIdentity-${deploymentNameSuffix}'
  scope: scope
  params: {
    functionAppIdentityName: entraLogSettings.functionAppIdentityName
    keyVaultName: keyVault.outputs.keyVaultName
    storageAccountName: entraLogSettings.storageAccountName
    eventHubNamespaceName: eventHub.outputs.eventHubNamespaceName
    tags: tags
  }
  dependsOn: [
    entraLogStorage
    entraLogStorageEncryption
  ]
}

module entraLogFunction 'modules/functionApp.bicep' = {
  name: '${deploymentNamePrefix}-entraLogFunction-${deploymentNameSuffix}'
  scope: scope
  params: {
    hostingPlanName: entraLogSettings.hostingPlanName
    functionAppName: entraLogSettings.functionAppName
    userAssignedIdentityId: entraLogFunctionIdentity.outputs.functionIdentityId
    packageURL: entraLogSettings.ioaPackageURL
    storageAccountName: entraLogSettings.storageAccountName
    eventHubNamespaceName: eventHub.outputs.eventHubNamespaceName
    eventHubName: entraLogSettings.eventHubName
    virtualNetworkName: virtualNetwork.outputs.virtualNetworkName
    virtualNetworkSubnetId: virtualNetwork.outputs.csSubnet2Id
    csCID: falconCID
    csClientIdUri: keyVault.outputs.csClientIdUri
    csClientSecretUri: keyVault.outputs.csClientSecretUri
    tags: tags
  }
  dependsOn: [
    entraLogStorage
    entraLogStorageEncryption
    entraLogFunctionIdentity
  ]
}
/*
resource keyVaultDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'cs-kv-to-storage'
  scope: keyVault
  properties: {
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    storageAccountId: logStorageAccount.id
  }
}
*/
