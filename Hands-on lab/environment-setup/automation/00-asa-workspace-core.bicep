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
