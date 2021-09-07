## Exercise 4: Exploring raw text based data with Azure Synapse SQL Serverless

[< Previous Exercise](../exercises/exercise03.md#exercise-3-exploring-raw-parquet) - **[Home](https://github.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI#azure-synapse-analytics-and-ai-hands-on-lab)** - [Next Exercise >](../exercises/exercise05.md#exercise-5-synapse-pipelines-and-cognitive-search-optional)

**Duration**: 15 minutes

**Contents**
* [Task 1: Query CSV data](#task-1-query-csv-data)
* [Task 2: Query JSON data](#task-2-query-json-data)

A common format for exporting and storing data is with text based files. These can delimited text files such as CSV as well as JSON structured data files. Azure Synapse Analytics also provides ways of querying into these types of raw files to gain valuable insights into the data without having to wait for them to be processed.

<div align="right"><a href="#exercise-4-exploring-raw-text-based-data-with-azure-synapse-sql-serverless">↥ back to top</a></div>

### Task 1: Query CSV data

1. Create a new SQL script by selecting **Develop** from the left menu, then in the **Develop** blade, expanding the **+** button and selecting **SQL script**.

2. Ensure **Built-in** is selected in the **Connect to** dropdown list above the query window.

    ![The Built-in SQL on-demand connection is highlighted on the query window toolbar.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/sql-on-demand-selected.png "SQL on-demand")

3. In this scenario, we will be querying into the CSV file that was used to populate the product table. This file is located in the `asadatalake{SUFFIX}` account at: **wwi-02/data-generators/generator-product.csv**. We will select all data from this file. Copy and paste the following query into the query window and select **Run** from the query window toolbar menu. Remember to replace `asadatalake{SUFFIX}` with your storage account name.

    ```sql
    SELECT
       csv.*
    FROM
        OPENROWSET(
            BULK 'https://asadatalake{SUFFIX}.dfs.core.windows.net/wwi-02/data-generators/generator-product/generator-product.csv',
            FORMAT='CSV',
            FIRSTROW = 1
        ) WITH (
            ProductID INT,
            Seasonality INT,
            Price DECIMAL(10,2),
            Profit DECIMAL(10,2)
        ) as csv
    ```

    > **Note**: In this query we are querying only a single file. Azure Synapse Analytics allows you to query across a series of CSV files (structured identically) by using wildcards in the path to the file(s).

4. You are also able to perform aggregations on this data. Replace the query with the following, and select **Run** from the toolbar menu. Remember to replace `asadatalake{SUFFIX}` with your storage account name.

    ```sql
    SELECT
        Seasonality,
        SUM(Price) as TotalSalesPrice,
        SUM(Profit) as TotalProfit
    FROM
        OPENROWSET(
            BULK 'https://asadatalake{SUFFIX}.dfs.core.windows.net/wwi-02/data-generators/generator-product/generator-product.csv',
            FORMAT='CSV',
            FIRSTROW = 1
        ) WITH (
            ProductID INT,
            Seasonality INT,
            Price DECIMAL(10,2),
            Profit DECIMAL(10,2)
        ) as csv
    GROUP BY
        csv.Seasonality
    ```

5. After you have run the previous query, switch the view on the **Results** tab to **Chart** to see a visualization of the aggregation of this data. Feel free to experiment with the chart settings to obtain the best visualization!

    ![The result of the previous aggregation query is displayed as a chart in the Results pane.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/querycsv_serverless_chart.png "Aggregation query results")

6. At the far right of the top toolbar, select the **Discard all** button as we will not be saving this query. When prompted, choose to **Discard changes**.

   ![The top toolbar menu is displayed with the Discard all button highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/toptoolbar_discardall.png "Discarding all changes")

<div align="right"><a href="#exercise-4-exploring-raw-text-based-data-with-azure-synapse-sql-serverless">↥ back to top</a></div>

### Task 2: Query JSON data

1. Create a new SQL script by selecting **Develop** from the left menu, then in the **Develop** blade, expanding the **+** button and selecting **SQL script**.

2. Ensure **Built-in** is selected in the **Connect to** dropdown list above the query window.

    ![The Built-in SQL on-demand connection is highlighted on the query window toolbar.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/sql-on-demand-selected.png "SQL on-demand")

3. Replace the query with the following, remember to replace `asadatalake{SUFFIX}` with the name of your storage account:

    ```sql
    SELECT
        products.*
    FROM
        OPENROWSET(
            BULK 'https://asadatalake{SUFFIX}.dfs.core.windows.net/wwi-02/product-json/json-data/*.json',
            FORMAT='CSV',
            FIELDTERMINATOR ='0x0b',
            FIELDQUOTE = '0x0b',
            ROWTERMINATOR = '0x0b'
        )
        WITH (
            jsonContent NVARCHAR(200)
        ) AS [raw]
    CROSS APPLY OPENJSON(jsonContent)
    WITH (
        ProductId INT,
        Seasonality INT,
        Price DECIMAL(10,2),
        Profit DECIMAL(10,2)
    ) AS products
    ```

4. At the far right of the top toolbar, select the **Discard all** button as we will not be saving this query. When prompted, choose to **Discard changes**.

   ![The top toolbar menu is displayed with the Discard all button highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/toptoolbar_discardall.png "Discarding all changes")

<div align="right"><a href="#exercise-4-exploring-raw-text-based-data-with-azure-synapse-sql-serverless">↥ back to top</a></div>