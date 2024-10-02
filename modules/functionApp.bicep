param location string = resourceGroup().location
param hostingPlanName string
param functionAppName string
param userAssignedIdentityId string
param packageURL string
param storageAccountName string
param eventHubNamespaceName string
param eventHubName string
param virtualNetworkName string
param virtualNetworkSubnetId string
param csCID string
param csClientIdUri string
param csClientSecretUri string
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource hostingPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: hostingPlanName
  location: location
  tags: tags
  sku: {
    name: 'S1'
    tier: 'Standard'
  }
  kind: 'Linux'
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2020-12-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    clientCertEnabled: true
    enabled: true
    httpsOnly: true
    serverFarmId: hostingPlan.id
    siteConfig: {
      alwaysOn: true
      appSettings: [
        {
          name:'PYTHON_THREADPOOL_THREAD_COUNT' 
          value: '2'
        }
        {
          name: 'FUNCTIONS_WORKER_PROCESS_COUNT'
          value: '1'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME_VERSION'
          value: '3.9'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: packageURL
        }
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: storageAccount.properties.primaryEndpoints.blob
        }
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccount.name
        }
        {
          name: 'AzureEventHubConnectionString__fullyQualifiedNamespace'
          value: '${eventHubNamespaceName}.servicebus.windows.net'
        }
        {
          name: 'AzureStorageAccount'
          value: storageAccount.name
        }
        {
          name: 'EventHubName'
          value: eventHubName
        }
        {
          name: 'CS_CLIENT_ID'
          value: '@Microsoft.KeyVault(SecretUri=${csClientIdUri})'
        }
        {
          name: 'CS_CLIENT_SECRET'
          value: '@Microsoft.KeyVault(SecretUri=${csClientSecretUri})'
        }
        {
          name: 'CS_AUTH_MODE'
          value: 'direct_auth'
        }
        {
          name: 'CS_CID'
          value: csCID
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1'
        }
      ]
      ftpsState: 'Disabled'
      http20Enabled: true
      ipSecurityRestrictions: [
        {
          action: 'Deny'
          ipAddress: '0.0.0.0/0'
          name: 'Deny all'
          priority: 0
        }
      ]
      linuxFxVersion: 'PYTHON|3.9'
      minTlsVersion: '1.2'
      pythonVersion: '3.9'
      scmIpSecurityRestrictionsUseMain: true
      use32BitWorkerProcess: false
      vnetName: virtualNetworkName
    }
    storageAccountRequired: true
    virtualNetworkSubnetId: virtualNetworkSubnetId
  }
}
