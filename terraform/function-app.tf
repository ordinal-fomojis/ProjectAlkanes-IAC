locals {
  fa_environments = {
    "prod" = {
      dotenv = "prod"
    }
    "nonprod" = {
      dotenv = "nonprod"
    }
  }
}

resource "azurerm_storage_account" "storage_account" {
  name                     = "shovelstorage${var.id}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "function_app_service_plan" {
  for_each            = local.fa_environments
  name                = "shovel-function-serviceplan-${each.key}${local.postfix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_name            = "FC1"
  os_type             = "Linux"
}

resource "azurerm_storage_container" "storage_container" {
  for_each              = local.fa_environments
  name                  = "flex-container-${each.key}"
  storage_account_id    = azurerm_storage_account.storage_account.id
  container_access_type = "private"
}

resource "azurerm_function_app_flex_consumption" "function_app" {
  for_each            = local.fa_environments
  name                = "shovel-functionapp-${each.key}${local.postfix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  service_plan_id = azurerm_service_plan.function_app_service_plan[each.key].id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.storage_account.primary_blob_endpoint}${azurerm_storage_container.storage_container[each.key].name}"
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
    "DOTENV_PRIVATE_KEY_${each.value.dotenv == "prod" ? "PROD" : "NONPROD"}" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.key_vault.name};SecretName=DotenvPrivateKey${each.value.dotenv == "prod" ? "Prod" : "NonProd"})"
    "APP_ENV"                                                                = each.key
    "DOTENV_PATH"                                                            = "env/.env.${each.value.dotenv}"
    "NODE_ENV"                                                               = "production"
  }
}

resource "azurerm_role_assignment" "keyvault_function_roleassignment" {
  for_each             = local.fa_environments
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_function_app_flex_consumption.function_app[each.key].identity.0.principal_id
  principal_type       = "ServicePrincipal"
}
