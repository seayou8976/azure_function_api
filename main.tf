terraform {
  required_version = ">= 1.5.7"
  backend "azurerm" {
    resource_group_name  = "sy4cloud"
    storage_account_name = "sy4tfstate"
    container_name       = "sy4resume-tfstate"
    key                  = "sy4resume-backend.tfstate"
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "sy4rg-backend" {
  name     = "sy4rgbackend"
  location = "North Central US"
}

resource "azurerm_storage_account" "sy4sa-backend" {
  name                     = "sy4sabackend"
  resource_group_name      = azurerm_resource_group.sy4rg-backend.name
  location                 = azurerm_resource_group.sy4rg-backend.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_cosmosdb_account" "sy4cosmos" {
  name                = "sy4dbresume"
  location            = azurerm_resource_group.sy4rg-backend.location
  resource_group_name = azurerm_resource_group.sy4rg-backend.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  enable_automatic_failover = true
  enable_free_tier = true

  consistency_policy {
    consistency_level = "Session"
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "POST"]
    allowed_origins = ["https://resume.seanyoung.me"]
    exposed_headers = ["*"]
  }

  geo_location {
    location          = azurerm_resource_group.sy4rg-backend.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_sql_database" "sy4db" {
  name                = "AzureResume"
  resource_group_name = azurerm_resource_group.sy4rg-backend.name
  account_name        = azurerm_cosmosdb_account.sy4cosmos.name
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "sy4container" {
  name                = "VistorCount"
  resource_group_name = azurerm_resource_group.sy4rg-backend.name
  account_name        = azurerm_cosmosdb_account.sy4cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.sy4db.name
  partition_key_path  = "/id"
  throughput          = 400
}

resource "azurerm_service_plan" "sy4sp" {
  name                = "sy4aspbackend"
  location            = azurerm_resource_group.sy4rg-backend.location
  resource_group_name = azurerm_resource_group.sy4rg-backend.name
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "sy4app" {
  name                       = "sy4faresume"
  location                   = azurerm_resource_group.sy4rg-backend.location
  resource_group_name        = azurerm_resource_group.sy4rg-backend.name
  service_plan_id            = azurerm_service_plan.sy4sp.id
  storage_account_name       = azurerm_storage_account.sy4sa-backend.name
  storage_account_access_key = azurerm_storage_account.sy4sa-backend.primary_access_key

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "COSMOS_DB_KEY" = azurerm_cosmosdb_account.sy4cosmos.primary_key
    "COSMOS_DB_URL" = azurerm_cosmosdb_account.sy4cosmos.endpoint
  }

  site_config {
    cors {
      allowed_origins = ["https://resume.seanyoung.me"]
    }
  }
}
