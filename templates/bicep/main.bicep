// param suffix string
@secure()
param sqlAdministratorLoginPassword string
var tenantId = subscription().tenantId
var location = resourceGroup().location
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
      libraryRequirements: {
        filename: 'requirements.txt'
        content: 'xgboost ==1.0.2\nonnxruntime ==1.0.0\nwerkzeug ==0.16.1\nnimbusml ==1.7.1\nruamel.yaml ==0.16.9\nazureml-train-automl-runtime ==1.6.0\nscikit-learn ==0.20.3\nnumpy ==1.16.2\npandas ==0.23.4\nscipy ==1.4.1'
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
    accessPolicies: []
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
