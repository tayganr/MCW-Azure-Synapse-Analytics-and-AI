param(
    [string]$dataLakeAccountName,
    [string]$resourceGroupName
)
$container = "wwi-02"
$dataLakeStorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $dataLakeAccountName)[0].Value
$dataLakeContext = New-AzStorageContext -StorageAccountName $dataLakeAccountName -StorageAccountKey $dataLakeStorageAccountKey
$sourceContext = New-AzStorageContext -StorageAccountName "solliancepublicdata" -Anonymous -Protocol "https"

# Single Files
$blobPaths = @(
    'sale-small/Year=2010/Quarter=Q4/Month=12/Day=20101231/sale-small-20101231-snappy.parquet'
    'customer-info/customerinfo.csv'
    'campaign-analytics/campaignanalytics.csv'
    'data-generators/generator-product/generator-product.csv'
    'ml/onnx-hex/product_seasonality_classifier.onnx.hex'
)
foreach ($blobPath in $blobPaths) { 
    Start-AzStorageBlobCopy -SrcContainer $container -SrcBlob $blobPath -DestContainer $container -DestBlob $blobPath -Context $sourceContext -DestContext $dataLakeContext
}
# Multiple Files
Get-AzStorageBlob -Container $container -Prefix "sale-small/Year=2018" -Context $sourceContext | Start-AzStorageBlobCopy -DestContainer $container -DestContext $dataLakeContext
Get-AzStorageBlob -Container $container -Prefix "sale-small/Year=2019" -Context $sourceContext | Start-AzStorageBlobCopy -DestContainer $container -DestContext $dataLakeContext
# JSON Documents
1..5 | ForEach-Object {
    $uri = "https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/environment-setup/automation/rawdata/json-data/product-$_.json"
    $jsonBlob = "product-json/json-data/product-$_.json"
    Start-AzStorageBlobCopy -AbsoluteUri $uri -DestContainer $container -DestBlob $jsonBlob -DestContext $dataLakeContext
}
