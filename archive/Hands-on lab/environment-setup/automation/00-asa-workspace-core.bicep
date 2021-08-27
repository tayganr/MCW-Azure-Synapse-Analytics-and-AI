@description('Suffix added to all resource name to make them unique.')
param uniqueSuffix string

@description('Password for SQL Admin')
@secure()
param sqlAdministratorLoginPassword string

var location = resourceGroup().location
var sqlAdministratorLogin = 'asa.sql.admin'
var workspaceName_var = 'asaworkspace${uniqueSuffix}'
var adlsStorageAccountName_var = 'asadatalake${uniqueSuffix}'
var defaultDataLakeStorageFilesystemName = 'defaultfs'
var sqlComputeName = 'SQLPool01'
var sparkComputeName = 'SparkPool01'
var computeSubnetId = ''
var sqlServerSKU = 'DW500c'
var storageBlobDataContributorRoleID = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var defaultDataLakeStorageAccountUrl = 'https://${adlsStorageAccountName_var}.dfs.core.windows.net'
var sparkAutoScaleEnabled = 'true'
var sparkMinNodeCount = '3'
var sparkMaxNodeCount = '4'
var sparkNodeCount = '0'
var sparkNodeSizeFamily = 'MemoryOptimized'
var sparkNodeSize = 'Small'
var sparkAutoPauseEnabled = 'true'
var sparkAutoPauseDelayInMinutes = '15'
var sparkVersion = '2.4'
var packagesRequirementsFileName = 'requirements.txt'
var packagesRequirementsContent = 'xgboost ==1.0.2\nonnxruntime ==1.0.0\nwerkzeug ==0.16.1\nnimbusml ==1.7.1\nruamel.yaml ==0.16.9\nazureml-train-automl-runtime ==1.6.0\nscikit-learn ==0.20.3\nnumpy ==1.16.2\npandas ==0.23.4\nscipy ==1.4.1'
var keyVaultName_var = 'asakeyvault${uniqueSuffix}'
var blobStorageAccountName_var = 'asastore${uniqueSuffix}'
var applicationInsightsName_var = 'asaappinsights${uniqueSuffix}'
var amlWorkspaceName_var = 'amlworkspace${uniqueSuffix}'

resource blobStorageAccountName 'Microsoft.Storage/storageAccounts@2019-04-01' = {
  name: blobStorageAccountName_var
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    supportsHttpsTrafficOnly: true
  }
}

resource blobStorageAccountName_default 'Microsoft.Storage/storageAccounts/blobServices@2019-06-01' = {
  parent: blobStorageAccountName
  name: 'default'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  properties: {
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      enabled: false
    }
  }
}

resource keyVaultName 'Microsoft.KeyVault/vaults@2018-02-14' = {
  name: keyVaultName_var
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    accessPolicies: []
  }
}

resource adlsStorageAccountName 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: adlsStorageAccountName_var
  location: location
  tags: {}
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: 'true'
    isHnsEnabled: 'true'
    largeFileSharesState: 'Disabled'
  }
  dependsOn: []
}

resource adlsStorageAccountName_default_defaultDataLakeStorageFilesystemName 'Microsoft.Storage/storageAccounts/blobServices/containers@2018-07-01' = {
  parent: adlsStorageAccountName_default
  name: defaultDataLakeStorageFilesystemName
  dependsOn: [
    adlsStorageAccountName
  ]
}

resource adlsStorageAccountName_default 'Microsoft.Storage/storageAccounts/blobServices@2019-06-01' = {
  parent: adlsStorageAccountName
  name: 'default'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  properties: {
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      enabled: false
    }
  }
}

resource Microsoft_Storage_storageAccounts_fileServices_adlsStorageAccountName_default 'Microsoft.Storage/storageAccounts/fileServices@2019-06-01' = {
  parent: adlsStorageAccountName
  name: 'default'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource workspaceName 'Microsoft.Synapse/workspaces@2019-06-01-preview' = {
  name: workspaceName_var
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    defaultDataLakeStorage: {
      accountUrl: defaultDataLakeStorageAccountUrl
      filesystem: defaultDataLakeStorageFilesystemName
    }
    virtualNetworkProfile: {
      computeSubnetId: computeSubnetId
    }
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
  }
  dependsOn: [
    adlsStorageAccountName_default_defaultDataLakeStorageFilesystemName
  ]
}

