# Getting Started

**[Home](https://github.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI#getting-started)** - [Next Exercise >](../exercises/exercise01.md#exercise-1-accessing-the-azure-synapse-analytics-workspace)

## :thinking: Prerequisites

* An active [Azure subscription](https://azure.microsoft.com/en-us/free/).
* Sufficient access to create resources and register an application.

<div align="right"><a href="#getting-started">↥ back to top</a></div>

## :test_tube: Usage

1. **Copy** the PowerShell code snippet below.
```powershell
$uri = "https://raw.githubusercontent.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI/master/scripts/preDeploymentScript.ps1"
Invoke-WebRequest $uri -OutFile "preDeploymentScript.ps1"
./preDeploymentScript.ps1
  ```
2. Navigate to the [Azure Portal](https://portal.azure.com), open the **Cloud Shell**.
![Azure Portal Cloud Shell](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/azure_portal_cloud_shell.png)

3. **Paste** the code snippet. Wait until the deployment is complete.


<div align="right"><a href="#getting-started">↥ back to top</a></div>

## :books: Exercises

1. [Exercise 1: Accessing the Azure Synapse Analytics workspace](../exercises/exercise01.md#exercise-1-accessing-the-azure-synapse-analytics-workspace)
2. [Exercise 2: Create and populate the supporting tables in the SQL Pool](../exercises/exercise02.md#exercise-2-create-and-populate-the-supporting-tables-in-the-sql-pool)
3. [Exercise 3: Exploring raw parquet](../exercises/exercise03.md#exercise-3-exploring-raw-parquet)
4. [Exercise 4: Exploring raw text based data with Azure Synapse SQL Serverless](../exercises/exercise04.md#exercise-4-exploring-raw-text-based-data-with-azure-synapse-sql-serverless)
5. [Exercise 5: Synapse Pipelines and Cognitive Search (Optional)](../exercises/exercise05.md#exercise-5-synapse-pipelines-and-cognitive-search-optional)
6. [Exercise 6: Security](../exercises/exercise06.md#exercise-6-security)
7. [Exercise 7: Machine Learning](../exercises/exercise07.md#exercise-7-machine-learning)
8. [Exercise 8: Monitoring](../exercises/exercise08.md#exercise-8-monitoring)

<div align="right"><a href="#getting-started">↥ back to top</a></div>
