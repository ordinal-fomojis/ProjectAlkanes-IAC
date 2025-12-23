locals {
  service_plans = {
    prod = {
      sku_name = "P0v3"
      apps = {
        prod = {
          dotenv = "prod"
          slots = {
            stage = {
              dotenv = "prod"
            }
          }
        }
      }
    }
    nonprod = {
      sku_name = "B1"
      apps = {
        dev = {
          dotenv = "dev"
        }
        mock = {
          dotenv = "mock"
        }
        # testnet = {
        #   dotenv = "nonprod"
        # }
      }
    }
  }
  apps = merge([for service_name, service in local.service_plans : {
    for app_name, app in service.apps : app_name => {
      service_name = service_name
      dotenv       = app.dotenv
      slots        = lookup(app, "slots", {})
      type         = "app"
    }
  }]...)
  slots = merge([for app_name, app in local.apps : {
    for slot_name, slot in app.slots : slot_name => {
      app_name = app_name
      dotenv   = slot.dotenv
      type     = "slot"
    }
  }]...)
  all_apps = merge(local.apps, local.slots)
  app_settings = {
    for env, config in local.all_apps : env => {
      "DOTENV_PRIVATE_KEY_${upper(config.dotenv)}" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.key_vault.name};SecretName=DotenvPrivateKey${config.dotenv == "prod" ? "Prod" : "NonProd"})"
      "APP_ENV"                                    = env
      "DOTENV_PATH"                                = "env/.env.${config.dotenv}"
      "NODE_ENV"                                   = "production"
      "RATE_LIMIT_ENABLED"                         = "false"
    }
  }
}

resource "azurerm_service_plan" "service_plan" {
  for_each                        = local.service_plans
  name                            = "shovel-serviceplan-${each.key}${local.postfix}"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  sku_name                        = each.value.sku_name
  os_type                         = "Linux"
  premium_plan_auto_scale_enabled = each.key == "prod"
}

resource "azurerm_linux_web_app" "webapp" {
  for_each            = local.apps
  name                = "shovel-webapp-${each.key}${local.postfix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.service_plan[each.value.service_name].id
  https_only          = true

  app_settings = local.app_settings[each.key]

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
    ip_restriction_default_action     = each.key == "prod" ? "Deny" : "Allow"
    application_stack {
      node_version = "22-lts"
    }
    dynamic "ip_restriction" {
      for_each = each.key == "prod" ? [0] : []
      content {
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
}

resource "azurerm_linux_web_app_slot" "webapp_slot" {
  for_each       = local.slots
  name           = each.key
  app_service_id = azurerm_linux_web_app.webapp[each.value.app_name].id

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

resource "azurerm_role_assignment" "keyvault_webapp_roleassignment" {
  for_each             = local.all_apps
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value.type == "app" ? azurerm_linux_web_app.webapp[each.key].identity.0.principal_id : azurerm_linux_web_app_slot.webapp_slot[each.key].identity.0.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_load_test" "load_test" {
  location            = azurerm_resource_group.rg.location
  name                = "shovel-loadtest${local.postfix}"
  resource_group_name = azurerm_resource_group.rg.name
}
