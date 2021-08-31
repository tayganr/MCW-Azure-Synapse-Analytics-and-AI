param(
    [string]$dataLakeAccountName,
    [string]$resourceGroupName
)

# $dataLakeAccountName = "asadatalaketr8595"
# $resourceGroupName = "Synapse-OG-MCW"
$blobPath = "sale-small/Year=2010/Quarter=Q4/Month=12/Day=20101231/sale-small-20101231-snappy.parquet"
$dataLakeStorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $dataLakeAccountName)[0].Value
$dataLakeContext = New-AzStorageContext -StorageAccountName $dataLakeAccountName -StorageAccountKey $dataLakeStorageAccountKey
$sourceContext = New-AzStorageContext -StorageAccountName "solliancepublicdata" -Anonymous -Protocol "https"

$blobPaths = @(
    'sale-small/Year=2010/Quarter=Q4/Month=12/Day=20101231/sale-small-20101231-snappy.parquet'
    'customer-info/customerinfo.csv'
    'campaign-analytics/campaignanalytics.csv'
    'data-generators/generator-product/generator-product.csv'
    'ml/onnx-hex/product_seasonality_classifier.onnx.hex'
)
foreach ($blobPath in $blobPaths) { 
    Start-AzStorageBlobCopy -SrcContainer "wwi-02" -SrcBlob $blobPath -DestContainer "wwi-02" -DestBlob $blobPath -Context $sourceContext -DestContext $dataLakeContext
}
Get-AzStorageBlob -Container "wwi-02" -Prefix "sale-small/Year=2018" -Context $sourceContext | Start-AzStorageBlobCopy -DestContainer "temp2" -DestContext $dataLakeContext
Get-AzStorageBlob -Container "wwi-02" -Prefix "sale-small/Year=2019" -Context $sourceContext | Start-AzStorageBlobCopy -DestContainer "temp2" -DestContext $dataLakeContext

# Write-Information "Copying sample JSON data from the repository..."
# $rawData = "./rawdata/json-data"
# $destination = $dataLakeStorageUrl +"wwi-02/product-json" + $destinationSasKey
# azcopy copy $rawData $destination --recursive
