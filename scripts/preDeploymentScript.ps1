$timer = [System.Diagnostics.Stopwatch]::StartNew()
if(!(Test-Path -Path "MCW" )){
    New-Item "MCW" -ItemType directory
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
    try {
        $response = Invoke-RestMethod @params
    } catch {
        $response = $_.Exception.Response
    }
    Return $response
}
function getDeploymentOps([string]$accessToken, [string]$subscriptionId, [string]$resourceGroupName, [string]$deploymentName) {
    $params = @{
        ContentType = "application/json"
        Headers = @{"Authorization"="Bearer ${accessToken}"}
        Method = "GET"
        URI =   "https://management.azure.com/subscriptions/${subscriptionId}/resourcegroups/${resourceGroupName}/deployments/${deploymentName}/operations?api-version=2021-04-01"
    }
    try {
        $response = Invoke-RestMethod @params

    } catch {
        $response = $_.Exception.Response
    }
    Return $response
}

function putNotebook([string]$accessToken, [string]$synapseWorkspaceName, [string]$notebookFileName) {
    $body = Get-Content "MCW/${notebookFileName}.json" | ConvertFrom-Json
    $params = @{
        ContentType = "application/json"
        Headers = @{"Authorization"="Bearer ${accessToken}"}
        Method = "PUT"
        Body = ($body | ConvertTo-Json -Depth 100)
        URI =   "https://${synapseWorkspaceName}.dev.azuresynapse.net/notebooks/${notebookFileName}?api-version=2020-12-01"
    }
    try {
        $response = Invoke-RestMethod @params
    } catch {
        $response = $_.Exception.Response
    }
    Return $response
}

# Variables
$subscriptionId = (Get-AzContext).Subscription.Id
$principalId = az ad signed-in-user show --query objectId -o tsv
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
    1..3 | ForEach-Object {
        Foreach ($x in $progress) {
            $table = @()
            ForEach ($op in $deploymentOperations.value) {
                $row = @{
                    provisioningState = $op.properties.provisioningState
                    resourceType = $op.properties.targetResource.resourceType
                    resourceName = $op.properties.targetResource.resourceName   
                }
                $table += $row
            }
            $elapsed = "{0:mm:ss}" -f ([datetime]$timer.Elapsed.Ticks)
            Clear-Host
            Write-Host "Deployment is in progress, this will take approximately 10 minutes. Elapsed ${elapsed}"
            Write-Host "${provisioningState}${x}"
            $table | ForEach-Object {[PSCustomObject]$_} | Format-Table -AutoSize
            Start-Sleep 1
        }
    }
    $provisioningState = (getDeployment $accessToken $subscriptionId $resourceGroupName $deploymentName).properties.provisioningState
    $deploymentOperations = getDeploymentOps $accessToken $subscriptionId $resourceGroupName $deploymentName
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
$amlWorkspaceName =  $deployment.Properties.Outputs.amlWorkspaceName.Value

# Keys
$storageAccountKey1 = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $storageAccountName)[0].Value
$storageAccountKey2 = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $dataLakeAccountName)[0].Value

# Synapse
Install-Module Az.Synapse -Force

# Linked Services
$resourceGroupName = "synapse-rg-ui9pc"
$synapseWorkspaceName = "asaworkspace4539c7"
$storageAccountName = "asastore4539c7"
$storageAccountKey1 = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $storageAccountName)[0].Value
$dataLakeAccountName = "asadatalake4539c7"
$storageAccountKey2 = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $dataLakeAccountName)[0].Value
$keyVaultName = "asakeyvault4539c7"
$sqlPoolName = "SQLPool01"
$sqlAdminName = "asa.sql.admin"
$keyVaultSecretName = "SQL-USER-ASA"

$assets = "https://raw.githubusercontent.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI/master/assets"
$linkedServices = @(
    "${assets}/linked_services/key_vault.json"
    "${assets}/linked_services/blob_storage.json"
    "${assets}/linked_services/data_lake.json"
    "${assets}/linked_services/sqlpool01.json"
    "${assets}/linked_services/sqlpool01_workload01.json"
    "${assets}/linked_services/sqlpool01_workload02.json"
)
foreach ($uri in $linkedServices) {
    $linkedService = Invoke-RestMethod -Uri $uri -Headers @{"Cache-Control"="no-cache"}
    $name = $linkedService.name
    if ($name -eq "asastore") {
        $linkedService.properties.typeProperties.connectionString = "DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountKey1};EndpointSuffix=core.windows.net;"
    }
    elseif ($name -eq "asadatalake") {
        $linkedService.properties.typeProperties.url = "https://${dataLakeAccountName}.dfs.core.windows.net"
        $linkedService.properties.typeProperties.accountKey.value = $storageAccountKey2
    }
    elseif ($name -eq "asakeyvault") {
        $linkedService.properties.typeProperties.baseUrl = "https://${keyVaultName}.vault.azure.net/"
    }
    elseif ($name -eq "sqlpool01") {
        $linkedService.properties.typeProperties.connectionString = "Integrated Security=False;Encrypt=True;Connection Timeout=30;Data Source=${synapseWorkspaceName}.sql.azuresynapse.net;Initial Catalog=${sqlPoolName};User ID=${sqlAdminName}"
    }
    elseif ($name -eq "sqlpool01_workload01") {
        $linkedService.properties.typeProperties.connectionString = "Integrated Security=False;Encrypt=True;Connection Timeout=30;Data Source=${synapseWorkspaceName}.sql.azuresynapse.net;Initial Catalog=${sqlPoolName};User ID=asa.sql.workload01"
    }
    elseif ($name -eq "sqlpool01_workload02") {
        $linkedService.properties.typeProperties.connectionString = "Integrated Security=False;Encrypt=True;Connection Timeout=30;Data Source=${synapseWorkspaceName}.sql.azuresynapse.net;Initial Catalog=${sqlPoolName};User ID=asa.sql.workload02"
    }
    $filepath = "MCW/linked_service.json"
    ConvertTo-Json $linkedService -Depth 10 | Out-File $filepath
    Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspaceName -Name $linkedService.name -DefinitionFile $filepath
}

