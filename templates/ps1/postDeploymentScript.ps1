param(
    [string]$dataLakeAccountName,
    [string]$resourceGroupName
)

$publicDataUrl = "https://solliancepublicdata.blob.core.windows.net/"
$dataLakeStorageUrl = "https://"+ $dataLakeAccountName + ".dfs.core.windows.net/"
$dataLakeStorageBlobUrl = "https://"+ $dataLakeAccountName + ".blob.core.windows.net/"
# $dataLakeStorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $dataLakeAccountName)[0].Value
# $dataLakeContext = New-AzureStorageContext -StorageAccountName $dataLakeAccountName -StorageAccountKey $dataLakeStorageAccountKey
# $destinationSasKey = New-AzureStorageContainerSASToken -Container "wwi-02" -Context $dataLakeContext -Permission rwdl
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $dataLakeAccountName
$destinationSasKey = New-AzureStorageContainerSASToken -Container "wwi-02" -Context $storageAccount.Context -Permission rwdl

Write-Information "Copying single files from the public data account..."
$singleFiles = @{
        parquet_query_file = "wwi-02/sale-small/Year=2010/Quarter=Q4/Month=12/Day=20101231/sale-small-20101231-snappy.parquet"
        customer_info = "wwi-02/customer-info/customerinfo.csv"
        campaign_analytics = "wwi-02/campaign-analytics/campaignanalytics.csv"
        products = "wwi-02/data-generators/generator-product/generator-product.csv"
        model = "wwi-02/ml/onnx-hex/product_seasonality_classifier.onnx.hex"
}
foreach ($singleFile in $singleFiles.Keys) {
        $source = $publicDataUrl + $singleFiles[$singleFile]
        $destination = $dataLakeStorageBlobUrl + $singleFiles[$singleFile] + $destinationSasKey
        Write-Information "Copying file $($source) to $($destination)"
        azcopy copy $source $destination 
}

Write-Information "Copying sample sales raw data directories from the public data account..."
$dataDirectories = @{
        data2018 = "wwi-02/sale-small,wwi-02/sale-small/Year=2018/"
        data2019 = "wwi-02/sale-small,wwi-02/sale-small/Year=2019/"
}
foreach ($dataDirectory in $dataDirectories.Keys) {
        $vals = $dataDirectories[$dataDirectory].tostring().split(",");
        $source = $publicDataUrl + $vals[1];
        $path = $vals[0];

        $destination = $dataLakeStorageBlobUrl + $path + $destinationSasKey
        Write-Information "Copying directory $($source) to $($destination)"
        azcopy copy $source $destination --recursive=true
}

Write-Information "Copying sample JSON data from the repository..."
$rawData = "./rawdata/json-data"
$destination = $dataLakeStorageUrl +"wwi-02/product-json" + $destinationSasKey
azcopy copy $rawData $destination --recursive