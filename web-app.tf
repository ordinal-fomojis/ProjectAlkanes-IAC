locals {
  environments = {
    "prod" = {
      dotenv = "prod"
    }
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
  app_settings = {
    for env, config in local.environments : env => {
      "DOTENV_PRIVATE_KEY_${config.dotenv == "prod" ? "PROD" : "NONPROD"}" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.key_vault.name};SecretName=DotenvPrivateKey${config.dotenv == "prod" ? "Prod" : "NonProd"})"
      "APP_ENV"                                                            = env
      "DOTENV_PATH"                                                        = "env/.env.${config.dotenv}"
      "NODE_ENV"                                                           = "production"
    }
  }
}

resource "azurerm_service_plan" "service_plan" {
  name                = "shovel-serviceplan${local.postfix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_name            = "P0v3"
  os_type             = "Linux"
}

resource "azurerm_linux_web_app" "webapp" {
  name                = "shovel-webapp${local.postfix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.service_plan.id
  https_only          = true

  app_settings = merge(local.app_settings["prod"], {
    "RATE_LIMIT_ENABLED" = "false"
  })

  sticky_settings {
    app_setting_names = ["APP_ENV", "DOTENV_PATH", "DOTENV_PRIVATE_KEY_PROD", "DOTENV_PRIVATE_KEY_NONPROD", "RATE_LIMIT_ENABLED"]
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

resource "azurerm_linux_web_app_slot" "stage_slot" {
  name           = "stage"
  app_service_id = azurerm_linux_web_app.webapp.id

  app_settings = local.app_settings.stage

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

resource "azurerm_service_plan" "service_plan_nonprod" {
  name                = "shovel-serviceplan-nonprod${local.postfix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_name            = "SHARED"
  os_type             = "Linux"
}

resource "azurerm_linux_web_app" "webapp_nonprod" {
  name                = "shovel-webapp-nonprod${local.postfix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.service_plan_nonprod.id
  https_only          = true

  app_settings = local.app_settings.dev

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

resource "azurerm_linux_web_app_slot" "nonprod_slot" {
  for_each       = toset(["testnet", "mock"])
  name           = each.key
  app_service_id = azurerm_linux_web_app.webapp_nonprod.id

  app_settings = local.app_settings[each.key]

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


resource "azurerm_load_test" "load_test" {
  location            = azurerm_resource_group.rg.location
  name                = "shovel-loadtest${local.postfix}"
  resource_group_name = azurerm_resource_group.rg.name
}
