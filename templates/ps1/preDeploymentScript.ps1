function getUserPrincipalId() {
    $principalId = $null
    Do {
        $emailAddress = Read-Host -Prompt "Please enter your Azure AD email address"
        $principalId = (Get-AzAdUser -Mail $emailAddress).id
        if ($null -eq $principalId) { $principalId = (Get-AzAdUser -UserPrincipalName $emailAddress).Id } 
        if ($null -eq $principalId) { Write-Host "Unable to find a user within the Azure AD with email address: ${emailAddress}. Please try again." }
    } until($null -ne $principalId)
    Return $principalId
}
function deployTemplate([string]$accessToken, [string]$templateLink, [string]$resourceGroupName, [hashtable]$parameters) {
    $randomId = -join ((65..90) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_})
    $deploymentName = "deployment-${randomId}"
    $scope = "/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}"
    $deploymentUri = "https://management.azure.com${scope}/providers/Microsoft.Resources/deployments/${deploymentName}?api-version=2021-04-01"
    $deploymentBody = @{
        "properties" = @{
            "templateLink" = @{
                "uri" = $templateLink
            }
            "parameters" = $parameters
            "mode" = "Incremental"
        }
    }
    $params = @{
        ContentType = "application/json"
        Headers = @{"Authorization"="Bearer ${accessToken}"}
        Body = ($deploymentBody | ConvertTo-Json -Depth 9)
        Method = "PUT"
        URI = $deploymentUri
    }
    $job = Invoke-RestMethod @params
    Return $job
}
function getDeployment([string]$accessToken, [string]$subscriptionId, [string]$resourceGroupName, [string]$deploymentName) {
    $params = @{
        ContentType = "application/json"
        Headers = @{"Authorization"="Bearer ${accessToken}"}
        Method = "GET"
        URI = "https://management.azure.com/subscriptions/${subscriptionId}/resourcegroups/${resourceGroupName}/providers/Microsoft.Resources/deployments/${deploymentName}?api-version=2021-04-01"
    }
    $response = Invoke-RestMethod @params
    Return $response
}

# Variables
$tenantId = (Get-AzContext).Tenant.Id
$subscriptionId = (Get-AzContext).Subscription.Id
Clear-Host
$principalId = getUserPrincipalId
$suffix = -join ((48..57) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_})
$location = 'uksouth'

# Create Resource Group
$resourceGroup = New-AzResourceGroup -Name "synapse-rg-${suffix}" -Location $location
$resourceGroupName = $resourceGroup.ResourceGroupName

# Main Deployment
$accessToken = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token
$templateLink = "https://raw.githubusercontent.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI/master/templates/json/main.json" 
$parameters = @{ azureActiveDirectoryObjectID = @{ value = $principalId } }
$deployment = deployTemplate $accessToken $templateLink $resourceGroupName $parameters
$deploymentName = $deployment.name
$progress = ('.', '..', '...')
$provisioningState = ""
While ($provisioningState -ne "Succeeded") {
    Foreach ($x in $progress) {
        Clear-Host
        Write-Host "Deployment is in progress, this will take approximately 10 minutes"
        Write-Host "Running${x}"
        Start-Sleep 1
    }
    $provisioningState = (getDeployment $accessToken $subscriptionId $resourceGroupName $deploymentName).properties.provisioningState
}

# Get Outputs
$deployment = (getDeployment $accessToken $subscriptionId $resourceGroupName $deploymentName)
$synapseWorkspaceName = $deployment.Properties.Outputs.synapseWorkspaceName.Value
$storageAccountName = $deployment.Properties.Outputs.storageAccountName.Value
$dataLakeAccountName = $deployment.Properties.Outputs.dataLakeAccountName.Value
$keyVaultName = $deployment.Properties.Outputs.keyVaultName.Value
$sqlPoolName = $deployment.Properties.Outputs.sqlPoolName.Value
$sqlAdminName = $deployment.Properties.Outputs.sqlAdminName.Value
$keyVaultSecretName = $deployment.Properties.Outputs.keyVaultSecretName.Value

