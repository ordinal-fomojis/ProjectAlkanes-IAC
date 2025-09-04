resource "azurerm_storage_account" "storage_account" {
  name                     = "shovelstorage${var.id}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "function_app_service_plan_prod" {
  name                = "shovel-function-serviceplan-prod${local.postfix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_name            = "FC1"
  os_type             = "Linux"
}

resource "azurerm_storage_container" "storage_container_prod" {
  name                  = "flex-container-prod"
  storage_account_id    = azurerm_storage_account.storage_account.id
  container_access_type = "private"
}

resource "azurerm_function_app_flex_consumption" "function_app_prod" {
  name                = "shovel-functionapp-prod${local.postfix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  service_plan_id = azurerm_service_plan.function_app_service_plan_prod.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.storage_account.primary_blob_endpoint}${azurerm_storage_container.storage_container_prod.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.storage_account.primary_access_key
  https_only                  = true

  runtime_name    = "node"
  runtime_version = "22"

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.app_insights.connection_string

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

resource "azurerm_role_assignment" "keyvault_function_roleassignment_prod" {
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_function_app_flex_consumption.function_app_prod.identity.0.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_service_plan" "function_app_service_plan_nonprod" {
  name                = "shovel-function-serviceplan-nonprod${local.postfix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_name            = "FC1"
  os_type             = "Linux"
}

resource "azurerm_storage_container" "storage_container_nonprod" {
  name                  = "flex-container-nonprod"
  storage_account_id    = azurerm_storage_account.storage_account.id
  container_access_type = "private"
}

resource "azurerm_function_app_flex_consumption" "function_app_nonprod" {
  name                = "shovel-functionapp-nonprod${local.postfix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  service_plan_id = azurerm_service_plan.function_app_service_plan_nonprod.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.storage_account.primary_blob_endpoint}${azurerm_storage_container.storage_container_nonprod.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.storage_account.primary_access_key
  https_only                  = true

  runtime_name    = "node"
  runtime_version = "22"

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.app_insights.connection_string

    cors {
      allowed_origins = ["https://portal.azure.com"]
    }
  }

  app_settings = {
    "NODE_ENV"                   = "production"
    "APP_ENV"                    = "nonprod"
    "DOTENV_PRIVATE_KEY_NONPROD" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.key_vault.name};SecretName=DotenvPrivateKeyNonProd)"
    "DOTENV_PATH"                = "env/.env.nonprod"
  }
}

resource "azurerm_role_assignment" "keyvault_function_roleassignment_nonprod" {
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_function_app_flex_consumption.function_app_nonprod.identity.0.principal_id
  principal_type       = "ServicePrincipal"
}
