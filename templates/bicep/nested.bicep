param synapseWorkspaceName string
param bigDataPoolName string
param location string

resource updateBigDataPool 'Microsoft.Synapse/workspaces/bigDataPools@2021-05-01' = {
  name: '${synapseWorkspaceName}/${bigDataPoolName}'
  location: location
  properties: {
    sparkVersion: '2.4'
    nodeCount: 0
    nodeSize: 'Small'
    nodeSizeFamily: 'MemoryOptimized'
    autoScale: {
      enabled: true
      minNodeCount: 3
      maxNodeCount: 4
    }
    autoPause: {
      enabled: true
      delayInMinutes: 15
    }
    libraryRequirements: {
      filename: 'requirements.txt'
      content: 'xgboost ==1.0.2\nonnxruntime ==1.0.0\nwerkzeug ==0.16.1\nnimbusml ==1.7.1\nruamel.yaml ==0.16.9\nazureml-train-automl-runtime ==1.6.0\nscikit-learn ==0.20.3\nnumpy ==1.16.2\npandas ==0.23.4\nscipy ==1.4.1'
    }
  }
}
