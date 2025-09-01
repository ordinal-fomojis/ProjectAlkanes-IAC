resource "azurerm_service_plan" "function_app_service_plan" {
  name                = "shovel-function-serviceplan${local.postfix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_name            = "B1"
  os_type             = "Linux"
}

resource "azurerm_storage_account" "storage_account" {
  name                     = "shovelstorage${var.id}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "storage_container" {
  name                  = "deploymentpackage"
  storage_account_id    = azurerm_storage_account.storage_account.id
  container_access_type = "private"
}

resource "azurerm_linux_function_app" "function_app" {
  name                = "shovel-functionapp${local.postfix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  service_plan_id = azurerm_service_plan.function_app_service_plan.id

  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key
  https_only                 = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.app_insights.connection_string
    always_on                              = true

    application_stack {
      node_version = "22"
    }
    cors {
      allowed_origins = ["https://portal.azure.com"]
    }
  }

  app_settings = {
    "NODE_ENV"                = "production"
    "APP_ENV"                 = "prod"
    "DOTENV_PRIVATE_KEY_PROD" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.key_vault.name};SecretName=DotenvPrivateKeyProd)"
    "DOTENV_PATH"             = "env/.env.prod"
  }
}

# resource "azurerm_linux_function_app_slot" "function_app_nonprod_slot" {
#   name = "nonprod"

#   function_app_id            = azurerm_linux_function_app.function_app.id
#   storage_account_name       = azurerm_storage_account.storage_account.name
#   storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key
#   https_only                 = true

#   identity {
#     type = "SystemAssigned"
#   }

#   site_config {
#     application_insights_connection_string = azurerm_application_insights.app_insights.connection_string
#     always_on                              = false

#     application_stack {
#       node_version = "22"
#     }
#     cors {
#       allowed_origins = ["https://portal.azure.com"]
#     }
#   }

#   app_settings = {
#     "NODE_ENV"                   = "production"
#     "APP_ENV"                    = "nonprod"
#     "DOTENV_PRIVATE_KEY_NONPROD" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.key_vault.name};SecretName=DotenvPrivateKeyNonProd)"
#     "DOTENV_PATH"                = "env/.env.nonprod"
#   }
# }