resource workspaceName_allowAll 'Microsoft.Synapse/workspaces/firewallrules@2019-06-01-preview' = {
  parent: workspaceName
  name: 'allowAll'
  location: location
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

resource adlsStorageAccountName_default_defaultDataLakeStorageFilesystemName_Microsoft_Authorization_id_storageBlobDataContributorRoleID_workspaceName 'Microsoft.Storage/storageAccounts/blobServices/containers/providers/roleAssignments@2018-09-01-preview' = {
  name: '${adlsStorageAccountName_var}/default/${defaultDataLakeStorageFilesystemName}/Microsoft.Authorization/${guid('${resourceGroup().id}/${storageBlobDataContributorRoleID}/${workspaceName_var}')}'
  location: location
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleID)
    principalId: reference('Microsoft.Synapse/workspaces/${workspaceName_var}', '2019-06-01-preview', 'Full').identity.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    workspaceName
  ]
}

resource id_storageBlobDataContributorRoleID_workspaceName_2 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: guid('${resourceGroup().id}/${storageBlobDataContributorRoleID}/${workspaceName_var}2')
  location: location
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleID)
    principalId: reference('Microsoft.Synapse/workspaces/${workspaceName_var}', '2019-06-01-preview', 'Full').identity.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    workspaceName
  ]
}

resource workspaceName_sparkComputeName 'Microsoft.Synapse/workspaces/bigDataPools@2019-06-01-preview' = {
  parent: workspaceName
  name: '${sparkComputeName}'
  location: location
  properties: {
    nodeCount: sparkNodeCount
    nodeSizeFamily: sparkNodeSizeFamily
    nodeSize: sparkNodeSize
    autoScale: {
      enabled: sparkAutoScaleEnabled
      minNodeCount: sparkMinNodeCount
      maxNodeCount: sparkMaxNodeCount
    }
    autoPause: {
      enabled: sparkAutoPauseEnabled
      delayInMinutes: sparkAutoPauseDelayInMinutes
    }
    sparkVersion: sparkVersion
  }
}

resource workspaceName_sqlComputeName 'Microsoft.Synapse/workspaces/sqlPools@2019-06-01-preview' = {
  parent: workspaceName
  name: '${sqlComputeName}'
  location: location
  sku: {
    name: sqlServerSKU
  }
  properties: {
    createMode: 'Default'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
  dependsOn: [
    workspaceName_sparkComputeName
  ]
}

module UpdateSparkPool01 './nested_UpdateSparkPool01.bicep' = {
  name: 'UpdateSparkPool01'
  params: {
    variables_workspaceName: workspaceName_var
    variables_sparkComputeName: sparkComputeName
    variables_location: location
    variables_sparkNodeCount: sparkNodeCount
    variables_sparkNodeSizeFamily: sparkNodeSizeFamily
    variables_sparkNodeSize: sparkNodeSize
    variables_sparkAutoScaleEnabled: sparkAutoScaleEnabled
    variables_sparkMinNodeCount: sparkMinNodeCount
    variables_sparkMaxNodeCount: sparkMaxNodeCount
    variables_sparkAutoPauseEnabled: sparkAutoPauseEnabled
    variables_sparkAutoPauseDelayInMinutes: sparkAutoPauseDelayInMinutes
    variables_sparkVersion: sparkVersion
    variables_packagesRequirementsFileName: packagesRequirementsFileName
    variables_packagesRequirementsContent: packagesRequirementsContent
  }
  dependsOn: [
    workspaceName_sparkComputeName
  ]
}

resource applicationInsightsName 'Microsoft.Insights/components@2018-05-01-preview' = {
  name: applicationInsightsName_var
  location: (((location == 'eastus2') || (location == 'westcentralus')) ? 'southcentralus' : location)
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource amlWorkspaceName 'Microsoft.MachineLearningServices/workspaces@2020-03-01' = {
  name: amlWorkspaceName_var
  location: location
  sku: {
    tier: 'Enterprise'
    name: 'Enterprise'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: amlWorkspaceName_var
    keyVault: keyVaultName.id
    applicationInsights: applicationInsightsName.id
    storageAccount: blobStorageAccountName.id
    hbiWorkspace: false
    allowPublicAccessWhenBehindVnet: false
  }
}

resource adlsStorageAccountName_default_staging 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  parent: adlsStorageAccountName_default
  name: 'staging'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    adlsStorageAccountName
  ]
}

resource adlsStorageAccountName_default_wwi_02 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  parent: adlsStorageAccountName_default
  name: 'wwi-02'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    adlsStorageAccountName
  ]
}

resource blobStorageAccountName_default_staging 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  parent: blobStorageAccountName_default
  name: 'staging'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    blobStorageAccountName
  ]
}

resource blobStorageAccountName_default_azureml 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  parent: blobStorageAccountName_default
  name: 'azureml'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    blobStorageAccountName
  ]
}