## Exercise 5: Synapse Pipelines and Cognitive Search (Optional)

[< Previous Exercise](../exercises/exercise04.md#exercise-4-exploring-raw-text-based-data-with-azure-synapse-sql-serverless) - **[Home](https://github.com/tayganr/MCW-Azure-Synapse-Analytics-and-AI#azure-synapse-analytics-and-ai-hands-on-lab)** - [Next Exercise >](../exercises/exercise06.md#exercise-6-security)

**Duration**: 45 minutes

**Contents**
* [Task 1: Create the invoice storage container](#task-1-create-the-invoice-storage-container)
* [Task 2: Create and train an Azure Forms Recognizer model and setup Cognitive Search](#task-2-create-and-train-an-azure-forms-recognizer-model-and-setup-cognitive-search)
* [Task 3: Configure a skillset with Form Recognizer](#task-3-configure-a-skillset-with-form-recognizer)
* [Task 4: Create the Synapse Pipeline](#task-4-create-the-synapse-pipeline)

In this exercise you will create a Synapse Pipeline that will orchestrate updating the part prices from a supplier invoice. You will accomplish this by a combination of a Synapse Pipeline with an Azure Cognitive Search Skillset that invokes the Form Recognizer service as a custom skill. The pipeline will work as follows:

- Invoice is uploaded to Azure Storage.
- An Azure Cognitive Search index is started
- The index of any new or updated invoices invokes an Azure Cognitive Search skillset.
- The first skill in the skillset invokes an Azure Function, passing it the URL to the PDF invoice.
- The Azure Function invokes the Form Recognizer service, passing it the URL and SAS token to the PDF invoice. Forms recognizer returns the OCR results to the function.
- The Azure Function returns the results to skillset. The skillset then extracts only the product names and costs and sends that to a configure knowledge store that writes the extracted data to JSON files in Azure Blob Storage.
- The Synapse pipeline reads these JSON files from Azure Storage in a Data Flow activity and performs an upsert against the product catalog table in the Synapse SQL Pool.

<div align="right"><a href="#placeholder">↥ back to top</a></div>

### Task 1: Create the invoice storage container

1. In the Azure Portal, navigate to the lab resource group and select the **asastore{suffix}** storage account.

    ![The lab resources list is shown with the asastore storage account highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task1a-000.png "Lab resource group listing")
  
2. From the left menu, beneath **Blob service**, select **Containers**. From the top toolbar menu of the **Containers** screen, select **+ Container**.
  
    ![The Containers screen is displayed with Containers selected from the left menu, and + Container selected from the toolbar.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task1a-001.png "Azure Storage Container screen")

3. On the **New container** blade, name the container **invoices**, and select **Create**, we will keep the default values for the remaining fields.

4. Repeat steps 2 and 3, and create two additional containers named **invoices-json** and **invoices-staging**.

5. From the left menu, select **Storage Explorer (preview)**. Then, in the hierarchical menu, expand the **BLOB CONTAINERS** item.

6. Beneath **BLOB CONTAINERS**, select the **invoices** container, then from the taskbar menu, select **+ New Folder**

    ![The Storage Explorer (preview) screen is shown with Storage Explorer selected from the left menu. In the hierarchical menu, the BLOB CONTAINERS item expanded with the invoices item selected. The + New Folder button is highlighted in the taskbar menu.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/storageexplorer_invoicesnewfolder.png "Azure Storage Explorer")

7. In the **Create New Virtual Directory** blade, name the directory **Test**, then select **OK**. This will automatically move you into the new **Test** folder.

    ![The Create New Virtual Directory form is displayed with Test entered in the name field.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/storageexplorer_createnewvirtualdirectoryblade.png "Create New Virtual Directory form")

8. From the taskbar, select **Upload**. Upload all invoices located in **Hands-on lab/artifacts/sample_invoices/Test**. These files are Invoice_6.pdf and Invoice_7.pdf.

9. Return to the root **invoices** folder by selecting the **invoices** breadcrumb from the location textbox found beneath the taskbar.

    ![A portion of the Storage Explorer window is displayed with the invoices breadcrumb selected from the location textbox.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/storageexplorer_breadcrumbnav.png "Storage Explorer breadcrumb navigation")

10. From the taskbar, select **+ New Folder** once again. This time creating a folder named **Train**. This will automatically move you into the new **Train** folder.

11. From the taskbar, select **Upload**. Upload all invoices located in **Hands-on lab/artifacts/sample_invoices/Train**. These files are Invoice_1.pdf, Invoice_2.pdf, Invoice_3.pdf, Invoice_4.pdf and Invoice_5.pdf.

12. From the left menu, select **Access keys**.

    ![The left menu is displayed with the Access keys link highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task1a-003.png "The Access keys menu item")

13. Copy the **Connection string** value beneath **key1**. Save it to notepad, Visual Studio Code, or another text file. We'll use this several times

    ![The copy button is selected next to the key1 connection string.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task1a-004.png "Copying the key1 connection string value")

14. From the left menu, beneath **Settings**, select **Shared access signature**.

15. Make sure all the checkboxes are selected and choose **Generate SAS and connection string**.

    ![The configuration form is displayed for SAS generation.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task1a-012.png "SAS Configuration form")

16. Copy the generated **Blob service SAS URL** to the same text file as above.

    ![The SAS form is shown with the shared access signature blob service SAS URL highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task1a-013.png "The SAS URL")

17. Modify the SAS URL that you just copied and add the **invoices** container name directly before the **?** character.

    >**Example**: https://asastore{{suffix}.blob.core.windows.net/invoices?sv=2019-12-12&ss=bfqt&srt ...

<div align="right"><a href="#placeholder">↥ back to top</a></div>

### Task 2: Create and train an Azure Forms Recognizer model and setup Cognitive Search

1. Browse to your Azure Portal homepage, select **+ Create a resource**, then search for and select **Form Recognizer** from the search results.

    ![The New resource screen is shown with Form Recognizer entered into the search text boxes and selected from the search results.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task2a-01.png "New resource search form")

2. Select **Create**.

    ![The Form Recognizer overview screen is displayed with the Create button highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task2a-02.png "The Form Recognizer overview form")

3. Enter the following configuration settings, then select **Create**:

    | Field | Value |
    |-------|-------|
    | Subscription | Select the lab subscription. |
    | Resource Group | Select the lab resource group |
    | Region | Select  the lab region. |
    | Name  | Enter a unique name (denoted by the green checkmark indicator) for the form recognition service. |
    | Pricing Tier | Select **Free F0**. |
    | Confirmation checkbox | Checked. |
  
    ![The Form Recognizer configuration screen is displayed populated with the preceding values.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task2a-03.png "Form Recognizer configuration screen")

4. Wait for the service to provision then navigate to the resource.

5. From the left menu, select **Keys and Endpoint**.

    ![The left side navigation is shown with the Keys and Endpoint item highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task2a-04.png "Left menu navigation")

6. Copy and Paste both **KEY 1** and the **ENDPOINT** values. Put these in the same location as the storage connection string you copied earlier.

    ![The Keys and Endpoint screen is shown with KEY 1 and ENDPOINT values highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task2a-05.png "The Keys and Endpoint screen")

7. Browse to your Azure Portal homepage, select **+ Create a new resource**, then search for and create a new instance of **Azure Cognitive Search**.

    ![The Azure Cognitive Search overview screen is displayed.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task1-006.png "Azure Cognititve Search Overview screen")

8. Choose the subscription and the resource group you've been using for this lab. Set the URL of the Cognitive Search Service to a unique value, relating to search. Then, switch the pricing tier to **Free**.

    ![The configuration screen for Cognitive Search is displayed populated as described above.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task1-007.png "Cognitive Search service configuration")

9. Select **Review + create**.

    ![displaying the review + create button](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task1-008.png "The review and create button")

10. Select **Create**.

11. Wait for the Search service to be provisioned then navigate to the resource.

12. From the left menu, select **Keys**, copy the **Primary admin key** and paste it into your text document. Also make note of the name of your search service resource.

    ![They Keys page of the Search service resource is shown with the Primary admin key value highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task3-010.png "Cognitive search keys")

13. Also make note of the name of your search service in the text document.

    ![The Search Service name is highlighted on the Keys screen.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task3-011.png "Search service name")

14. Open Visual Studio Code.

15. From the **File** menu, select **Open file** then choose to open **Hands-on lab/artifacts/pocformreader.py**.

16. Update Lines 8, 10, and 18 with the appropriate values indicated below:

    - Line 8: The endpoint of Form Recognizer Service.

    - Line 10: The Blob Service SAS URL storage account with your Train and Test invoice folders.

    - Line 18: The KEY1 value for your Form Recognizer Service.

    ![The source code listing of pocformreader.py is displayed with the lines mentioned above highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task2a-06.png "The source listing of pocofrmreader.py")

17. Save the file.

18. Select Run, then Start Debugging.

    ![The VS Code File menu is shown with Run selected and Start Debugging highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task2a-07.png "The VS Code File menu")

19. In the **Debug Configuration**, select to debug the **Python File - Debug the currently active Python File** value.

    ![The Debug Configuration selection is shown with Python File - Debug the currently active Python File highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task2a-08.png "Debug Configuration selection")

20. This process will take a few minutes to complete. When it completes, you should see an output similar to what is seen in the screenshot below. The output should also contain a modelId. Copy and paste this value into your text file to use later

    ![A sample output of the python script is shown with a modelId value highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task2a-09.png "Visual Studio Code output window")

    >**Note**: If you receive an error stating the **requests** module is not found, from the terminal window in Visual Studio code, execute: **pip install requests**

    >**Note**: If you receive an exception related to SystemExit, this is a known issue in the Python debugger and can be safely ignored. Continue or Terminate the debug execution of the script.

<div align="right"><a href="#placeholder">↥ back to top</a></div>

### Task 3: Configure a skillset with Form Recognizer

1. Open a new instance of Visual Studio Code.

2. In Visual Studio Code open the folder **Hands-on lab/environment-setup/functions**.

   ![The file structure of the /environment-setup/functions folder is shown.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task1-001.png "The file structure of the functions folder")

3. In the **GetInvoiceData/\_\_init\_\_.py** file, update lines 66, 68, 70, and 73 with the appropriate values for your environment, the values that need replacing are located between **\<\<** and **\>\>** values.

   ![The __init__.py code listing is displayed.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task1-step2.png "The __init__.py code listing")

4. Use the Azure Functions extension to publish to a new Azure function. If you don't see the Azure Functions panel, go to the **View** menu, select **Open View...** and choose **Azure**. If the panel shows the **Sign-in to Azure** link, select it and log into Azure. Select the **Publish** button at the top of the panel.

   ![The Azure Functions extension panel in VS Code is displayed highlighting the button to publish the function.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task1-002.png "The Azure Function panel")

    - If prompted for a subscription, select the same subscription as your Synapse workspace.

    - If prompted for the folder to deploy, select **GetInvoiceData**.
  
    - Choose to **+ Create new Function App in Azure...** (the first one).

    - Give this function a unique name, relative to form recognition.

        ![The Create new function App in Azure dialog is shown with the name populated.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task1-003.png "The Create new function App in Azure dialog")

    - For the runtime select Python 3.7.

        ![The python runtime version selection dialog is shown with Python 3.7 highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task1-004.png "Setting the Python runtime version")

    - Deploy the function to the same region as your Synapse workspace.

        ![The Region selection dialog is shown.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task1-005.png "The region selection dialog")

5. Once publishing has completed, return to the Azure Portal and search for a resource group that was created with the same name as the Azure Function App.

6. Within this resource group, open the **Function App** resource with the same name.

   ![A resource listing is shown with the Function App highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/formrecognizerresourcelist.png "Resource group listing")

7. From the left menu, beneath the **Functions** heading, select **Functions**.

8. From the Functions listing, select **GetInvoiceData**.

9. From the toolbar menu of the **GetInvoiceData** screen, select the **Get Function Url** item, then copy this value to your text document for later reference.

    ![The GetInvoiceData function screen is shown with the Get Function Url button highlighted in the taskbar and the URL displayed in a textbox.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/azurefunctionurlvalue.png "GetInvoiceData function screen")

10. Now that we have the function published and all our resources created, we can create the skillset. This will be accomplished using **Postman**. Open Postman.

11. From the **File** menu, select **Import** and choose to import the postman collection from **Hands-on lab/environment-setup/skillset** named **InvoiceKnowledgeStore.postman_collection.json**.

    ![The Postman File menu is expanded with the Import option selected.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task3-004.png "Postman File menu")

    ![The Postman file import screen is displayed with the Upload files button highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task3-005.png "The Postman Import Screen")

    ![The file selection dialog is shown with the file located in the skillset folder highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task3-006.png "File selection dialog")

12. Select **Import**.

13. In Postman, the Collection that was imported will give you 4 items in the **Create a KnowledgeStore** collection. These are: Create Index, Create Datasource, Create the skillset, and Create the Indexer.

    ![The Collections pane is shown with the Create a KnowledgeStore collection expanded with the four items indicated above.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task3-007.png "The Postman Collections Pane")

14. The first thing we need to do, is edit some properties that will affect each of the calls in the collection. Hover over the **Create a KnowledgeStore** collection, and select the ellipsis button **...**, and then select **Edit**.

    ![In Postman, the ellipsis is expanded next to the Create a KnowledgeStore collection with the edit menu option selected.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task3-008.png "Editing the Postman Collection")

15. In the Edit Collection screen, select the **Variables** tab.

    ![In the Edit Collection screen, the Variables tab is selected.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task3-009.png "Edit Collection variables screen")

16. We are going to need to edit each one of these variables to match the following:

    | Variable | Value |
    |-------|-------|
    | admin-key  | The key from the cognitive search service you created. |
    | search-service-name | The name of the cognitive search service. |
    | storage-account-name | asastore{{suffix}} |
    | storage-connection-string | The connection string from the asastore{{suffix}} storage account. |
    | datasourcename | Enter **invoices** |
    | indexer-name | Enter **invoice-indexer** |
    | index-name | Enter **invoice-index** |
    | skillset-name | Enter **invoice-skillset** |
    | storage-container-name | Enter **invoices** |
    | skillset-function | Enter function URL from the function you published.|

17. Select **Update** to update the collection with the modified values.

    ![The Edit Collection Variables screen is shown with a sampling of modified values.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task3-014.png "The Edit Collection Values screen")

18. Expand the **Create a KnowledgeStore** collection, and select the **Create Index** call, then select the **Body** tab and review the content. For this call, and every subsequent call from Postman - ensure the Content Type is set to **JSON**.

    ![The Create Index call is selected from the collection, and the Body tab is highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task3-015.png "The Create Index Call")

    ![The Postman Body tab is selected with the JSON item highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/postman_jsoncontenttype.png "The Postman Body tab")

19. Select "Send".

    ![The Postman send button is selected.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task3-016.png "Send button")

20. You should get a response that the index was created.

    ![The Create Index response is displayed in Postman with the Status of 201 Created highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task3-017.png "The Create Index call response")

21. Do the same steps for the **Create Datasource, Create the Skillset, and Create the indexer** calls.

22. After you Send the Indexer request, if you navigate to your search service you should see your indexer running, indicated by the in-progress indicator. It will take a couple of minutes to run.

    ![The invoice-indexer is shown with a status of in-progress.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task3-018.png "The invoice-indexer status")

23. Once the indexer has run, it will show two successful documents. If you go to your Blob storage account, **asastore{suffix}** and look in the **invoices-json** container you will see two folders with .json documents in them.

    ![The execution history of the invoice-indexer is shown as successful.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task3-019.png "The execution history of the invoice-indexer")

    ![The invoices-json container is shown with two folders. A JSON file is shown in the blob window.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task3-020.png "Contents of the invoices-json container")

<div align="right"><a href="#placeholder">↥ back to top</a></div>

### Task 4: Create the Synapse Pipeline

1. Open your Synapse workspace.

    ![The Azure Synapse Workspace resource screen is shown with the Launch Synapse Studio button highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-001.png)

2. Expand the left menu and select the **Develop** item. From the **Develop** blade, expand the **+** button and select the **SQL script** item.

    ![The left menu is expanded with the Develop item selected. The Develop blade has the + button expanded with the SQL script item highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/develop_newsqlscript_menu.png "Creating a new SQL script")

3. In the query tab toolbar menu, ensure you connect to your SQL Pool, `SQLPool01`.

    ![The query tab toolbar menu is displayed with the Connect to set to the SQL Pool.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/querytoolbar_connecttosqlpool.png "Connecting to the SQL Pool")

4. In the query window, copy and paste the following query to create the invoice information table. Then select the **Run** button in the query tab toolbar.

    ```sql
      CREATE TABLE [wwi_mcw].[Invoices]
      (
        [TransactionId] [uniqueidentifier]  NOT NULL,
        [CustomerId] [int]  NOT NULL,
        [ProductId] [smallint]  NOT NULL,
        [Quantity] [tinyint]  NOT NULL,
        [Price] [decimal](9,2)  NOT NULL,
        [TotalAmount] [decimal](9,2)  NOT NULL
      );
    ```

5. At the far right of the top toolbar, select the **Discard all** button as we will not be saving this query. When prompted, choose to **Discard changes**.

   ![The top toolbar menu is displayed with the Discard all button highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/toptoolbar_discardall.png "Discarding all changes")

6. Select the **Integrate** hub from the left navigation.

    ![The Integrate hub is selected from the left navigation.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-012.png "The Integrate hub")

7. In the Integrate blade, expand the **+** button and then select **Pipeline** to create a new pipeline.

    ![The + button is expanded with the pipeline option selected.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-013.png "Create a new pipeline")

8. Name your pipeline **InvoiceProcessing**.

    ![The new pipeline properties are shown with InvoiceProcessing entered as the name of the pipeline.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-014.png "Naming the pipeline")

9. On the pipeline taskbar, select **Add trigger** then choose **New/Edit** to create an event to start the pipeline.

    ![The Add trigger button is expanded with the New/Edit option selected.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-015.png "New Trigger menu item")

10. On the Add triggers form, select  **+New** from the **Choose trigger** dropdown.

    ![The Add triggers form is displayed with the Choose trigger dropdown expanded and the +New item is selected.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-016.png "Choosing to create a new trigger")

11. For this exercise, we're going to do a schedule. However, in the future you'll also be able to use an event-based trigger that would fire off new JSON files being added to blob storage. Set the trigger to start every 5 minutes, then select **OK**.

    ![The new trigger form is displayed with the trigger set to start every 5 minutes.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-017.png "New trigger form")

12. Select **OK** on the Run Parameters form, nothing needs to be done here.

13. Next we need to add a Data Flow to the pipeline. Under Activities, expand **Move & transform** then drag and drop a **Data flow** onto the designer canvas.

    ![The pipeline designer is shown with an indicator of a drag and drop operation of the data flow activity.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-018.png "The Data flow activity")

14. On the **Adding data flow** form, select **Create new data flow** and select **Data flow**.

    ![The Adding data flow form is displayed populated with the preceding values.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-019.png)

15. On the **Properties** blade of the new Data Flow, on **General** tab, enter **NewInvoicesProcessing** in the **Name** field.

16. On the **NewInvoicesProcessing** data flow design canvas. Select the **Add source** box.

    ![The NewInvoicesProcessing designer is shown with the Add source box selected.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-020.png "The NewInvoicesProcessing designer")

17. In the bottom pane, name the output stream **jsonInvoice**, leave the source type as **Dataset**, and keep all the remaining options set to their defaults. Select **+New** next to the Dataset field.

    ![The Source settings tab is displayed populated with the name of jsonInvoice and the +New button next to the Dataset field is selected.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-021.png "Source Settings")

18. In the **New dataset blade**, select **Azure Blob Storage** then select **Continue**.

    ![The New dataset blade is displayed with Azure Blob Storage selected.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-022.png "Azure Blob Storage dataset")

19. On the **Select format** blade, select **Json** then select **Continue**.

    ![The select format screen is displayed with Json selected as the type.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-023.png "Select format form")

20. On the **Set properties** screen, name the dataset **InvoicesJson** then for the linked service field, choose the Azure Storage linked service **asastore{suffix}**.

    ![A portion of the Set properties form is displayed populated with the above values.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-024.png "Dataset Set properties form")

21. For the file path field, enter **invoices-json** and set the import schema field to **From sample file**.

    ![The set properties form is displayed with the file path and import schema fields populated as described.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-025.png "Data set properties form")

22. Select **Browse** and select the file located at **Hands-on lab/environment-setup/synapse/sampleformrecognizer.json** and select **OK**.

    ![The Set properties form is displayed with the sampleformrecognizer.json selected as the selected file.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-026.png "Data set properties form")

23. Select the **Source options** tab on the bottom pane. Add \*/\* to the Wildcard paths field.

    ![The Source options tab is shown with the Wildcard paths field populated as specified.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-048.png "Source options tab")

24. On the Data flow designer surface, select **+** to the lower right of the source activity to add another step in your data flow.

    ![The + button is highlighted to the lower right of the source activity.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-028.png "Adding a data flow step")

25. From the list of options, select **Derived column** from beneath the **Schema modifier** section.

    ![With the + button expanded, Derived column is selected from the list of options.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-029.png "Adding a derived column activity")

26. On the **Derived column's settings** tab, provide the output stream name of **RemoveCharFromStrings**. Then for the Columns field, select the following 3 columns and configure them as follows, using the **Open expression builder** link for the expressions:

    | Column | Expression |
    |--------|------------|
    | productprice | toDecimal(replace(productprice,'$','')) |
    | totalcharges | toDecimal(replace(replace(totalcharges,'$',''),',','')) |
    | quantity | toInteger(replace(quantity,',','')) |

     ![The Derived column's settings tab is shown with the fields populated as described.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-030.png "The derived column's settings tab")

27. Return to the Data flow designer, select the **+** next to the derived column activity to add another step to your data flow.

28. This time select the **Alter Row** from beneath the **Row modifier** section.

    ![In the Row modifier section, the Alter Row option is selected.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-031.png "The Alter row activity")

29. On the **Alter row settings** tab on the bottom pane, Name the Output stream **AlterTransactionID**, and leave the incoming stream set to the default value. Change **Alter row conditions** field to **Upsert If** and then set the expression to **notEquals(transactionid,"")**

    ![The Alter row settings tab is shown populated with the values described above.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-032.png "The Alter row settings tab")

30. Return to the Data flow designer, select the **+** to the lower right of the **Alter Row** activity to add another step into your data flow.

31. Within the **Destination** section, select **Sink**.

    ![In the activity listing, the sink option is selected from within the Destination section.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-033.png "The Sink Activity")

32. On the bottom pane, with the **Sink** tab selected, name the Output stream name **SQLDatabase** and leave everything else set to the default values. Next to the **Dataset** field, select **+New** to add a new Dataset.

    ![The sink tab is shown with the output stream name set to SQLDatabase and the +New button selected next to the Dataset field.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-034.png "The Sink tab")

33. On the **New integration dataset** blade, enter **Azure Synapse** as a search term and select the **Azure Synapse Analytics** item. Select **Continue**.

    ![The New integration dataset form is shown with Azure Synapse entered in the search box and the Azure Synapse Analytics item highlighted.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/dataset_azuresynapseanalytics.png "Azure Synapse Analytics Dataset")

34. Set the name of the Dataset to **InvoiceTable** and choose the **sqlpool01** Linked service. Choose **Select from existing table** and choose the **wwi_mcw.Invoices** table. If you don't see it in the list of your table names, select the **Refresh** button and it should show up. Select **OK**.

    ![The Dataset Set properties form is displayed populated as described.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-036.png "Set properties form")

35. In the bottom pane, with the Sink activity selected on the data flow designer, select the **Settings** tab and check the box to **Allow upsert**. Set the **Key columns** field to **transactionid**.

    ![The Settings tab of the Sink activity is shown and is populated as described.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-037.png "Sink Settings tab")

36. Select the **Mapping** tab, disable the **Auto mapping** setting and configure the mappings between the json file and the database. Select **+ Add mapping** then choose **Fixed mapping** to add the following mappings:

    | Input column | Output column |
    |--------------|---------------|
    | transactionid | TransactionId |
    | productid | ProductId |
    | customerid | CustomerId |
    | productprice | Price |
    | quantity  | Quantity |
    | totalcharges | TotalAmount |

    ![The Mapping tab is displayed with Auto Mapping disabled and the column mappings from the table above are defined.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-038.png "The Mapping tab")

37. Return to the **InvoiceProcessing** pipeline by selecting its tab at the top of the workspace.

    ![The InvoiceProcessing tab is selected at the top of the workspace.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-039.png "The InvoiceProcessing pipeline tab")

38. Select the data flow activity on the pipeline designer surface, then in the bottom pane, select the **Settings** tab.

    ![The data flow activity Settings tab is displayed.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-040.png "The Settings tab")

39. Under the **PolyBase** settings, set the **Staging linked service** to the **asastore{suffix}** linked service. Enter **invoices-staging** as the **Storage staging folder**.

    ![The data flow activity Settings tab is displayed with its form populated as indicated above.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-041.png "The Settings tab")

40. Select **Publish All** from the top toolbar.

    ![The Publish All button is selected from the top toolbar.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-042.png "The Publish all button")

41. Select **Publish**.

42. Within a few moments, you should see a notification that Publishing completed.

    ![The Publishing completed notification is shown.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-043.png "The Publishing Completed notification")

43. From the left menu, select the **Monitor** hub, then ensure the **Pipeline runs** option is selected from the hub menu.

    ![The Monitor hub is selected from the left menu.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-044.png "The Monitor Hub menu option")

44. In approximately 5 minutes, you should see the **InvoiceProcessing** pipeline begin processing. You may need to refresh this list to see it appear, a refresh button is located in the toolbar.

    ![On the Pipeline runs list, the InvoiceProcessing pipeline is shown as in-progress.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-045.png "The Pipeline runs list")

45. After about 3 or 4 minutes it will complete. You may need to refresh the list to see the completed pipeline.

    ![The Pipeline runs list is displayed with the InvoiceProcessing pipeline shown as succeeded.](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-046.png "The pipeline runs list")

46. From the left menu, select the **Develop** hub, then expand the **+** button an choose **SQL Script**. Ensure the proper database is selected, then run the following query to verify the data from the two test invoices.

    ```SQL
    SELECT * FROM wwi_mcw.Invoices
    ```

    ![show the data in the databases](https://raw.githubusercontent.com/microsoft/MCW-Azure-Synapse-Analytics-and-AI/master/Hands-on%20lab/media/ex5-task4-047.png)

<div align="right"><a href="#placeholder">↥ back to top</a></div>