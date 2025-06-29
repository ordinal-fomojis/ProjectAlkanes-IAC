terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }

  backend "azurerm" {
    resource_group_name  = "iac"
    storage_account_name = "fomojisterraform"
    container_name       = "tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  blobStorageAndContainer = "${azurerm_storage_account.storageAccount.primary_blob_endpoint}deploymentpackage"
  location                = "East US 2"
}

resource "azurerm_resource_group" "rg" {
  name     = "alkanes-${var.env_name}"
  location = local.location
}

resource "azurerm_service_plan" "servicePlan" {
  name                = "alkanes-serviceplan-${var.env_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  sku_name            = "FC1"
  os_type             = "Linux"
}

resource "azurerm_storage_account" "storageAccount" {
  name                     = "alkanesstorage${var.env_name}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = local.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "storageContainer" {
  name                  = "deploymentpackage"
  storage_account_id    = azurerm_storage_account.storageAccount.id
  container_access_type = "private"
}

resource "azurerm_log_analytics_workspace" "logAnalyticsWorkspace" {
  name                = "alkanes-loganalytics-${var.env_name}"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
  retention_in_days   = 30
}

resource "azurerm_application_insights" "appInsights" {
  name                = "alkanes-appinsights-${var.env_name}"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.logAnalyticsWorkspace.id
}

resource "azurerm_function_app_flex_consumption" "functionApps" {
  name                        = "alkanes-functionapp-${var.env_name}"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = local.location
  service_plan_id             = azurerm_service_plan.servicePlan.id
  storage_container_type      = "blobContainer"
  storage_container_endpoint  = local.blobStorageAndContainer
  storage_authentication_type = "SystemAssignedIdentity"
  runtime_name                = "node"
  runtime_version             = "22"

  identity {
    type = "SystemAssigned"
  }
  site_config {
    application_insights_connection_string = azurerm_application_insights.appInsights.connection_string
  }
  app_settings = {
    "AzureWebJobsStorage"              = "" //workaround until https://github.com/hashicorp/terraform-provider-azurerm/pull/29099 gets released
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.storageAccount.name
    "DOTENV_PRIVATE_KEY_PRODUCTION"    = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.keyVault.name};SecretName=DotenvPrivateKey)"
  }
}

resource "azurerm_key_vault" "keyVault" {
  name                        = "alkanes-kv-${var.env_name}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  enabled_for_disk_encryption = true
  enable_rbac_authorization   = true

  sku_name = "standard"
}

resource "azurerm_role_assignment" "storage_roleassignment" {
  scope                = azurerm_storage_account.storageAccount.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_function_app_flex_consumption.functionApps.identity.0.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "keyvault_roleassignment" {
  scope                = azurerm_key_vault.keyVault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_function_app_flex_consumption.functionApps.identity.0.principal_id
  principal_type       = "ServicePrincipal"
}