# Datasets
$assets = "https://raw.githubusercontent.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI/master/assets"
$datasets = @(
    "${assets}/datasets/asamcw_product_asa.json"
    "${assets}/datasets/asamcw_product_csv.json"
    "${assets}/datasets/asamcw_wwi_salesmall_workload1_asa.json"
    "${assets}/datasets/asamcw_wwi_salesmall_workload2_asa.json"
)
foreach ($uri in $datasets) {
    $dataset = Invoke-RestMethod -Uri $uri -Headers @{"Cache-Control"="no-cache"}
    $name = $dataset.name
    $filepath = "MCW/dataset.json"
    ConvertTo-Json $dataset -Depth 10 | Out-File $filepath
    Set-AzSynapseDataset -WorkspaceName $synapseWorkspaceName -Name $dataset.name -DefinitionFile $filepath
}

# Pipelines
$assets = "https://raw.githubusercontent.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI/master/assets"
$pipelines = @(
    "${assets}/pipelines/ASAMCW - Exercise 2 - Copy Product Information.json"
    "${assets}/pipelines/ASAMCW - Exercise 8 - ExecuteBusinessAnalystQueries.json"
    "${assets}/pipelines/ASAMCW - Exercise 8 - ExecuteDataAnalystAndCEOQueries.json"
)
foreach ($uri in $pipelines) {
    $pipeline = Invoke-RestMethod -Uri $uri -Headers @{"Cache-Control"="no-cache"}
    $name = $pipeline.name
    $filepath = "MCW/pipeline.json"
    ConvertTo-Json $pipeline -Depth 10 | Out-File $filepath
    Set-AzSynapsePipeline -WorkspaceName $synapseWorkspaceName -Name $pipeline.name -DefinitionFile $filepath
}

# SQL Script 1
$uriSql = "https://raw.githubusercontent.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI/master/assets/00_master_setup.sql"
Invoke-RestMethod -Uri $uriSql -OutFile "MCW/00_master_setup.sql"
$params = "PASSWORD=Synapse2021!"
Invoke-Sqlcmd -InputFile "MCW/00_master_setup.sql" -ServerInstance "${synapseWorkspaceName}.sql.azuresynapse.net" -Database "master" -User "asa.sql.admin" -Password "Synapse2021!" -Variable $params
# SQL Script 2
$uriSql = "https://raw.githubusercontent.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI/master/assets/01_sqlpool01_mcw.sql"
Invoke-RestMethod -Uri $uriSql -OutFile "MCW/01_sqlpool01_mcw.sql"
Invoke-Sqlcmd -InputFile "MCW/01_sqlpool01_mcw.sql" -ServerInstance "${synapseWorkspaceName}.sql.azuresynapse.net" -Database "SQLPool01" -User "asa.sql.admin" -Password "Synapse2021!"
# SQL Script 3
$uriSql = "https://raw.githubusercontent.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI/master/assets/02_sqlpool01_ml.sql"
Invoke-RestMethod -Uri $uriSql -OutFile "MCW/02_sqlpool01_ml.sql"
[IO.File]::ReadAllText("MCW/02_sqlpool01_ml.sql") -replace '#DATALAKESTORAGEKEY#',"${storageAccountKey2}" > "MCW/foo.sql"
[IO.File]::ReadAllText("MCW/foo.sql") -replace '#DATALAKESTORAGEACCOUNTNAME#',"${dataLakeAccountName}" > "MCW/bar.sql"
Invoke-Sqlcmd -InputFile "MCW/bar.sql" -ServerInstance "${synapseWorkspaceName}.sql.azuresynapse.net" -Database "SQLPool01" -User "asa.sql.admin" -Password "Synapse2021!"

# Notebook
$notebookFileName = "notebook"
$notebookUri = "https://raw.githubusercontent.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI/master/assets/${notebookFileName}.json"
$notebook = Invoke-RestMethod -Uri $notebookUri 
foreach ($cell in $notebook.properties.cells) {
    $cell.source = @($cell.source.Replace('#SUBSCRIPTION_ID#', $subscriptionId).Replace('#RESOURCE_GROUP_NAME#', $resourceGroupName).Replace('#AML_WORKSPACE_NAME#', $amlWorkspaceName))
}
$notebook | ConvertTo-Json -Depth 100 | Out-File "MCW/${notebookFileName}.json" -Encoding utf8
$accessToken = (Get-AzAccessToken -ResourceUrl "https://dev.azuresynapse.net").Token
putNotebook $accessToken $synapseWorkspaceName $notebookFileName

# Clean-up Files
Remove-Item -Recurse -Force MCW
Remove-Item preDeploymentScript.ps1

$timer.Stop()
$totalTime = "{0:HH:mm:ss}" -f ([datetime]$timer.Elapsed.Ticks)
Write-Output "Duration ${totalTime}"
Write-Output "Resource Group: ${resourceGroupName}"