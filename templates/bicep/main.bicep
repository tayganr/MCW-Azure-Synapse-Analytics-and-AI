// Variables
var sqlAdministratorLoginPassword = 'Synapse2021!'
var subscriptionId = subscription().subscriptionId
var location = resourceGroup().location
var resourceGroupName = resourceGroup().name
var suffix = substring(guid(resourceGroup().id),0,6)
var roleDefinitionPrefix = '/subscriptions/${subscriptionId}/providers/Microsoft.Authorization/roleDefinitions'
var role = {
  Owner: '${roleDefinitionPrefix}/8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
  Contributor: '${roleDefinitionPrefix}/b24988ac-6180-42a0-ab88-20f7382dd24c'
  KeyVaultAdministrator: '${roleDefinitionPrefix}/00482a5a-887f-4fb3-b363-3b7fe8e74483'
  StorageBlobDataOwner: '${roleDefinitionPrefix}/b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  StorageBlobDataContributor : '${roleDefinitionPrefix}/ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: 'asastore${suffix}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
  resource service 'blobServices' = {
    name: 'default'
  }
}

resource synapseStorageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: 'asadatalake${suffix}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    isHnsEnabled: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
  resource service 'blobServices' = {
    name: 'default'
    resource container1 'containers' = {
      name: 'defaultfs'
    }
  }
}

resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-05-01' = {
  name: 'asaworkspace${suffix}'
  location: location
  properties: {
    defaultDataLakeStorage: {
      accountUrl: reference(synapseStorageAccount.name).primaryEndpoints.dfs
      filesystem: 'defaultfs'
    }
    sqlAdministratorLogin: 'asa.sql.admin'
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
  }
  identity: {
    type: 'SystemAssigned'
  }
  resource firewall 'firewallRules' = {
    name: 'allowAll'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '255.255.255.255'
    }
  }
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'postDeploymentIdentity'
  location: location
}

resource roleAssignmentX 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('X${resourceGroupName}')
  properties: {
    principalId: userAssignedIdentity.properties.principalId
    roleDefinitionId: role['Owner']
    principalType: 'ServicePrincipal'
  }
}

resource script 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'synapseArtifacts'
  kind: 'AzurePowerShell'
  location: location
  properties: {
    azPowerShellVersion: '3.0'
    arguments: '-resourceGroupName ${resourceGroupName} -storageAccountName ${storageAccount.name} -synapseWorkspaceName ${synapseWorkspace.name}'
    primaryScriptUri: 'https://raw.githubusercontent.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI/master/templates/ps1/postDeploymentScript2.ps1'
    forceUpdateTag: guid(resourceGroup().id)
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT4H '
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  dependsOn: [
    synapseWorkspace
    storageAccount
    userAssignedIdentity
  ]
}
