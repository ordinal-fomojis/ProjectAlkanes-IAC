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
      name   = "",
      domain = "api.shovel.space",
      app_settings = {
        "MOCK_BTC" = "false"
      }
    },
    "mock" = {
      name   = "mock",
      domain = "mock.api.shovel.space",
      app_settings = {
        "MOCK_BTC" = "false"
      }
    }
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "alkanes-${var.env_name}"
  location = "East US 2"
}

resource "azurerm_service_plan" "service_plan" {
  name                = "alkanes-serviceplan-${var.env_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_name            = "B1"
  os_type             = "Linux"
}

resource "azurerm_storage_account" "storage_account" {
  name                     = "alkanesstorage${var.env_name}"
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
  name                = "alkanes-loganalytics-${var.env_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  retention_in_days   = 30
}

resource "azurerm_application_insights" "app_insights" {
  name                = "alkanes-appinsights-${var.env_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.log_analytics_workspace.id
}

resource "azurerm_linux_function_app" "function_app" {
  name                = "alkanes-functionapp-${var.env_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  service_plan_id = azurerm_service_plan.service_plan.id

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
    "DOTENV_PRIVATE_KEY_PRODUCTION" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.key_vault.name};SecretName=DotenvPrivateKey)"
  }
}

resource "azurerm_linux_web_app" "webapp" {
  for_each            = local.environments
  name                = "alkanes-webapp${each.value.name == "" ? "" : "-${each.value.name}"}-${var.env_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.service_plan.id
  https_only          = true

  app_settings = merge(each.value.app_settings, {
    "DOTENV_PRIVATE_KEY_PRODUCTION" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.key_vault.name};SecretName=DotenvPrivateKey)"
    "NODE_ENV"                      = "production"
  })

  identity {
    type = "SystemAssigned"
  }

  site_config {
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 3
    application_stack {
      node_version = "22-lts"
    }
  }
}

resource "azurerm_key_vault" "key_vault" {
  name                        = "alkanes-kv-${var.env_name}"
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

resource "azurerm_app_service_custom_hostname_binding" "host_binding" {
  for_each            = azurerm_linux_web_app.webapp
  hostname            = "mock.api.shovel.space"
  app_service_name    = each.value.webapp.name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_app_service_managed_certificate" "managed_certificate" {
  for_each                   = azurerm_app_service_custom_hostname_binding.host_binding
  custom_hostname_binding_id = each.value.id
}

resource "azurerm_app_service_certificate_binding" "certificate_binding" {
  for_each            = azurerm_linux_web_app.webapp
  hostname_binding_id = azurerm_app_service_custom_hostname_binding.host_binding[each.key].id // azurerm_app_service_custom_hostname_binding.mock_host_binding.id
  certificate_id      = azurerm_app_service_managed_certificate.managed_certificate[each.key].id
  ssl_state           = "SniEnabled"
}
