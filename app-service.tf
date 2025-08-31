resource "azurerm_service_plan" "service_plan" {
  name                = "shovel-serviceplan${local.postfix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_name            = "P0v3"
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
    "NODE_ENV"                = "production"
    "APP_ENV"                 = "prod"
    "DOTENV_PRIVATE_KEY_PROD" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.key_vault.name};SecretName=DotenvPrivateKeyProd)"
    "DOTENV_PATH"             = "env/.env.prod"
  }
}

resource "azurerm_linux_function_app_slot" "function_app_nonprod_slot" {
  name = "non-prod"

  function_app_id            = azurerm_linux_function_app.function_app.id
  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key
  https_only                 = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.app_insights.connection_string
    always_on                              = false

    application_stack {
      node_version = "22"
    }
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

resource "azurerm_linux_web_app" "webapp" {
  name                = "shovel-webapp${local.postfix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.service_plan.id
  https_only          = true

  app_settings = {
    "DOTENV_PRIVATE_KEY_PROD" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.key_vault.name};SecretName=DotenvPrivateKeyProd)"
    "APP_ENV"                 = "prod"
    "DOTENV_PATH"             = "env/.env.prod"
    "NODE_ENV"                = "production"
  }

  sticky_settings {
    app_setting_names = ["APP_ENV", "DOTENV_PATH", "DOTENV_PRIVATE_KEY_PROD", "DOTENV_PRIVATE_KEY_NONPROD"]
  }

  identity {
    type = "SystemAssigned"
  }

  site_config {
    health_check_path                 = "/api/health"
    health_check_eviction_time_in_min = 3
    ftps_state                        = "Disabled"
    minimum_tls_version               = "1.2"
    ip_restriction_default_action     = "Deny"
    application_stack {
      node_version = "22-lts"
    }
    ip_restriction {
      service_tag               = "AzureFrontDoor.Backend"
      ip_address                = null
      virtual_network_subnet_id = null
      action                    = "Allow"
      priority                  = 100
      headers {
        x_azure_fdid      = [azurerm_cdn_frontdoor_profile.frontdoor.resource_guid]
        x_fd_health_probe = []
        x_forwarded_for   = []
        x_forwarded_host  = []
      }
      name = "Allow traffic from Front Door"
    }
  }
}

locals {
  environments = {
    "stage" = {
      dotenv = "prod"
    }
    "dev" = {
      dotenv = "dev"
    }
    "testnet" = {
      dotenv = "testnet"
    }
    "mock" = {
      dotenv = "mock"
    }
  }
}

resource "azurerm_linux_web_app_slot" "slot" {
  for_each       = local.environments
  name           = each.key
  app_service_id = azurerm_linux_web_app.webapp.id

  app_settings = {
    "DOTENV_PRIVATE_KEY_${each.value.dotenv == "prod" ? "PROD" : "NONPROD"}" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.key_vault.name};SecretName=DotenvPrivateKey${each.value.dotenv == "prod" ? "Prod" : "NonProd"})"
    "APP_ENV"                                                                = each.key
    "DOTENV_PATH"                                                            = "env/.env.${each.value.dotenv}"
    "NODE_ENV"                                                               = "production"
  }

  identity {
    type = "SystemAssigned"
  }

  site_config {
    health_check_path                 = "/api/health"
    health_check_eviction_time_in_min = 3
    ftps_state                        = "Disabled"
    minimum_tls_version               = "1.2"
    application_stack {
      node_version = "22-lts"
    }
  }
}
