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

resource "random_pet" "random_id" {
  separator = ""
}

resource "azurerm_resource_group" "rg" {
  name     = "alkanes-${var.env_name}"
  location = "East US 2"
}

resource "azurerm_service_plan" "service_plan" {
  name                = "alkanes-serviceplan-${random_pet.random_id}-${var.env_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_name            = "FC1"
  os_type             = "Linux"
}

resource "azurerm_storage_account" "storage_account" {
  name                     = "alkanesstorage${random_pet.random_id}${var.env_name}"
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

resource "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  name                = "alkanes-loganalytics-${random_pet.random_id}-${var.env_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  retention_in_days   = 30
}

resource "azurerm_application_insights" "app_insights" {
  name                = "alkanes-appinsights-${random_pet.random_id}-${var.env_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.log_analytics_workspace.id
}

resource "azurerm_function_app_flex_consumption" "function_app" {
  name                        = "alkanes-functionapp-${random_pet.random_id}-${var.env_name}"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  service_plan_id             = azurerm_service_plan.service_plan.id
  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.storage_account.primary_blob_endpoint}${azurerm_storage_container.storage_container.name}"
  storage_authentication_type = "SystemAssignedIdentity"
  runtime_name                = "node"
  runtime_version             = "22"

  identity {
    type = "SystemAssigned"
  }
  site_config {
    application_insights_connection_string = azurerm_application_insights.app_insights.connection_string
  }
  app_settings = {
    "AzureWebJobsStorage"              = "" //workaround until https://github.com/hashicorp/terraform-provider-azurerm/pull/29099 gets released
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.storage_account.name
    "DOTENV_PRIVATE_KEY_PRODUCTION"    = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.keyVault.name};SecretName=DotenvPrivateKey)"
  }
}

resource "azurerm_linux_web_app" "webapp" {
  name                  = "alkanes-webapp-${random_pet.random_id}-${var.env_name}"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  service_plan_id       = azurerm_service_plan.service_plan.id
  https_only            = true

  app_settings = {
    "DOTENV_PRIVATE_KEY_PRODUCTION"    = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.keyVault.name};SecretName=DotenvPrivateKey)"
  }

  site_config { 
    health_check_path = "/health"
    application_stack {
      node_version = "22-lts"
    }
  }
}

resource "azurerm_key_vault" "key_vault" {
  name                        = "alkanes-kv-${random_pet.random_id}-${var.env_name}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  enabled_for_disk_encryption = true
  enable_rbac_authorization   = true

  sku_name = "standard"
}

resource "azurerm_role_assignment" "storage_roleassignment" {
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_function_app_flex_consumption.function_app.identity.0.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "keyvault_function_roleassignment" {
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_function_app_flex_consumption.function_app.identity.0.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "keyvault_webapp_roleassignment" {
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.webapp.identity.0.principal_id
  principal_type       = "ServicePrincipal"
}
