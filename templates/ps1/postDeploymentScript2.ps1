param(
    [string]$resourceGroupName,
    [string]$storageAccountName,
    [string]$synapseWorkspaceName
)

$token = Get-AzAccessToken -ResourceUrl "https://dev.azuresynapse.net"
Write-Output $token

$headers = @{ Authorization = "Bearer $token" }

$uri = "https://${synapseWorkspaceName}.dev.azuresynapse.net/linkedservices?api-version=2020-12-01"
$result = Invoke-RestMethod -Method Get -ContentType "application/json" -Uri $uri -Headers $headers
Write-Output $result


# Install-Module Az.Synapse -Force


# $storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $storageAccountName)[0].Value
# # Linked Services
$linkedService1 = @{
    name = "${storageAccountName}"
    type = "Microsoft.Synapse/workspaces/linkedservices"
    properties = @{
        type = "AzureBlobStorage"
        typeProperties = @{
            connectionString = "DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountKey};EndpointSuffix=core.windows.net;"
        }
    }
}
ConvertTo-Json $linkedService1  | Out-File ls1.json
Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspaceName -Name $storageAccountName -DefinitionFile "ls1.json"