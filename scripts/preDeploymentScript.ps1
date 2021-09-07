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
ConvertTo-Json $linkedService1 | Out-File "MCW/ls1.json"
Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspaceName -Name $linkedService1.name -DefinitionFile "MCW/ls1.json"

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
ConvertTo-Json $linkedService2 -Depth 10 | Out-File "MCW/ls2.json"
Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspaceName -Name $linkedService2.name -DefinitionFile "MCW/ls2.json"

# Linked Service #3 - Key Vault
$linkedService3 = @{
    name = "${keyVaultName}"
    type = "Microsoft.Synapse/workspaces/linkedservices"
    properties = @{
        type = "AzureKeyVault"
        typeProperties = @{
            baseUrl = "https://${keyVaultName}.vault.azure.net/"
        }
    }
}
ConvertTo-Json $linkedService3  -Depth 10 | Out-File "MCW/ls3.json"
Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspaceName -Name $linkedService3.name -DefinitionFile "MCW/ls3.json"

# Linked Service #4 - SQL DWH
$linkedService4 = @{
    name = "${sqlPoolName}"
    type = "Microsoft.Synapse/workspaces/linkedservices"
    properties = @{
        type = "AzureSqlDW"
        typeProperties = @{
            connectionString = "Integrated Security=False;Encrypt=True;Connection Timeout=30;Data Source=${synapseWorkspaceName}.sql.azuresynapse.net;Initial Catalog=${sqlPoolName};User ID=${sqlAdminName}"
            password = @{
                type = "AzureKeyVaultSecret"
                store = @{ 
                    referenceName = "${keyVaultName}"
                    type = "LinkedServiceReference"
                }
                secretName = "${keyVaultSecretName}"
            }
        }
    }
}
ConvertTo-Json $linkedService4 -Depth 10 | Out-File "MCW/ls4.json"
Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspaceName -Name $linkedService4.name -DefinitionFile "MCW/ls4.json"

# Linked Service #5 - SQL DWH Workload 01
$linkedService5 = @{
    name = "${sqlPoolName}_workload01"
    properties = @{
        type = "AzureSqlDW"
        typeProperties = @{
            connectionString = "Integrated Security=False;Encrypt=True;Connection Timeout=30;Data Source=${synapseWorkspaceName}.sql.azuresynapse.net;Initial Catalog=${sqlPoolName};User ID=asa.sql.workload01"
            password = @{
                type = "AzureKeyVaultSecret"
                store = @{ 
                    referenceName = "${keyVaultName}"
                    type = "LinkedServiceReference"
                }
                secretName = "${keyVaultSecretName}"
            }
        }
    }
}
ConvertTo-Json $linkedService5 -Depth 10 | Out-File "MCW/ls5.json"
Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspaceName -Name $linkedService5.name -DefinitionFile "MCW/ls5.json"

# Linked Service #6 - SQL DWH Workload 01
$linkedService6 = @{
    name = "${sqlPoolName}_workload02"
    properties = @{
        type = "AzureSqlDW"
        typeProperties = @{
            connectionString = "Integrated Security=False;Encrypt=True;Connection Timeout=30;Data Source=${synapseWorkspaceName}.sql.azuresynapse.net;Initial Catalog=${sqlPoolName};User ID=asa.sql.workload02"
            password = @{
                type = "AzureKeyVaultSecret"
                store = @{ 
                    referenceName = "${keyVaultName}"
                    type = "LinkedServiceReference"
                }
                secretName = "${keyVaultSecretName}"
            }
        }
    }
}
ConvertTo-Json $linkedService6 -Depth 10 | Out-File "MCW/ls6.json"
Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspaceName -Name $linkedService6.name -DefinitionFile "MCW/ls6.json"

