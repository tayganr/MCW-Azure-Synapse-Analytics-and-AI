// Variables
var sqlAdministratorLoginPassword = 'Synapse2021!'
var location = resourceGroup().location
var resourceGroupName = resourceGroup().name
var suffix = substring(guid(resourceGroup().id),0,6)

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