# Synapse
Install-Module Az.Synapse -Force
# Linked Service #1 - Storage Account
$storageAccountKey1 = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $storageAccountName)[0].Value
$linkedService1 = @{
    name = "${storageAccountName}"
    type = "Microsoft.Synapse/workspaces/linkedservices"
    properties = @{
        type = "AzureBlobStorage"
        typeProperties = @{
            connectionString = "DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountKey1};EndpointSuffix=core.windows.net;"
        }
    }
}
ConvertTo-Json $linkedService1  | Out-File ls1.json
Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspaceName -Name $storageAccountName -DefinitionFile "ls1.json"

# Linked Service #2 - Data Lake
$storageAccountKey2 = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $dataLakeAccountName)[0].Value
$linkedService2 = @{
    name = "${dataLakeAccountName}"
    properties =  @{
        type = "AzureBlobFS"
        typeProperties =  @{
            url = "https://${dataLakeAccountName}.dfs.core.windows.net"
            accountKey =  @{
                type =  "SecureString"
                value = "${storageAccountKey2}"
            }
        }
    }
}
ConvertTo-Json $linkedService2  | Out-File ls2.json
Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspaceName -Name $storageAccountName -DefinitionFile "ls2.json"

# Linked Service #3 - Key Vault
$linkedService3 = @{
    name = "${keyVaultName}"
    type = "Microsoft.Synapse/workspaces/linkedservices"
    properties = {
        type = "AzureKeyVault"
        typeProperties = {
            baseUrl = "https://${keyVaultName}.vault.azure.net/"
        }
    }
}
ConvertTo-Json $linkedService3  | Out-File ls3.json
Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspaceName -Name $storageAccountName -DefinitionFile "ls3.json"

# Linked Service #4 - SQL DWH
$linkedService4 = @{
    name = "${sqlPoolName}"
    properties = {
        type = "AzureSqlDW"
        typeProperties = {
            connectionString = "Integrated Security=False;Encrypt=True;Connection Timeout=30;Data Source=${synapseWorkspaceName}.sql.azuresynapse.net;Initial Catalog=${sqlPoolName};User ID=${sqlAdminName}"
            password = {
                type = "AzureKeyVaultSecret"
                store = { 
                    referenceName = "${keyVaultName}"
                    type = "LinkedServiceReference"
                },
                secretName = "${keyVaultSecretName}"
            }
        }
    }
}
ConvertTo-Json $linkedService4  | Out-File ls4.json
Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspaceName -Name $storageAccountName -DefinitionFile "ls4.json"

# Linked Service #5 - SQL DWH Workload 01
$linkedService5 = @{
    name = "${sqlPoolName}_workload01"
    properties = {
        type = "AzureSqlDW"
        typeProperties = {
            connectionString = "Integrated Security=False;Encrypt=True;Connection Timeout=30;Data Source=${synapseWorkspaceName}.sql.azuresynapse.net;Initial Catalog=${sqlPoolName};User ID=asa.sql.workload01"
            password = {
                type = "AzureKeyVaultSecret"
                store = { 
                    referenceName = "${keyVaultName}"
                    type = "LinkedServiceReference"
                },
                secretName = "${keyVaultSecretName}"
            }
        }
    }
}
ConvertTo-Json $linkedService5  | Out-File ls5.json
Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspaceName -Name $storageAccountName -DefinitionFile "ls5.json"

# Linked Service #6 - SQL DWH Workload 01
$linkedService6 = @{
    name = "${sqlPoolName}_workload02"
    properties = {
        type = "AzureSqlDW"
        typeProperties = {
            connectionString = "Integrated Security=False;Encrypt=True;Connection Timeout=30;Data Source=${synapseWorkspaceName}.sql.azuresynapse.net;Initial Catalog=${sqlPoolName};User ID=asa.sql.workload02"
            password = {
                type = "AzureKeyVaultSecret"
                store = { 
                    referenceName = "${keyVaultName}"
                    type = "LinkedServiceReference"
                },
                secretName = "${keyVaultSecretName}"
            }
        }
    }
}
ConvertTo-Json $linkedService6  | Out-File ls6.json
Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspaceName -Name $storageAccountName -DefinitionFile "ls6.json"