param variables_workspaceName ? /* TODO: fill in correct type */
param variables_sparkComputeName ? /* TODO: fill in correct type */
param variables_location ? /* TODO: fill in correct type */
param variables_sparkNodeCount ? /* TODO: fill in correct type */
param variables_sparkNodeSizeFamily ? /* TODO: fill in correct type */
param variables_sparkNodeSize ? /* TODO: fill in correct type */
param variables_sparkAutoScaleEnabled ? /* TODO: fill in correct type */
param variables_sparkMinNodeCount ? /* TODO: fill in correct type */
param variables_sparkMaxNodeCount ? /* TODO: fill in correct type */
param variables_sparkAutoPauseEnabled ? /* TODO: fill in correct type */
param variables_sparkAutoPauseDelayInMinutes ? /* TODO: fill in correct type */
param variables_sparkVersion ? /* TODO: fill in correct type */
param variables_packagesRequirementsFileName ? /* TODO: fill in correct type */
param variables_packagesRequirementsContent ? /* TODO: fill in correct type */

resource variables_workspaceName_variables_sparkComputeName 'Microsoft.Synapse/workspaces/bigDataPools@2019-06-01-preview' = {
  name: '${variables_workspaceName}/${variables_sparkComputeName}'
  location: variables_location
  properties: {
    nodeCount: variables_sparkNodeCount
    nodeSizeFamily: variables_sparkNodeSizeFamily
    nodeSize: variables_sparkNodeSize
    autoScale: {
      enabled: variables_sparkAutoScaleEnabled
      minNodeCount: variables_sparkMinNodeCount
      maxNodeCount: variables_sparkMaxNodeCount
    }
    autoPause: {
      enabled: variables_sparkAutoPauseEnabled
      delayInMinutes: variables_sparkAutoPauseDelayInMinutes
    }
    sparkVersion: variables_sparkVersion
    libraryRequirements: {
      filename: variables_packagesRequirementsFileName
      content: variables_packagesRequirementsContent
    }
  }
}