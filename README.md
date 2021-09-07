# Azure Synapse Analytics and AI Hands-on Lab

**[Home](https://github.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI#prerequisites)** - [Next Exercise >](exercises/exercise01.md)

## Abstract

In this hands-on-lab, you will build an end-to-end data analytics with machine learning solution using Azure Synapse Analytics. The information will be presented in the context of a retail scenario. We will be heavily leveraging Azure Synapse Studio, a tool that conveniently unifies the most common data operations from ingestion, transformation, querying, and visualization.

## Overview

In this lab various features of Azure Synapse Analytics will be explored. Azure Synapse Analytics Studio is a single tool that every team member can use collaboratively. Synapse Studio will be the only tool used throughout this lab through data ingestion, cleaning, and transforming raw files to using Notebooks to train, register, and consume a Machine learning model. The lab will also provide hands-on-experience monitoring and prioritizing data related workloads.

## Solution Architecture

![Architecture diagram explained in the next paragraph.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/archdiagram.png "Architecture Diagram")

This lab explores the cold data scenario of ingesting various types of raw data files. These files can exist anywhere. The file types used in this lab are CSV, parquet, and JSON. This data will be ingested into Synapse Analytics via Pipelines. From there, the data can be transformed and enriched using various tools such as data flows, Synapse Spark, and Synapse SQL (both provisioned and serverless). Once processed, data can be queried using Synapse SQL tooling. Azure Synapse Studio also provides the ability to author notebooks to further process data, create datasets, train, and create machine learning models. These models can then be stored in a storage account or even in a SQL table. These models can then be consumed via various methods, including T-SQL. The foundational component supporting all aspects of Azure Synapse Analytics is the ADLS Gen 2 Data Lake.

## :thinking: Prerequisites

* An active [Azure subscription](https://azure.microsoft.com/en-us/free/).
* Sufficient access to create resources and register an application.

<div align="right"><a href="#prerequisites">↥ back to top</a></div>

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


<div align="right"><a href="#prerequisites">↥ back to top</a></div>

## :books: Exercises

1. [Exercise 1: Accessing the Azure Synapse Analytics workspace](exercises/exercise01.md)
2. [Exercise 2: Create and populate the supporting tables in the SQL Pool](exercises/exercise02.md)
3. [Exercise 3: Exploring raw parquet](exercises/exercise03.md)
4. [Exercise 4: Exploring raw text based data with Azure Synapse SQL Serverless](exercises/exercise04.md)
5. [Exercise 5: Synapse Pipelines and Cognitive Search (Optional)](exercises/exercise05.md)
6. [Exercise 6: Security](exercises/exercise06.md)
7. [Exercise 7: Machine Learning](exercises/exercise07.md)
8. [Exercise 8: Monitoring](exercises/exercise08.md)

<div align="right"><a href="#prerequisites">↥ back to top</a></div>











