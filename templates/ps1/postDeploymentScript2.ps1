param(
    [string]$resourceGroupName,
    [string]$storageAccountName,
    [string]$synapseWorkspaceName
)

$token = Get-AzAccessToken -ResourceUrl "https://management.core.windows.net/"
Write-Output $token

# Install-Module Az.Synapse -Force


# $storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $storageAccountName)[0].Value
# # Linked Services
# $linkedService1 = @{
#     name = "${storageAccountName}"
#     type = "Microsoft.Synapse/workspaces/linkedservices"
#     properties = @{
#         type = "AzureBlobStorage"
#         typeProperties = @{
#             connectionString = "DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountKey};EndpointSuffix=core.windows.net;"
#         }
#     }
# }
# ConvertTo-Json $linkedService1  | Out-File ls1.json
# Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspaceName -Name $storageAccountName -DefinitionFile "ls1.json"