# Datasets
$dataset1 = @{
    name = "asamcw_product_asa"
    properties = @{
        linkedServiceName = @{
            referenceName = $linkedService4.name
            type = "LinkedServiceReference"
        }
        type = "AzureSqlDWTable"
        schema = @(
            @{
                name = "ProductId"
                type = "smallint"
                precision = 5
            }
            @{
                name = "Seasonality"
                type = "tinyint"
                precision = 3
            }
            @{
                name = "Price"
                type = "decimal"
                precision = 6
                scale = 2
            }
            @{
                name = "Profit"
                type = "decimal"
                precision = 6
                scale = 2
            }
        )
        typeProperties = @{
            schema = "wwi_mcw"
            table = "Product"
        }
    }
    type = "Microsoft.Synapse/workspaces/datasets"
}
$dataset2 = @{
    name = "asamcw_product_csv"
    properties = @{
        linkedServiceName = @{
            referenceName = $linkedService2.name
            type = "LinkedServiceReference"
        }
        annotations = @()
        type = "DelimitedText"
        typeProperties = @{
            location = @{
                type = "AzureBlobStorageLocation"
                fileName = "generator-product.csv"
                folderPath = "data-generators/generator-product"
                container = "wwi-02"
            }
            columnDelimiter = ""
            escapeChar = "\\"
            quoteChar = '\"'
        }
        schema = @(
            @{
                type = "String"
            }
            @{
                type = "String"
            }
            @{
                type = "String"
            }
            @{
                type = "String"
            }
        )
    }
    type = "Microsoft.Synapse/workspaces/datasets"
}
$dataset3 = @{
    name = "asamcw_wwi_salesmall_workload1_asa"
    properties = @{
        linkedServiceName = @{
            referenceName = $linkedService5.name
            type = "LinkedServiceReference"
        }
        annotations = @()
        type = "AzureSqlDWTable"
        schema = @(
            @{
                name = "TransactionId"
                type = "uniqueidentifier"
            }
            @{
                name = "CustomerId"
                type = "int"
                precision = 10
            }
            @{
                name = "ProductId"
                type = "smallint"
                precision = 5
            }
            @{
                name = "Quantity"
                type = "tinyint"
                precision = 3
            }
            @{
                name = "Price"
                type = "decimal"
                precision = 9
                scale = 2
            }
            @{
                name = "TotalAmount"
                type = "decimal"
                precision = 9
                scale = 2
            }
            @{
                name = "TransactionDateId"
                type = "int"
                precision = 10
            }
            @{
                name = "ProfitAmount"
                type = "decimal"
                precision = 9
                scale = 2
            }
            @{
                name = "Hour"
                type = "tinyint"
                precision = 3
            }
            @{
                name = "Minute"
                type = "tinyint"
                precision = 3
            }
            @{
                name = "StoreId"
                type = "smallint"
                precision = 5
            }
        )
        typeProperties = @{
            schema = "wwi_mcw"
            table = "SaleSmall"
        }
    }
    type = "Microsoft.Synapse/workspaces/datasets"
}
$dataset4 = @{
    name = "asamcw_wwi_salesmall_workload2_asa"
    properties = @{
        linkedServiceName = @{
            referenceName = $linkedService6.name
            type = "LinkedServiceReference"
        }
        annotations = @()
        type = "AzureSqlDWTable"
        schema = @(
            @{
                name = "TransactionId"
                type = "uniqueidentifier"
            }
            @{
                name = "CustomerId"
                type = "int"
                precision = 10
            }
            @{
                name = "ProductId"
                type = "smallint"
                precision = 5
            }
            @{
                name = "Quantity"
                type = "tinyint"
                precision = 3
            }
            @{
                name = "Price"
                type = "decimal"
                precision = 9
                scale = 2
            }
            @{
                name = "TotalAmount"
                type = "decimal"
                precision = 9
                scale = 2
            }
            @{
                name = "TransactionDateId"
                type = "int"
                precision = 10
            }
            @{
                name = "ProfitAmount"
                type = "decimal"
                precision = 9
                scale = 2
            }
            @{
                name = "Hour"
                type = "tinyint"
                precision = 3
            }
            @{
                name = "Minute"
                type = "tinyint"
                precision = 3
            }
            @{
                name = "StoreId"
                type = "smallint"
                precision = 5
            }
        )
        typeProperties = @{
            schema = "wwi_mcw"
            table = "SaleSmall"
        }
    }
    type = "Microsoft.Synapse/workspaces/datasets"
}
ConvertTo-Json $dataset1 -Depth 10 | Out-File "MCW/ds1.json"
ConvertTo-Json $dataset2 -Depth 10 | Out-File "MCW/ds2.json"
ConvertTo-Json $dataset3 -Depth 10 | Out-File "MCW/ds3.json"
ConvertTo-Json $dataset4 -Depth 10 | Out-File "MCW/ds4.json"
Set-AzSynapseDataset -WorkspaceName $synapseWorkspaceName -Name $dataset1.name -DefinitionFile "MCW/ds1.json"
Set-AzSynapseDataset -WorkspaceName $synapseWorkspaceName -Name $dataset2.name -DefinitionFile "MCW/ds2.json"
Set-AzSynapseDataset -WorkspaceName $synapseWorkspaceName -Name $dataset3.name -DefinitionFile "MCW/ds3.json"
Set-AzSynapseDataset -WorkspaceName $synapseWorkspaceName -Name $dataset4.name -DefinitionFile "MCW/ds4.json"

# Pipelines
$assets = "https://raw.githubusercontent.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI/master/assets"
$pipelines = @(
    "${assets}/pipelines/ASAMCW - Exercise 2 - Copy Product Information.json"
    "${assets}/pipelines/ASAMCW - Exercise 8 - ExecuteBusinessAnalystQueries.json"
    "${assets}/pipelines/ASAMCW - Exercise 8 - ExecuteDataAnalystAndCEOQueries.json"
)
foreach ($pipelineUri in $pipelines) {
    $pipeline = Invoke-RestMethod -Uri $pipelineUri
    Write-Output $pipeline.properties.activities[0].typeProperties.stagingSettings.linkedServiceName.referenceName
    # $filepath = "MCW/pipeline.json"
    # ConvertTo-Json $pipeline -Depth 10 | Out-File $filepath
    # Set-AzSynapsePipeline -WorkspaceName $synapseWorkspaceName -Name $pipeline.name -DefinitionFile $filepath
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