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
  postfix = var.id == "" ? "" : "-${var.id}"
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

  sku_name = "standard"
}
