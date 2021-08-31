@description('Please enter your Azure AD Object ID. This can be found by locating your profile within Azure Portal > Azure Active Directory > Users.')
param azureActiveDirectoryObjectID string

// Variables
var sqlAdministratorLoginPassword = 'Synapse2021!'
var tenantId = subscription().tenantId
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
    resource container1 'containers' = {
      name: 'azureml'
    }
    resource container2 'containers' = {
      name: 'staging'
    }
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
    resource container2 'containers' = {
      name: 'staging'
    }
    resource container3 'containers' = {
      name: 'wwi-02'
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
  resource bigDataPool 'bigDataPools' = {
    name: 'SparkPool01'
    location: location
    properties: {
      sparkVersion: '2.4'
      nodeCount: 0
      nodeSize: 'Small'
      nodeSizeFamily: 'MemoryOptimized'
      autoScale: {
        enabled: true
        minNodeCount: 3
        maxNodeCount: 4
      }
      autoPause: {
        enabled: true
        delayInMinutes: 15
      }
    }
  }
  resource sqlPool 'sqlPools' = {
    name: 'SQLPool01'
    location: location
    sku: {
      name: 'DW100c'
      capacity: 0
    }
    properties: {
      createMode: 'Default'
      collation: 'SQL_Latin1_General_CP1_CI_AS'
    }
  }
  resource integrationRuntime 'integrationRuntimes@2021-05-01' = {
    name: 'AzureIntegrationRuntime01'
    properties: {
      type: 'Managed'
      typeProperties: {
        computeProperties: {
          location: 'AutoResolve'
          dataFlowProperties: {
            computeType: 'MemoryOptimized'
            coreCount: 16
            timeToLive: 60
          }
        }
      }
    }
  }
}

resource updateBigDataPool 'Microsoft.Resources/deployments@2021-04-01' = {
  name: 'updateBigDataPool'
  properties: {
    mode: 'Incremental'
    templateLink: {
      uri: 'https://raw.githubusercontent.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI/master/templates/json/nested.json'
    }
    parameters: {
      synapseWorkspaceName: {
        value: synapseWorkspace.name
      }
      bigDataPoolName: {
        value: synapseWorkspace::bigDataPool.name
      }
      location: {
        value: location
      }
    }
  }
  dependsOn: [
    synapseWorkspace::bigDataPool
  ]
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: 'asakeyvault${suffix}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableSoftDelete: false
    tenantId: tenantId
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: synapseWorkspace.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
            'delete'
          ]
        }
      }
      {
        tenantId: tenantId
        objectId: azureActiveDirectoryObjectID
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
            'delete'
          ]
        }
      }
    ]
  }
  resource secret 'secrets' = {
    name: 'SQL-USER-ASA'
    properties: {
      value: sqlAdministratorLoginPassword
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'asaappinsights${suffix}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource mlWorkspace 'Microsoft.MachineLearningServices/workspaces@2021-07-01' = {
  name: 'amlworkspace${suffix}'
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'amlworkspace${suffix}'
    keyVault: keyVault.id
    applicationInsights: applicationInsights.id
    storageAccount: storageAccount.id
    hbiWorkspace: false
    allowPublicAccessWhenBehindVnet: false
  }
}

resource roleAssignment1 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('1${resourceGroupName}')
  scope: synapseStorageAccount
  properties: {
    principalId: azureActiveDirectoryObjectID
    roleDefinitionId: role['StorageBlobDataOwner']
    principalType: 'User'
  }
}

resource roleAssignment2 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('2${resourceGroupName}')
  properties: {
    principalId: synapseWorkspace.identity.principalId
    roleDefinitionId: role['StorageBlobDataContributor']
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignment3 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('3${resourceGroupName}')
  scope: synapseStorageAccount
  properties: {
    principalId: synapseWorkspace.identity.principalId
    roleDefinitionId: role['StorageBlobDataOwner']
    principalType: 'ServicePrincipal'
  }
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'postDeploymentIdentity'
  location: location
}

resource roleAssignment4 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('4${resourceGroupName}')
  scope: synapseStorageAccount
  properties: {
    principalId: userAssignedIdentity.properties.principalId
    roleDefinitionId: role['Owner']
    principalType: 'ServicePrincipal'
  }
}

resource script 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'powerShellLoadData'
  kind: 'AzurePowerShell'
  location: location
  properties: {
    azPowerShellVersion: '3.0'
    arguments: '-dataLakeAccountName ${synapseStorageAccount.name} -resourceGroupName ${resourceGroupName}'
    primaryScriptUri: 'https://raw.githubusercontent.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI/master/templates/ps1/postDeploymentScript.ps1'
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
    synapseStorageAccount
    userAssignedIdentity
    roleAssignment4
  ]
}
