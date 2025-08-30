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
  environments = {
    "main" = {
      name  = "",
      route = "/*",
      app_settings = {
        "MOCK_BTC" = "false"
      }
    },
    "mock" = {
      name  = "mock",
      route = "/mock/*",
      app_settings = {
        "MOCK_BTC" = "true"
      }
    }
  }
  postfix = "${var.id == "" ? "" : "-${var.id}"}"
}

resource "azurerm_resource_group" "rg" {
  name     = "shovel${local.postfix}"
  location = "East US 2"
}

resource "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  name                = "shovel-loganalytics${local.postfix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  retention_in_days   = 30
}

resource "azurerm_application_insights" "app_insights" {
  name                = "shovel-appinsights${local.postfix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.log_analytics_workspace.id
}

resource "azurerm_key_vault" "key_vault" {
  name                        = "shovel-kv${local.postfix}"
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
  principal_id         = azurerm_linux_function_app.function_app.identity.0.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "keyvault_function_roleassignment" {
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.function_app.identity.0.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "keyvault_webapp_roleassignment" {
  for_each             = azurerm_linux_web_app.webapp
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value.identity.0.principal_id
  principal_type       = "ServicePrincipal"
}
