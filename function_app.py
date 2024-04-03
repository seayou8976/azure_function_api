import logging
import azure.functions as func
import os
from azure.cosmos import CosmosClient

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUD)


@app.route(route="http_trigger", methods=["GET", "POST"])
def http_trigger(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("Python HTTP trigger function processed a request.")

    # Initialize Cosmos Client
    url = os.getenv("COSMOS_DB_URL")
    key = os.getenv("COSMOS_DB_KEY")
    client = CosmosClient(url, credential=key)

    # Select database
    database_name = "AzureResume"
    database = client.get_database_client(database_name)

    # Select container
    container_name = "VisitorCount"
    container = database.get_container_client(container_name)

    # Get the request method
    method = req.method

    if method == "GET":
        # Retrieve a value
        item_id = "index"
        item = container.read_item(item=item_id, partition_key=item_id)
        return func.HttpResponse(str(item["count"]))

    elif method == "POST":
        # Increment count
        item_id = "index"
        item = container.read_item(item=item_id, partition_key=item_id)
        item["count"] += 1
        container.replace_item(item=item_id, body=item)
        return func.HttpResponse("View count incremented", status_code=200)
